import { getConnection } from "../database/database";
import type { LootHistoryRow, PlayerRow, PointHistoryRow } from "../database/types";
import { Logger } from "../Logger";
import type {
    AddonExport,
    AddonLootHistoryEntry,
    AddonPlayerEntry,
    AddonPointHistoryEntry,
    ImportLog,
} from "../../shared/types";
import type { FieldPacket, PoolConnection, RowDataPacket } from "mysql2/promise";
import { makeDataBackup } from "./backup";
import type { DataExport } from "./export";
import { createPlayer } from "../database/tableFunctions/players";
import { createPointHistoryEntry } from "../database/tableFunctions/pointHistory";
import { createLootHistoryEntry } from "../database/tableFunctions/lootHistory";

// TODO: validate integrity of data.
// current player state + new point history should add up to be the new player state
// also the first new history entry per player should match (newVal - change = oldVal) with the previous one in DB

const logger = new Logger("DB import");

function getOldest(hist: { timeStamp: number }[]): number {
    let oldest = 4444444444444;
    for (const h of hist) {
        if (h.timeStamp < oldest) oldest = h.timeStamp;
    }
    return oldest;
}

async function updatePlayers(conn: PoolConnection, players: AddonPlayerEntry[]): Promise<ImportLog["players"]> {
    const log: ImportLog["players"] = [];
    const [dbPlayers] = (await conn.query<RowDataPacket[]>(`SELECT * FROM players;`)) as [PlayerRow[], FieldPacket[]];
    const dbPlayersDict: Record<string, PlayerRow> = {};
    for (const dbp of dbPlayers) {
        dbPlayersDict[dbp.playerName] = dbp;
    }

    for (const player of players) {
        const existing = dbPlayersDict[player.playerName];
        if (existing) {
            await conn.query(`UPDATE players SET classId=?, points=? WHERE playerName=?;`, [
                player.classId,
                player.points,
                player.playerName,
            ]);
            log.push({ old: existing, new: player });
        } else {
            await conn.query("INSERT INTO players (playerName, classId, points) VALUES (?,?,?);", [
                player.playerName,
                player.classId,
                player.points,
            ]);
            log.push({ new: player });
        }
    }

    return log;
}

async function updateLootHistory(conn: PoolConnection, history: AddonLootHistoryEntry[]): Promise<ImportLog["lootHistory"]> {
    const log: ImportLog["lootHistory"] = [];
    const oldestImport = getOldest(history) * 1000; // Addon is seconds timestamps

    const [dbHistory] = (await conn.query<RowDataPacket[]>(`SELECT * FROM lootHistory WHERE timestamp>=?;`, [
        oldestImport,
    ])) as [LootHistoryRow[], FieldPacket[]];

    const dict: Record<string, LootHistoryRow> = {};
    for (const h of dbHistory) {
        dict[h.guid] = h;
    }

    for (const importEntry of history) {
        if (dict[importEntry.guid]) continue;
        await conn.query(
            "INSERT INTO `lootHistory` (`guid`, `timestamp`, `playerName`, `itemId`, `response`) VALUES (?, ?, ?, ?, ?);",
            [
                importEntry.guid,
                importEntry.timeStamp * 1000,
                importEntry.playerName,
                importEntry.itemId,
                importEntry.response,
            ]
        );
        log.push({ new: importEntry });
    }

    return log;
}

async function updatePointHistory(
    conn: PoolConnection,
    history: AddonPointHistoryEntry[]
): Promise<ImportLog["pointHistory"]> {
    const log: ImportLog["pointHistory"] = [];
    const oldestImport = getOldest(history) * 1000; // Addon is seconds timestamps

    const [dbHistory] = (await conn.query<RowDataPacket[]>(`SELECT * FROM pointHistory WHERE timestamp>=?;`, [
        oldestImport,
    ])) as [PointHistoryRow[], FieldPacket[]];

    // key = time + player
    const dict: Record<string, PointHistoryRow> = {};
    for (const h of dbHistory) {
        dict[h.guid] = h;
    }

    for (const importEntry of history) {
        const timeStampForDb = importEntry.timeStamp * 1000;
        if (dict[importEntry.guid]) continue;
        const res = await createPointHistoryEntry(
            {
                guid: importEntry.guid,
                timestamp: timeStampForDb,
                playerName: importEntry.playerName,
                pointChange: importEntry.change,
                newPoints: importEntry.newPoints,
                changeType: importEntry.type,
                reason: importEntry.reason,
            },
            conn
        );
        if (res.isError) throw new Error("DB error on importing new point hist entry.");
        log.push({ new: importEntry });
    }

    return log;
}

/**
 * Import addon export into database.
 * @param data
 * @returns
 */
export const importAddonExport = async (data: AddonExport): Promise<{ error?: string; log?: ImportLog }> => {
    const conn = await getConnection();
    try {
        conn.query("LOCK TABLES players WRITE, pointHistory WRITE, lootHistory WRITE;");
        conn.beginTransaction();

        const backupSuccess = await makeDataBackup(conn, 0, "before_addon_import");
        if (!backupSuccess) return { error: "Making data backup failed!" };

        const playerLog = await updatePlayers(conn, data.players);
        const lootLog = await updateLootHistory(conn, data.lootHistory);
        const pointLog = await updatePointHistory(conn, data.pointHistory);

        await conn.commit();
        return {
            log: {
                players: playerLog,
                lootHistory: lootLog,
                pointHistory: pointLog,
            },
        };
    } catch (error) {
        await conn.rollback();
        logger.logError("Error on DB import.", error);
        return { error: "Internal error." };
    } finally {
        await conn.query("UNLOCK TABLES;");
        conn.release();
    }
};

/**
 * Import addon export into database.
 * @param data
 * @returns
 */
export const importDataExport = async (data: DataExport): Promise<boolean> => {
    const conn = await getConnection();

    const rollbackThenFalse = async () => {
        await conn.rollback();
        return false;
    };

    try {
        conn.query("LOCK TABLES players WRITE, pointHistory WRITE, lootHistory WRITE;");
        conn.beginTransaction();

        const backupSuccess = await makeDataBackup(conn, 0, "before_data_import");
        if (!backupSuccess) return rollbackThenFalse();

        await conn.query("DELETE FROM players;");
        await conn.query("DELETE FROM pointHistory;");
        await conn.query("DELETE FROM lootHistory;");

        for (const player of data.players) {
            const res = await createPlayer(player.playerName, player.classId, player.points, player.account, conn);
            if (res.isError) return rollbackThenFalse();
        }

        for (const phist of data.pointHistory) {
            const res = await createPointHistoryEntry(
                {
                    guid: phist.guid,
                    timestamp: phist.timestamp,
                    playerName: phist.playerName,
                    pointChange: phist.pointChange,
                    newPoints: phist.newPoints,
                    changeType: phist.changeType,
                    reason: phist.reason,
                },
                conn
            );
            if (res.isError) return rollbackThenFalse();
        }

        for (const lhist of data.lootHistory) {
            const res = await createLootHistoryEntry(
                lhist.guid,
                lhist.timestamp,
                lhist.playerName,
                lhist.itemId,
                lhist.response,
                conn
            );
            if (res.isError) return rollbackThenFalse();
        }

        await conn.commit();
        return true;
    } catch (error) {
        await conn.rollback();
        logger.logError("Error on DB import.", error);
        return false;
    } finally {
        await conn.query("UNLOCK TABLES;");
        conn.release();
    }
};

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
import { getAllUsers } from "../database/tableFunctions/users";

const logger = new Logger("DB import");

/**
 * Get oldest timestamp from a history array.
 * @param hist
 * @returns
 */
function getOldest(hist: { timeStamp: number }[]): number {
    let oldest = 4444444444444;
    for (const h of hist) {
        if (h.timeStamp < oldest) oldest = h.timeStamp;
    }
    return oldest;
}

/**
 * Validate loot history.
 * @param conn
 * @param lootHistory
 * @returns
 */
async function validateLootHistory(
    conn: PoolConnection,
    lootHistory: AddonLootHistoryEntry[],
    players: AddonPlayerEntry[]
): Promise<{ newEntries: Map<string, AddonLootHistoryEntry[]>; error?: string }> {
    const oldestImport = getOldest(lootHistory) * 1000; // Addon is seconds timestamps

    const [dbHistory] = (await conn.query<RowDataPacket[]>(`SELECT * FROM lootHistory WHERE timestamp>=?;`, [
        oldestImport,
    ])) as [LootHistoryRow[], FieldPacket[]];

    const dict: Record<string, LootHistoryRow> = {};
    for (const h of dbHistory) {
        dict[h.guid] = h;
    }

    // TODO: Deduplicate getting player dict.
    const [dbPlayers] = (await conn.query<RowDataPacket[]>(`SELECT * FROM players;`)) as [PlayerRow[], FieldPacket[]];
    const dbPlayersDict = new Map<string, PlayerRow>();
    for (const dbp of dbPlayers) {
        dbPlayersDict.set(dbp.playerName, dbp);
    }

    const importPlayerDict = new Map<string, AddonPlayerEntry>();
    for (const ip of players) {
        importPlayerDict.set(ip.playerName, ip);
    }

    const newEntries = new Map<string, AddonLootHistoryEntry[]>();

    for (const importEntry of lootHistory) {
        if (dict[importEntry.guid]) continue;

        if (!dbPlayersDict.has(importEntry.playerName) && !importPlayerDict.has(importEntry.playerName)) {
            return { error: `Unknown player ${importEntry.playerName} for loot entry ${importEntry.guid}`, newEntries };
        }

        if (!newEntries.has(importEntry.playerName)) newEntries.set(importEntry.playerName, []);
        newEntries.get(importEntry.playerName)!.push(importEntry);
    }

    return { newEntries };
}

/**
 * Insert previously validated loot history entries.
 * @param conn
 * @param history
 * @returns
 */
async function updateLootHistory(
    conn: PoolConnection,
    history: Map<string, AddonLootHistoryEntry[]>
): Promise<ImportLog["lootHistory"]> {
    const log: ImportLog["lootHistory"] = [];

    for (const playerEntries of history.values()) {
        for (const importEntry of playerEntries) {
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
    }

    return log;
}

/**
 * Validate player changes.
 * Checks if newly added history entries applied to current player points add up to be the imported player state.
 * @param conn
 * @param pointHistory
 * @param players
 * @returns
 */
async function validatePlayerChanges(
    conn: PoolConnection,
    pointHistory: AddonPointHistoryEntry[],
    players: AddonPlayerEntry[]
): Promise<{
    pointChanges: Map<string, AddonPointHistoryEntry[]>;
    changedPlayers: Map<string, { data: AddonPlayerEntry; oldEntry?: PlayerRow }>;
    error?: string;
}> {
    const oldestPointImport = getOldest(pointHistory) * 1000; // Addon is seconds timestamps
    const [dbPointHistory] = (await conn.query<RowDataPacket[]>(`SELECT * FROM pointHistory WHERE timestamp>=?;`, [
        oldestPointImport,
    ])) as [PointHistoryRow[], FieldPacket[]];

    const pointDict: Record<string, PointHistoryRow> = {};
    for (const h of dbPointHistory) {
        pointDict[h.guid] = h;
    }

    const pointChanges = new Map<string, AddonPointHistoryEntry[]>();
    for (const importEntry of pointHistory) {
        if (pointDict[importEntry.guid]) continue;
        if (!pointChanges.has(importEntry.playerName)) pointChanges.set(importEntry.playerName, []);
        pointChanges.get(importEntry.playerName)!.push(importEntry);
    }

    const [dbPlayers] = (await conn.query<RowDataPacket[]>(`SELECT * FROM players;`)) as [PlayerRow[], FieldPacket[]];
    const dbPlayersDict = new Map<string, PlayerRow>();
    for (const dbp of dbPlayers) {
        dbPlayersDict.set(dbp.playerName, dbp);
    }

    const changedPlayers = new Map<string, { data: AddonPlayerEntry; oldEntry?: PlayerRow }>();
    const errorList: string[] = [];
    let isCriticalError = false;

    for (const newPlayerEntry of players) {
        const newChanges = pointChanges.get(newPlayerEntry.playerName);
        const dbPlayer = dbPlayersDict.get(newPlayerEntry.playerName);

        if (!dbPlayer) {
            changedPlayers.set(newPlayerEntry.playerName, { data: newPlayerEntry });
            continue;
        }

        if (!newChanges) continue;

        const playerErrors: string[] = [];
        let reconstructedPoints = dbPlayer ? dbPlayer.points : 0; // If player doesn't exist it should start at 0.

        // Make sure it's always chronological.
        newChanges.sort((a, b) => a.timeStamp - b.timeStamp);

        for (const change of newChanges) {
            const newReconstructedPoints = reconstructedPoints + change.change;
            if (newReconstructedPoints != change.newPoints) {
                playerErrors.push(
                    `Mismatch on change: ${change.timeStamp}, ${change.change} to ${change.newPoints}, ${change.type} ${change.reason} | Previous points were ${reconstructedPoints}!`
                );
            }
            reconstructedPoints = newReconstructedPoints;
        }

        if (reconstructedPoints != newPlayerEntry.points) {
            const diff = newPlayerEntry.points - reconstructedPoints;
            playerErrors.push(
                `=> Points would be ${reconstructedPoints} following new changes, but import sets them to ${newPlayerEntry.points}! Resolve by changing player's points by ${diff} on website or ${-diff} in addon before import.`
            );
            // We only care if points do not end up being the same.
            // If they are the same it's not a big deal going forward.
            isCriticalError = true;
        }

        if (playerErrors.length > 0) {
            errorList.push(`History for ${newPlayerEntry.playerName} has conflicts!\n` + playerErrors.join("\n") + "\n\n");
        }

        changedPlayers.set(newPlayerEntry.playerName, { data: newPlayerEntry, oldEntry: dbPlayer });
    }

    const error = isCriticalError ? errorList.join("\n") : undefined;
    return { pointChanges, changedPlayers, error };
}

/**
 * Update point history by inserting previously validated entries.
 * @param conn
 * @param history
 * @returns
 */
async function updatePointHistory(
    conn: PoolConnection,
    changes: Map<string, AddonPointHistoryEntry[]>
): Promise<ImportLog["pointHistory"]> {
    const log: ImportLog["pointHistory"] = [];

    for (const playerChanges of changes.values()) {
        for (const importEntry of playerChanges) {
            const timeStampForDb = importEntry.timeStamp * 1000;

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
    }

    return log;
}

/**
 * Update players by inserting previously validated player entries.
 * @param conn
 * @param changedPlayers
 * @returns
 */
async function updatePlayers(
    conn: PoolConnection,
    changedPlayers: Map<string, { data: AddonPlayerEntry; oldEntry?: PlayerRow }>
): Promise<ImportLog["players"]> {
    const log: ImportLog["players"] = [];

    for (const changedPlayer of changedPlayers.values()) {
        const playerData = changedPlayer.data;
        if (changedPlayer.oldEntry) {
            await conn.query(`UPDATE players SET classId=?, points=? WHERE playerName=?;`, [
                playerData.classId,
                playerData.points,
                playerData.playerName,
            ]);
            log.push({ old: changedPlayer.oldEntry, new: playerData });
        } else {
            await conn.query("INSERT INTO players (playerName, classId, points) VALUES (?,?,?);", [
                playerData.playerName,
                playerData.classId,
                playerData.points,
            ]);
            log.push({ new: playerData });
        }
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

        const lootHistValidationRes = await validateLootHistory(conn, data.lootHistory, data.players);
        if (lootHistValidationRes.error) {
            return { error: lootHistValidationRes.error };
        }

        const playerChangeValidationRes = await validatePlayerChanges(conn, data.pointHistory, data.players);
        if (playerChangeValidationRes.error) {
            return { error: playerChangeValidationRes.error };
        }

        const backupSuccess = await makeDataBackup(conn, 0, "before_addon_import");
        if (!backupSuccess) return { error: "Making data backup failed!" };

        conn.beginTransaction();
        const playerLog = await updatePlayers(conn, playerChangeValidationRes.changedPlayers);
        const lootLog = await updateLootHistory(conn, lootHistValidationRes.newEntries);
        const pointLog = await updatePointHistory(conn, playerChangeValidationRes.pointChanges);
        await conn.commit();

        return { log: { players: playerLog, lootHistory: lootLog, pointHistory: pointLog } };
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

        const usersRes = await getAllUsers(conn);
        if (usersRes.isError) return rollbackThenFalse();
        const loginIdDict: Record<string, boolean> = {};
        for (const user of usersRes.rows) {
            loginIdDict[user.loginId] = true;
        }

        for (const player of data.players) {
            // DB expects account to exist if given. Users may not exist (anymore) when this is loaded.
            const account = player.account && loginIdDict[player.account] ? player.account : undefined;
            const res = await createPlayer(player.playerName, player.classId, player.points, account, conn);
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

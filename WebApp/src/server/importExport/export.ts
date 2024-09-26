import type { FieldPacket, PoolConnection } from "mysql2/promise";
import type { LootHistoryRow, PlayerRow, PointHistoryRow } from "../database/types";
import { getConnection } from "../database/database";
import type { AddonExport } from "@/shared/types";
import { Logger } from "../Logger";
import { deflateRaw } from "zlib";

const ADDON_IMPORT_PREFIX = "DMSAE";
const ADDON_IMPORT_SUFFIX = "END";

const logger = new Logger("Exporter");

export type DataExport = {
    time: number;
    minTimestamp: number;
    players: PlayerRow[];
    pointHistory: PointHistoryRow[];
    lootHistory: LootHistoryRow[];
};

/**
 * Create export of data tables.
 * @param conn
 * @param minTimestamp
 * @returns
 * @throws Error if DB operations throw an error.
 */
export const createDataExport = async (conn: PoolConnection, minTimestamp = 0): Promise<DataExport> => {
    const [players, _fp] = (await conn.query("SELECT * FROM players")) as [PlayerRow[], FieldPacket[]];
    const [pointHistory, _fp2] = (await conn.query("SELECT * FROM pointhistory WHERE timestamp>?;", [minTimestamp])) as [
        PointHistoryRow[],
        FieldPacket[],
    ];
    const [lootHistory, _fp3] = (await conn.query("SELECT * FROM loothistory WHERE timestamp>?;", [minTimestamp])) as [
        LootHistoryRow[],
        FieldPacket[],
    ];

    const now = new Date();
    const backup: DataExport = {
        time: now.getTime(),
        minTimestamp,
        players,
        pointHistory,
        lootHistory,
    };

    return backup;
};

function deflate(buf: Buffer): Promise<Buffer> {
    return new Promise((resolve, reject) => {
        deflateRaw(buf, (err, res) => {
            if (err) {
                reject(err);
                return;
            }
            resolve(res);
        });
    });
}

function toSecondsTimeStamp(jsTimestamp: number): number {
    return Math.round(jsTimestamp / 1000);
}

/**
 * Create export data for addon.
 * @param minTimestamp
 * @returns
 */
export const createExportForAddon = async (minTimestamp = 0): Promise<string | undefined> => {
    try {
        const conn = await getConnection();
        const exportData = await createDataExport(conn, minTimestamp);
        const apiExport: AddonExport = {
            time: toSecondsTimeStamp(exportData.time),
            minTimestamp: toSecondsTimeStamp(exportData.minTimestamp),
            players: [],
            pointHistory: [],
            lootHistory: [],
        };
        for (const p of exportData.players) {
            apiExport.players.push({
                playerName: p.playerName,
                classId: p.classId,
                points: p.points,
            });
        }
        for (const p of exportData.pointHistory) {
            apiExport.pointHistory.push({
                guid: p.guid,
                timeStamp: toSecondsTimeStamp(p.timestamp),
                playerName: p.playerName,
                change: p.pointChange,
                newPoints: p.newPoints,
                type: p.changeType,
                reason: p.reason,
            });
        }
        for (const p of exportData.lootHistory) {
            apiExport.lootHistory.push({
                guid: p.guid,
                timeStamp: toSecondsTimeStamp(p.timestamp),
                playerName: p.playerName,
                itemId: p.itemId,
                response: p.response,
            });
        }

        const json = JSON.stringify(apiExport);

        const deflated = await deflate(Buffer.from(json));
        const base64 = deflated.toString("base64");
        const forAddon = ADDON_IMPORT_PREFIX + base64 + ADDON_IMPORT_SUFFIX;
        return forAddon;
    } catch (error) {
        logger.logError("Failed to create export.", error);
    }
};

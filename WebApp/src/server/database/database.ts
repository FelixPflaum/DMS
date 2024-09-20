import mysql, { ResultSetHeader, RowDataPacket } from "mysql2/promise";
import { creationSqlQueries } from "./createSql";
import { AccPermissions } from "@/shared/enums";
import { getConfig } from "../config";
import { Logger } from "../Logger";
import { checkAndUpdateItemDb } from "./dbcLoader/itemDataLoader";
import type { AuditRow, ItemDataRow, PlayerRow, PointHistoryRow, SettingsRow, UserRow } from "./types";
import type { ClassId } from "@/shared/wow";

const logger = new Logger("DB");
const pool = mysql.createPool({
    host: getConfig().dbHost,
    port: getConfig().dbPort,
    user: getConfig().dbUser,
    password: getConfig().dbPass,
    database: getConfig().dbName,
});

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const queryDb = async <T extends mysql.QueryResult>(sql: string, values: any[]): Promise<T> => {
    const [res] = await pool.query<T>(sql, values);
    return res as T;
};

/**
 * Get settings entry.
 * @param key
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getSetting = async (key: string): Promise<SettingsRow | undefined> => {
    const [res] = await pool.query<RowDataPacket[]>("SELECT * FROM settings WHERE skey=?", [key]);
    return res.length == 1 ? (res[0] as SettingsRow) : undefined;
};

/**
 * Set settings entry.
 * @param key
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const setSetting = async (key: string, value: string): Promise<boolean> => {
    const [res] = await pool.query<ResultSetHeader>("REPLACE INTO settings (skey, svalue) VALUES (?, ?);", [key, value]);
    return res.affectedRows != 0;
};

export const settingsDb = {
    get: getSetting,
    set: setSetting,
};

/**
 * Check if DB is set up and apply updates if needed.
 * @returns
 */
export const checkDb = async (): Promise<boolean> => {
    const conn = await pool.getConnection();
    try {
        const [existsRes] = await conn.query<RowDataPacket[]>("SHOW TABLES LIKE 'settings'");
        let currentVersion = existsRes.length;

        if (currentVersion > 0) {
            const [res] = await conn.query<RowDataPacket[]>("SELECT * FROM settings WHERE skey='dbVersion'");
            currentVersion = res.length == 1 ? parseInt((res[0] as SettingsRow).svalue) : 0;
        }

        const targetVersion = creationSqlQueries.length;

        if (currentVersion < targetVersion) {
            logger.log(`Updating database. Current ver ${currentVersion}, target ver ${targetVersion}`);

            await conn.beginTransaction();
            for (let i = currentVersion; i < targetVersion; i++) {
                logger.log("Applying sql update: " + (i + 1));
                await conn.query(creationSqlQueries[i]);
            }
            if (currentVersion == 0) {
                await conn.query(`INSERT INTO settings (skey, svalue) VALUES ('dbVersion', ?);`, [targetVersion.toString()]);
            } else {
                await conn.query(`UPDATE settings SET svalue=? WHERE skey='dbVersion';`, [targetVersion.toString()]);
            }
            await conn.commit();
            logger.log("Database updated!");
        }

        await checkAndUpdateItemDb();
    } catch (error) {
        logger.logError("DB check failed.", error);
        return false;
    } finally {
        pool.releaseConnection(conn);
    }

    return true;
};

/**
 * Create new auth entry.
 * @param loginId
 * @param userName
 * @param permissions
 * @returns true if entry was created, false it loginId already exists.
 * @throws Error if DB operation fails for whatever reason.
 */
const createAuthEntry = async (loginId: string, userName: string, permissions = AccPermissions.NONE): Promise<boolean> => {
    const [existsResult] = await pool.query<RowDataPacket[]>(`SELECT * FROM users WHERE loginId=?`, [loginId]);
    if (existsResult.length == 1) return false;

    const [insertResult] = await pool.query<ResultSetHeader>(
        `INSERT INTO users (loginId, userName, permissions) VALUES (?, ?, ?);`,
        [loginId, userName, permissions]
    );

    if (insertResult.affectedRows) return true;
    return false;
};

/**
 * Get auth entry.
 * @param loginId
 * @returns The auth entry if it exists.
 * @throws Error if DB operation fails for whatever reason.
 */
const getAuthEntry = async (loginId: string): Promise<UserRow | undefined> => {
    const [existsResult] = await pool.query<RowDataPacket[]>(`SELECT * FROM users WHERE loginId=?;`, [loginId]);
    if (existsResult.length == 1) return existsResult[0] as UserRow;
};

/**
 * Get all auth entries.
 * @returns The array of auth rows.
 * @throws Error if DB operation fails for whatever reason.
 */
const getAuthEntries = async (): Promise<UserRow[]> => {
    const [existsResult] = await pool.query<RowDataPacket[]>(`SELECT * FROM users;`);
    return existsResult as UserRow[];
};

/**
 * Update auth entry.
 * @param loginId
 * @param newValues Object with values to update set. Unset value will not change.
 * @returns true if entry was updated, false if loginId is not valid.
 * @throws Error if DB operation fails for whatever reason.
 */
const updateAuthEntry = async (loginId: string, newValues: Partial<UserRow>): Promise<boolean> => {
    delete newValues.loginId;

    const setStrings: string[] = [];
    const valueArray = [];
    for (const k in newValues) {
        setStrings.push(`${k}=?`);
        valueArray.push(newValues[k as keyof UserRow]);
    }
    valueArray.push(loginId);

    const [res] = await pool.query<ResultSetHeader>(`UPDATE users SET ${setStrings.join(",")} WHERE loginId=?;`, valueArray);
    return res.affectedRows > 0;
};

/**
 * Remove auth entry.
 * @param loginId
 * @returns true if it was deleted, false if it didn't exist.
 * @throws Error if DB operation fails for whatever reason.
 */
const removeAuthEntry = async (loginId: string): Promise<boolean> => {
    const [deleteResult] = await pool.query<ResultSetHeader>(`DELETE FROM users WHERE loginId=?;`, [loginId]);
    if (deleteResult.affectedRows) return true;
    return false;
};

export const authDb = {
    createEntry: createAuthEntry,
    getEntry: getAuthEntry,
    getEntries: getAuthEntries,
    updateEntry: updateAuthEntry,
    removeEntry: removeAuthEntry,
};

/**
 * Add new entry to audit log.
 * @param loginId
 * @param userName
 * @param eventInfo
 * @throws Error if DB operation fails for whatever reason.
 */
const addAuditEntry = async (loginId: string, userName: string, eventInfo: string): Promise<void> => {
    await pool.query<ResultSetHeader>(`INSERT INTO audit (timestamp, loginId, userName, eventInfo) VALUES (?, ?, ?, ?);`, [
        new Date(),
        loginId,
        userName,
        eventInfo,
    ]);
};

/**
 * Add new entry to audit log.
 * @param loginId
 * @param userName
 * @param eventInfo
 */
const addAuditEntryNoErr = async (loginId: string, userName: string, eventInfo: string): Promise<void> => {
    try {
        await addAuditEntry(loginId, userName, eventInfo);
    } catch (error) {
        logger.logError("Add audit entry failed.", error);
    }
};

/**
 * Get last audit entries.
 * @param limit How many entries to get.
 * @param pageOffset Pagination page offset.
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getAuditEntries = async (limit = 50, pageOffset = 0): Promise<AuditRow[]> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM audit ORDER BY id DESC LIMIT ? OFFSET ?;`, [
        limit,
        pageOffset * limit,
    ]);
    return result as AuditRow[];
};

export const auditDb = {
    addEntry: addAuditEntry,
    addEntryNoErr: addAuditEntryNoErr,
    getEntries: getAuditEntries,
};

/**
 * Get item data.
 * @param itemId
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getItem = async (itemId: number): Promise<ItemDataRow | undefined> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM itemData WHERE itemId=?;`, [itemId]);
    return result.length == 1 ? (result[0] as ItemDataRow) : undefined;
};

/**
 * Get item data by name.
 * @param itemId
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const searchItemByName = async (itemName: string): Promise<ItemDataRow[]> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM itemData WHERE itemName LIKE ?;`, [
        "%" + itemName + "%",
    ]);
    return result as ItemDataRow[];
};

/**
 * Get all items.
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getAllItems = async (): Promise<ItemDataRow[]> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM itemData;`);
    return result as ItemDataRow[];
};

export const itemDb = {
    getItem,
    searchByName: searchItemByName,
    getAll: getAllItems,
};

/**
 * Get player entry.
 * @param name
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getPlayer = async (name: string): Promise<PlayerRow | undefined> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM players WHERE playerName=?;`, [name]);
    return result.length == 1 ? (result[0] as PlayerRow) : undefined;
};

/**
 * Get all player entries.
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getPlayers = async (): Promise<PlayerRow[]> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM players;`);
    return result as PlayerRow[];
};

/**
 * Create new player entry.
 * @param name
 * @param classId
 * @param points
 * @param accountId
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const createPlayer = async (name: string, classId: ClassId, points: number, accountId?: string): Promise<boolean> => {
    const [existsResult] = await pool.query<RowDataPacket[]>(`SELECT * FROM players WHERE playerName=?;`, [name]);
    if (existsResult.length == 1) return false;

    const [insertResult] = await pool.query<ResultSetHeader>(
        `INSERT INTO players (playerName, classId, points, account) VALUES (?, ?, ?, ?);`,
        [name, classId, points, accountId]
    );

    if (insertResult.affectedRows) return true;
    return false;
};

/**
 * Update player entry.
 * @param name
 * @param newValues Object with values to update set. Unset value will not change.
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const updatePlayer = async (name: string, newValues: Partial<PlayerRow>): Promise<boolean> => {
    const setStrings: string[] = [];
    const valueArray = [];
    for (const k in newValues) {
        setStrings.push(`${k}=?`);
        valueArray.push(newValues[k as keyof PlayerRow]);
    }
    valueArray.push(name);

    const [res] = await pool.query<ResultSetHeader>(
        `UPDATE players SET ${setStrings.join(",")} WHERE playerName=?;`,
        valueArray
    );
    return res.affectedRows > 0;
};

/**
 * Remove player entry.
 * @param name
 * @returns true if it was deleted, false if it didn't exist.
 * @throws Error if DB operation fails for whatever reason.
 */
const deletePlayer = async (name: string): Promise<boolean> => {
    const [deleteResult] = await pool.query<ResultSetHeader>(`DELETE FROM players WHERE playerName=?;`, [name]);
    if (deleteResult.affectedRows) return true;
    return false;
};

export const playerDb = {
    getPlayer,
    getPlayers,
    createPlayer,
    updatePlayer,
    deletePlayer,
};

/**
 * Get player entry.
 * @param name
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getPointHistoryEntry = async (timestamp: number, playerName: string): Promise<PointHistoryRow | undefined> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM pointHistory WHERE timestamp=? AND playerName=?;`, [
        timestamp,
        playerName,
    ]);
    return result.length == 1 ? (result[0] as PointHistoryRow) : undefined;
};

/**
 * Get all player entries.
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getPointHistory = async (): Promise<PointHistoryRow[]> => {
    const [result] = await pool.query<RowDataPacket[]>(`SELECT * FROM pointHistory;`);
    return result as PointHistoryRow[];
};

/**
 * Get last history entries.
 * @param limit How many entries to get.
 * @param pageOffset Pagination page offset.
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getPointHistoryEntryPage = async (limit = 50, pageOffset = 0): Promise<PointHistoryRow[]> => {
    const [result] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM pointHistory ORDER BY timestamp DESC LIMIT ? OFFSET ?;`,
        [limit, pageOffset * limit]
    );
    return result as PointHistoryRow[];
};

/**
 * Get history entries by filter.
 * @param filter
 * @param limit
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const getPointHistoryEntrySearch = async (
    filter: {
        name?: string;
        timeStart?: number;
        timeEnd?: number;
    },
    limit = 150
): Promise<PointHistoryRow[]> => {
    const wheres: string[] = [];
    const values: (string | number)[] = [];

    for (const k in filter) {
        switch (k) {
            case "name":
                wheres.push("playerName LIKE ?");
                values.push(`%${filter[k]}%`);
                break;
            case "timeStart":
                wheres.push("timestamp>?");
                values.push(filter[k]!);
                break;
            case "timeEnd":
                wheres.push("timestamp<?");
                values.push(filter[k]!);
                break;
        }
    }

    let sql = `SELECT * FROM pointHistory`;
    if (wheres.length) sql += " " + wheres.join(" AND ");

    sql += ` ORDER BY timestamp DESC LIMIT ?;`;
    values.push(limit);

    const [result] = await pool.query<RowDataPacket[]>(sql, values);
    return result as PointHistoryRow[];
};

/**
 * Create new history entry.
 * @param name
 * @param classId
 * @param points
 * @param accountId
 * @returns
 * @throws Error if DB operation fails for whatever reason.
 */
const createPointHistoryEntry = async (
    timestamp: number,
    playerName: string,
    pointChange: number,
    newPoints: number,
    changeType: string,
    reason?: string
): Promise<boolean> => {
    const [existsResult] = await pool.query<RowDataPacket[]>(
        `SELECT * FROM pointHistory WHERE timestamp=? AND playerName=?;`,
        [timestamp, playerName]
    );
    if (existsResult.length == 1) return false;

    const [insertResult] = await pool.query<ResultSetHeader>(
        `INSERT INTO pointHistory (timestamp, playerName, pointChange, newPoints, changeType, reason) VALUES (?, ?, ?, ?, ?, ?);`,
        [timestamp, playerName, pointChange, newPoints, changeType, reason]
    );

    if (insertResult.affectedRows) return true;
    return false;
};

/**
 * Remove point history entry.
 * @param name
 * @returns true if it was deleted, false if it didn't exist.
 * @throws Error if DB operation fails for whatever reason.
 */
const deletePointHistoryEntry = async (id: number): Promise<boolean> => {
    const [deleteResult] = await pool.query<ResultSetHeader>(`DELETE FROM pointHistory WHERE id=?;`, [id]);
    if (deleteResult.affectedRows) return true;
    return false;
};

export const pointHistoryDb = {
    getPointHistoryEntry,
    getPointHistory,
    getPointHistoryEntryPage,
    getPointHistoryEntrySearch,
    createPointHistoryEntry,
    deletePointHistoryEntry,
};

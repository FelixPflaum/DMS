import mysql, { ResultSetHeader, RowDataPacket } from "mysql2/promise";
import { creationSqlQueries } from "./createSql";
import { AccPermissions } from "@/shared/enums";
import { getConfig } from "../config";
import { Logger } from "../Logger";

const logger = new Logger("DB");
const pool = mysql.createPool({
    host: getConfig().dbHost,
    port: getConfig().dbPort,
    user: getConfig().dbUser,
    password: getConfig().dbPass,
    database: getConfig().dbName,
});

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

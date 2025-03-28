import type { PoolConnection, ResultSetHeader, RowDataPacket } from "mysql2/promise";
import mysql from "mysql2/promise";
import { creationSqlQueries } from "./createSql";
import { getConfig } from "../config";
import { Logger } from "../Logger";
import { checkAndUpdateItemDb } from "./dbcLoader/itemDataLoader";
import type { SettingsRow } from "./types";

const logger = new Logger("DB");
const pool = mysql.createPool({
    host: getConfig().dbHost,
    port: getConfig().dbPort,
    user: getConfig().dbUser,
    password: getConfig().dbPass,
    database: getConfig().dbName,
});

export type DbDataValue = number | string | Date;

/**
 * Query the DB.
 * @param sql
 * @param values
 * @returns
 * @throws Error if DB operation throws an error.
 */
export const queryDb = async <T extends mysql.QueryResult>(sql: string, values?: DbDataValue[]): Promise<T> => {
    const [res] = await pool.query<T>(sql, values);
    return res;
};

/**
 * Get a DB connection for manual queries.
 * @returns
 */
export const getConnection = async (): Promise<mysql.PoolConnection> => {
    return pool.getConnection();
};

export type DbResult = {
    isError?: boolean;
};

export type DbRowResult<T> = DbResult & {
    row?: T;
};

export type DbRowsResult<T> = DbResult & {
    rows: T[];
};

/**
 * Convenience function for SELECTing single rows.
 * @param sql
 * @param values
 * @returns A DatabaseResult containing a single row or undefined if 0 or 2+ results.
 */
export const querySelectSingle = async <T extends {}>(sql: string, values: DbDataValue[]): Promise<DbRowResult<T>> => {
    try {
        const [res] = await pool.query<RowDataPacket[]>(sql, values);
        const dbres: DbRowResult<T> = {};
        if (res.length === 1) dbres.row = res[0] as T;
        return dbres;
    } catch (error) {
        logger.logError(`DB error for query "${sql}"`, error);
        return { isError: true };
    }
};

/**
 * Convenience function for SELECTing multiple rows.
 * @param sql
 * @param values
 * @param conn
 * @returns A DatabaseResult containing the rows.
 */
export const querySelect = async <T extends {}>(
    sql: string,
    values?: DbDataValue[],
    conn?: PoolConnection
): Promise<DbRowsResult<T>> => {
    const db = conn ?? pool;
    try {
        const [res] = await db.query<RowDataPacket[]>(sql, values);
        return { rows: res as T[] };
    } catch (error) {
        logger.logError(`DB error for query "${sql}"`, error);
        return { isError: true, rows: [] };
    }
};

export type DbUpdateResult = DbResult & {
    affectedRows: number;
};

/**
 * Convenience function for UPDATEing rows.
 * @param table
 * @param idFields The fields that are the unique id of the row and their values.
 * @param fields The remaining fields and their values, without fields already provided in idFields.
 * @returns
 */
export const queryUpdate = async (
    table: string,
    idFields: Record<string, DbDataValue>,
    fields: Record<string, DbDataValue>,
    conn?: PoolConnection
): Promise<DbUpdateResult> => {
    const db = conn ?? pool;
    const idKeys: string[] = [];
    const idValues: DbDataValue[] = [];
    for (const key in idFields) {
        idKeys.push(key);
        idValues.push(idFields[key]);
    }

    const setKeys: string[] = [];
    const setValues: DbDataValue[] = [];
    for (const key in fields) {
        setKeys.push(key);
        setValues.push(fields[key]);
    }

    const sqlQuery = `UPDATE ${table} SET ${setKeys.join("=? ,")}=? WHERE ${idKeys.join("=? AND ")}=?;`;
    try {
        const [ures] = await db.query<ResultSetHeader>(sqlQuery, [...setValues, ...idValues]);
        return { affectedRows: ures.affectedRows };
    } catch (error) {
        logger.logError(`DB error for query "${sqlQuery}"`, error);
        return { isError: true, affectedRows: 0 };
    }
};

/**
 * Convenience function that updates a row or inserts it if it doesn't exist. All required columns need to be provided for insert to work!
 * @param table
 * @param idFields The fields that are the unique id of the row and their values.
 * @param fields The remaining fields and their values, without fields already provided in idFields.
 * @returns
 */
export const queryUpdateOrInsert = async (
    table: string,
    idFields: Record<string, DbDataValue>,
    fields: Record<string, DbDataValue>,
    conn?: PoolConnection
): Promise<DbUpdateResult> => {
    const db = conn ?? pool;
    let sqlQuery: string | undefined;

    const idKeys: string[] = [];
    const idValues: DbDataValue[] = [];
    for (const key in idFields) {
        idKeys.push(key);
        idValues.push(idFields[key]);
    }

    const setKeys: string[] = [];
    const setValues: DbDataValue[] = [];
    for (const key in fields) {
        setKeys.push(key);
        setValues.push(fields[key]);
    }

    try {
        // Check if it exists.
        sqlQuery = `SELECT * FROM ${table} WHERE ${idKeys.join("=? AND ")}=?;`;
        const [sres] = await db.query<RowDataPacket[]>(sqlQuery, idValues);
        if (sres.length === 0) {
            // Insert
            const valphs = new Array(idKeys.length + setKeys.length).fill("?");
            sqlQuery = `INSERT INTO ${table} (${Object.keys(fields).join(",")}, ${Object.keys(idFields).join(",")}) VALUES (${valphs.join(",")});`;
            const [isres] = await db.query<ResultSetHeader>(sqlQuery, [...setValues, ...idValues]);
            return { affectedRows: isres.affectedRows };
        } else {
            // Update
            sqlQuery = `UPDATE ${table} SET ${setKeys.join("=? ,")}=? WHERE ${idKeys.join("=? AND ")}=?;`;
            const [ures] = await db.query<ResultSetHeader>(sqlQuery, [...setValues, ...idValues]);
            return { affectedRows: ures.affectedRows };
        }
    } catch (error) {
        logger.logError(`DB error for query "${sqlQuery || "--"}"`, error);
        return { isError: true, affectedRows: 0 };
    }
};

/**
 * Convenience function that inserts a row.
 * @param table
 * @param fields The fields and their values.
 * @returns insert id if auto increment table, 1 as fallback, 0 on error
 */
export const queryInsert = async (table: string, fields: Record<string, DbDataValue>): Promise<number> => {
    let sqlQuery: string | undefined;
    try {
        const keys: string[] = [];
        const values: DbDataValue[] = [];
        const valphs: "?"[] = [];
        for (const key in fields) {
            keys.push(key);
            values.push(fields[key]);
            valphs.push("?");
        }

        sqlQuery = `INSERT INTO ${table} (${keys.join(",")}) VALUES (${valphs.join(",")});`;
        const [resHeader, _fd] = await pool.query<ResultSetHeader>(sqlQuery, values);
        return resHeader.insertId || 1;
    } catch (error) {
        logger.logError(`DB error for query "${sqlQuery || "--"}"`, error);
        return 0;
    }
};

export type DbInsertCheckedResult = DbResult & {
    duplicate: boolean;
};

/**
 * Convenience function that inserts a row if it doesn't exist.
 * @param table
 * @param idFields The fields that are the unique id of the row and their values.
 * @param fields The remaining fields and their values, without fields already provided in idFields.
 * @returns
 */
export const queryInsertChecked = async (
    table: string,
    idFields: Record<string, DbDataValue>,
    fields: Record<string, DbDataValue>,
    conn?: PoolConnection
): Promise<DbInsertCheckedResult> => {
    const db = conn ?? pool;
    let sqlQuery: string | undefined;
    try {
        const idKeys: string[] = [];
        const idValues: DbDataValue[] = [];
        for (const key in idFields) {
            idKeys.push(key);
            idValues.push(idFields[key]);
        }

        const setKeys: string[] = [];
        const setValues: DbDataValue[] = [];
        for (const key in fields) {
            setKeys.push(key);
            setValues.push(fields[key]);
        }

        // Check if it exists.
        sqlQuery = `SELECT * FROM ${table} WHERE ${idKeys.join("=? AND ")}=?;`;
        const [sres] = await db.query<RowDataPacket[]>(sqlQuery, idValues);
        if (sres.length === 0) {
            // Insert
            const valphs = new Array(idKeys.length + setKeys.length).fill("?");
            sqlQuery = `INSERT INTO ${table} (${setKeys.join(",")}, ${idKeys.join(",")}) VALUES (${valphs.join(",")});`;
            await db.query<ResultSetHeader>(sqlQuery, [...setValues, ...idValues]);
            return { duplicate: false };
        } else {
            return { duplicate: true };
        }
    } catch (error) {
        logger.logError(`DB error for query "${sqlQuery || "--"}"`, error);
        return { isError: true, duplicate: false };
    }
};

export type DbDeleteResult = DbResult & {
    affectedRows: number;
};

/**
 * Convenience function that deletes row(s).
 * @param table
 * @param idFields The fields that are the id of the row(s) and their values.
 * @returns
 */
export const queryDelete = async (table: string, idFields: Record<string, DbDataValue>): Promise<DbDeleteResult> => {
    const idKeys: string[] = [];
    const idValues: DbDataValue[] = [];
    for (const key in idFields) {
        idKeys.push(key);
        idValues.push(idFields[key]);
    }
    const sqlQuery = `DELETE FROM ${table} WHERE ${idKeys.join("=? AND ")}=?;`;
    try {
        const [deleteResult] = await pool.query<ResultSetHeader>(sqlQuery, [idValues]);
        return { affectedRows: deleteResult.affectedRows };
    } catch (error) {
        logger.logError(`DB error for query "${sqlQuery || "--"}"`, error);
        return { isError: true, affectedRows: 0 };
    }
};

/**
 * Check if DB is set up and apply updates if needed.
 * @returns
 */
export const checkDb = async (): Promise<boolean> => {
    logger.log("Checking DB...");
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
        } else {
            logger.log("Database up to date.");
        }

        await checkAndUpdateItemDb();
    } catch (error) {
        await conn.rollback();
        logger.logError("DB check failed.", error);
        return false;
    } finally {
        pool.releaseConnection(conn);
    }

    return true;
};

/**
 * Generate string in the format <8B time as hex>-<7B random hex>
 */
export const generateGuid = (): string => {
    return `${Math.round(Date.now() / 1000).toString(16)}-${Math.round(Math.random() * 0xfffffff).toString(16)}`;
};

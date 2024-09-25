import type { PoolConnection } from "mysql2/promise";
import { mkdir, writeFile } from "fs/promises";
import { isError } from "../nodeError";
import { join } from "path";
import { Logger } from "../Logger";
import { createDataExport } from "./export";

const BACKUP_BASE_DIR = "backups";
const logger = new Logger("Data Backup");

/**
 * Create backup of data tables.
 * @param conn
 * @param minTimestamp
 * @returns
 */
export const makeDataBackup = async (conn: PoolConnection, minTimestamp = 0, suffix = ""): Promise<boolean> => {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;

    try {
        await mkdir(BACKUP_BASE_DIR);
    } catch (error) {
        // Any error besides dir existing should return here.
        if (!isError(error) || error.code != "EEXIST") return false;
    }

    try {
        await mkdir(join(BACKUP_BASE_DIR, year.toString()));
    } catch (error) {
        // Any error besides dir existing should return here.
        if (!isError(error) || error.code != "EEXIST") return false;
    }

    const backupDir = join(BACKUP_BASE_DIR, year.toString(), month.toString());

    try {
        await mkdir(backupDir);
    } catch (error) {
        // Any error besides dir existing should return here.
        if (!isError(error) || error.code != "EEXIST") return false;
    }

    try {
        const backup = await createDataExport(conn, minTimestamp);
        const now = new Date(backup.time);
        const fileName = `data_${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}_${now.getHours()}.${now.getMinutes()}.${now.getSeconds()}_${suffix}.json`;
        await writeFile(join(backupDir, fileName), JSON.stringify(backup));
        return true;
    } catch (error) {
        logger.logError("Data backup failed!", error);
        return false;
    }
};

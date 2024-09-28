import type { PoolConnection } from "mysql2/promise";
import { access, mkdir, readdir, readFile, stat, writeFile } from "fs/promises";
import { isError } from "../nodeError";
import { basename, join } from "path";
import { Logger } from "../Logger";
import type { DataExport } from "./export";
import { createDataExport } from "./export";
import { importDataExport } from "./importToDb";

const BACKUP_BASE_DIR = "backups/data";
const BACKUP_FILE_PREFIX = "data_";
const logger = new Logger("Data Backup");

function generateBackupDirPath(year?: number, month?: number): string {
    let path = BACKUP_BASE_DIR;
    if (year) {
        path = join(path, year.toString());
        if (month) {
            path = join(path, month.toString());
        }
    }
    return path;
}

// async function makeBackupDir(year: number, month: number): Promise<string | undefined> {
//     const basePath = getBackupDirPath();
//     const yearPath = getBackupDirPath(year);
//     const yearMonthPath = getBackupDirPath(year, month);
//     if ((await makeDir(basePath)) && (await makeDir(yearPath)) && (await makeDir(yearMonthPath))) {
//         return yearMonthPath;
//     }
// }

function generateBackupFileName(date: Date, suffix?: string): string {
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, "0");
    const day = date.getDate().toString().padStart(2, "0");
    const hour = date.getHours().toString().padStart(2, "0");
    const minute = date.getMinutes().toString().padStart(2, "0");
    const second = date.getSeconds().toString().padStart(2, "0");
    suffix = suffix ? "_" + suffix : "";
    return `${BACKUP_FILE_PREFIX}${year}-${month}-${day}__${hour}_${minute}_${second}${suffix}.json`;
}

async function isFileAccessAllowed(path: string): Promise<boolean> {
    try {
        await access(path);
        const stats = await stat(path);
        // Not directory and not starting with prefix for backup files.
        if (!stats.isDirectory() && !basename(path).startsWith(BACKUP_FILE_PREFIX)) return false;
        return true;
    } catch (error) {
        return false;
    }
}

/**
 * Create backup of data tables.
 * @param conn
 * @param minTimestamp
 * @returns
 */
export const makeDataBackup = async (conn: PoolConnection, minTimestamp = 0, suffix = ""): Promise<string | false> => {
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const backupDir = generateBackupDirPath(year, month);

    try {
        await mkdir(backupDir, { recursive: true });
    } catch (error) {
        if (!isError(error) || error.code != "EEXIST") {
            logger.logError("Error creating backup dir.", error);
            return false;
        }
    }

    try {
        const backup = await createDataExport(conn, minTimestamp);
        const now = new Date(backup.time);
        const fileName = generateBackupFileName(now, suffix);
        await writeFile(join(backupDir, fileName), JSON.stringify(backup));
        return fileName;
    } catch (error) {
        logger.logError("Data backup failed!", error);
        return false;
    }
};

/**
 * Get list of backup directory contents.
 * @param year
 * @param month
 * @returns
 */
export const getBackupList = async (year?: number, month?: number): Promise<string[]> => {
    const dirPath = generateBackupDirPath(year, month);
    try {
        await access(dirPath);
    } catch (error) {
        return [];
    }

    try {
        const allowedFiles: string[] = [];
        const files = await readdir(dirPath);
        for (const fileName of files) {
            const canAccess = await isFileAccessAllowed(join(dirPath, fileName));
            if (canAccess) allowedFiles.push(fileName);
        }
        return allowedFiles;
    } catch (error) {
        logger.logError("Failed to read dir for backup list.", error);
        return [];
    }
};

/**
 * Get backup data if it exists.
 * @param year
 * @param month
 * @param file
 * @returns
 */
export const getBackup = async (year: number, month: number, file: string): Promise<DataExport | undefined> => {
    const pathToBackupFile = join(generateBackupDirPath(year, month), file);

    if (!(await isFileAccessAllowed(pathToBackupFile))) return;

    try {
        const data = await readFile(pathToBackupFile, "utf-8");
        const parsed = JSON.parse(data) as DataExport;
        return parsed;
    } catch (error) {
        logger.logError("Error on reading backup file.", error);
    }
};

/**
 * Apply backup.
 * @param path
 * @returns error string if not successful, true otherwise
 */
export const applyDataBackup = async (path: string[]): Promise<string | true> => {
    if (path.length !== 3) return "Invalid path length!";
    const year = parseInt(path[0]);
    const month = parseInt(path[1]);
    const file = path[2].trim();

    if (
        typeof year !== "number" ||
        typeof month !== "number" ||
        file.indexOf("..") !== -1 ||
        file.indexOf("/") !== -1 ||
        !file.startsWith(BACKUP_FILE_PREFIX)
    )
        return "Invalid path!";

    const data = await getBackup(year, month, file);
    if (!data) return "No backup found!";

    const success = importDataExport(data);
    if (!success) return "Failed on data import!";

    return true;
};

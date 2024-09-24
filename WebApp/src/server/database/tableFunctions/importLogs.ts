import type { ApiImportLogEntry } from "@/shared/types";
import type { DbRowResult, DbRowsResult } from "../database";
import { queryInsert, querySelect, querySelectSingle } from "../database";

/**
 * Get import logs list without data.
 * @param limit
 * @returns
 */
export const getImportLogList = (limit = 10): Promise<DbRowsResult<ApiImportLogEntry>> => {
    return querySelect<ApiImportLogEntry>(
        `SELECT i.id, i.timestamp, i.user, u.userName FROM importLogs i LEFT JOIN users u ON u.loginId=i.user ORDER BY i.id DESC LIMIT ?;`,
        [limit]
    );
};

/**
 * Get import log.
 * @param limit
 * @returns
 */
export const getImportLog = (id: number): Promise<DbRowResult<ApiImportLogEntry>> => {
    return querySelectSingle<ApiImportLogEntry>(
        `SELECT i.id, i.timestamp, i.user, u.userName, i.logData FROM importlogs i LEFT JOIN users u ON u.loginId=i.user WHERE id=?`,
        [id]
    );
};

/**
 * Add new log.
 * @param loginId
 * @param log
 */
export const addImportLog = (loginId: string, log: string): Promise<number> => {
    return queryInsert("importLogs", {
        timestamp: Date.now(),
        user: loginId,
        logData: log,
    });
};

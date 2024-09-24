import type { DbRowsResult } from "../database";
import { queryInsert, querySelect } from "../database";
import type { AuditRow } from "../types";

/**
 * Add new entry to audit log.
 * @param loginId
 * @param userName
 * @param eventInfo
 */
export const addAuditEntry = async (loginId: string, userName: string, eventInfo: string): Promise<boolean> => {
    return (
        (await queryInsert("audit", {
            timestamp: Date.now(),
            loginId: loginId,
            userName: userName,
            eventInfo: eventInfo,
        })) != 0
    );
};

/**
 * Get audit entries.
 * @param limit How many entries to get.
 * @param pageOffset Pagination page offset.
 * @returns
 */
export const getAuditPage = (limit = 50, pageOffset = 0): Promise<DbRowsResult<AuditRow>> => {
    return querySelect<AuditRow>(`SELECT * FROM audit ORDER BY id DESC LIMIT ? OFFSET ?;`, [limit, pageOffset * limit]);
};

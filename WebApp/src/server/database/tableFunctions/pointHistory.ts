import type { ApiPointHistorySearchInput } from "@/shared/types";
import type { DbDataValue, DbInsertCheckedResult, DbRowsResult } from "../database";
import { queryInsertChecked, querySelect } from "../database";
import type { PointHistoryRow } from "../types";
import type { PoolConnection } from "mysql2/promise";

/**
 * Get history entry page.
 * @param limit How many entries to get.
 * @param pageOffset Pagination page offset.
 * @returns
 */
export const getPointHistoryPage = (limit = 50, pageOffset = 0): Promise<DbRowsResult<PointHistoryRow>> => {
    return querySelect<PointHistoryRow>(`SELECT * FROM pointHistory ORDER BY timestamp DESC LIMIT ? OFFSET ?;`, [
        limit,
        pageOffset * limit,
    ]);
};

/**
 * Get history entries by filter.
 * @param filter
 * @param limit
 * @returns
 */
export const getPointHistorySearch = (
    filter: ApiPointHistorySearchInput,
    limit = 150
): Promise<DbRowsResult<PointHistoryRow>> => {
    const wheres: string[] = [];
    const values: (string | number)[] = [];

    let k: keyof ApiPointHistorySearchInput;
    for (k in filter) {
        if (typeof filter[k as keyof typeof filter] === "undefined") continue;
        switch (k) {
            case "playerName":
                wheres.push("playerName=?");
                values.push(filter[k]!);
                break;
            case "searchName":
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
    if (wheres.length) sql += " WHERE " + wheres.join(" AND ");
    sql += ` ORDER BY timestamp DESC LIMIT ?;`;
    values.push(limit);

    return querySelect<PointHistoryRow>(sql, values);
};

/**
 * Create new history entry.
 * @param name
 * @param classId
 * @param points
 * @param accountId
 * @returns
 */
export const createPointHistoryEntry = (data: PointHistoryRow, conn?: PoolConnection): Promise<DbInsertCheckedResult> => {
    const nonIdFields: Record<string, DbDataValue> = {
        pointChange: data.pointChange,
        newPoints: data.newPoints,
        changeType: data.changeType,
        timestamp: data.timestamp,
        playerName: data.playerName,
    };
    if (data.reason) nonIdFields.reason = data.reason;
    return queryInsertChecked("pointHistory", { guid: data.guid }, nonIdFields, conn);
};

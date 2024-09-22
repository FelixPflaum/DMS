import type { LootHistorySearchInput } from "@/shared/types";
import type { DbInsertCheckedResult, DbRowsResult } from "../database";
import { queryInsertChecked, querySelect } from "../database";
import type { LootHistoryRow } from "../types";

/**
 * Get history entry page.
 * @param limit How many entries to get.
 * @param pageOffset Pagination page offset.
 * @returns
 */
export const getLootHistoryPage = (limit = 50, pageOffset = 0): Promise<DbRowsResult<LootHistoryRow>> => {
    return querySelect<LootHistoryRow>(`SELECT * FROM lootHistory ORDER BY timestamp DESC LIMIT ? OFFSET ?;`, [
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
export const getLootHistorySearch = (filter: LootHistorySearchInput, limit = 150): Promise<DbRowsResult<LootHistoryRow>> => {
    const wheres: string[] = [];
    const values: (string | number)[] = [];

    let k: keyof LootHistorySearchInput;
    for (k in filter) {
        if (typeof filter[k as keyof typeof filter] === "undefined") continue;
        switch (k) {
            case "playerName":
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

    let sql = `SELECT * FROM lootHistory`;
    if (wheres.length) sql += " WHERE " + wheres.join(" AND ");
    sql += ` ORDER BY timestamp DESC LIMIT ?;`;
    values.push(limit);

    return querySelect<LootHistoryRow>(sql, values);
};

/**
 * Create new history entry.
 * @param guid
 * @param timestamp
 * @param playerName
 * @param itemId
 * @param response
 * @param reverted
 * @returns
 */
export const createLootHistoryEntry = (
    guid: string,
    timestamp: number,
    playerName: string,
    itemId: number,
    response: string,
    reverted: boolean
): Promise<DbInsertCheckedResult> => {
    const nonIdFields: Omit<LootHistoryRow, "id" | "guid"> = {
        timestamp: timestamp,
        playerName: playerName,
        itemId: itemId,
        response: response,
        reverted: reverted ? 1 : 0,
    };
    return queryInsertChecked("lootHistory", { guid: guid }, nonIdFields);
};

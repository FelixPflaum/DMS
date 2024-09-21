import type { DbRowResult, DbRowsResult } from "../database";
import { querySelect, querySelectSingle } from "../database";
import type { ItemDataRow } from "../types";

/**
 * Get item data.
 * @param itemId
 * @returns
 */
export const getItemData = async (itemId: number): Promise<DbRowResult<ItemDataRow>> => {
    return querySelectSingle<ItemDataRow>(`SELECT * FROM itemData WHERE itemId=?;`, [itemId]);
};

/**
 * Get item data by name search.
 * @param searchTerm
 * @returns
 */
export const searchItemByName = async (searchTerm: string): Promise<DbRowsResult<ItemDataRow>> => {
    return querySelect<ItemDataRow>(`SELECT * FROM itemData WHERE itemName LIKE ?;`, ["%" + searchTerm + "%"]);
};

/**
 * Get all items.
 * @returns
 */
export const getAllItems = async (): Promise<DbRowsResult<ItemDataRow>> => {
    return querySelect<ItemDataRow>(`SELECT * FROM itemData;`);
};

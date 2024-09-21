import type { DbRowResult, DbUpdateResult } from "../database";
import { querySelectSingle, queryUpdateOrInsert } from "../database";
import type { SettingsRow } from "../types";

/**
 * Get settings entry from DB.
 * @param key
 * @returns
 */
export const getSetting = (key: string): Promise<DbRowResult<SettingsRow>> => {
    return querySelectSingle<SettingsRow>("SELECT * FROM settings WHERE skey=?", [key]);
};

/**
 * Set settings entry in DB.
 * @param key
 * @returns
 */
export const setSetting = async (key: string, value: string): Promise<DbUpdateResult> => {
    return queryUpdateOrInsert("settings", { skey: key }, { svalue: value });
};

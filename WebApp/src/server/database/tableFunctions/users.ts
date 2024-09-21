import { AccPermissions } from "@/shared/permissions";
import type { DbDeleteResult, DbInsertCheckedResult, DbRowResult, DbRowsResult, DbUpdateResult } from "../database";
import { queryDelete, queryInsertChecked, querySelect, querySelectSingle, queryUpdate } from "../database";
import type { UserRow } from "../types";

/**
 * Create new auth entry.
 * @param loginId
 * @param userName
 * @param permissions
 * @returns
 */
export const addUser = (
    loginId: string,
    userName: string,
    permissions = AccPermissions.NONE
): Promise<DbInsertCheckedResult> => {
    return queryInsertChecked("users", { loginId: loginId }, { userName: userName, permissions: permissions });
};

/**
 * Get auth entry.
 * @param loginId
 * @returns
 */
export const getUser = (loginId: string): Promise<DbRowResult<UserRow>> => {
    return querySelectSingle<UserRow>(`SELECT * FROM users WHERE loginId=?;`, [loginId]);
};

/**
 * Get all auth entries.
 * @returns
 */
export const getAllUsers = (): Promise<DbRowsResult<UserRow>> => {
    return querySelect<UserRow>(`SELECT * FROM users;`);
};

/**
 * Update auth entry.
 * @param loginId
 * @param newValues Object with values to update set. Unset value will not change.
 * @returns
 */
export const updateUser = async (loginId: string, newValues: Partial<UserRow>): Promise<DbUpdateResult> => {
    delete newValues.loginId;
    return queryUpdate("users", { loginId: loginId }, newValues);
};

/**
 * Remove auth entry.
 * @param loginId
 * @returns true if it was deleted, false if it didn't exist.
 */
export const removeUser = async (loginId: string): Promise<DbDeleteResult> => {
    return queryDelete("users", { loginId: loginId });
};

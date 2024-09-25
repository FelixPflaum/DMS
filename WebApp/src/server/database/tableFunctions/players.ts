import type { ClassId } from "@/shared/wow";
import type {
    DbDataValue,
    DbDeleteResult,
    DbInsertCheckedResult,
    DbRowResult,
    DbRowsResult,
    DbUpdateResult,
} from "../database";
import { queryDelete, queryInsertChecked, querySelect, querySelectSingle, queryUpdate } from "../database";
import type { PlayerRow } from "../types";
import type { PoolConnection } from "mysql2/promise";

/**
 * Get player entry.
 * @param name
 * @returns
 */
export const getPlayer = (name: string): Promise<DbRowResult<PlayerRow>> => {
    return querySelectSingle<PlayerRow>(`SELECT * FROM players WHERE playerName=?;`, [name]);
};

/**
 * Get all player entries.
 * @param conn
 * @returns
 */
export const getAllPlayers = (conn?: PoolConnection): Promise<DbRowsResult<PlayerRow>> => {
    return querySelect<PlayerRow>(`SELECT * FROM players;`, undefined, conn);
};

/**
 * Get player entries by account.
 * @param account
 * @returns
 */
export const getPlayersForAccount = (account: string): Promise<DbRowsResult<PlayerRow>> => {
    return querySelect<PlayerRow>(`SELECT playerName, classId, points, account FROM players WHERE account=?;`, [account]);
};

/**
 * Create new player entry.
 * @param name
 * @param classId
 * @param points
 * @param accountId
 * @returns
 */
export const createPlayer = (
    name: string,
    classId: ClassId,
    points: number,
    accountId?: string
): Promise<DbInsertCheckedResult> => {
    const fields: Record<string, DbDataValue> = { classId: classId, points: points };
    if (accountId) fields.account = accountId;
    return queryInsertChecked("players", { playerName: name }, fields);
};

/**
 * Update player entry.
 * @param name
 * @param newValues PlayerRow with values to update set. Unset values will not change.
 * @returns
 */
export const updatePlayer = (
    name: string,
    newValues: Partial<PlayerRow>,
    conn?: PoolConnection
): Promise<DbUpdateResult> => {
    return queryUpdate("players", { playerName: name }, newValues, conn);
};

/**
 * Remove player entry.
 * @param name
 * @returns
 */
export const deletePlayer = (name: string): Promise<DbDeleteResult> => {
    return queryDelete("players", { playerName: name });
};

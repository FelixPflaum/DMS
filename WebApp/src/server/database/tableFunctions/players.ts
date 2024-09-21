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

/**
 * Get player entry.
 * @param name
 * @returns
 */
export const getPlayer = async (name: string): Promise<DbRowResult<PlayerRow>> => {
    return querySelectSingle<PlayerRow>(`SELECT * FROM players WHERE playerName=?;`, [name]);
};

/**
 * Get all player entries.
 * @returns
 */
export const getAllPlayers = async (): Promise<DbRowsResult<PlayerRow>> => {
    return querySelect<PlayerRow>(`SELECT * FROM players;`);
};

/**
 * Create new player entry.
 * @param name
 * @param classId
 * @param points
 * @param accountId
 * @returns
 */
export const createPlayer = async (
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
export const updatePlayer = async (name: string, newValues: Partial<PlayerRow>): Promise<DbUpdateResult> => {
    return queryUpdate("players", { playerName: name }, newValues);
};

/**
 * Remove player entry.
 * @param name
 * @returns
 */
export const deletePlayer = async (name: string): Promise<DbDeleteResult> => {
    return queryDelete("players", { playerName: name });
};

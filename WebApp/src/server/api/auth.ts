import type { Request } from "express";
import { AccPermissions } from "@/shared/permissions";
import type { UserRow } from "../database/types";
import { getUser, updateUser } from "../database/tableFunctions/users";

export const TOKEN_LIFETIME = 7 * 86400 * 1000;
export const TOKEN_REFRESH_TIME = 3 * 86400 * 1000;

export class AuthUser {
    readonly loginId: string;
    readonly userName: string;
    readonly permissions: AccPermissions;
    readonly isAdmin: boolean;

    constructor(userData: UserRow) {
        this.loginId = userData.loginId;
        this.userName = userData.userName;
        this.permissions = userData.permissions;
        this.isAdmin = (userData.permissions & AccPermissions.ADMIN) !== 0;
    }

    /**
     * Check if user has permissions.
     * @param permissions
     * @returns true if (all) permission(s) are set or user has admin permission.
     */
    hasPermission(permissions: AccPermissions): boolean {
        return this.isAdmin || (this.permissions & permissions) === permissions;
    }
}

/**
 * Check if request provides valid login cookies.
 * @param req The Request object.
 * @returns The user data if valid login data in request, otherwise false.
 */
export const getUserFromRequest = async (req: Request): Promise<AuthUser | false> => {
    if (!req.cookies) return false;
    const loginId = req.cookies.loginId;
    const loginToken = req.cookies.loginToken;
    if (!loginId || !loginToken) return false;

    const userRes = await getUser(loginId);
    if (userRes.isError || !userRes.row) return false;

    const userRow = userRes.row;
    if (!userRow.loginToken || userRow.loginToken != loginToken) return false;

    const now = Date.now();
    const remainingLife = userRow.validUntil - now;
    if (remainingLife <= 0) {
        await updateUser(loginId, { loginToken: "" });
        return false;
    } else if (remainingLife < TOKEN_REFRESH_TIME) {
        await updateUser(loginId, { validUntil: now + TOKEN_LIFETIME });
    }

    return new AuthUser(userRow);
};

/**
 * Generates a random hex string.
 * @param byteLen Byte length of the string.
 * @returns The random hex string.
 */
export const generateLoginToken = (): string => {
    let bytes = 16;
    let hex = "";
    while (bytes > 0) {
        const usedBytes = Math.min(4, bytes);
        const max = Math.pow(2, 8 * usedBytes);
        hex += Math.floor(Math.random() * max)
            .toString(16)
            .padStart(2 * usedBytes, "0");
        bytes -= usedBytes;
    }
    return hex;
};

import type { Request } from "express";
import { AccPermissions } from "@/shared/permissions";
import type { UserRow } from "../database/types";
import { getUser, updateUser } from "../database/tableFunctions/users";
import type { ApiUserEntry } from "@/shared/types";

export const TOKEN_LIFETIME = 7 * 86400 * 1000;
export const TOKEN_REFRESH_TIME = 3 * 86400 * 1000;

const dummyUser: ApiUserEntry = {
    loginId: "",
    userName: "",
    permissions: 0,
    lastActivity: 0,
};

export class RequestAuth {
    readonly validLogin: boolean;
    readonly isDbError: boolean;
    readonly user: Readonly<ApiUserEntry> = dummyUser;
    readonly isAdmin: boolean;

    constructor(isDbError: boolean, userData?: UserRow) {
        this.isDbError = isDbError;
        this.validLogin = !!userData;
        if (userData) {
            this.user = {
                loginId: userData.loginId,
                userName: userData.userName,
                permissions: userData.permissions,
                lastActivity: userData.lastActivity,
            };
        }
        this.isAdmin = !!userData && (userData.permissions & AccPermissions.ADMIN) !== 0;
    }

    /**
     * Check if user has permissions.
     * @param permissions
     * @returns true if (all) permission(s) are set or user has admin permission.
     */
    hasPermission(permissions: AccPermissions): boolean {
        return this.isAdmin || (this.user.permissions & permissions) === permissions;
    }
}

/**
 * Check if request provides valid login cookies.
 * @param req The Request object.
 * @returns A RequestAuth instance if login data was provided, otherwise undefined.
 */
export const getAuthFromRequest = async (req: Request): Promise<RequestAuth | undefined> => {
    if (!req.cookies) return;
    const loginId = req.cookies.loginId;
    const loginToken = req.cookies.loginToken;
    if (!loginId || !loginToken) return;

    const userRes = await getUser(loginId);
    if (userRes.isError) return new RequestAuth(true);
    if (!userRes.row || !userRes.row.loginToken || userRes.row.loginToken != loginToken) {
        return new RequestAuth(false);
    }

    const now = Date.now();
    const remainingLife = userRes.row.validUntil - now;

    if (remainingLife <= 0) {
        await updateUser(loginId, { loginToken: "", lastActivity: now });
        return new RequestAuth(false);
    } else if (remainingLife < TOKEN_REFRESH_TIME) {
        await updateUser(loginId, { validUntil: now + TOKEN_LIFETIME, lastActivity: now });
    } else {
        await updateUser(loginId, { lastActivity: now });
    }

    return new RequestAuth(false, userRes.row);
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

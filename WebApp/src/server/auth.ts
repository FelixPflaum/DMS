import { Request } from "express";
import { authDb } from "./database/database";
import { AccPermissions } from "@/shared/enums";

export const TOKEN_LIFETIME = 7 * 86400 * 1000;
export const TOKEN_REFRESH_TIME = 3 * 86400 * 1000;

export class AuthUser {
    constructor(
        readonly loginId: string,
        readonly userName: string,
        readonly permissions: AccPermissions
    ) {}

    /**
     * Check if user has permissions.
     * @param permissions
     * @returns true if (all) permission(s) are set.
     */
    hasPermission(permissions: AccPermissions): boolean {
        return (this.permissions & permissions) === permissions;
    }
}

/**
 * Check if request provides valid login cookies.
 * @param req The Request object.
 * @returns The user data if valid login data in request, otherwise false.
 */
export const checkRequestAuth = async (req: Request): Promise<AuthUser | false> => {
    if (!req.cookies) return false;
    const loginId = req.cookies.loginId;
    const loginToken = req.cookies.loginToken;
    if (!loginId || !loginToken) return false;

    try {
        const authData = await authDb.getEntry(loginId);
        if (!authData || !authData.loginToken) return false;
        if (authData.loginToken != loginToken) return false;

        const now = Date.now();
        const remainingLife = authData.validUntil - now;
        if (remainingLife <= 0) {
            await authDb.updateEntry(loginId, { loginToken: "" });
            return false;
        } else if (remainingLife < TOKEN_REFRESH_TIME) {
            await authDb.updateEntry(loginId, { validUntil: now + TOKEN_LIFETIME });
        }

        return new AuthUser(loginId, authData.userName, authData.permissions);
    } catch (error) {
        console.error(error);
        // Just treat this as no permissions on any DB error.
        return false;
    }
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

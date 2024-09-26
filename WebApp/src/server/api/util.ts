import type { AccPermissions } from "@/shared/permissions";
import type { ApiResponse } from "@/shared/types";
import type { Response } from "express";
import type { RequestAuth } from "./auth";

/** Check if auth has valid login and permissions.  */
export const checkAuth = (res: Response, auth?: RequestAuth, permissions?: AccPermissions): auth is RequestAuth => {
    if (!auth) {
        send401(res);
        return false;
    }
    if (auth.isDbError) {
        send500Db(res);
        return false;
    }
    if (!auth.validLogin) {
        send401(res);
        return false;
    }
    if (permissions && !auth.hasPermission(permissions)) {
        send403(res);
        return false;
    }
    return true;
};

/**
 * Send api response.
 * @param res
 * @param data if string then send as error, if true send default success response, otherwise provide custom response data.
 */
export const sendApiResponse = <T extends ApiResponse>(res: Response, data: T | string | true): void => {
    if (typeof data === "string") {
        const apires: ApiResponse = { error: data };
        res.send(apires);
    } else if (data === true) {
        const apires: ApiResponse = {};
        res.send(apires);
    } else {
        res.send(data);
    }
};

/** Send 400 */
export const send400 = (res: Response, reason: string): void => {
    const r: ApiResponse = {
        error: reason,
    };
    res.status(401).send(r);
};

/** Send 401 */
export const send401 = (res: Response): void => {
    const r: ApiResponse = {
        error: "Unauthorized.",
    };
    res.status(401).send(r);
};

/** Send 403 */
export const send403 = (res: Response, reason = "Missing permissions."): void => {
    const r: ApiResponse = {
        error: reason,
    };
    res.status(403).send(r);
};

/** Send 404 */
export const send404 = (res: Response, reason = "No found."): void => {
    const r: ApiResponse = {
        error: reason,
    };
    res.status(404).send(r);
};

/** Send 429, "Try again later." */
export const send429 = (res: Response): void => {
    const r: ApiResponse = {
        error: "Try again later.",
    };
    res.status(429).send(r);
};

/** Send 500*/
export const send500 = (res: Response, reason = "Server error."): void => {
    const r: ApiResponse = {
        error: reason,
    };
    res.status(500).send(r);
};

/** Send 500, DB operation failed.*/
export const send500Db = (res: Response): void => {
    const r: ApiResponse = {
        error: "DB operation failed.",
    };
    res.status(500).send(r);
};

/**
 * Parses input for int and returns number if successful.
 * @param input
 * @returns The number or undefined.
 */
export const parseIntIfNumber = (input: unknown): number | undefined => {
    if (typeof input !== "string") return;
    const parseResult = parseInt(input);
    if (typeof parseResult === "number") return parseResult;
};

/**
 * Return string if input is string.
 * @param input
 * @returns The input string or undefined.
 */
export const getStringIfString = (input: unknown): string | undefined => {
    if (typeof input === "string") return input;
};

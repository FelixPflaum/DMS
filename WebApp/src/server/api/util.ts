import { Response } from "express";

/** Send 400 */
export const send400 = (res: Response, reason: string): void => {
    const r: ErrorRes = {
        error: reason,
    };
    res.status(401).send(r);
};

/** Send 401 */
export const send401 = (res: Response): void => {
    const r: ErrorRes = {
        error: "Unauthorized.",
    };
    res.status(401).send(r);
};

/** Send 403 */
export const send403 = (res: Response, reason = "Missing permissions."): void => {
    const r: ErrorRes = {
        error: reason,
    };
    res.status(403).send(r);
};

/** Send 429, "Try again later." */
export const send429 = (res: Response): void => {
    const r: ErrorRes = {
        error: "Try again later.",
    };
    res.status(429).send(r);
};

/** Send 500*/
export const send500 = (res: Response, reason = "Server error."): void => {
    const r: ErrorRes = {
        error: reason,
    };
    res.status(500).send(r);
};

/** Send 500, DB operation failed.*/
export const send500Db = (res: Response): void => {
    const r: ErrorRes = {
        error: "DB operation failed.",
    };
    res.status(500).send(r);
};

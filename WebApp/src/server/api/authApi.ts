import express from "express";
import { Request, Response } from "express";
import { getConfig } from "../config";
import { AccPermissions } from "@/shared/enums";
import { SpamCheck } from "./spamCheck";
import { getUserDataFromOauthCode } from "../discordApi";
import { authDb } from "../database/database";
import { checkRequestAuth, generateLoginToken, TOKEN_LIFETIME } from "../auth";
import { send500Db, send401, send400, send500, send429 } from "./util";
import { Logger } from "../Logger";

export const authRouter = express.Router();
const logger = new Logger("API:Auth");
const authSpamCheck = new SpamCheck(2, 60000);

authRouter.post("/authenticate", async (req: Request, res: Response): Promise<void> => {
    const code = req.body.code;

    if (authSpamCheck.isSpam(req)) {
        return send429(res);
    }

    if (typeof code != "string") {
        return send400(res, "No code provided!");
    }

    const userData = await getUserDataFromOauthCode(code);
    if (!userData) {
        return send500(res, "Failed to get user data!");
    }
    const loginId = userData.id;
    const loginToken = generateLoginToken();
    const userName = userData.userName; // TODO: does bot get that by default?

    try {
        const userEntry = await authDb.getEntry(loginId);
        if (!userEntry) {
            if (loginId == getConfig().adminLoginId) {
                const didCreate = await authDb.createEntry(loginId, userName, AccPermissions.ALL);
                if (!didCreate) {
                    return send500(res, "Failed to create admin user entry!");
                }
            } else {
                return send401(res);
            }
        }
    } catch (error) {
        logger.logError("Getting or creating auth entry in authentication process failed.", error);
        return send500Db(res);
    }

    try {
        await authDb.updateEntry(loginId, {
            loginToken,
            userName,
            validUntil: Date.now() + TOKEN_LIFETIME,
        });
        const authRes: AuthRes = { loginId, loginToken };
        res.send(authRes);
        return;
    } catch (error) {
        logger.logError("Updating auth entry in auth process failed.", error);
        return send500Db(res);
    }
});

authRouter.get("/user", async (req: Request, res: Response): Promise<void> => {
    const checkRes: AuthUserRes = {
        loginValid: false,
        userName: "",
        permissions: 0,
    };
    const auth = await checkRequestAuth(req);
    if (auth) {
        checkRes.loginValid = true;
        checkRes.userName = auth.userName;
        checkRes.permissions = auth.permissions;
    }
    res.send(checkRes);
});

authRouter.get("/logout", async (req: Request, res: Response): Promise<void> => {
    const auth = await checkRequestAuth(req);
    if (!auth) return send401(res);

    try {
        await authDb.updateEntry(auth.loginId, { loginToken: "" });
        res.status(200).end();
    } catch (error) {
        logger.logError("Logout failed.", error);
        return send500Db(res);
    }
});

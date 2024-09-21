import express from "express";
import type { Request, Response } from "express";
import { SpamCheck } from "../SpamCheck";
import { getUserDataFromOauthCode } from "../../discordApi";
import { getUserFromRequest, generateLoginToken, TOKEN_LIFETIME } from "../auth";
import { send500Db, send401, send400, send500, send429 } from "../util";
import type { AuthRes, AuthUserRes } from "@/shared/types";
import { getUser, updateUser } from "@/server/database/tableFunctions/users";

export const authRouter = express.Router();
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

    const userRes = await getUser(loginId);
    if (userRes.isError) send500Db(res);
    if (!userRes.row) return send401(res);

    const updateRes = await updateUser(loginId, { loginToken, validUntil: Date.now() + TOKEN_LIFETIME });
    if (updateRes.isError) send500Db(res);

    const authRes: AuthRes = { loginId, loginToken };
    res.send(authRes);
});

authRouter.get("/self", async (req: Request, res: Response): Promise<void> => {
    const checkRes: AuthUserRes = {
        loginValid: false,
        userName: "",
        permissions: 0,
    };
    const auth = await getUserFromRequest(req);
    if (auth) {
        checkRes.loginValid = true;
        checkRes.userName = auth.userName;
        checkRes.permissions = auth.permissions;
    }
    res.send(checkRes);
});

authRouter.get("/logout", async (req: Request, res: Response): Promise<void> => {
    const auth = await getUserFromRequest(req);
    if (!auth) return send401(res);

    const updateRes = await updateUser(auth.loginId, { loginToken: "" });
    if (updateRes.isError) return send500Db(res);
    res.status(200).end();
});

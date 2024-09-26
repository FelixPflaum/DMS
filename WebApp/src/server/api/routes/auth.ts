import express from "express";
import type { Request, Response } from "express";
import { SpamCheck } from "../SpamCheck";
import { getUserDataFromOauthCode } from "../../discordApi";
import { generateLoginToken, getAuthFromRequest, TOKEN_LIFETIME } from "../auth";
import { send500Db, send401, send400, send500, send429, sendApiResponse, checkAuth } from "../util";
import type { ApiAuthRes, ApiAuthUserRes } from "@/shared/types";
import { getUser, updateUser } from "@/server/database/tableFunctions/users";
import { getSetting } from "@/server/database/tableFunctions/settings";

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

    sendApiResponse<ApiAuthRes>(res, { loginId, loginToken });
});

authRouter.get("/check", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!auth) return send401(res);
    if (auth.isDbError) return send500Db(res);
    const apiRes: ApiAuthUserRes = {
        invalidLogin: true,
        user: { userName: "", loginId: "", permissions: 0, lastActivity: 0 },
        itemDbVer: 0,
    };
    if (auth.validLogin && auth.user) {
        apiRes.invalidLogin = false;
        apiRes.user.userName = auth.user.userName;
        apiRes.user.loginId = auth.user.loginId;
        apiRes.user.permissions = auth.user.permissions;
        apiRes.user.lastActivity = auth.user.lastActivity;

        const itemDbVer = await getSetting("itemDbVersion");
        if (itemDbVer.isError) return send500Db(res);
        apiRes.itemDbVer = parseInt(itemDbVer.row?.svalue ?? "0") || 0;
    }
    sendApiResponse(res, apiRes);
});

authRouter.get("/logout", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth)) return;

    const updateRes = await updateUser(auth.user.loginId, { loginToken: "" });
    if (updateRes.isError) return send500Db(res);
    sendApiResponse(res, true);
});

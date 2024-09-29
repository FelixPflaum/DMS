import express from "express";
import type { Request, Response } from "express";
import { getAuthFromRequest } from "../auth";
import { checkAuth, send400, send500, send500Db, sendApiResponse } from "../util";
import { AccPermissions } from "@/shared/permissions";
import {
    checkValueType,
    getDynamicSetting,
    getDynamicSettings,
    isDynamicSettingKey,
    setDynamicSetting,
} from "@/server/configDynamic";
import type { ApiSetSettingReq, ApiSettingRes } from "@/shared/types";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";

export const settingsRouter = express.Router();

settingsRouter.get("/get", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.SETTINGS_VIEW)) return;

    const getRes = await getDynamicSettings();
    if (getRes.dbError) return send500Db(res);

    if (!getRes.data) {
        return send500(res, "Settings DB is corrupted.");
    }

    sendApiResponse<ApiSettingRes>(res, { settings: getRes.data });
});

settingsRouter.post("/set", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.SETTINGS_EDIT)) return;

    const data = req.body as Partial<ApiSetSettingReq>;
    if (!data.changes || !Array.isArray(data.changes)) return send400(res, "Invalid data format.");
    const changeLogs: string[] = [];
    let change: Partial<ApiSetSettingReq["changes"][0]>;
    for (change of data.changes) {
        const k = change.key;
        const v = change.value;
        if (!isDynamicSettingKey(k)) return send400(res, "Invalid change key!");
        if (!checkValueType(k, v)) return send400(res, `invalid value type for key ${k}!`);
        const curRes = await getDynamicSetting(k);
        if (curRes.dbError) return send500Db(res);
        const setRes = await setDynamicSetting(k, v);
        if (!setRes) return send500Db(res);
        changeLogs.push(`${k}: ${curRes.value} -> ${v}`);
    }
    if (changeLogs.length) {
        await addAuditEntry(auth.user.loginId, auth.user.userName, "Updated settings", changeLogs.join(", "));
    }

    sendApiResponse(res, true);
});

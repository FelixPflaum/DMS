import express from "express";
import type { Request, Response } from "express";
import { getUserFromRequest } from "../auth";
import { send400, send401, send403, send500, send500Db } from "../util";
import { AccPermissions } from "@/shared/permissions";
import {
    checkValueType,
    getDynamicSetting,
    getDynamicSettings,
    isDynamicSettingKey,
    setDynamicSetting,
} from "@/server/configDynamic";
import type { ApiSetSettingReq, ApiSettingRes, UpdateRes } from "@/shared/types";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";

export const settingsRouter = express.Router();

settingsRouter.get("/get", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.SETTINGS_VIEW)) return send403(res);

    const getRes = await getDynamicSettings();
    if (getRes.dbError) return send500Db(res);

    if (getRes.data) {
        const apiRes: ApiSettingRes = getRes.data;
        res.send(apiRes);
    } else {
        return send500(res, "Settings DB is corrupted.");
    }
});

settingsRouter.post("/set", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.SETTINGS_EDIT)) return send403(res);

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
        const auditLog = `${user.userName} updated settings: ${changeLogs.join(", ")}`;
        await addAuditEntry(user.loginId, user.userName, auditLog);
    }
    const updateResponse: UpdateRes = { success: true };
    res.send(updateResponse);
});

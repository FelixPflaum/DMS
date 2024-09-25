import express from "express";
import type { Request, Response } from "express";
import { getUserFromRequest } from "../auth";
import { send400, send401, send403 } from "../util";
import { AccPermissions } from "@/shared/permissions";
import type { ApiBackupListRes, ApiMakeBackupRes, ApiResponse } from "@/shared/types";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";
import { applyDataBackup, getBackupList, makeDataBackup } from "@/server/importExport/backup";
import { getConnection } from "@/server/database/database";

export const backupRouter = express.Router();

backupRouter.get("/list/:year?/:month?", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.SETTINGS_VIEW)) return send403(res);

    const yearParam = req.params["year"];
    const monthParam = req.params["month"];
    const year = yearParam ? parseInt(yearParam) || undefined : undefined;
    const month = year && monthParam ? parseInt(monthParam) || undefined : undefined;

    const list: ApiBackupListRes = await getBackupList(year, month);
    res.send(list);
});

backupRouter.post("/make", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.SETTINGS_EDIT)) return send403(res);

    const apiRes: ApiMakeBackupRes = { file: "" };
    const conn = await getConnection();
    try {
        const fileOrFalse = await makeDataBackup(conn, 0, "manual");
        const log = `Create manual backup: ${fileOrFalse}`;
        await addAuditEntry(user.loginId, user.userName, log);
        if (fileOrFalse !== false) {
            apiRes.file = fileOrFalse;
        } else {
            apiRes.error = "Backup creation failed!";
        }
    } finally {
        conn.release();
    }
    res.send(apiRes);
});

backupRouter.post("/apply", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.SETTINGS_EDIT)) return send403(res);

    const path = req.body.path as unknown;
    if (!path || !Array.isArray(path)) return send400(res, "Invalid arguments!");
    for (const p of path) {
        if (typeof p !== "string") send400(res, "Invalid path parts!");
    }

    const apiRes: ApiResponse = {};
    const applyResult = await applyDataBackup(path);
    if (applyResult !== true) {
        apiRes.error = applyResult;
    } else {
        const log = `Applied backup: ${path.join("/")}`;
        await addAuditEntry(user.loginId, user.userName, log);
    }

    res.send(apiRes);
});

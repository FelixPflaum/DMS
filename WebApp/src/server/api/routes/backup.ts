import express from "express";
import type { Request, Response } from "express";
import { getAuthFromRequest } from "../auth";
import { checkAuth, send400, sendApiResponse } from "../util";
import { AccPermissions } from "@/shared/permissions";
import type { ApiBackupListRes, ApiMakeBackupRes } from "@/shared/types";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";
import { applyDataBackup, getBackupList, makeDataBackup } from "@/server/importExport/backup";
import { getConnection } from "@/server/database/database";

export const backupRouter = express.Router();

backupRouter.get("/list/:year?/:month?", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.SETTINGS_VIEW)) return;

    const yearParam = req.params["year"];
    const monthParam = req.params["month"];
    const year = yearParam ? parseInt(yearParam) || undefined : undefined;
    const month = year && monthParam ? parseInt(monthParam) || undefined : undefined;

    const list = await getBackupList(year, month);
    sendApiResponse<ApiBackupListRes>(res, { list });
});

backupRouter.post("/make", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.SETTINGS_EDIT)) return;

    const apiRes: ApiMakeBackupRes = { file: "" };
    const conn = await getConnection();
    try {
        const fileOrFalse = await makeDataBackup(conn, 0, "manual");
        const log = `Create manual backup: ${fileOrFalse}`;
        await addAuditEntry(auth.user.loginId, auth.user.userName, log);
        if (fileOrFalse !== false) {
            apiRes.file = fileOrFalse;
        } else {
            apiRes.error = "Backup creation failed!";
        }
    } catch (error) {
        console.error(error); // Don't think we can end up here anyway.
        apiRes.error = "Error on backup creation.";
    } finally {
        conn.release();
    }

    sendApiResponse<ApiMakeBackupRes>(res, apiRes);
});

backupRouter.post("/apply", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.SETTINGS_EDIT)) return;

    const path = req.body.path as unknown;
    if (!path || !Array.isArray(path)) {
        return send400(res, "Invalid arguments!");
    }
    for (const p of path) {
        if (typeof p !== "string") send400(res, "Invalid path parts!");
    }

    const applyResult = await applyDataBackup(path);
    if (applyResult !== true) {
        return sendApiResponse(res, applyResult);
    }

    const log = `Applied backup: ${path.join("/")}`;
    await addAuditEntry(auth.user.loginId, auth.user.userName, log);

    sendApiResponse(res, true);
});

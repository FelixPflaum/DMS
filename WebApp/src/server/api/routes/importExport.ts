import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { checkAuth, send400, send404, send500, send500Db, sendApiResponse } from "../util";
import { parseAddonExport } from "@/server/importExport/parseAddonData";
import type { ApiImportLogRes, ApiExportResult, ApiImportLogListResult, ApiImportResult } from "@/shared/types";
import { addImportLog, getImportLog, getImportLogList } from "@/server/database/tableFunctions/importLogs";
import { importAddonExport } from "@/server/importExport/importToDb";
import { createExportForAddon } from "@/server/importExport/export";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";

export const importExportRouter = express.Router();

importExportRouter.post("/import", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;

    if (!req.body.input) return send400(res, "Invalid input data!");

    const parseResult = await parseAddonExport(req.body.input);
    if (parseResult.error || !parseResult.data) {
        return sendApiResponse(res, parseResult.error || "Parsing import data failed.");
    }

    const importRes = await importAddonExport(parseResult.data);
    const log = importRes.log;
    if (importRes.error || !log) {
        return sendApiResponse(res, importRes.error || "Parsing import data failed.");
    }

    const insertId = await addImportLog(auth.user.loginId, JSON.stringify(log));
    await addAuditEntry(auth.user.loginId, auth.user.userName, `Imported data. Log id: ${insertId}`);

    sendApiResponse<ApiImportResult>(res, { log: log });
});

importExportRouter.get("/export", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const exportForAddon = await createExportForAddon();
    if (!exportForAddon) return send500(res, "Error creating export data!");
    sendApiResponse<ApiExportResult>(res, { export: exportForAddon });
});

importExportRouter.get("/logs", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;
    const limit = 100;
    const getRes = await getImportLogList(limit);
    if (getRes.isError) return send500Db(res);
    sendApiResponse<ApiImportLogListResult>(res, { logs: getRes.rows });
});

importExportRouter.get("/log/:id", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;

    const id = parseInt(req.params.id);
    if (!id) return send400(res, "Invalid log id!");

    const getRes = await getImportLog(id);
    if (getRes.isError) return send500Db(res);
    if (!getRes.row) return send404(res, "Log not found!");
    sendApiResponse<ApiImportLogRes>(res, { entry: getRes.row });
});

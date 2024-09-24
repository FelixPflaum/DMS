import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send400, send401, send403, send404, send500, send500Db } from "../util";
import { parseAddonExport } from "@/server/importExport/parseAddonData";
import type { ApiExportResult, ApiImportLogListResult, ApiImportResult } from "@/shared/types";
import { addImportLog, getImportLog, getImportLogList } from "@/server/database/tableFunctions/importLogs";
import { importToDatabase } from "@/server/importExport/importToDb";
import { createExportForAddon } from "@/server/importExport/export";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";

export const importExportRouter = express.Router();

importExportRouter.post("/import", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);

    if (!req.body.input) return send400(res, "Invalid input data!");

    const apiResult: ApiImportResult = {};

    const parseResult = await parseAddonExport(req.body.input);
    if (parseResult.error || !parseResult.data) {
        apiResult.error = parseResult.error;
        res.send(apiResult);
        return;
    }

    const importRes = await importToDatabase(parseResult.data);
    if (importRes.error) {
        apiResult.error = importRes.error;
        res.send(apiResult);
        return;
    }

    importRes.log = importRes.log;
    const insertId = await addImportLog(user.loginId, JSON.stringify(importRes.log));
    await addAuditEntry(user.loginId, user.userName, `Imported data. Log id: ${insertId}`);

    res.send(importRes);
});

importExportRouter.get("/export", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const exportForAddon = await createExportForAddon();
    if (!exportForAddon) return send500(res, "Error of creating export data!");
    const apiRes: ApiExportResult = { export: exportForAddon };
    res.send(apiRes);
});

importExportRouter.get("/logs", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);
    const limit = 100;
    const getRes = await getImportLogList(limit);
    if (getRes.isError) return send500Db(res);
    const apiRes: ApiImportLogListResult = { logs: getRes.rows };
    res.send(apiRes);
});

importExportRouter.get("/log/:id", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);

    const id = parseInt(req.params.id);
    if (!id) return send400(res, "Invalid log id!");

    const getRes = await getImportLog(id);
    if (getRes.isError) return send500Db(res);
    if (!getRes.row) return send404(res, "Log not found!");
    res.send(getRes.row);
});

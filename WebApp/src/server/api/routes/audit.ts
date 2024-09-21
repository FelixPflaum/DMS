import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send500Db, send401, send403 } from "../util";
import type { AuditRes } from "@/shared/types";
import { getAuditPage } from "@/server/database/tableFunctions/audit";

export const auditRouter = express.Router();

auditRouter.get("/page/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.AUDIT_VIEW)) return send403(res);

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    const limit = 50;
    const rowsResult = await getAuditPage(limit, pageOffset);
    if (rowsResult.isError) return send500Db(res);
    const auditRes: AuditRes = {
        pageOffset: pageOffset,
        entries: rowsResult.rows,
        haveMore: rowsResult.rows.length == limit,
    };
    res.send(auditRes);
});

import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send500Db, sendApiResponse, checkAuth } from "../util";
import type { ApiAuditPageRes } from "@/shared/types";
import { getAuditPage } from "@/server/database/tableFunctions/audit";

export const auditRouter = express.Router();

auditRouter.get("/page/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.AUDIT_VIEW)) return;

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    const limit = 50;
    const rowsResult = await getAuditPage(limit, pageOffset);
    if (rowsResult.isError) return send500Db(res);

    sendApiResponse<ApiAuditPageRes>(res, {
        pageOffset: pageOffset,
        entries: rowsResult.rows,
        haveMore: rowsResult.rows.length == limit,
    });
});

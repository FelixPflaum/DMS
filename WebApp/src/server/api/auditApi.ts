import express from "express";
import { Request, Response } from "express";
import { AccPermissions } from "@/shared/enums";
import { auditDb } from "../database/database";
import { checkRequestAuth } from "../auth";
import { send500Db, send401, send403 } from "./util";
import { Logger } from "../Logger";

export const auditRouter = express.Router();
const logger = new Logger("API:Audit");

auditRouter.get("/get/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const user = await checkRequestAuth(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.AUDIT_VIEW)) return send403(res);

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    try {
        const limit = 50;
        const entries = await auditDb.getEntries(limit, pageOffset);
        const auditRes: AuditRes = {
            pageOffset: pageOffset,
            entries: entries,
            haveMore: entries.length == limit,
        };
        res.send(auditRes);
    } catch (error) {
        logger.logError("Getting audit log page failed.", error);
        return send500Db(res);
    }
});

import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send400, send403, send500Db, send401, parseIntIfNumber, getStringIfString } from "../util";
import type { PointHistoryEntry, PointHistoryPageRes, PointHistorySearchInput, UpdateRes } from "@/shared/types";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";
import {
    createPointHistoryEntry,
    getPointHistoryPage,
    getPointHistorySearch,
} from "@/server/database/tableFunctions/pointHistory";

export const pointHistoryRouter = express.Router();

pointHistoryRouter.get("/page/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    const limit = 100;
    const rowsResult = await getPointHistoryPage(limit, pageOffset);
    if (rowsResult.isError) return send500Db(res);

    const historyRes: PointHistoryPageRes = {
        pageOffset: pageOffset,
        entries: rowsResult.rows,
        haveMore: rowsResult.rows.length == limit,
    };

    res.send(historyRes);
});

pointHistoryRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);

    const body = req.body as Partial<PointHistoryEntry>;
    const timestamp = body.timestamp;
    const playerName = body.playerName;
    const pointChange = body.pointChange;
    const newPoints = body.newPoints;
    const changeType = body.changeType;
    const reason = body.reason;

    if (!playerName || playerName.length < 2) return send400(res, "Invalid player name.");
    if (typeof pointChange !== "number") return send400(res, "Invalid pointChange.");
    if (typeof timestamp !== "number") return send400(res, "Invalid timestamp.");
    if (typeof newPoints !== "number") return send400(res, "Invalid newPoints.");
    if (typeof newPoints !== "number") return send400(res, "Invalid newPoints.");
    if (!changeType || changeType.length < 2) return send400(res, "Invalid changeType.");
    if (reason && typeof reason !== "string") return send400(res, "Invalid reason.");

    const userRes: UpdateRes = { success: true };

    const createRes = await createPointHistoryEntry(timestamp, playerName, pointChange, newPoints, changeType, reason);
    if (createRes.isError) return send500Db(res);
    if (createRes.duplicate) {
        userRes.success = false;
        userRes.error = "Entry already exists!";
    } else {
        const log = `Created point history entry ${timestamp} ${playerName}, Change: ${pointChange}, New points: ${newPoints}, Type: ${changeType}, Reason: ${reason ?? ""}`;
        await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
    }

    res.send(userRes);
});

pointHistoryRouter.get("/search", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const filter: PointHistorySearchInput = {
        playerName: getStringIfString(req.query.playerName),
        timeStart: parseIntIfNumber(req.query.timeStart),
        timeEnd: parseIntIfNumber(req.query.timeEnd),
    };

    const rowsResult = await getPointHistorySearch(filter);
    if (rowsResult.isError) return send500Db(res);

    const historyRes: PointHistoryEntry[] = rowsResult.rows;
    res.send(historyRes);
});

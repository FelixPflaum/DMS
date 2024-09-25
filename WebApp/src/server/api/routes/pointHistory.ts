import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send403, send500Db, send401, parseIntIfNumber, getStringIfString } from "../util";
import type { PointHistoryEntry, PointHistoryPageRes, PointHistorySearchInput } from "@/shared/types";
import { getPointHistoryPage, getPointHistorySearch } from "@/server/database/tableFunctions/pointHistory";

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

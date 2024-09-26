import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send500Db, parseIntIfNumber, getStringIfString, checkAuth, sendApiResponse } from "../util";
import type { ApiPointHistorySearchInput, ApiPointHistoryPageRes, ApiPointHistorySearchRes } from "@/shared/types";
import { getPointHistoryPage, getPointHistorySearch } from "@/server/database/tableFunctions/pointHistory";

export const pointHistoryRouter = express.Router();

pointHistoryRouter.get("/page/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    const limit = 100;
    const rowsResult = await getPointHistoryPage(limit, pageOffset);
    if (rowsResult.isError) return send500Db(res);

    sendApiResponse<ApiPointHistoryPageRes>(res, {
        pageOffset: pageOffset,
        entries: rowsResult.rows,
        haveMore: rowsResult.rows.length == limit,
    });
});

pointHistoryRouter.get("/search", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const filter: ApiPointHistorySearchInput = {
        playerName: getStringIfString(req.query.playerName),
        timeStart: parseIntIfNumber(req.query.timeStart),
        timeEnd: parseIntIfNumber(req.query.timeEnd),
    };

    const rowsResult = await getPointHistorySearch(filter);
    if (rowsResult.isError) return send500Db(res);

    sendApiResponse<ApiPointHistorySearchRes>(res, { list: rowsResult.rows });
});

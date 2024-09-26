import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send500Db, parseIntIfNumber, getStringIfString, checkAuth, sendApiResponse } from "../util";
import type { ApiLootHistoryPageRes, ApiLootHistorySearchRes, LootHistorySearchInput } from "@/shared/types";
import { getLootHistoryPage, getLootHistorySearch } from "@/server/database/tableFunctions/lootHistory";

export const lootHistoryRouter = express.Router();

lootHistoryRouter.get("/page/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    const limit = 100;
    const rowsResult = await getLootHistoryPage(limit, pageOffset);
    if (rowsResult.isError) return send500Db(res);

    sendApiResponse<ApiLootHistoryPageRes>(res, {
        pageOffset: pageOffset,
        entries: rowsResult.rows,
        haveMore: rowsResult.rows.length == limit,
    });
});

lootHistoryRouter.get("/search/:name/:start/:end", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const filter: LootHistorySearchInput = {
        playerName: getStringIfString(req.query.playerName),
        timeStart: parseIntIfNumber(req.query.timeStart),
        timeEnd: parseIntIfNumber(req.query.timeEnd),
    };

    const rowsResult = await getLootHistorySearch(filter);
    if (rowsResult.isError) return send500Db(res);
    sendApiResponse<ApiLootHistorySearchRes>(res, { results: rowsResult.rows });
});

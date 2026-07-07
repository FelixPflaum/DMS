import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send500Db, parseIntIfNumber, getStringIfString, checkAuth, sendApiResponse, send400 } from "../util";
import type { ApiLootHistoryPageRes, ApiLootHistorySearchRes, LootHistorySearchInput } from "@/shared/types";
import {
    getLootHistoryByIds,
    getLootHistoryEntries,
    getLootHistoryPage,
    getLootHistorySearch,
} from "@/server/database/tableFunctions/lootHistory";
import { searchItemByName } from "@/server/database/tableFunctions/itemData";

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

lootHistoryRouter.get("/searchitem/:search", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const search = getStringIfString(req.params.search);
    if (!search) return send400(res, "No search input");

    const itemResults = await searchItemByName(search, 100);
    if (itemResults.isError) return send500Db(res);

    if (itemResults.rows.length === 0) {
        sendApiResponse<ApiLootHistorySearchRes>(res, { results: [] });
        return;
    }

    const ids: number[] = [];
    for (const row of itemResults.rows) {
        ids.push(row.itemId);
    }

    const rowsResult = await getLootHistoryByIds(ids);
    if (rowsResult.isError) return send500Db(res);

    sendApiResponse<ApiLootHistorySearchRes>(res, { results: rowsResult.rows });
});

lootHistoryRouter.get("/entries/:guids", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const guidsParam = req.params["guids"];
    if (!guidsParam) return send400(res, "Missing guids parameter!");

    const guids = guidsParam.split(",");
    if (guids.length == 0) return send400(res, "Invalid guids parameter!");

    const rowsResult = await getLootHistoryEntries(guids);
    if (rowsResult.isError) return send500Db(res);

    sendApiResponse<ApiLootHistorySearchRes>(res, {
        results: rowsResult.rows,
    });
});

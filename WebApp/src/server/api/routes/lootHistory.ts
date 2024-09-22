import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send403, send500Db, send401, parseIntIfNumber, getStringIfString } from "../util";
import type { LootHistoryEntry, LootHistoryPageRes, LootHistorySearchInput } from "@/shared/types";
import { getLootHistoryPage, getLootHistorySearch } from "@/server/database/tableFunctions/lootHistory";

export const lootHistoryRouter = express.Router();

lootHistoryRouter.get("/page/:pageOffset", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const pageOffsetParam = req.params["pageOffset"];
    const pageOffset = parseInt(pageOffsetParam) || 0;

    const limit = 100;
    const rowsResult = await getLootHistoryPage(limit, pageOffset);
    if (rowsResult.isError) return send500Db(res);

    const historyRes: LootHistoryPageRes = {
        pageOffset: pageOffset,
        entries: rowsResult.rows,
        haveMore: rowsResult.rows.length == limit,
    };

    res.send(historyRes);
});

lootHistoryRouter.get("/search/:name/:start/:end", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const filter: LootHistorySearchInput = {
        playerName: getStringIfString(req.query.playerName),
        timeStart: parseIntIfNumber(req.query.timeStart),
        timeEnd: parseIntIfNumber(req.query.timeEnd),
    };

    const rowsResult = await getLootHistorySearch(filter);
    if (rowsResult.isError) return send500Db(res);

    const historyRes: LootHistoryEntry[] = rowsResult.rows;
    res.send(historyRes);
});

import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send500Db, checkAuth, sendApiResponse } from "../util";
import type { ApiItemListRes } from "@/shared/types";
import { getAllItems } from "@/server/database/tableFunctions/itemData";

export const itemRouter = express.Router();

itemRouter.get("/all", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const rowsResult = await getAllItems();
    if (rowsResult.isError) return send500Db(res);
    sendApiResponse<ApiItemListRes>(res, { list: rowsResult.rows });
});

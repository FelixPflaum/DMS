import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send500Db, send401, send403 } from "../util";
import type { ItemData } from "@/shared/types";
import { getAllItems } from "@/server/database/tableFunctions/itemData";

export const itemRouter = express.Router();

itemRouter.get("/all", async (req: Request, res: Response): Promise<void> => {
    const user = await getUserFromRequest(req);
    if (!user) return send401(res);
    if (!user.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const rowsResult = await getAllItems();
    if (rowsResult.isError) return send500Db(res);
    const items: ItemData[] = rowsResult.rows;
    res.send(items);
});

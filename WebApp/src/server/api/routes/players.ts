import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/enums";
import { getUserFromRequest } from "../auth";
import { send400, send403, send500Db, send401, send404 } from "../util";
import type { DeleteRes, PlayerEntry, UpdateRes } from "@/shared/types";
import { getUser } from "@/server/database/tableFunctions/users";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";
import {
    createPlayer,
    deletePlayer,
    getAllPlayers,
    getPlayer,
    updatePlayer,
} from "@/server/database/tableFunctions/players";

export const playerRouter = express.Router();

playerRouter.get("/player/:name", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const playerName = req.params["name"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    const getRes = await getPlayer(playerName);
    if (getRes.isError) return send500Db(res);
    if (getRes.row) {
        const playerRes: PlayerEntry = getRes.row;
        res.send(playerRes);
    } else {
        return send404(res, "Player not found.");
    }
});

playerRouter.get("/list", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const playersRes: PlayerEntry[] = [];
    const getRes = await getAllPlayers();
    if (getRes.isError) return send500Db(res);
    for (const player of getRes.rows) {
        playersRes.push(player);
    }
    res.send(playersRes);
});

playerRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);

    const body = req.body as Partial<PlayerEntry>;
    const playerName = body.playerName;
    const classId = body.classId;
    const points = body.points;

    if (!playerName || playerName.length < 2) return send400(res, "Invalid player name.");
    if (!classId || classId < 1 || classId > 13) return send400(res, "Invalid class id.");
    if (typeof points !== "number") return send400(res, "Invalid point value.");

    const userRes: UpdateRes = { success: true };

    const createRes = await createPlayer(playerName, classId, points);
    if (createRes.isError) return send500Db(res);
    if (createRes.duplicate) {
        userRes.success = false;
        userRes.error = "Player already exists!";
    } else {
        const log = `Created player ${playerName}, Class: ${classId}, Points: ${points}`;
        await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
    }

    res.send(userRes);
});

playerRouter.get("/delete/:playerName", async (req: Request, res: Response): Promise<void> => {
    const accessUser = await getUserFromRequest(req);
    if (!accessUser) return send401(res);
    if (!accessUser.hasPermission(AccPermissions.DATA_DELETE)) return send403(res);

    const playerName = req.params["playerName"];
    if (!playerName) {
        return send400(res, "Invalid player name.");
    }

    const deleteResponse: DeleteRes = { success: true };

    const getRes = await getPlayer(playerName);
    if (getRes.isError) return send500Db(res);
    if (!getRes.row) {
        deleteResponse.success = false;
        deleteResponse.error = "Player does not exist.";
    } else {
        const delRes = await deletePlayer(playerName);
        if (delRes.isError) return send500Db(res);
        if (!delRes.affectedRows) {
            deleteResponse.success = false;
            deleteResponse.error = "Player did not exist.";
        } else {
            const log = `Deleted player ${playerName}, Had points: ${getRes.row.points}`;
            await addAuditEntry(accessUser.loginId, accessUser.userName, log);
        }
    }

    res.send(deleteResponse);
});

playerRouter.post("/update/:playerName", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);

    const playerNameKey = req.params["playerName"];
    if (!playerNameKey) {
        return send400(res, "Invalid player name.");
    }

    const body = req.body as Partial<PlayerEntry>;
    const playerName = body.playerName;
    const classId = body.classId;
    const points = body.points;
    const account = body.account;

    if (!playerName || playerName.length < 2) return send400(res, "Invalid player name.");
    if (!classId || classId < 1 || classId > 13) return send400(res, "Invalid class id.");
    if (typeof points !== "number") return send400(res, "Invalid point value.");
    if (account) {
        const userRes = await getUser(account);
        if (userRes.isError) return send500Db(res);
        if (!userRes.row) return send400(res, "Invalid account!");
    }

    const updateResponse: UpdateRes = { success: true };

    const targetPlayerRes = await getPlayer(playerNameKey);
    if (targetPlayerRes.isError) return send500Db(res);

    const targetPlayer = targetPlayerRes.row;
    if (!targetPlayer) {
        updateResponse.success = false;
        updateResponse.error = "Player doesn't exists!";
    } else {
        const updRes = await updatePlayer(playerNameKey, { playerName, classId, points });
        if (updRes.isError) return send500Db(res);
        if (updRes.affectedRows) {
            const log = `Update player ${targetPlayer.playerName} - ${targetPlayer.classId} - ${targetPlayer.points} => ${playerName} - ${classId} - ${points}`;
            await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
        } else {
            updateResponse.success = false;
            updateResponse.error = "Player doesn't exist!";
        }
    }

    res.send(updateResponse);
});

import express from "express";
import { Request, Response } from "express";
import { AccPermissions } from "@/shared/enums";
import { auditDb, authDb, playerDb } from "../database/database";
import { checkRequestAuth } from "../auth";
import { send400, send403, send500Db, send401, send404 } from "./util";
import { Logger } from "../Logger";
import type { DeleteRes, PlayerEntry, UpdateRes } from "@/shared/types";

const logger = new Logger("API:Players");
export const playerRouter = express.Router();

playerRouter.get("/player/:name", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const playerName = req.params["name"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    try {
        const player = await playerDb.getPlayer(playerName);
        if (player) {
            const playerRes: PlayerEntry = player;
            res.send(playerRes);
        } else {
            return send404(res, "Player not found.");
        }
    } catch (error) {
        logger.logError("Get user failed.", error);
        return send500Db(res);
    }
});

playerRouter.get("/list", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const playersRes: PlayerEntry[] = [];
    try {
        const players = await playerDb.getPlayers();
        for (const player of players) {
            playersRes.push(player);
        }
    } catch (error) {
        logger.logError("Get player list failed.", error);
        return send500Db(res);
    }
    res.send(playersRes);
});

playerRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
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

    try {
        const exists = await playerDb.getPlayer(playerName);
        if (exists) {
            userRes.success = false;
            userRes.error = "Player already exists!";
        }
        const created = await playerDb.createPlayer(playerName, classId, points);
        if (!created) {
            userRes.success = false;
            userRes.error = "Player could not be created!";
        } else {
            const log = `Created player ${playerName}, Class: ${classId}, Points: ${points}`;
            await auditDb.addEntryNoErr(accessingUser.loginId, accessingUser.userName, log);
        }
    } catch (error) {
        logger.logError("Create player failed.", error);
        return send500Db(res);
    }

    res.send(userRes);
});

playerRouter.get("/delete/:playerName", async (req: Request, res: Response): Promise<void> => {
    const accessUser = await checkRequestAuth(req);
    if (!accessUser) return send401(res);
    if (!accessUser.hasPermission(AccPermissions.DATA_DELETE)) return send403(res);

    const playerName = req.params["playerName"];
    if (!playerName) {
        return send400(res, "Invalid player name.");
    }

    const delRes: DeleteRes = { success: true };
    try {
        const playerEntry = await playerDb.getPlayer(playerName);
        if (!playerEntry) {
            delRes.success = false;
            delRes.error = "Player does not exist.";
        } else {
            const success = await playerDb.deletePlayer(playerName);
            if (!success) {
                delRes.success = false;
                delRes.error = "Player did not exist.";
            } else {
                const log = `Deleted player ${playerName}, Had points: ${playerEntry.points}`;
                await auditDb.addEntryNoErr(accessUser.loginId, accessUser.userName, log);
            }
        }
    } catch (error) {
        logger.logError("Delete player failed.", error);
        return send500Db(res);
    }

    res.send(delRes);
});

playerRouter.post("/update/:playerName", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
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
        try {
            const authEntry = authDb.getEntry(account);
            if (!authEntry) return send400(res, "Invalid account!");
        } catch (error) {
            logger.logError("Failed to get auth entry for player update.", error);
            return send500Db(res);
        }
    }

    const updateRes: UpdateRes = { success: true };
    try {
        const targetPlayer = await playerDb.getPlayer(playerNameKey);
        if (!targetPlayer) {
            updateRes.success = false;
            updateRes.error = "Player doesn't exists!";
            return;
        }

        const success = await playerDb.updatePlayer(playerNameKey, { playerName, classId, points });
        if (success) {
            const log = `Update player ${targetPlayer.playerName} - ${targetPlayer.classId} - ${targetPlayer.points} => ${playerName} - ${classId} - ${points}`;
            await auditDb.addEntryNoErr(accessingUser.loginId, accessingUser.userName, log);
        } else {
            updateRes.success = false;
            updateRes.error = "Player doesn't exist!";
        }
    } catch (error) {
        logger.logError("Update player failed.", error);
        return send500Db(res);
    }

    res.send(updateRes);
});

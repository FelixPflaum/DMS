import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getUserFromRequest } from "../auth";
import { send400, send403, send500Db, send401, send404 } from "../util";
import type {
    ApiPointChangeRequest,
    ApiPointChangeResult,
    ApiProfileResult,
    DeleteRes,
    PlayerEntry,
    UpdateRes,
} from "@/shared/types";
import { getUser } from "@/server/database/tableFunctions/users";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";
import {
    createPlayer,
    deletePlayer,
    getAllPlayers,
    getPlayersForAccount,
    getPlayer,
    updatePlayer,
} from "@/server/database/tableFunctions/players";
import { createPointHistoryEntry, getPointHistorySearch } from "@/server/database/tableFunctions/pointHistory";
import { getConnection } from "@/server/database/database";
import { getLootHistorySearch } from "@/server/database/tableFunctions/lootHistory";
import { makeDataBackup } from "@/server/importExport/backup";

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
        const conn = await getConnection();
        try {
            await makeDataBackup(conn, 0, "before_delete_" + playerName);
        } finally {
            conn.release();
        }
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
    const account = body.account;

    if (!playerName || playerName.length < 2) return send400(res, "Invalid player name.");
    if (!classId || classId < 1 || classId > 13) return send400(res, "Invalid class id.");
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
        const updRes = await updatePlayer(playerNameKey, { playerName, classId, account });
        if (updRes.isError) return send500Db(res);
        if (updRes.affectedRows) {
            const log = `Update player ${targetPlayer.playerName} - ${targetPlayer.classId} => ${playerName} - ${classId}`;
            await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
        } else {
            updateResponse.success = false;
            updateResponse.error = "Player doesn't exist!";
        }
    }

    res.send(updateResponse);
});

playerRouter.post("/pointchange/:playerName", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_MANAGE)) return send403(res);

    const playerNameKey = req.params["playerName"];
    if (!playerNameKey) {
        return send400(res, "Invalid player name.");
    }

    const body = req.body as Partial<ApiPointChangeRequest>;
    const reason = body.reason;
    const change = body.change;

    if (!reason || reason.length < 2) return send400(res, "Invalid reason.");
    if (typeof change !== "number") return send400(res, "Invalid point change value.");

    const updateResponse: ApiPointChangeResult = { success: false, change: 0, newPoints: 0 };

    const targetPlayerRes = await getPlayer(playerNameKey);
    if (targetPlayerRes.isError) return send500Db(res);
    const targetPlayer = targetPlayerRes.row;
    if (!targetPlayer) {
        updateResponse.error = "Player doesn't exists!";
        res.send(updateResponse);
        return;
    }

    const newPoints = targetPlayer.points + change;
    updateResponse.newPoints = newPoints;
    updateResponse.change = change;

    const conn = await getConnection();
    try {
        conn.beginTransaction();
        const phRes = await createPointHistoryEntry(Date.now(), playerNameKey, change, newPoints, "CUSTOM", reason, conn);
        if (phRes.isError) return send500Db(res);
        const updRes = await updatePlayer(playerNameKey, { points: newPoints }, conn);
        if (updRes.isError) return send500Db(res);
        conn.commit();
        const log = `Add player point change: ${targetPlayer.playerName} | Change: ${change} | Points: ${targetPlayer.points} => ${newPoints}`;
        await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
    } finally {
        conn.release();
    }

    updateResponse.success = true;
    res.send(updateResponse);
});

playerRouter.get("/profile/:name", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const playerName = req.params["name"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    const playerRes = await getPlayer(playerName);
    if (playerRes.isError) return send500Db(res);
    if (!playerRes.row) return send404(res, "Player not found.pointRes");

    const pointRes = await getPointHistorySearch({ playerName: playerName }, 100);
    if (pointRes.isError) return send500Db(res);

    const lootRes = await getLootHistorySearch({ playerName: playerName }, 100);
    if (lootRes.isError) return send500Db(res);

    const apiRes: ApiProfileResult = {
        player: playerRes.row,
        pointHistory: pointRes.rows,
        lootHistory: lootRes.rows,
    };

    res.send(apiRes);
});

playerRouter.get("/self", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);
    const playerRes = await getPlayersForAccount(accessingUser.loginId);
    if (playerRes.isError) return send500Db(res);
    const apiRes: PlayerEntry[] = playerRes.rows;
    res.send(apiRes);
});

playerRouter.get("/claim/:playerName", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.DATA_VIEW)) return send403(res);

    const playerName = req.params["playerName"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    const playerRes = await getPlayer(playerName);
    if (playerRes.isError) return send500Db(res);
    if (!playerRes.row) return send400(res, "Player doesn't exist!");
    if (playerRes.row.account) return send403(res, "Player is already claimed!");

    const updRes = await updatePlayer(playerName, { account: accessingUser.loginId });
    if (updRes.isError) return send500Db(res);

    const apiRes: UpdateRes = { success: true };
    res.send(apiRes);
});

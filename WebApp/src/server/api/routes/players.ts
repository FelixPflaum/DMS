import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send400, send403, send500Db, send404, checkAuth, sendApiResponse, send500 } from "../util";
import type {
    ApiPlayerListRes,
    ApiPlayerRes,
    ApiPointChangeRequest,
    ApiPointChangeResult,
    ApiProfileResult,
    ApiPlayerEntry,
    ApiSelfPlayerRes,
    ApiMultiPointChangeRequest,
    ApiMultiPointChangeResult,
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
import { Logger } from "@/server/Logger";
import type { PoolConnection } from "mysql2/promise";
import type { PlayerRow } from "@/server/database/types";
import { generateGuid } from "@/shared/guid";

const logger = new Logger("API Players");

export const playerRouter = express.Router();

playerRouter.get("/player/:name", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const playerName = req.params["name"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    const getRes = await getPlayer(playerName);
    if (getRes.isError) return send500Db(res);
    if (!getRes.row) return send404(res, "Player not found.");

    return sendApiResponse<ApiPlayerRes>(res, { player: getRes.row });
});

playerRouter.get("/list", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const list: ApiPlayerEntry[] = [];

    const getRes = await getAllPlayers();
    if (getRes.isError) return send500Db(res);

    for (const player of getRes.rows) {
        list.push(player);
    }

    sendApiResponse<ApiPlayerListRes>(res, { list });
});

playerRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;

    const body = req.body as Partial<ApiPlayerEntry>;
    const playerName = body.playerName;
    const classId = body.classId;
    const points = 0; // body.points;

    if (!playerName || playerName.length < 2) return send400(res, "Invalid player name.");
    if (!classId || classId < 1 || classId > 13) return send400(res, "Invalid class id.");
    if (typeof points !== "number") return send400(res, "Invalid point value.");

    const createRes = await createPlayer(playerName, classId, points);
    if (createRes.isError) return send500Db(res);

    if (createRes.duplicate) {
        return sendApiResponse(res, "Player already exists!");
    }

    await addAuditEntry(
        auth.user.loginId,
        auth.user.userName,
        "Created player",
        `Name: ${playerName}, Class: ${classId}, Sanity: ${points}`
    );

    sendApiResponse(res, true);
});

playerRouter.get("/delete/:playerName", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_DELETE)) return;

    const playerName = req.params["playerName"];
    if (!playerName) {
        return send400(res, "Invalid player name.");
    }

    const getRes = await getPlayer(playerName);
    if (getRes.isError) return send500Db(res);
    if (!getRes.row) {
        return sendApiResponse(res, "Player does not exist.");
    }

    const conn = await getConnection();
    await makeDataBackup(conn, 0, "before_delete_" + playerName);
    conn.release();

    const delRes = await deletePlayer(playerName);
    if (delRes.isError) return send500Db(res);
    if (!delRes.affectedRows) {
        return sendApiResponse(res, "Player did not exist.");
    }

    await addAuditEntry(
        auth.user.loginId,
        auth.user.userName,
        "Deleted player",
        `Name: ${playerName}, Sanity ${getRes.row.points}`
    );

    sendApiResponse(res, true);
});

playerRouter.post("/update/:playerName", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;

    const playerNameKey = req.params["playerName"];
    if (!playerNameKey) {
        return send400(res, "Invalid player name.");
    }

    const body = req.body as Partial<ApiPlayerEntry>;
    const playerName = body.playerName;
    const classId = body.classId;
    const account = body.account || undefined; // Turn empty string into undefined.

    if (!playerName || playerName.length < 2) return send400(res, "Invalid player name.");
    if (!classId || classId < 1 || classId > 13) return send400(res, "Invalid class id.");
    if (account) {
        const userRes = await getUser(account);
        if (userRes.isError) return send500Db(res);
        if (!userRes.row) return send400(res, "Invalid account!");
    }

    const targetPlayerRes = await getPlayer(playerNameKey);
    if (targetPlayerRes.isError) return send500Db(res);

    const targetPlayer = targetPlayerRes.row;
    if (!targetPlayer) {
        return sendApiResponse(res, "Player does not exist.");
    }

    const changes: string[] = [];
    if (targetPlayer.classId != classId) changes.push(`Class: ${targetPlayer.classId} -> ${classId}`);
    if (targetPlayer.playerName != playerName) changes.push(`Name: ${targetPlayer.playerName} -> ${playerName}`);
    if (targetPlayer.account != account) changes.push(`Account: ${targetPlayer.account} -> ${account}`);

    if (changes.length == 0) return send400(res, "No changes made.");

    const updRes = await updatePlayer(playerNameKey, { playerName, classId, account });
    if (updRes.isError) return send500Db(res);
    if (!updRes.affectedRows) {
        return sendApiResponse(res, "Player does not exist.");
    }

    await addAuditEntry(auth.user.loginId, auth.user.userName, "Updated player", changes.join(", "));

    sendApiResponse(res, true);
});

playerRouter.post("/pointchange", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;

    const body = req.body as Partial<ApiPointChangeRequest>;
    const reason = body.reason;
    const change = body.change;
    const playerName = body.playerName;

    if (typeof reason !== "string" || reason.length < 2) return send400(res, "Invalid reason.");
    if (typeof change !== "number") return send400(res, "Invalid point change value.");
    if (typeof playerName !== "string") return send400(res, "Invalid name!");

    const targetPlayerRes = await getPlayer(playerName);
    if (targetPlayerRes.isError) return send500Db(res);
    const targetPlayer = targetPlayerRes.row;
    if (!targetPlayer) {
        return sendApiResponse(res, "Player doesn't exists!");
    }

    const newPoints = targetPlayer.points + change;

    const conn = await getConnection();
    try {
        conn.beginTransaction();
        const phRes = await createPointHistoryEntry(
            {
                guid: generateGuid(),
                timestamp: Date.now(),
                playerName: playerName,
                pointChange: change,
                newPoints: newPoints,
                changeType: "CUSTOM",
                reason: reason,
            },
            conn
        );
        if (phRes.isError) return send500Db(res);
        const updRes = await updatePlayer(playerName, { points: newPoints }, conn);
        if (updRes.isError) return send500Db(res);
        conn.commit();
        const log = `${targetPlayer.playerName} | Change: ${change > 0 ? "+" + change : change} | Sanity: ${targetPlayer.points} => ${newPoints}`;
        await addAuditEntry(auth.user.loginId, auth.user.userName, "Sanity change", log);
    } finally {
        conn.release();
    }

    sendApiResponse<ApiPointChangeResult>(res, {
        playerName: targetPlayer.playerName,
        change: change,
        newPoints: newPoints,
    });
});

playerRouter.post("/multipointchange", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_MANAGE)) return;

    const body = req.body as Partial<ApiMultiPointChangeRequest>;
    const reason = body.reason;
    const change = body.change;
    const playerNames = body.playerNames;

    if (typeof reason !== "string" || reason.length < 2) return send400(res, "Invalid reason.");
    if (typeof change !== "number") return send400(res, "Invalid point change value.");
    if (!Array.isArray(playerNames) || playerNames.some((v) => typeof v !== "string"))
        return send400(res, "Invalid name list!");

    let conn: PoolConnection;
    try {
        conn = await getConnection();
    } catch (error) {
        logger.logError("Error on getting connection for point history multi insert.", error);
        return send500Db(res);
    }

    let isSuccess = false;
    try {
        await conn.query("LOCK TABLES pointHistory WRITE, players WRITE;");
        await conn.beginTransaction();

        const targetPlayers: Record<string, PlayerRow> = {};
        for (const playerName of playerNames) {
            const targetPlayerRes = await getPlayer(playerName);
            if (targetPlayerRes.isError) return send500Db(res);
            const targetPlayer = targetPlayerRes.row;
            if (!targetPlayer) {
                return sendApiResponse(res, `Player ${playerName} doesn't exists!`);
            }
            targetPlayers[playerName] = targetPlayer;
        }

        const now = Date.now();
        const updates: { playerName: string; newPoints: number }[] = [];

        for (const playerName in targetPlayers) {
            const newPoints = targetPlayers[playerName].points + change;
            const insertRes = await createPointHistoryEntry(
                {
                    guid: generateGuid(),
                    playerName: playerName,
                    timestamp: now,
                    pointChange: change,
                    newPoints: newPoints,
                    changeType: "CUSTOM",
                    reason: reason,
                },
                conn
            );
            if (insertRes.isError) return send500Db(res);
            const updateRes = await updatePlayer(playerName, { points: newPoints }, conn);
            if (updateRes.isError) return send500Db(res);
            updates.push({ playerName, newPoints });
        }

        isSuccess = true;
        await conn.commit();
        await addAuditEntry(
            auth.user.loginId,
            auth.user.userName,
            "Multi sanity change",
            `Reason: ${reason}, Change: ${change}, Players: ${updates.map((v) => v.playerName).join(", ")}`
        );
        sendApiResponse<ApiMultiPointChangeResult>(res, { change, updates });
    } catch (error) {
        logger.logError("Error during point history multi insert.", error);
        return send500(res, "Error during transaction process.");
    } finally {
        if (!isSuccess) await conn.rollback();
        await conn.query("UNLOCK TABLES;");
        conn.release();
    }
});

playerRouter.get("/profile/:name", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth)) return;

    const playerName = req.params["name"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    const playerRes = await getPlayer(playerName);
    if (playerRes.isError) return send500Db(res);
    if (!playerRes.row) return send404(res, "Player not found.");

    if (playerRes.row.account != auth.user.loginId && !auth.hasPermission(AccPermissions.DATA_VIEW)) {
        return send403(res);
    }

    const pointRes = await getPointHistorySearch({ playerName: playerName }, 100);
    if (pointRes.isError) return send500Db(res);

    const lootRes = await getLootHistorySearch({ playerName: playerName }, 100);
    if (lootRes.isError) return send500Db(res);

    sendApiResponse<ApiProfileResult>(res, {
        player: playerRes.row,
        pointHistory: pointRes.rows,
        lootHistory: lootRes.rows,
    });
});

playerRouter.get("/self", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth)) return;
    const playerRes = await getPlayersForAccount(auth.user.loginId);
    if (playerRes.isError) return send500Db(res);
    const list: ApiPlayerEntry[] = playerRes.rows;
    sendApiResponse<ApiSelfPlayerRes>(res, { myChars: list });
});

playerRouter.get("/claim/:playerName", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.DATA_VIEW)) return;

    const playerName = req.params["playerName"];
    if (!playerName) {
        return send400(res, "Invalid name.");
    }

    const playerRes = await getPlayer(playerName);
    if (playerRes.isError) return send500Db(res);
    if (!playerRes.row) return send400(res, "Player doesn't exist!");
    if (playerRes.row.account) return send403(res, "Player is already claimed!");

    const updRes = await updatePlayer(playerName, { account: auth.user.loginId });
    if (updRes.isError) return send500Db(res);

    await addAuditEntry(auth.user.loginId, auth.user.userName, "Claimed player", playerName);

    sendApiResponse(res, true);
});

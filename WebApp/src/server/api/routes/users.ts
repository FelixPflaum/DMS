import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/permissions";
import { getAuthFromRequest } from "../auth";
import { send400, send403, send500Db, checkAuth, send404, sendApiResponse } from "../util";
import type { ApiUserListRes, ApiUserEntry, ApiUserRes } from "@/shared/types";
import { addUser, getAllUsers, getUser, removeUser, updateUser } from "@/server/database/tableFunctions/users";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";

export const userRouter = express.Router();

userRouter.get("/user/:loginId", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.USERS_VIEW)) return;

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const dbRes = await getUser(loginId);
    if (dbRes.isError) return send500Db(res);
    if (!dbRes.row) return send404(res, "User doesn't exist!");

    sendApiResponse<ApiUserRes>(res, {
        user: {
            loginId: dbRes.row.loginId,
            userName: dbRes.row.userName,
            permissions: dbRes.row.permissions,
            lastActivity: dbRes.row.lastActivity,
        },
    });
});

userRouter.get("/list", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.USERS_VIEW)) return;

    const userList: ApiUserEntry[] = [];
    const allUsersRes = await getAllUsers();
    if (allUsersRes.isError) return send500Db(res);

    for (const user of allUsersRes.rows) {
        userList.push({
            loginId: user.loginId,
            userName: user.userName,
            permissions: user.permissions,
            lastActivity: user.lastActivity,
        });
    }

    sendApiResponse<ApiUserListRes>(res, { list: userList });
});

userRouter.get("/delete/:loginId", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.USERS_MANAGE)) return;

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const getRes = await getUser(loginId);
    if (getRes.isError) return send500Db(res);

    const targetUser = getRes.row;
    if (!targetUser) {
        return sendApiResponse(res, "User does not exist.");
    }

    if (
        (targetUser.permissions & AccPermissions.ADMIN) == AccPermissions.ADMIN &&
        !auth.hasPermission(AccPermissions.ADMIN)
    ) {
        return sendApiResponse(res, "You can't delete that user.");
    }

    const delRes = await removeUser(loginId);
    if (delRes.isError) return send500Db(res);
    if (!delRes.affectedRows) {
        return sendApiResponse(res, "User did not exist.");
    }

    const log = `Deleted user ${loginId} - ${targetUser.userName}`;
    await addAuditEntry(auth.user.loginId, auth.user.userName, log);

    sendApiResponse(res, true);
});

userRouter.post("/update/:loginId", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.USERS_MANAGE)) return;

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const body = req.body as Partial<ApiUserEntry>;
    const permissions = body.permissions;
    const userName = body.userName;

    if (typeof permissions !== "number") {
        return send400(res, "Invalid permissions.");
    }

    if (typeof userName !== "string" || userName.length < 4) {
        return send400(res, "Invalid name.");
    }

    const targetUserRes = await getUser(loginId);
    if (targetUserRes.isError) return send500Db(res);

    const targetUser = targetUserRes.row;
    if (!targetUser) {
        return sendApiResponse(res, "User doesn't exists!");
    }

    const permsChanged = targetUser.permissions ^ permissions;
    if (!auth.hasPermission(permsChanged)) {
        return send403(res, "Can't change missing permissions.");
    }

    const updateRes = await updateUser(loginId, { userName, permissions });
    if (updateRes.isError) return send500Db(res);
    if (!updateRes.affectedRows) {
        return sendApiResponse(res, "User doesn't exist!");
    }

    const log = `Update user ${targetUser.loginId} - ${targetUser.userName} - ${targetUser.permissions} => ${loginId} - ${userName} - ${permissions}`;
    await addAuditEntry(auth.user.loginId, auth.user.userName, log);

    sendApiResponse(res, true);
});

userRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const auth = await getAuthFromRequest(req);
    if (!checkAuth(res, auth, AccPermissions.USERS_MANAGE)) return;

    const body = req.body as Partial<ApiUserEntry>;
    const permissions = body.permissions;
    const loginId = body.loginId;
    const userName = body.userName;

    if (!loginId || loginId.length < 17) return send400(res, "Invalid login id.");
    if (!userName) return send400(res, "Invalid name.");
    if (typeof permissions !== "number") return send400(res, "Invalid permissions.");

    if (auth.hasPermission(permissions)) {
        return send403(res, "Can't set missing permissions.");
    }

    const createRes = await addUser(loginId, userName, permissions);
    if (createRes.isError) return send500Db(res);
    if (createRes.duplicate) {
        return sendApiResponse(res, "User already exists!");
    }

    const log = `Created user ${loginId} - ${userName}, Permissions: ${permissions}`;
    await addAuditEntry(auth.user.loginId, auth.user.userName, log);

    sendApiResponse(res, true);
});

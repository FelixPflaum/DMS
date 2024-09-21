import express from "express";
import type { Request, Response } from "express";
import { AccPermissions } from "@/shared/enums";
import { getUserFromRequest } from "../auth";
import { send400, send403, send500Db, send401 } from "../util";
import type { DeleteRes, UpdateRes, UserEntry, UserRes } from "@/shared/types";
import { addUser, getAllUsers, getUser, removeUser, updateUser } from "@/server/database/tableFunctions/users";
import { addAuditEntry } from "@/server/database/tableFunctions/audit";

export const userRouter = express.Router();

userRouter.get("/user/:loginId", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_VIEW)) return send403(res);

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const userRes: UserRes = [];
    const dbRes = await getUser(loginId);
    if (dbRes.isError) return send500Db(res);
    if (dbRes.row) {
        userRes.push({
            loginId: dbRes.row.loginId,
            userName: dbRes.row.userName,
            permissions: dbRes.row.permissions,
        });
    }

    res.send(userRes);
});

userRouter.get("/list", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_VIEW)) return send403(res);

    const userRes: UserRes = [];
    const allUsersRes = await getAllUsers();
    if (allUsersRes.isError) return send500Db(res);

    for (const user of allUsersRes.rows) {
        userRes.push({
            loginId: user.loginId,
            userName: user.userName,
            permissions: user.permissions,
        });
    }

    res.send(userRes);
});

userRouter.get("/delete/:loginId", async (req: Request, res: Response): Promise<void> => {
    const accessUser = await getUserFromRequest(req);
    if (!accessUser) return send401(res);
    if (!accessUser.hasPermission(AccPermissions.USERS_MANAGE)) return send403(res);

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const userRes: DeleteRes = { success: true };

    const getRes = await getUser(loginId);
    if (getRes.isError) return send500Db(res);

    const targetUser = getRes.row;
    if (!targetUser) {
        userRes.success = false;
        userRes.error = "User does not exist.";
        res.send(userRes);
        return;
    }

    if (
        (targetUser.permissions & AccPermissions.ADMIN) == AccPermissions.ADMIN &&
        !accessUser.hasPermission(AccPermissions.ADMIN)
    ) {
        userRes.success = false;
        userRes.error = "You can't delete that user.";
        res.send(userRes);
        return;
    }

    const delRes = await removeUser(loginId);
    if (delRes.isError) return send500Db(res);
    if (!delRes.affectedRows) {
        userRes.success = false;
        userRes.error = "User did not exist.";
    } else {
        const log = `Deleted user ${loginId} - ${targetUser.userName}`;
        await addAuditEntry(accessUser.loginId, accessUser.userName, log);
    }

    res.send(userRes);
});

userRouter.post("/update/:loginId", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_MANAGE)) return send403(res);

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const body = req.body as Partial<UserEntry>;
    const permissions = body.permissions;
    const userName = body.userName;

    if (typeof permissions !== "number") {
        return send400(res, "Invalid permissions.");
    }

    if (typeof userName !== "string" || userName.length < 4) {
        return send400(res, "Invalid name.");
    }

    const userRes: UpdateRes = { success: true };

    const targetUserRes = await getUser(loginId);
    if (targetUserRes.isError) return send500Db(res);

    const targetUser = targetUserRes.row;
    if (!targetUser) {
        userRes.success = false;
        userRes.error = "User doesn't exists!";
    } else {
        const permsChanged = targetUser.permissions ^ permissions;
        if ((accessingUser.permissions & permsChanged) !== permsChanged) {
            return send403(res, "Can't change missing permissions.");
        }

        const updateRes = await updateUser(loginId, { userName, permissions });
        if (updateRes.isError) return send500Db(res);
        if (updateRes.affectedRows) {
            const log = `Update user ${targetUser.loginId} - ${targetUser.userName} - ${targetUser.permissions} => ${loginId} - ${userName} - ${permissions}`;
            await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
        } else {
            userRes.success = false;
            userRes.error = "User doesn't exist!";
        }
    }

    res.send(userRes);
});

userRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await getUserFromRequest(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_MANAGE)) return send403(res);

    const body = req.body as Partial<UserEntry>;
    const permissions = body.permissions;
    const loginId = body.loginId;
    const userName = body.userName;

    if (!loginId || loginId.length < 17) return send400(res, "Invalid login id.");
    if (!userName) return send400(res, "Invalid name.");
    if (typeof permissions !== "number") return send400(res, "Invalid permissions.");

    if ((accessingUser.permissions & permissions) !== permissions) {
        return send403(res, "Can't set missing permissions.");
    }

    const userRes: UpdateRes = { success: true };

    const createRes = await addUser(loginId, userName, permissions);
    if (createRes.isError) return send500Db(res);
    if (createRes.duplicate) {
        userRes.success = false;
        userRes.error = "User already exists!";
    } else {
        const log = `Created user ${loginId} - ${userName}, Permissions: ${permissions}`;
        await addAuditEntry(accessingUser.loginId, accessingUser.userName, log);
    }

    res.send(userRes);
});

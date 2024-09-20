import express from "express";
import { Request, Response } from "express";
import { AccPermissions } from "@/shared/enums";
import { auditDb, authDb } from "../database/database";
import { checkRequestAuth } from "../auth";
import { send400, send403, send500Db, send401 } from "./util";

export const userRouter = express.Router();

userRouter.get("/user/:loginId", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_VIEW)) return send403(res);

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const userRes: UserRes = [];
    try {
        const user = await authDb.getEntry(loginId);
        if (user) {
            userRes.push({
                loginId: user.loginId,
                userName: user.userName,
                permissions: user.permissions,
            });
        }
    } catch (error) {
        console.error(error);
        return send500Db(res);
    }

    res.send(userRes);
});

userRouter.get("/list", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_VIEW)) return send403(res);

    const userRes: UserRes = [];
    try {
        const users = await authDb.getEntries();
        for (const user of users) {
            userRes.push({
                loginId: user.loginId,
                userName: user.userName,
                permissions: user.permissions,
            });
        }
    } catch (error) {
        console.error(error);
        return send500Db(res);
    }

    res.send(userRes);
});

userRouter.get("/delete/:loginId", async (req: Request, res: Response): Promise<void> => {
    const accessUser = await checkRequestAuth(req);
    if (!accessUser) return send401(res);
    if (!accessUser.hasPermission(AccPermissions.USERS_MANAGE)) return send403(res);

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const userRes: UserDeleteRes = { success: true };
    try {
        const userEntry = await authDb.getEntry(loginId);
        if (!userEntry) {
            userRes.success = false;
            userRes.error = "User does not exist.";
        } else {
            const success = await authDb.removeEntry(loginId);
            if (!success) {
                userRes.success = false;
                userRes.error = "User did not exist.";
            } else {
                const log = `Deleted user ${loginId} - ${userEntry.userName}`;
                await auditDb.addEntryNoErr(accessUser.loginId, accessUser.userName, log);
            }
        }
    } catch (error) {
        console.error(error);
        return send500Db(res);
    }

    res.send(userRes);
});

userRouter.post("/update/:loginId", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_MANAGE)) return send403(res);

    const loginId = req.params["loginId"];
    if (!loginId) {
        return send400(res, "Invalid loginId.");
    }

    const permissions = req.body.permissions;
    if (typeof permissions !== "number") {
        return send400(res, "Invalid permissions.");
    }

    const userRes: UserUpdateRes = { success: true };
    try {
        const targetUser = await authDb.getEntry(loginId);
        if (!targetUser) {
            userRes.success = false;
            userRes.error = "User doesn't exists!";
            return;
        }

        const permsChanged = targetUser.permissions ^ permissions;
        if ((accessingUser.permissions & permsChanged) !== permsChanged) {
            return send403(res, "Can't change missing permissions.");
        }

        const success = await authDb.updateEntry(loginId, { permissions });
        if (success) {
            const log = `Update user ${loginId} - ${targetUser.userName}, Permissions: ${permissions}`;
            await auditDb.addEntryNoErr(accessingUser.loginId, accessingUser.userName, log);
        } else {
            userRes.success = false;
            userRes.error = "User doesn't exist!";
        }
    } catch (error) {
        console.error(error);
        return send500Db(res);
    }

    res.send(userRes);
});

userRouter.post("/create", async (req: Request, res: Response): Promise<void> => {
    const accessingUser = await checkRequestAuth(req);
    if (!accessingUser) return send401(res);
    if (!accessingUser.hasPermission(AccPermissions.USERS_MANAGE)) return send403(res);

    const body = req.body as Partial<UserEntry>;
    const permissions = body.permissions;
    const loginId = body.loginId;
    const userName = body.userName;

    if (!loginId) return send400(res, "Invalid login id.");
    if (!userName) return send400(res, "Invalid name.");
    if (typeof permissions !== "number") return send400(res, "Invalid permissions.");

    if ((accessingUser.permissions & permissions) !== permissions) {
        return send403(res, "Can't set missing permissions.");
    }

    const userRes: UserUpdateRes = { success: true };

    try {
        const exists = await authDb.getEntry(loginId);
        if (exists) {
            userRes.success = false;
            userRes.error = "User already exists!";
            return;
        }
        const created = await authDb.createEntry(loginId, userName, permissions);
        if (!created) {
            userRes.success = false;
            userRes.error = "User could not be created!";
            return;
        } else {
            const log = `Created user ${loginId} - ${userName}, Permissions: ${permissions}`;
            await auditDb.addEntryNoErr(accessingUser.loginId, accessingUser.userName, log);
        }
    } catch (error) {
        console.error(error);
        return send500Db(res);
    }

    res.send(userRes);
});

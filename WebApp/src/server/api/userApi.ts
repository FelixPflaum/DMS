import express from "express";
import { Request, Response } from "express";
import { AccPermissions } from "@/shared/enums";
import { auditDb, authDb } from "../database/database";
import { checkRequestAuth } from "../auth";
import { send400, send403, send500Db, send401 } from "./util";
import { Logger } from "../Logger";
import type { DeleteRes, UpdateRes, UserEntry, UserRes } from "@/shared/types";

const logger = new Logger("API:User");
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
        logger.logError("Get user failed.", error);
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
        logger.logError("Get user list failed.", error);
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

    const userRes: DeleteRes = { success: true };
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
        logger.logError("Delete user failed.", error);
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

        const success = await authDb.updateEntry(loginId, { userName, permissions });
        if (success) {
            const log = `Update user ${targetUser.loginId} - ${targetUser.userName} - ${targetUser.permissions} => ${loginId} - ${userName} - ${permissions}`;
            await auditDb.addEntryNoErr(accessingUser.loginId, accessingUser.userName, log);
        } else {
            userRes.success = false;
            userRes.error = "User doesn't exist!";
        }
    } catch (error) {
        logger.logError("Update user failed.", error);
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

    if (!loginId || loginId.length < 17) return send400(res, "Invalid login id.");
    if (!userName) return send400(res, "Invalid name.");
    if (typeof permissions !== "number") return send400(res, "Invalid permissions.");

    if ((accessingUser.permissions & permissions) !== permissions) {
        return send403(res, "Can't set missing permissions.");
    }

    const userRes: UpdateRes = { success: true };

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
        logger.logError("Create user failed.", error);
        return send500Db(res);
    }

    res.send(userRes);
});

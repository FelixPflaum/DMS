import type { Application } from "express";
import express from "express";
import cors from "cors";
import { authRouter } from "./routes/auth";
import { auditRouter } from "./routes/audit";
import { userRouter } from "./routes/users";
import { playerRouter } from "./routes/players";
import { pointHistoryRouter } from "./routes/pointHistory";
import { lootHistoryRouter } from "./routes/lootHistory";
import { itemRouter } from "./routes/items";
import { importExportRouter } from "./routes/importExport";
import { settingsRouter } from "./routes/settings";
import { backupRouter } from "./routes/backup";
import { getConfig } from "../config";
import { Logger } from "../Logger";
import { existsSync } from "fs";

const logger = new Logger("API");

const cookieParser = require("cookie-parser");
const app: Application = express();

app.use(express.json({ limit: "1mb" }));
app.use(cors());
app.use(express.urlencoded({ extended: true, limit: "1mb" }));
app.use(cookieParser());

const apiRouter = express.Router();
apiRouter.use("/auth", authRouter);
apiRouter.use("/users", userRouter);
apiRouter.use("/audit", auditRouter);
apiRouter.use("/players", playerRouter);
apiRouter.use("/pointhistory", pointHistoryRouter);
apiRouter.use("/loothistory", lootHistoryRouter);
apiRouter.use("/items", itemRouter);
apiRouter.use("/io", importExportRouter);
apiRouter.use("/settings", settingsRouter);
apiRouter.use("/backup", backupRouter);

app.use("/api", apiRouter);

if (getConfig().hostClient) {
    logger.log("Serving client files.");

    const indexPath = process.cwd() + "/build/client/index.html";
    if (!existsSync(indexPath)) {
        logger.logError("Can't find index.html at path: " + indexPath);
        process.exit(1);
    }

    app.use(express.static("build/client", {}));
    app.use((req, res, _next) => {
        res.sendFile(indexPath, (err) => {
            if (err) logger.logError(`Error serving 404 redirect for path ${req.path}!`, err);
        });
    });
}

export default app;

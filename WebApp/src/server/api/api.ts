import express, { Application } from "express";
import cors from "cors";
import { checkDb } from "../database/database";
import { authRouter } from "./authApi";
import { auditRouter } from "./auditApi";
import { userRouter } from "./userApi";

const cookieParser = require("cookie-parser");
const app: Application = express();

app.use(express.json({ limit: "5mb" }));
app.use(cors());
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

const apiRouter = express.Router();
apiRouter.use("/auth", authRouter);
apiRouter.use("/users", userRouter);
apiRouter.use("/audit", auditRouter);

checkDb().then((ok) => {
    if (!ok) {
        console.log("DB setup failed, exiting.");
        process.exit(1);
    }
    app.use("/api", apiRouter);
});

export default app;

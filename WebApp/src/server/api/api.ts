import express, { Application } from "express";
import cors from "cors";
import { authRouter } from "./authApi";
import { auditRouter } from "./auditApi";
import { userRouter } from "./userApi";
import { playerRouter } from "./playerApi";

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
apiRouter.use("/players", playerRouter);

app.use("/api", apiRouter);

export default app;

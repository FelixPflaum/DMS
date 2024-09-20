import { createServer } from "http";
import apiApp from "./api/api.ts";
import { Logger } from "./Logger.ts";

const logger = new Logger("Server");
const port = 9001;
const server = createServer();
server.on("request", apiApp);
server.listen(port, () => {
    logger.log(`Started. Listening on port ${port}.`);
});

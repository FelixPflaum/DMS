import { createServer } from "http";
import apiApp from "./api/api.ts";

const port = 9001;
const server = createServer();
server.on("request", apiApp);
server.listen(port, () => {
    console.log(`Server started. Listening on port ${port}.`);
});

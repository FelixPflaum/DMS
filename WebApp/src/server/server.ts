import { createServer } from "http";
import apiApp from "./api/api.ts";
import { Logger } from "./Logger.ts";
import { checkDb } from "./database/database.ts";
import { Discordbot } from "./discordBot/Discordbot.ts";
import { getConfig } from "./config.ts";
import { RegisterCommand } from "./discordBot/registerCommand.ts";

const logger = new Logger("Server");
const port = 9001;
const server = createServer();
server.on("request", apiApp);

checkDb().then((ok) => {
    if (!ok) {
        logger.logError("DB setup failed, exiting.");
        process.exit(1);
    }

    const bot = new Discordbot(getConfig().discordBotToken);
    bot.registerCommand(new RegisterCommand());
    //bot.connect(); // TODO: enable again

    server.listen(port, () => {
        logger.log(`Started. Listening on port ${port}.`);
    });
});

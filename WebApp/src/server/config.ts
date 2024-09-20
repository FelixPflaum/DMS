import { existsSync, readFileSync, writeFileSync } from "fs";

type ConfigData = {
    discordClientId: string;
    discordClientSecret: string;
    discordRedirectUrl: string;
    dbHost: string;
    dbPort: number;
    dbUser: string;
    dbPass: string;
    dbName: string;
    adminLoginId: string;
};

const config: ConfigData = {
    discordClientId: "",
    discordClientSecret: "",
    discordRedirectUrl: "",
    dbHost: "localhost",
    dbPort: 3306,
    dbUser: "",
    dbPass: "",
    dbName: "",
    adminLoginId: "",
};
let loaded = false;

function isKey<T extends object>(x: T, k: PropertyKey): k is keyof T {
    return k in x;
}

/** Get config file data. */
export const getConfig = (): Readonly<ConfigData> => {
    if (!loaded) {
        if (!existsSync("config.json")) {
            writeFileSync("config.json", JSON.stringify(config, null, 4));
            console.log("Config file created! Edit and start again.");
            process.exit(0);
        }
        const file = readFileSync("config.json");
        const parsed = JSON.parse(file.toString("utf-8")) as Partial<ConfigData>;
        for (const key in parsed) {
            if (!isKey(config, key)) continue;
            if (typeof parsed[key] != typeof config[key]) {
                console.error(`Config file entry ${key} has type ${typeof parsed[key]} but expected ${typeof config[key]}`);
                process.exit(1);
            }
            // @ts-ignore
            config[key] = parsed[key]!;
        }
        loaded = true;
    }
    return config;
};

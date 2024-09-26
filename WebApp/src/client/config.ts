import cfgdata from "../../config_client.json";

type ClientConfig = {
    discordClientId: string;
    discordRedirectUrl: string;
};

export const config = cfgdata as Readonly<ClientConfig>;

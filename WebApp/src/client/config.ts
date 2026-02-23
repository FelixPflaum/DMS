import cfgdata from "../../config_client.json";

type ClientConfig = {
    discordClientId: string;
    discordRedirectUrl: string;
    wowheadBranch: string;
};

export const config = cfgdata as Readonly<ClientConfig>;

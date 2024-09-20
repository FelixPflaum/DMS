import { getConfig } from "./config";

const API_URL = "https://discord.com/api/v10";

/**
 * Do a discord oauth token request.
 * @param reqParams The requst parameters.
 * @returns Resolves to fetch response.
 */
function doTokenRequest(reqParams: Record<string, string>): Promise<globalThis.Response> {
    const cfg = getConfig();
    return fetch(API_URL + "/oauth2/token", {
        method: "POST",
        headers: {
            "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
            ...reqParams,
            client_id: cfg.discordClientId,
            client_secret: cfg.discordClientSecret,
        }),
    });
}

type DiscordUserData = {
    id: string;
    userName: string;
};

/**
 * Get discird user data from oauth redirect code.
 * @param code The oauth2 redirect code.
 * @returns
 */
export const getUserDataFromOauthCode = async (code: string): Promise<DiscordUserData | false> => {
    const tokenResult = await doTokenRequest({
        redirect_uri: getConfig().discordRedirectUrl,
        code: code,
        grant_type: "authorization_code",
    });

    if (tokenResult.status != 200) {
        if (tokenResult.status == 400) {
            const data = await tokenResult.json();
            console.log("Status 400 on discord oauth request:");
            console.log(data);
        }
        return false;
    }

    const tokenData = await tokenResult.json();
    const accessToken: string = tokenData.access_token;

    const userResult = await fetch(API_URL + "/users/@me", {
        method: "GET",
        headers: { Authorization: `Bearer ${accessToken}` },
    });

    if (userResult.status != 200) {
        if (userResult.status == 400) {
            const data = await userResult.json();
            console.log("Status 400 on discord user request:");
            console.log(data);
        }

        return false;
    }

    const userData = await userResult.json();
    const id: string = userData.id;
    const userName: string = userData.global_name ?? userData.username;

    return {
        id,
        userName,
    };
};

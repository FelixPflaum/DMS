import { getConfig } from "./config";
import { Logger } from "./Logger";

const API_URL = "https://discord.com/api/v10";
const logger = new Logger("Discord API");

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
        try {
            if (tokenResult.status == 400) {
                const data = await tokenResult.text();
                logger.logError(`Status ${tokenResult.status} on discord oauth request.`, data);
            }
        } catch (error) {
            logger.logError(`Status ${tokenResult.status} on discord oauth request.`);
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
        try {
            if (userResult.status == 400) {
                const data = await userResult.text();
                logger.logError(`Status ${userResult.status} on discord user request.`, data);
            }
        } catch (error) {
            logger.logError(`Status ${userResult.status} on discord user request.`);
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

import { useContext, createContext, useState, useEffect } from "react";
import { config } from "./config";
import { apiGet, apiPost } from "./serverApi";
import type { ApiAuthRes, ApiAuthUserRes, ApiUserEntry } from "@/shared/types";
import { AccPermissions } from "@/shared/permissions";
import { isItemDataLoaded, loadItemData } from "./data/itemStorage";

type AuthContextType = {
    user: ApiUserEntry | null;
    logout: () => void;
    hasPermission: (perm: AccPermissions) => boolean;
};

const AuthContext = createContext<AuthContextType>({
    user: null,
    logout: () => {},
    hasPermission: () => false,
});

export const useAuthContext = (): AuthContextType => useContext<AuthContextType>(AuthContext);

const AuthProvider = ({ children }: { children: JSX.Element[] | JSX.Element }): JSX.Element => {
    const [user, setUser] = useState<ApiUserEntry | null>(null);
    const [auth, setAuth] = useState<{ loginId: string; loginToken: string } | null>(null);
    const [authStatus, setAuthStatus] = useState("");

    const logout = () => {
        apiGet("/api/auth/logout").then((res) => {
            if (!res.error || confirm("Error on logout request! Log out in browser only?.\nError: " + res.error)) {
                document.cookie = "loginId=; Max-Age=-1";
                document.cookie = "loginToken=; Max-Age=-1";
                setAuth(null);
                setUser(null);
            }
        });
    };

    const hasPermission = (permissions: AccPermissions): boolean => {
        if (!user) return false;
        return (user.permissions & AccPermissions.ADMIN) !== 0 || (user.permissions & permissions) === permissions;
    };

    const checkLoginAndGetUser = async (): Promise<void> => {
        setAuthStatus("Checking login...");
        const data = await apiGet<ApiAuthUserRes>("/api/auth/check");
        if (data.error) {
            alert("Login failed: " + data.error);
        } else if (data.invalidLogin) {
            alert("Login data expired, logging out.");
            logout();
        } else {
            setUser(data.user);

            // TODO: move this somewhere else
            if (!isItemDataLoaded(data.itemDbVer)) {
                console.log("Loading new item data...");
                loadItemData().then(() => console.log("Item data loaded!"));
            }
        }
        setAuthStatus("");
    };

    let alreadyDidRequest = false; // Dev strict mode fires useEffect twice...
    const login = async (code: string): Promise<void> => {
        if (alreadyDidRequest) return;
        alreadyDidRequest = true;
        setAuthStatus("Logging in...");
        const data = await apiPost<ApiAuthRes>("/api/auth/authenticate", { code });
        if (data.error) {
            alert("Login failed: " + data.error);
        } else {
            const expDate = new Date();
            expDate.setTime(expDate.getTime() + 30 * 86400 * 1000);
            document.cookie = `loginId=${data.loginId}; path=/; expires=${expDate.toUTCString()}`;
            document.cookie = `loginToken=${data.loginToken}; path=/; expires=${expDate.toUTCString()}`;
            checkLoginAndGetUser();
        }
    };

    useEffect(() => {
        if (user && auth) return;

        // See if cookies are there and check auth if so.
        const cookies = document.cookie;
        const idMatch = cookies.match(/loginId=([^;]+)/);
        const tokenMatch = cookies.match(/loginToken=([^;]+)/);
        if (idMatch && tokenMatch) {
            checkLoginAndGetUser();
            return;
        }

        // Check if page was loaded with oauth code. Try login if so.
        const urlParams = new URLSearchParams(window.location.search);
        const code = urlParams.get("code");
        if (code) {
            urlParams.delete("code");
            const nurl =
                window.location.protocol +
                "//" +
                window.location.host +
                window.location.pathname +
                "?" +
                urlParams.toString();
            window.history.replaceState(null, "", nurl);
            login(code);
        }
    }, []);

    return (
        <AuthContext.Provider value={{ user, logout, hasPermission }}>
            {user ? (
                children
            ) : authStatus ? (
                <div className="centered">{authStatus}</div>
            ) : (
                <div className="centered">
                    <a
                        className="loginButton"
                        href={`https://discord.com/oauth2/authorize?client_id=${config.discordClientId}&response_type=code&redirect_uri=${encodeURIComponent(config.discordRedirectUrl)}&scope=identify`}
                    >
                        Login with Discord
                    </a>
                </div>
            )}
        </AuthContext.Provider>
    );
};

export default AuthProvider;

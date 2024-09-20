import { useContext, createContext, useState, useEffect } from "react";
import { config } from "./config";
import { apiGet, apiPost } from "./serverApi";

type AuthUser = {
    name: string;
    permissions: number;
};

type AuthContextType = {
    user: AuthUser | null;
    logout: () => void;
};

const AuthContext = createContext<AuthContextType>({
    user: null,
    logout: () => {},
});

export const useAuthContext = (): AuthContextType => useContext<AuthContextType>(AuthContext);

const AuthProvider = ({ children }: { children: JSX.Element }): JSX.Element => {
    const [user, setUser] = useState<AuthUser | null>(null);
    const [auth, setAuth] = useState<{ loginId: string; loginToken: string } | null>(null);
    const [authStatus, setAuthStatus] = useState("");

    const logout = () => {
        fetch("/api/auth/logout").then(() => {
            document.cookie = "loginId=; Max-Age=-1";
            document.cookie = "loginToken=; Max-Age=-1";
            setAuth(null);
            setUser(null);
        });
    };

    const checkLoginAndGetUser = async (): Promise<void> => {
        setAuthStatus("Checking login...");
        const data = await apiGet<AuthUserRes>("/api/auth/user", "login check");
        if (data && data.loginValid) {
            setUser({ name: data.userName, permissions: data.permissions });
        } else {
            logout();
        }
        setAuthStatus("");
    };

    let alreadyDidRequest = false; // Dev strict mode fires useEffect twice...
    const login = async (code: string): Promise<void> => {
        if (alreadyDidRequest) return;
        alreadyDidRequest = true;
        setAuthStatus("Logging in...");
        const data = await apiPost<AuthRes>("/api/auth/authenticate", "login", { code });
        if (data) {
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
        <AuthContext.Provider value={{ user, logout }}>
            {user ? (
                children
            ) : authStatus ? (
                <div className="centered">{authStatus}</div>
            ) : (
                <div className="centered">
                    <a
                        className="loginButton"
                        href={`https://discord.com/oauth2/authorize?client_id=${config.discordClientId}&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A9000&scope=identify`}
                    >
                        Login with Discord
                    </a>
                </div>
            )}
        </AuthContext.Provider>
    );
};

export default AuthProvider;

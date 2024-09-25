import { Link } from "react-router-dom";
import styles from "./header.module.css";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/permissions";
import { useEffect, useState } from "react";
import { apiGet } from "../serverApi";
import type { PlayerEntry } from "@/shared/types";

const Header = (): JSX.Element => {
    const [ownChars, setOwnChars] = useState<PlayerEntry[] | undefined>();
    const authctx = useAuthContext();
    if (!authctx.user) return <></>;

    useEffect(() => {
        apiGet<PlayerEntry[]>("/api/players/self", "get own player list").then((playersRes) => {
            if (playersRes && playersRes.length > 0) setOwnChars(playersRes);
        });
    }, []);

    const buttons: ({ text: string; path: string; permission?: AccPermissions } | "|")[] = [
        { text: "Settings", path: "/settings", permission: AccPermissions.SETTINGS_VIEW },
        { text: "Auditlog", path: "/audit", permission: AccPermissions.AUDIT_VIEW },
        { text: "Users", path: "/users", permission: AccPermissions.USERS_VIEW },
        "|",
        { text: "Players", path: "/players", permission: AccPermissions.DATA_VIEW },
        { text: "Sanity History", path: "/pointhistory", permission: AccPermissions.DATA_VIEW },
        { text: "Loot History", path: "/loothistory", permission: AccPermissions.DATA_VIEW },
        "|",
        { text: "Import", path: "/import", permission: AccPermissions.DATA_MANAGE },
        { text: "Export", path: "/export", permission: AccPermissions.DATA_MANAGE },
        { text: "Import-Logs", path: "/importlogs", permission: AccPermissions.DATA_MANAGE },
    ];

    const charButtons: JSX.Element[] = [];
    if (ownChars) {
        for (const char of ownChars) {
            charButtons.push(
                <Link
                    key={char.playerName}
                    className={`${styles.headerButton} classId${char.classId}`}
                    to={`/profile?name=${char.playerName}`}
                >
                    {char.playerName}
                </Link>
            );
        }
    }

    const buttonElems: JSX.Element[] = [];
    for (const btn of buttons) {
        if (typeof btn === "string") {
            buttonElems.push(<span className={styles.headerSpacer}>{btn}</span>);
        } else if (!btn.permission || authctx.hasPermission(btn.permission)) {
            buttonElems.push(
                <Link key={btn.path} className={styles.headerButton} to={btn.path}>
                    {btn.text}
                </Link>
            );
        }
    }

    return (
        <header className={styles.headerWrap}>
            {buttonElems}
            <div className={styles.headerOwnChars}>{charButtons}</div>
            <div className={styles.headerUserInfo}>
                <span className={styles.headerUserLabel}>Logged in as:</span>
                <span className={styles.headerUserName}>{authctx.user.name}</span>
                <button className={styles.headerButton} onClick={authctx.logout}>
                    Logout
                </button>
            </div>
        </header>
    );
};

export default Header;

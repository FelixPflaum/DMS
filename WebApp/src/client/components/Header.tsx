import { Link } from "react-router-dom";
import styles from "./header.module.css";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/permissions";
import { useEffect, useState } from "react";
import { apiGet } from "../serverApi";
import type { ApiPlayerEntry, ApiSelfPlayerRes } from "@/shared/types";
import { useToaster } from "./toaster/Toaster";

const Header = (): JSX.Element => {
    const [ownChars, setOwnChars] = useState<ApiPlayerEntry[] | undefined>();
    const authctx = useAuthContext();
    const toaster = useToaster();
    if (!authctx.user) return <></>;

    useEffect(() => {
        apiGet<ApiSelfPlayerRes>("/api/players/self").then((playersRes) => {
            if (playersRes.error) {
                return toaster.addToast("Loading Players Failed", playersRes.error, "error");
            }
            if (playersRes.myChars.length > 0) setOwnChars(playersRes.myChars);
        });
    }, []);

    const buttons: { link?: { text: string; path: string }; elem?: JSX.Element; permission?: AccPermissions }[] = [
        { link: { text: "Settings", path: "/settings" }, permission: AccPermissions.SETTINGS_VIEW },
        { link: { text: "Auditlog", path: "/audit" }, permission: AccPermissions.AUDIT_VIEW },
        { link: { text: "Users", path: "/users" }, permission: AccPermissions.USERS_VIEW },
        {
            elem: <span className={styles.headerSpacer}></span>,
            permission: AccPermissions.USERS_VIEW | AccPermissions.AUDIT_VIEW | AccPermissions.SETTINGS_VIEW,
        },
        { link: { text: "Import", path: "/import" }, permission: AccPermissions.DATA_IMPORT },
        { link: { text: "Export", path: "/export" } },
        { link: { text: "Import-Logs", path: "/importlogs" }, permission: AccPermissions.DATA_MANAGE },
        { elem: <span className={styles.headerSpacer}></span> },
        { link: { text: "Players", path: "/players" }, permission: AccPermissions.DATA_VIEW },
        { link: { text: "Sanity History", path: "/pointhistory" }, permission: AccPermissions.DATA_VIEW },
        { link: { text: "Loot History", path: "/loothistory" }, permission: AccPermissions.DATA_VIEW },
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
        if (!btn.permission || authctx.hasPermission(btn.permission)) {
            if (btn.elem) {
                buttonElems.push(btn.elem);
            } else if (btn.link) {
                buttonElems.push(
                    <Link key={btn.link.path} className={styles.headerButton} to={btn.link.path}>
                        {btn.link.text}
                    </Link>
                );
            }
        }
    }

    return (
        <header className={styles.headerWrap}>
            {buttonElems}
            <div className={styles.headerOwnChars}>{charButtons}</div>
            <div className={styles.headerUserInfo}>
                <span className={styles.headerUserLabel}>Logged in as:</span>
                <span className={styles.headerUserName}>{authctx.user.userName}</span>
                <button className={styles.headerButton} onClick={authctx.logout}>
                    Logout
                </button>
            </div>
        </header>
    );
};

export default Header;

import { Link } from "react-router-dom";
import styles from "./header.module.css";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/permissions";

const Header = (): JSX.Element => {
    const authctx = useAuthContext();
    if (!authctx.user) return <></>;

    const buttons: ({ text: string; path: string; permission?: AccPermissions } | "|")[] = [
        { text: "Auditlog", path: "/audit", permission: AccPermissions.AUDIT_VIEW },
        { text: "Users", path: "/users", permission: AccPermissions.USERS_VIEW },
        "|",
        { text: "Players", path: "/players", permission: AccPermissions.DATA_VIEW },
        { text: "Sanity History", path: "/pointhistory", permission: AccPermissions.DATA_VIEW },
        { text: "Loot History", path: "/loothistory", permission: AccPermissions.DATA_VIEW },
        "|",
        { text: "Import", path: "/import", permission: AccPermissions.DATA_MANAGE },
        { text: "Export", path: "/export", permission: AccPermissions.DATA_MANAGE },
    ];

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

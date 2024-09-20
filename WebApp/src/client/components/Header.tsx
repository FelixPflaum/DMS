import { Link } from "react-router-dom";
import styles from "./header.module.css";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/enums";

const Header = (): JSX.Element => {
    const authctx = useAuthContext();
    if (!authctx.user) return <></>;

    const buttons: { text: string; path: string; permission?: AccPermissions }[] = [
        { text: "Test", path: "/" },
        { text: "Users", path: "/users", permission: AccPermissions.USERS_VIEW },
        { text: "Audit", path: "/audit", permission: AccPermissions.AUDIT_VIEW },
        { text: "Players", path: "/players", permission: AccPermissions.DATA_VIEW },
    ];

    const buttonElems: JSX.Element[] = [];
    for (const btn of buttons) {
        if (!btn.permission || (btn.permission & authctx.user.permissions) == btn.permission) {
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

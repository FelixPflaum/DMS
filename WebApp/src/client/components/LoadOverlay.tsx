import type { CSSProperties } from "react";
import styles from "./loadOverlay.module.css";

const LoadOverlay = ({ text, isTransparent }: { text: string; isTransparent?: boolean }): JSX.Element => {
    const styleOverride: CSSProperties = {};
    if (isTransparent) styleOverride.background = "none";
    return (
        <div style={styleOverride} className={styles.loadOverlay}>
            <div className={styles.loadStatusWrap}>
                <div className={styles.loadIndicator}>8==D</div>
                <span className={styles.loadStatusText}>{text}</span>
            </div>
        </div>
    );
};

export default LoadOverlay;

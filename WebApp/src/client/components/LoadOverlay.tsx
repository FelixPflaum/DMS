import styles from "./loadOverlay.module.css";

const LoadOverlay = ({ text }: { text: string }): JSX.Element => {
    return (
        <div className={styles.loadOverlay}>
            <div className={styles.loadStatusWrap}>
                <div className={styles.loadIndicator}>8==D</div>
                <span className={styles.loadStatusText}>{text}</span>
            </div>
        </div>
    );
};

export default LoadOverlay;

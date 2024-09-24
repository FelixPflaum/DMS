import styles from "./logview.module.css";
import type { ApiImportLogEntry, ImportLog } from "@/shared/types";

function getNewTdClass(oldVal: number, newVal: number): string {
    if (oldVal != newVal) return styles.importLogViewTd + " " + styles.changed;
    return styles.importLogViewTd;
}

const ImportLogViewer = ({ log }: { log: ApiImportLogEntry }): JSX.Element => {
    const playersAdded: JSX.Element[] = [];
    const playersUpdated: JSX.Element[] = [];
    const pointHist: JSX.Element[] = [];
    const loottHist: JSX.Element[] = [];

    const data = JSON.parse(log.logData) as ImportLog;

    for (const p of data.players) {
        if (p.old) {
            playersUpdated.push(
                <tr key={p.new.playerName} className={styles.importLogViewTr}>
                    <td className={styles.importLogViewTd}>{p.new.playerName}</td>
                    <td className={styles.importLogViewTd}>{p.old.classId}</td>
                    <td className={getNewTdClass(p.old.classId, p.new.classId)}>{p.new.classId}</td>
                    <td className={styles.importLogViewTd}>{p.old.points}</td>
                    <td className={getNewTdClass(p.old.points, p.new.points)}>{p.new.points}</td>
                </tr>
            );
        } else {
            playersAdded.push(
                <tr key={p.new.playerName} className={styles.importLogViewTr}>
                    <td className={styles.importLogViewTd}>{p.new.playerName}</td>
                    <td className={styles.importLogViewTd}>{p.new.classId}</td>
                    <td className={styles.importLogViewTd}>{p.new.points}</td>
                </tr>
            );
        }
    }

    for (const p of data.pointHistory) {
        pointHist.push(
            <tr key={p.new.timeStamp + p.new.playerName} className={styles.importLogViewTr}>
                <td className={styles.importLogViewTd}>{p.new.timeStamp}</td>
                <td className={styles.importLogViewTd}>{p.new.playerName}</td>
                <td className={styles.importLogViewTd}>{p.new.change}</td>
                <td className={styles.importLogViewTd}>{p.new.newPoints}</td>
                <td className={styles.importLogViewTd}>{p.new.type}</td>
                <td className={styles.importLogViewTd}>{p.new.reason}</td>
            </tr>
        );
    }

    for (const p of data.lootHistory) {
        loottHist.push(
            <tr key={p.new.timeStamp + p.new.playerName} className={styles.importLogViewTr}>
                <td className={styles.importLogViewTd}>{p.new.timeStamp}</td>
                <td className={styles.importLogViewTd}>{p.new.guid}</td>
                <td className={styles.importLogViewTd}>{p.new.playerName}</td>
                <td className={styles.importLogViewTd}>{p.new.itemId}</td>
                <td className={styles.importLogViewTd}>{p.new.response}</td>
            </tr>
        );
    }

    return (
        <div className={styles.logViewWrap}>
            <h3>{playersAdded.length} players added:</h3>
            <form className={styles.importLogViewForm}>
                <thead>
                    <tr>
                        <th className={styles.importLogViewTh}>Name</th>
                        <th className={styles.importLogViewTh}>Class</th>
                        <th className={styles.importLogViewTh}>Points</th>
                    </tr>
                </thead>
                <tbody>{playersAdded}</tbody>
            </form>
            <h3>{playersUpdated.length} players updated:</h3>
            <form className={styles.importLogViewForm}>
                <thead>
                    <tr>
                        <th className={styles.importLogViewTh}>Name</th>
                        <th className={styles.importLogViewTh}>Class old</th>
                        <th className={styles.importLogViewTh}>Class new</th>
                        <th className={styles.importLogViewTh}>Points old</th>
                        <th className={styles.importLogViewTh}>Points new</th>
                    </tr>
                </thead>
                <tbody>{playersUpdated}</tbody>
            </form>
            <h3>{pointHist.length} sanity history entries added:</h3>
            <form className={styles.importLogViewForm}>
                <thead>
                    <tr>
                        <th className={styles.importLogViewTh}>Time</th>
                        <th className={styles.importLogViewTh}>Name</th>
                        <th className={styles.importLogViewTh}>Change</th>
                        <th className={styles.importLogViewTh}>New</th>
                        <th className={styles.importLogViewTh}>Type</th>
                        <th className={styles.importLogViewTh}>Reason</th>
                    </tr>
                </thead>
                <tbody>{pointHist}</tbody>
            </form>
            <h3>{loottHist.length} loot history entries added:</h3>
            <form className={styles.importLogViewForm}>
                <thead>
                    <tr>
                        <th className={styles.importLogViewTh}>Time</th>
                        <th className={styles.importLogViewTh}>GUID</th>
                        <th className={styles.importLogViewTh}>Name</th>
                        <th className={styles.importLogViewTh}>Item Id</th>
                        <th className={styles.importLogViewTh}>Response</th>
                    </tr>
                </thead>
                <tbody>{loottHist}</tbody>
            </form>
        </div>
    );
};

export default ImportLogViewer;

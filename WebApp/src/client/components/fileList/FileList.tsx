import styles from "./filelist.module.css";

const FileList = ({
    path,
    files,
    onBack,
    onSelect,
}: {
    path: string[];
    files: string[];
    onBack: () => void;
    onSelect: (file: string) => void;
}): JSX.Element => {
    const listElems: JSX.Element[] = [];

    for (const entry of files) {
        listElems.push(
            <li key={entry} className={styles.fileListLi} onClick={() => onSelect(entry)}>
                {entry}
            </li>
        );
    }

    return (
        <div className={styles.fileListWrap}>
            <div className={styles.fileListPath}>
                <button className={styles.fileListPathBackBtn} onClick={onBack}>
                    &lt;
                </button>
                <span className={styles.fileListPathString}>{"/" + path.join("/")}</span>
            </div>
            <ul className={styles.fileListList}>{listElems}</ul>
        </div>
    );
};

export default FileList;

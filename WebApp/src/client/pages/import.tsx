import type { ApiImportResult } from "@/shared/types";
import { apiPost } from "../serverApi";
import styles from "../styles/pageImport.module.css";
import { useRef } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { useToaster } from "../components/toaster/Toaster";

const ImportPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const inputAreaRef = useRef<HTMLDivElement>(null);
    const submitButtonRef = useRef<HTMLButtonElement>(null);
    const textareaRef = useRef<HTMLTextAreaElement>(null);
    const statusRef = useRef<HTMLSpanElement>(null);
    const toaster = useToaster();

    const onSubmit: React.FormEventHandler<HTMLFormElement> = (evt) => {
        evt.preventDefault();
        if (!submitButtonRef.current || !textareaRef.current) return;
        const input = textareaRef.current.value;
        if (!input) return;
        statusRef.current!.innerText = "Importing data...";
        loadctx.setLoading("getexport", "Importing data...");
        apiPost<ApiImportResult>("/api/io/import", { input }).then((res) => {
            loadctx.removeLoading("getexport");
            if (res.error) {
                statusRef.current!.innerText = "VALIDATION ERROR: " + res.error;
            } else {
                statusRef.current!.innerText = "Data imported successfully!";
                toaster.addToast("Import Successful", "Imported data.", "success");
                inputAreaRef.current!.style.display = "none";
            }
        });
    };

    return (
        <>
            <h1 className="pageHeading">Import</h1>
            <div className={styles.importInputArea} ref={inputAreaRef}>
                <form onSubmit={onSubmit}>
                    <label>String from addon export:</label>
                    <textarea ref={textareaRef} className={styles.importTextarea} required={true}></textarea>
                    <button ref={submitButtonRef} className="button">
                        Import Data
                    </button>
                </form>
            </div>
            <div className={styles.validationResultArea}>
                <span ref={statusRef}></span>
            </div>
        </>
    );
};

export default ImportPage;

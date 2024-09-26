import type { ApiExportResult } from "@/shared/types";
import { apiGet } from "../serverApi";
import styles from "../styles/pageImport.module.css";
import { useRef } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";

const ExportPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const buttonRef = useRef<HTMLButtonElement>(null);
    const textRef = useRef<HTMLTextAreaElement>(null);

    const onClick: React.MouseEventHandler<HTMLButtonElement> = (evt) => {
        evt.preventDefault();
        if (!buttonRef.current || !textRef.current) return;
        textRef.current.value = "";
        loadctx.setLoading("getexport", "Creating export...");
        apiGet<ApiExportResult>("/api/io/export").then((res) => {
            loadctx.removeLoading("getexport");
            if (res.error) return alert("Failed to get export: " + res.error);
            if (textRef.current) textRef.current.value = res.export;
        });
    };

    return (
        <>
            <h1 className="pageHeading">Export</h1>
            <button ref={buttonRef} className="button" onClick={onClick}>
                Create Export
            </button>
            <textarea ref={textRef} className={styles.importTextarea}></textarea>
        </>
    );
};

export default ExportPage;

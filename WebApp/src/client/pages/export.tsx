import type { ApiExportResult } from "@/shared/types";
import { apiGet } from "../serverApi";
import styles from "../styles/pageImport.module.css";
import { useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import NumberInput from "../components/form/NumberInput";
import { useToaster } from "../components/toaster/Toaster";

const ExportPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const toaster = useToaster();
    const buttonRef = useRef<HTMLButtonElement>(null);
    const [days, setDays] = useState<number>(60);
    const [exportString, setExportString] = useState<string>("");

    const onClick: React.MouseEventHandler<HTMLButtonElement> = (evt) => {
        evt.preventDefault();
        if (!buttonRef.current) return;
        setExportString("");
        buttonRef.current.disabled = true;
        loadctx.setLoading("getexport", "Creating export...");
        apiGet<ApiExportResult>("/api/io/export/" + days).then((res) => {
            loadctx.removeLoading("getexport");
            if (buttonRef.current) buttonRef.current.disabled = false;
            if (res.error) return toaster.addToast("Export Failed", res.error, "error"); //alert("Failed to get export: " + res.error);
            setExportString(res.export);
        });
    };

    const copyToClipboard: React.MouseEventHandler<HTMLButtonElement> = async (_evt) => {
        try {
            await navigator.clipboard.writeText(exportString);
            toaster.addToast("Text Copied", "Copied text to clipboard.", "info");
        } catch (error) {
            console.error(error);
            toaster.addToast("Clipboar Error", "Could not copy text to clipboard!", "error");
        }
    };

    return (
        <>
            <h1 className="pageHeading">Export</h1>
            <NumberInput label="History length (days)" value={days} onChange={(_, val) => setDays(val)}></NumberInput>
            <button ref={buttonRef} className={"button " + styles.exportButton} onClick={onClick}>
                Create Export
            </button>
            <textarea
                className={styles.importTextarea}
                readOnly={true}
                value={exportString}
                onFocus={(e) => e.target.select()}
            ></textarea>
            {exportString ? (
                <>
                    <button className="button" onClick={copyToClipboard}>
                        Copy Text
                    </button>
                    <span className={styles.exportSizeInfo}>{`Size: ${exportString.length}`}</span>
                </>
            ) : (
                <></>
            )}
        </>
    );
};

export default ExportPage;

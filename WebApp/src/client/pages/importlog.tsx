import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import type { ApiImportLogEntry, ApiImportLogRes } from "@/shared/types";
import { useSearchParams } from "react-router-dom";
import ImportLogViewer from "../components/importLogViewer/ImportLogViewer";
import { useToaster } from "../components/toaster/Toaster";

const ImportLogViewPage = (): JSX.Element => {
    const toaster = useToaster();
    const [log, setLog] = useState<ApiImportLogEntry | null>(null);
    const loadctx = useLoadOverlayCtx();
    const [searchParams, _setSearchParams] = useSearchParams();
    const navigate = useNavigate();

    const idParam = searchParams.get("id");
    const logId = idParam ? parseInt(idParam) : -1;

    if (logId === -1) {
        navigate("/importlogs");
    }

    useEffect(() => {
        loadctx.setLoading("fetchlog", "Loading log...");
        apiGet<ApiImportLogRes>("/api/io/log/" + logId).then((logRes) => {
            loadctx.removeLoading("fetchlog");
            if (logRes.error) {
                toaster.addToast("Failed Loading Importlog", logRes.error, "error");
                navigate("/importlogs");
                return;
            }
            setLog(logRes.entry);
        });
    }, []);

    let view: JSX.Element | null = null;

    if (log)
        view = (
            <>
                <h3>
                    #{log.id} imported by {log.userName}
                </h3>
                <h4>{new Date(log.timestamp).toLocaleString()}</h4>
                <ImportLogViewer log={log}></ImportLogViewer>
            </>
        );

    return (
        <>
            <h1 className="pageHeading">Log View</h1>
            {view}
        </>
    );
};

export default ImportLogViewPage;

import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import type { ApiImportLogEntry } from "@/shared/types";
import { useSearchParams } from "react-router-dom";
import ImportLogViewer from "../components/importLogViewer/ImportLogViewer";

const ImportLogViewPage = (): JSX.Element => {
    const [log, setLog] = useState<ApiImportLogEntry | null>(null);
    const loadctx = useLoadOverlayCtx();
    const [searchParams, _setSearchParams] = useSearchParams();

    const idParam = searchParams.get("id");
    const logId = idParam ? parseInt(idParam) : -1;

    if (logId === -1) {
        const navigate = useNavigate();
        navigate("/importlogs");
    }

    useEffect(() => {
        loadctx.setLoading("fetchlog", "Loading log...");
        apiGet<ApiImportLogEntry>("/api/io/log/" + logId, "get log").then((logRes) => {
            loadctx.removeLoading("fetchlog");
            if (logRes) setLog(logRes);
        });
    }, []);

    let view: JSX.Element | null = null;

    if (log)
        view = (
            <>
                <h3>
                    #{log.id} imported by {log.userName}
                </h3>
                <h4>{log.timestamp}</h4>
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

import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ActionDef, ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import type { ApiImportLogListResult } from "@/shared/types";

type ListLog = ApiImportLogListResult["logs"][0];

const ImportLogsPage = (): JSX.Element => {
    const [logs, setLogs] = useState<ListLog[]>([]);
    const loadctx = useLoadOverlayCtx();

    useEffect(() => {
        loadctx.setLoading("fetchlogs", "Loading log list...");
        apiGet<ApiImportLogListResult>("/api/io/logs", "get log list").then((logsRes) => {
            loadctx.removeLoading("fetchlogs");
            if (logsRes) setLogs(logsRes.logs);
        });
    }, []);

    const navigate = useNavigate();
    const showLog = (logEntry: ListLog) => {
        navigate("/importlog?id=" + logEntry.id);
    };

    const columDefs: ColumnDef<ListLog>[] = [
        { name: "Id", dataKey: "id", canSort: true },
        {
            name: "Time",
            dataKey: "timestamp",
            canSort: true,
            render: (rd) => {
                const dt = new Date(rd.timestamp);
                return dt.toLocaleString();
            },
        },
        { name: "Importer", dataKey: "userName", canSort: true },
    ];

    const actions: ActionDef<ListLog>[] = [{ name: "View", onClick: showLog }];

    return (
        <>
            <h1 className="pageHeading">Import Logs</h1>
            <Tablel columnDefs={columDefs} data={logs} sortCol="id" sortDir="desc" actions={actions}></Tablel>
        </>
    );
};

export default ImportLogsPage;

import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { ApiAuditEntry, ApiAuditPageRes } from "@/shared/types";

const AuditPage = (): JSX.Element => {
    const [auditLogData, setAuditLog] = useState<{ lastPageOffset: number; data: ApiAuditEntry[]; haveMore: boolean }>({
        lastPageOffset: -1,
        data: [],
        haveMore: true,
    });
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);

    const loadMore = () => {
        const nextPage = auditLogData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadctx.setLoading("auditfetch", "Loading audit log data...");
        apiGet<ApiAuditPageRes>("/api/audit/page/" + nextPage).then((res) => {
            if (loadBtnRef.current) loadBtnRef.current.disabled = false;
            loadctx.removeLoading("auditfetch");
            if (res.error) {
                alert("Failed to load audit data: " + res.error);
            } else {
                setAuditLog({
                    lastPageOffset: res.pageOffset,
                    data: res.entries.concat(auditLogData.data),
                    haveMore: res.haveMore,
                });
            }
        });
    };

    useEffect(() => {
        loadMore();
    }, []);

    const columDefs: ColumnDef<ApiAuditEntry>[] = [
        { name: "ID", dataKey: "id" },
        {
            name: "Time",
            dataKey: "timestamp",
            render: (rd) => {
                const dt = new Date(rd.timestamp);
                return dt.toLocaleString();
            },
        },
        { name: "Discord ID", dataKey: "loginId" },
        { name: "Name", dataKey: "userName" },
        { name: "Event", dataKey: "eventInfo" },
    ];

    return (
        <>
            <h1 className="pageHeading">Audit Log</h1>
            <Tablel columnDefs={columDefs} data={auditLogData.data} sortCol="id" sortDir="desc"></Tablel>
            {auditLogData.haveMore ? (
                <button className="button" onClick={loadMore} ref={loadBtnRef}>
                    Load more
                </button>
            ) : null}
        </>
    );
};

export default AuditPage;

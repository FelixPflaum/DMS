import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { AuditEntry, AuditRes } from "@/shared/types";

const AuditPage = (): JSX.Element => {
    const [auditLogData, setAuditLog] = useState<{ lastPageOffset: number; data: AuditEntry[]; haveMore: boolean }>({
        lastPageOffset: 0,
        data: [],
        haveMore: true,
    });
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);

    useEffect(() => {
        loadctx.setLoading("auditfetch", "Loading user data...");
        apiGet<AuditRes>("/api/audit/page/0", "get audit log").then((auditRes) => {
            loadctx.removeLoading("auditfetch");
            if (auditRes) setAuditLog({ lastPageOffset: 0, data: auditRes.entries, haveMore: auditRes.haveMore });
        });
    }, []);

    const loadMore = () => {
        const nextPage = auditLogData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadctx.setLoading("auditfetch", "Loading user data...");
        apiGet<AuditRes>("/api/audit/page/" + nextPage, "get audit log").then((auditRes) => {
            if (loadBtnRef.current) loadBtnRef.current.disabled = false;
            loadctx.removeLoading("auditfetch");
            if (auditRes)
                setAuditLog({
                    lastPageOffset: auditRes.pageOffset,
                    data: auditRes.entries.concat(auditLogData.data),
                    haveMore: auditRes.haveMore,
                });
        });
    };

    const columDefs: ColumnDef<AuditEntry>[] = [
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

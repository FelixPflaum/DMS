import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { PointHistoryEntry, PointHistoryPageRes } from "@/shared/types";

const PointHistoryPage = (): JSX.Element => {
    const [historyData, setHistoryData] = useState<{
        lastPageOffset: number;
        data: PointHistoryEntry[];
        haveMore: boolean;
    }>({
        lastPageOffset: 0,
        data: [],
        haveMore: true,
    });
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);

    useEffect(() => {
        loadctx.setLoading("fetchPointHistory", "Loading history...");
        apiGet<PointHistoryPageRes>("/api/pointhistory/page/0", "get point history page").then((pageRes) => {
            loadctx.removeLoading("fetchPointHistory");
            if (pageRes)
                setHistoryData({
                    lastPageOffset: pageRes.pageOffset,
                    data: pageRes.entries.concat(historyData.data),
                    haveMore: pageRes.haveMore,
                });
        });
    }, []);

    const loadMore = () => {
        const nextPage = historyData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadctx.setLoading("fetchPointHistory", "Loading history...");
        apiGet<PointHistoryPageRes>("/api/pointhistory/page/" + nextPage, "get additional point history page").then(
            (pageRes) => {
                if (loadBtnRef.current) loadBtnRef.current.disabled = false;
                loadctx.removeLoading("fetchPointHistory");
                if (pageRes)
                    setHistoryData({
                        lastPageOffset: pageRes.pageOffset,
                        data: pageRes.entries.concat(historyData.data),
                        haveMore: pageRes.haveMore,
                    });
            }
        );
    };

    const columDefs: ColumnDef<PointHistoryEntry>[] = [
        {
            name: "Time",
            dataKey: "timestamp",
            defaultSort: "desc",
            canSort: true,
            render: (rd) => {
                const dt = new Date(rd.timestamp);
                return dt.toLocaleString();
            },
        },
        {
            name: "Player",
            dataKey: "playerName",
            canSort: true,
            defaultSort: "asc",
        },
        { name: "Change", dataKey: "pointChange" },
        { name: "New Sanity", dataKey: "newPoints" },
        { name: "Change Type", dataKey: "changeType" },
        { name: "Reason", dataKey: "reason" },
    ];

    return (
        <>
            <h1 className="pageHeading">Sanity History</h1>
            <Tablel columnDefs={columDefs} data={historyData.data} sortCol="timestamp" sortDir="desc"></Tablel>
            {historyData.haveMore ? (
                <button className="button" onClick={loadMore} ref={loadBtnRef}>
                    Load more
                </button>
            ) : null}
        </>
    );
};

export default PointHistoryPage;

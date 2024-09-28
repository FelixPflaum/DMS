import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { ApiPointHistoryEntry, ApiPointHistoryPageRes } from "@/shared/types";
import { useToaster } from "../components/toaster/Toaster";
import styles from "../styles/pagePointHist.module.css";

const PointHistoryPage = (): JSX.Element => {
    const toaster = useToaster();
    const [historyData, setHistoryData] = useState<{
        lastPageOffset: number;
        data: ApiPointHistoryEntry[];
        haveMore: boolean;
    }>({
        lastPageOffset: -1,
        data: [],
        haveMore: true,
    });
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);

    const loadMore = () => {
        const nextPage = historyData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadctx.setLoading("fetchPointHistory", "Loading history...");
        apiGet<ApiPointHistoryPageRes>("/api/pointhistory/page/" + nextPage).then((pageRes) => {
            if (loadBtnRef.current) loadBtnRef.current.disabled = false;
            loadctx.removeLoading("fetchPointHistory");
            if (pageRes.error) return toaster.addToast("Failed Loading More", pageRes.error, "error");
            setHistoryData({
                lastPageOffset: pageRes.pageOffset,
                data: pageRes.entries.concat(historyData.data),
                haveMore: pageRes.haveMore,
            });
        });
    };

    useEffect(() => {
        loadMore();
    }, []);

    const columDefs: ColumnDef<ApiPointHistoryEntry>[] = [
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
        {
            name: "Change",
            dataKey: "pointChange",
            render: (rd) => (
                <span className={rd.pointChange > 0 ? styles.changePositive : styles.changeNegative}>
                    {rd.pointChange > 0 ? "+" + rd.pointChange : rd.pointChange}
                </span>
            ),
        },
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

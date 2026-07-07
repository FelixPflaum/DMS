import { useEffect, useRef, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { apiGet } from "../serverApi";
import type { ApiLootHistoryEntry, ApiLootHistoryPageRes, ApiLootHistorySearchRes } from "@/shared/types";
import LootResponse from "../components/LootResponse";
import { isItemDataLoaded, loadItemData } from "../data/itemStorage";
import ItemIconLink from "../components/item/ItemIconLink";
import { useToaster } from "../components/toaster/Toaster";
import TextInput from "../components/form/TextInput";

const LootHistoryPage = (): JSX.Element => {
    const toaster = useToaster();
    const [historyData, setHistoryData] = useState<{
        lastPageOffset: number;
        data: ApiLootHistoryEntry[];
        haveMore: boolean;
        isSearch?: boolean;
    }>({
        lastPageOffset: 0,
        data: [],
        haveMore: true,
    });
    const loadctx = useLoadOverlayCtx();
    const loadBtnRef = useRef<HTMLButtonElement>(null);
    const [searchTerm, setSearchTerm] = useState<string>("text");

    const loadPage = async (page: number): Promise<void> => {
        loadctx.setLoading("fetchLootHistory", "Loading history...");
        apiGet<ApiLootHistoryPageRes>("/api/loothistory/page/" + page).then((pageRes) => {
            loadctx.removeLoading("fetchLootHistory");
            if (pageRes.error) return toaster.addToast("Failed To Load More", pageRes.error, "error");
            setHistoryData({
                lastPageOffset: pageRes.pageOffset,
                data: pageRes.entries.concat(historyData.data),
                haveMore: pageRes.haveMore,
            });
        });
    };

    useEffect(() => {
        if (!isItemDataLoaded()) {
            loadctx.setLoading("loadItemData", "Loading item data...");
            loadItemData().then(() => {
                loadctx.removeLoading("loadItemData");
                loadPage(0);
            });
        } else {
            loadPage(0);
        }
    }, []);

    // TODO: Don't use page wide load thing. Only search on enter?
    useEffect(() => {
        if (!isItemDataLoaded()) return;

        if (!searchTerm) {
            loadPage(0);
            return;
        }

        const searchTimer = setTimeout(() => {
            loadctx.setLoading("searchEntries", "Searching...");
            apiGet<ApiLootHistorySearchRes>(`/api/loothistory/searchitem/${searchTerm}`).then((res) => {
                loadctx.removeLoading("searchEntries");
                if (res.error) {
                    alert(`Failed to get search results: ${res.error}`);
                    return;
                }
                setHistoryData({
                    lastPageOffset: 0,
                    data: res.results,
                    haveMore: false,
                    isSearch: true,
                });
            });
        }, 500);

        return () => clearTimeout(searchTimer);
    }, [searchTerm]);

    const loadMore = () => {
        const nextPage = historyData.lastPageOffset + 1;
        if (!loadBtnRef.current) return;
        loadBtnRef.current.disabled = true;
        loadPage(nextPage).then(() => {
            if (loadBtnRef.current) loadBtnRef.current.disabled = false;
        });
    };

    const columDefs: ColumnDef<ApiLootHistoryEntry>[] = [
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
        //{ name: "GUID", dataKey: "guid" },
        {
            name: "Player",
            dataKey: "playerName",
            canSort: true,
            defaultSort: "asc",
        },
        {
            name: "Item",
            dataKey: "itemId",
            render: (rd) => <ItemIconLink itemId={rd.itemId}></ItemIconLink>,
        },
        { name: "Response", dataKey: "response", render: (rd) => <LootResponse dataText={rd.response}></LootResponse> },
        { name: "GUID", dataKey: "guid" },
    ];

    return (
        <>
            <h1 className="pageHeading">Loot History</h1>
            <div>
                <TextInput label={"Search For Item"} onChange={(_, val) => setSearchTerm(val)} value={searchTerm} />
            </div>
            <Tablel columnDefs={columDefs} data={historyData.data} sortCol="timestamp" sortDir="desc"></Tablel>
            {historyData.isSearch && historyData.data.length === 0 ? <>No results!</> : null}
            {historyData.haveMore ? (
                <button className="button" onClick={loadMore} ref={loadBtnRef}>
                    Load more
                </button>
            ) : null}
        </>
    );
};

export default LootHistoryPage;

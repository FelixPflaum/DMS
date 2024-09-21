import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ActionDef, ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/enums";
import { classData } from "../../shared/wow";
import type { DeleteRes, PlayerEntry } from "@/shared/types";

const PlayersPage = (): JSX.Element => {
    const [players, setPlayers] = useState<PlayerEntry[]>([]);
    const loadctx = useLoadOverlayCtx();
    const authctx = useAuthContext();
    const canManage = authctx.user && !!(authctx.user.permissions & AccPermissions.DATA_MANAGE);
    //const canDelete = authctx.user && !!(authctx.user.permissions & AccPermissions.DATA_DELETE);

    useEffect(() => {
        loadctx.setLoading("fetchPlayers", "Loading player list...");
        apiGet<PlayerEntry[]>("/api/players/list", "get player list").then((playersRes) => {
            loadctx.removeLoading("fetchPlayers");
            if (playersRes) setPlayers(playersRes);
        });
    }, []);

    const navigate = useNavigate();
    const editUser = (playerEntry: PlayerEntry) => {
        navigate("/player-add-edit?name=" + playerEntry.playerName);
    };

    const deleteUser = async (playerEntry: PlayerEntry) => {
        const confirmWord = "UwU";
        const promptResult = prompt(
            `Really delete player ${playerEntry.playerName}?\nThe complete sanity and loot history of the player will be deleted!\nEnter ${confirmWord} to confirm.`
        );
        if (!promptResult || promptResult != confirmWord) return;

        const res = await apiGet<DeleteRes>("/api/players/delete/" + playerEntry.playerName, "delete player");
        if (!res || !res.success) {
            if (res?.error) alert(res.error);
            return;
        }
        const delIdx = players.findIndex((x) => x.playerName == playerEntry.playerName);
        if (delIdx !== -1) {
            const newPlayers = [...players];
            newPlayers.splice(delIdx, 1);
            setPlayers(newPlayers);
        }
    };

    const columDefs: ColumnDef<PlayerEntry>[] = [
        {
            name: "Player",
            dataKey: "playerName",
            canSort: true,
            render: (v) => {
                return <span className={`classId${v.classId}`}>{v.playerName}</span>;
            },
        },
        {
            name: "Class",
            dataKey: "classId",
            canSort: true,
            defaultSort: "asc",
            render: (v) => <span className={`classId${v.classId}`}>{classData[v.classId].name}</span>,
        },
        { name: "Sanity", dataKey: "points", canSort: true, defaultSort: "desc" },
        { name: "Account", dataKey: "account" },
    ];

    const actions: ActionDef<PlayerEntry>[] = [
        { name: "Edit", onClick: editUser },
        { name: "Delete", style: "red", onClick: deleteUser },
    ];

    return (
        <>
            <h1 className="pageHeading">Players</h1>
            {canManage ? (
                <button className="button" onClick={() => navigate("/player-add-edit")}>
                    Add New
                </button>
            ) : null}
            <Tablel
                columnDefs={columDefs}
                data={players}
                sortCol="playerName"
                sortDir="asc"
                actions={canManage ? actions : undefined}
            ></Tablel>
        </>
    );
};

export default PlayersPage;

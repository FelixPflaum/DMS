import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ActionDef, ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/permissions";
import { classData } from "../../shared/wow";
import type { ApiPlayerEntry, ApiPlayerListRes } from "@/shared/types";
import styles from "../styles/pagePlayers.module.css";

const PlayersPage = (): JSX.Element => {
    const [players, setPlayers] = useState<ApiPlayerEntry[]>([]);
    const loadctx = useLoadOverlayCtx();
    const authctx = useAuthContext();
    const canManage = authctx.hasPermission(AccPermissions.DATA_MANAGE);
    const canDelete = authctx.hasPermission(AccPermissions.DATA_DELETE);

    useEffect(() => {
        loadctx.setLoading("fetchPlayers", "Loading player list...");
        apiGet<ApiPlayerListRes>("/api/players/list").then((playersRes) => {
            loadctx.removeLoading("fetchPlayers");
            if (playersRes.error) alert("Failed to get player list: " + playersRes.error);
            setPlayers(playersRes.list);
        });
    }, []);

    const navigate = useNavigate();
    const editPlayer = (playerEntry: ApiPlayerEntry) => {
        navigate("/player-add-edit?name=" + playerEntry.playerName);
    };
    const viewPlayer = (playerEntry: ApiPlayerEntry) => {
        navigate("/profile?name=" + playerEntry.playerName);
    };

    const deletePlayer = async (playerEntry: ApiPlayerEntry) => {
        const confirmWord = "UwU";
        const promptResult = prompt(
            `Really delete player ${playerEntry.playerName}?\nThe complete sanity and loot history of the player will be deleted!\nEnter ${confirmWord} to confirm.`
        );
        if (!promptResult || promptResult != confirmWord) return;

        const res = await apiGet("/api/players/delete/" + playerEntry.playerName);
        if (res.error) {
            return alert("Failed to delete player: " + res.error);
        }
        const delIdx = players.findIndex((x) => x.playerName == playerEntry.playerName);
        if (delIdx !== -1) {
            const newPlayers = [...players];
            newPlayers.splice(delIdx, 1);
            setPlayers(newPlayers);
        }
    };

    const claimPlayer = async (playerEntry: ApiPlayerEntry) => {
        const promptResult = confirm(`Really claim ${playerEntry.playerName}?`);
        if (!promptResult) return;

        const res = await apiGet("/api/players/claim/" + playerEntry.playerName);
        if (res.error) {
            return alert("Could not claim player: " + res.error);
        }
        alert(playerEntry.playerName + " claimed. Reload page to see effects.");
    };

    const columDefs: ColumnDef<ApiPlayerEntry>[] = [
        {
            name: "Class",
            dataKey: "classId",
            canSort: true,
            defaultSort: "asc",
            render: (v) => {
                const cd = classData[v.classId].name;
                return (
                    <>
                        <img
                            className={styles.playerTableClassIcon}
                            src={`/img/classicons/class_${cd.toLowerCase()}.jpg`}
                            alt={cd}
                            title={cd}
                        ></img>
                        {/* <span className={`classId${v.classId}`}>{classData[v.classId].name}</span> */}
                    </>
                );
            },
        },
        {
            name: "Player",
            dataKey: "playerName",
            canSort: true,
            render: (v) => {
                return <span className={`classId${v.classId}`}>{v.playerName}</span>;
            },
        },
        { name: "Sanity", dataKey: "points", canSort: true, defaultSort: "desc" },
        { name: "Account", dataKey: "account" },
    ];

    const actions: ActionDef<ApiPlayerEntry>[] = [
        { name: "View", onClick: viewPlayer },
        { name: "Claim", onClick: claimPlayer, shouldShow: (rd) => !rd.account },
    ];
    if (canManage) actions.push({ name: "Edit", onClick: editPlayer });
    if (canDelete) actions.push({ name: "Delete", style: "red", onClick: deletePlayer });

    return (
        <>
            <h1 className="pageHeading">Players</h1>
            {canManage ? (
                <button className="button" onClick={() => navigate("/player-add-edit")}>
                    Add New
                </button>
            ) : null}
            <Tablel columnDefs={columDefs} data={players} sortCol="playerName" sortDir="asc" actions={actions}></Tablel>
        </>
    );
};

export default PlayersPage;

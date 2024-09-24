import type { FormEventHandler } from "react";
import { useEffect, useRef, useState } from "react";
import TextInput from "../components/form/TextInput";
import NumberInput from "../components/form/NumberInput";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { PlayerEntry, UpdateRes } from "@/shared/types";
import PointChangeForm from "../components/PointChangeForm";
import StaticFormRow from "../components/form/StaticFormRow";

const PlayerAddEditPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const [searchParams, _setSearchParams] = useSearchParams();
    const [player, setPlayer] = useState<PlayerEntry | undefined>();
    const navigate = useNavigate();

    const nameParam = searchParams.get("name");
    const isEdit = !!nameParam;

    const nameInputRef = useRef<HTMLInputElement>(null);
    const classInputRef = useRef<HTMLInputElement>(null);
    const pointInputRef = useRef<HTMLInputElement>(null);
    const accountInputRef = useRef<HTMLInputElement>(null);
    const submitBtnRef = useRef<HTMLButtonElement>(null);

    useEffect(() => {
        if (!nameParam) return;
        loadctx.setLoading("fetchplayer", "Loading player data...");
        apiGet<PlayerEntry>("/api/players/player/" + nameParam, "get player data").then((res) => {
            loadctx.removeLoading("fetchplayer");
            if (!res) {
                alert("Player doesn't exist.");
                navigate("/players");
                return;
            }
            setPlayer(res);
            if (nameInputRef.current) nameInputRef.current.value = res.playerName;
            if (classInputRef.current) classInputRef.current.value = res.classId.toString();
            if (pointInputRef.current) pointInputRef.current.value = res.points.toString();
            if (accountInputRef.current) accountInputRef.current.value = res.account ?? "";
        });
    }, []);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();

        const nameValue = nameInputRef.current?.value;
        const classValue = parseInt(classInputRef.current?.value ?? "x");
        const pointValue = parseInt(pointInputRef.current?.value ?? "x");
        const accValue = accountInputRef.current?.value;
        if (typeof classValue !== "number" || typeof pointValue !== "number" || !nameValue) return;

        const body: PlayerEntry = {
            playerName: nameValue,
            classId: classValue,
            points: pointValue,
            account: accValue,
        };

        if (!submitBtnRef.current) return;
        if (submitBtnRef.current) submitBtnRef.current.disabled = true;

        if (isEdit) {
            apiPost<UpdateRes>("/api/players/update/" + nameValue, "update player", body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
                if (updateRes) {
                    if (updateRes.success) {
                        alert("player updated.");
                    } else {
                        alert("Failed to update player: " + updateRes.error);
                    }
                }
            });
        } else {
            apiPost<UpdateRes>("/api/players/create/", "create player", body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
                if (updateRes) {
                    if (updateRes.success) {
                        alert("Player created.");
                    } else {
                        alert("Failed to create player: " + updateRes.error);
                    }
                }
            });
        }
        return false;
    };

    const onPointChange = (change: number, newPoints: number) => {
        if (!player) return;
        const newPlayer = { ...player };
        newPlayer.points = newPoints;
        setPlayer(newPlayer);
    };

    return (
        <>
            <h1 className="pageHeading">{isEdit ? "Edit" : "Add"} Player</h1>
            <form onSubmit={onSubmit}>
                <TextInput label="Name" inputRef={nameInputRef} required={true} minLen={2}></TextInput>
                <NumberInput label="Class" inputRef={classInputRef} required={true}></NumberInput>
                <TextInput label="Account" inputRef={accountInputRef} minLen={17}></TextInput>
                <StaticFormRow label="Sanity" value={player?.points.toString() ?? "0"}></StaticFormRow>
                <div>
                    <button className="button" ref={submitBtnRef}>
                        Save
                    </button>
                </div>
            </form>
            {isEdit ? (
                <div>
                    <h2>Actions</h2>
                    <h3>Change Sanity</h3>
                    <PointChangeForm playerName={player?.playerName} onChange={onPointChange}></PointChangeForm>
                </div>
            ) : (
                <></>
            )}
        </>
    );
};

export default PlayerAddEditPage;

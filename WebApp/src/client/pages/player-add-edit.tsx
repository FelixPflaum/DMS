import type { FormEventHandler } from "react";
import { useEffect, useRef, useState } from "react";
import TextInput from "../components/form/TextInput";
import NumberInput from "../components/form/NumberInput";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { ApiPlayerEntry, ApiPlayerRes } from "@/shared/types";
import PointChangeForm from "../components/PointChangeForm";
import StaticFormRow from "../components/form/StaticFormRow";
import { useToaster } from "../components/toaster/Toaster";

const PlayerAddEditPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const toaster = useToaster();
    const [searchParams, _setSearchParams] = useSearchParams();
    const [player, setPlayer] = useState<ApiPlayerEntry | undefined>();
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
        apiGet<ApiPlayerRes>("/api/players/player/" + nameParam).then((res) => {
            loadctx.removeLoading("fetchplayer");
            if (res.error) {
                toaster.addToast("Loading Player Failed", res.error, "error");
                navigate("/players");
                return;
            }
            setPlayer(res.player);
            if (nameInputRef.current) nameInputRef.current.value = res.player.playerName;
            if (classInputRef.current) classInputRef.current.value = res.player.classId.toString();
            if (pointInputRef.current) pointInputRef.current.value = res.player.points.toString();
            if (accountInputRef.current) accountInputRef.current.value = res.player.account ?? "";
        });
    }, []);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();

        const nameValue = nameInputRef.current?.value;
        const classValue = parseInt(classInputRef.current?.value ?? "x");
        const pointValue = parseInt(pointInputRef.current?.value ?? "x");
        const accValue = accountInputRef.current?.value;
        if (typeof classValue !== "number" || typeof pointValue !== "number" || !nameValue) return;

        const body: ApiPlayerEntry = {
            playerName: nameValue,
            classId: classValue,
            points: pointValue,
            account: accValue,
        };

        if (!submitBtnRef.current) return;
        if (submitBtnRef.current) submitBtnRef.current.disabled = true;

        if (isEdit) {
            apiPost("/api/players/update/" + nameValue, body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
                if (updateRes.error) {
                    toaster.addToast("Updating Player Failed", updateRes.error, "error");
                } else {
                    toaster.addToast("Updated Player", `Player ${body.playerName} was updated.`, "success");
                }
            });
        } else {
            apiPost("/api/players/create/", body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
                if (updateRes.error) {
                    toaster.addToast("Creating Player Failed", updateRes.error, "error");
                } else {
                    toaster.addToast("Created Player", `Player ${body.playerName} was created.`, "success");
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

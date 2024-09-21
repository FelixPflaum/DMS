import type { FormEventHandler } from "react";
import { useEffect, useRef } from "react";
import TextInput from "../components/form/TextInput";
import NumberInput from "../components/form/NumberInput";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { UpdateRes, UserEntry, UserRes } from "@/shared/types";

const UserAddEditPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const [searchParams, _setSearchParams] = useSearchParams();
    const navigate = useNavigate();

    const idParam = searchParams.get("id");
    const isEdit = !!idParam;

    const idInputRef = useRef<HTMLInputElement>(null);
    const nameInputRef = useRef<HTMLInputElement>(null);
    const permInputRef = useRef<HTMLInputElement>(null);
    const submitBtnRef = useRef<HTMLButtonElement>(null);

    useEffect(() => {
        if (isEdit) {
            idInputRef.current!.disabled = true;
        } else {
            return;
        }

        loadctx.setLoading("fetchuser", "Loading user data...");
        apiGet<UserRes>("/api/users/user/" + idParam, "get user data").then((userRes) => {
            loadctx.removeLoading("fetchuser");
            if (!userRes || userRes.length === 0) {
                alert("User doesn't exist.");
                navigate("/users");
                return;
            }
            idInputRef.current!.value = userRes[0].loginId;
            nameInputRef.current!.value = userRes[0].userName;
            permInputRef.current!.value = userRes[0].permissions.toString();
        });
    }, []);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();

        const idValue = idInputRef.current?.value;
        const nameValue = nameInputRef.current?.value;
        const permValue = parseInt(permInputRef.current?.value ?? "x");
        if (typeof permValue !== "number" || !idValue || !nameValue) return;

        const body: UserEntry = {
            loginId: idValue,
            userName: nameValue,
            permissions: permValue,
        };

        submitBtnRef.current!.disabled = true;
        if (isEdit) {
            apiPost<UpdateRes>("/api/users/update/" + idValue, "update user", body).then((updateRes) => {
                submitBtnRef.current!.disabled = false;
                if (updateRes) {
                    if (updateRes.success) {
                        alert("User updated.");
                    } else {
                        alert("Failed to update user: " + updateRes.error);
                    }
                }
            });
        } else {
            apiPost<UpdateRes>("/api/users/create/", "create user", body).then((updateRes) => {
                submitBtnRef.current!.disabled = false;
                if (updateRes) {
                    if (updateRes.success) {
                        alert("User created.");
                    } else {
                        alert("Failed to create user: " + updateRes.error);
                    }
                }
            });
        }
        return false;
    };

    return (
        <>
            <h1 className="pageHeading">{isEdit ? "Edit" : "Add"} User</h1>
            <form onSubmit={onSubmit}>
                <TextInput label="Discord ID" inputRef={idInputRef} required={true} minLen={17}></TextInput>
                <TextInput label="Name" inputRef={nameInputRef} required={true} minLen={4}></TextInput>
                <NumberInput label="Permissions" inputRef={permInputRef} required={true}></NumberInput>
                <div>
                    <button className="button" ref={submitBtnRef}>
                        Save
                    </button>
                </div>
            </form>
        </>
    );
};

export default UserAddEditPage;

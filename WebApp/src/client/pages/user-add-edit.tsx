import type { FormEventHandler } from "react";
import { useEffect, useRef, useState } from "react";
import TextInput from "../components/form/TextInput";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { UpdateRes, UserEntry, UserRes } from "@/shared/types";
import PermissionInput from "../components/form/PermissionInput";
import { AccPermissions } from "@/shared/permissions";

const UserAddEditPage = (): JSX.Element => {
    const loadctx = useLoadOverlayCtx();
    const [searchParams, _setSearchParams] = useSearchParams();
    const [permissions, setPermissions] = useState<AccPermissions>(AccPermissions.NONE);
    const navigate = useNavigate();

    const idParam = searchParams.get("id");
    const isEdit = !!idParam;

    const idInputRef = useRef<HTMLInputElement>(null);
    const nameInputRef = useRef<HTMLInputElement>(null);
    const submitBtnRef = useRef<HTMLButtonElement>(null);

    const onPermChange = (perms: AccPermissions) => {
        setPermissions(perms);
    };

    useEffect(() => {
        if (isEdit) {
            if (idInputRef.current) idInputRef.current.disabled = true;
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
            if (idInputRef.current) idInputRef.current.value = userRes[0].loginId;
            if (nameInputRef.current) nameInputRef.current.value = userRes[0].userName;
            setPermissions(userRes[0].permissions);
        });
    }, []);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();

        const idValue = idInputRef.current?.value;
        const nameValue = nameInputRef.current?.value;
        if (!idValue || !nameValue) return;

        const body: UserEntry = {
            loginId: idValue,
            userName: nameValue,
            permissions: permissions,
        };

        if (!submitBtnRef.current) return;
        submitBtnRef.current.disabled = true;

        if (isEdit) {
            apiPost<UpdateRes>("/api/users/update/" + idValue, "update user", body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
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
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
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
                <PermissionInput label="Permissions" perms={permissions} onChange={onPermChange}></PermissionInput>
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

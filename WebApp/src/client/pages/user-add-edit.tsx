import type { FormEventHandler } from "react";
import { useEffect, useRef, useState } from "react";
import TextInput from "../components/form/TextInput";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import { apiGet, apiPost } from "../serverApi";
import type { ApiUserEntry, ApiUserRes } from "@/shared/types";
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

    const onPermChange = (_key: string, perms: AccPermissions) => {
        setPermissions(perms);
    };

    useEffect(() => {
        if (isEdit) {
            if (idInputRef.current) idInputRef.current.disabled = true;
        } else {
            return;
        }

        loadctx.setLoading("fetchuser", "Loading user data...");
        apiGet<ApiUserRes>("/api/users/user/" + idParam).then((userRes) => {
            loadctx.removeLoading("fetchuser");
            if (userRes.error) {
                alert("Failed to get user data: " + userRes.error);
                navigate("/users");
                return;
            }
            if (idInputRef.current) idInputRef.current.value = userRes.user.loginId;
            if (nameInputRef.current) nameInputRef.current.value = userRes.user.userName;
            setPermissions(userRes.user.permissions);
        });
    }, []);

    const onSubmit: FormEventHandler<HTMLFormElement> = (event) => {
        event.preventDefault();

        const idValue = idInputRef.current?.value;
        const nameValue = nameInputRef.current?.value;
        if (!idValue || !nameValue) return;

        const body: ApiUserEntry = {
            loginId: idValue,
            userName: nameValue,
            permissions: permissions,
            lastActivity: 0,
        };

        if (!submitBtnRef.current) return;
        submitBtnRef.current.disabled = true;

        if (isEdit) {
            apiPost("/api/users/update/" + idValue, body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
                if (updateRes.error) {
                    alert("Failed to update user: " + updateRes.error);
                } else {
                    alert("User updated.");
                }
            });
        } else {
            apiPost("/api/users/create/", body).then((updateRes) => {
                if (submitBtnRef.current) submitBtnRef.current.disabled = false;
                if (updateRes.error) {
                    alert("Failed to create user: " + updateRes.error);
                } else {
                    alert("User created.");
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

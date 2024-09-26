import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import type { ActionDef, ColumnDef } from "../components/table/Tablel";
import Tablel from "../components/table/Tablel";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions, getPermissionStrings } from "@/shared/permissions";
import type { ApiUserEntry, ApiUserListRes } from "@/shared/types";

const UsersPage = (): JSX.Element => {
    const [users, setUsers] = useState<ApiUserEntry[]>([]);
    const loadctx = useLoadOverlayCtx();
    const authctx = useAuthContext();
    const canManage = authctx.hasPermission(AccPermissions.USERS_MANAGE);

    useEffect(() => {
        loadctx.setLoading("fetchusers", "Loading user data...");
        apiGet<ApiUserListRes>("/api/users/list").then((res) => {
            loadctx.removeLoading("fetchusers");
            if (res.error) return alert("Failed to load user list: " + res.error);
            setUsers(res.list);
        });
    }, []);

    const navigate = useNavigate();
    const editUser = (userEntry: ApiUserEntry) => {
        navigate("/user-add-edit?id=" + userEntry.loginId);
    };

    const deleteUser = async (userEntry: ApiUserEntry) => {
        if (!confirm(`Really delete user ${userEntry.userName}?`)) return;
        const res = await apiGet("/api/users/delete/" + userEntry.loginId);
        if (res.error) {
            alert("Failed to delete user: " + res.error);
            return;
        }
        const delIdx = users.findIndex((x) => x.loginId == userEntry.loginId);
        if (delIdx !== -1) {
            const newUsers = [...users];
            newUsers.splice(delIdx, 1);
            setUsers(newUsers);
        }
    };

    const columDefs: ColumnDef<ApiUserEntry>[] = [
        { name: "Name", dataKey: "userName", canSort: true },
        { name: "Discord ID", dataKey: "loginId" },
        {
            name: "Permissions",
            dataKey: "permissions",
            render: (rd) => getPermissionStrings(rd.permissions).join(", "),
        },
        {
            name: "Last Active",
            dataKey: "lastActivity",
            render: (rd) => {
                const dt = new Date(rd.lastActivity);
                return dt.toLocaleString();
            },
        },
    ];

    const actions: ActionDef<ApiUserEntry>[] = [
        { name: "Edit", onClick: editUser },
        { name: "Delete", style: "red", onClick: deleteUser },
    ];

    return (
        <>
            <h1 className="pageHeading">Users</h1>
            {canManage ? (
                <button className="button" onClick={() => navigate("/user-add-edit")}>
                    Add New
                </button>
            ) : null}
            <Tablel
                columnDefs={columDefs}
                data={users}
                sortCol="userName"
                sortDir="asc"
                actions={canManage ? actions : undefined}
            ></Tablel>
        </>
    );
};

export default UsersPage;

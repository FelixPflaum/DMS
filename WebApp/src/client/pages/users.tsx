import { useEffect, useState } from "react";
import { useLoadOverlayCtx } from "../LoadOverlayProvider";
import Tablel, { ActionDef, ColumnDef } from "../components/table/Tablel";
import { useNavigate } from "react-router";
import { apiGet } from "../serverApi";
import { useAuthContext } from "../AuthProvider";
import { AccPermissions } from "@/shared/enums";

const UsersPage = (): JSX.Element => {
    const [users, setUsers] = useState<UserEntry[]>([]);
    const loadctx = useLoadOverlayCtx();
    const authctx = useAuthContext();
    const canManage = authctx.user && !!(authctx.user.permissions & AccPermissions.USERS_MANAGE);

    useEffect(() => {
        loadctx.setLoading("fetchusers", "Loading user data...");
        apiGet<UserRes>("/api/users/list", "get user list").then((userRes) => {
            loadctx.removeLoading("fetchusers");
            if (userRes) setUsers(userRes);
        });
    }, []);

    const navigate = useNavigate();
    const editUser = (userEntry: UserEntry) => {
        navigate("/user-add-edit?id=" + userEntry.loginId);
    };

    const deleteUser = async (userEntry: UserEntry) => {
        if (!confirm(`Really delete user ${userEntry.userName}?`)) return;

        const res = await fetch("/api/users/delete/" + userEntry.loginId);
        if (res.status !== 200) {
            try {
                const errRes: ErrorRes = await res.json();
                alert("User deletiong failed: " + errRes.error);
            } catch (error) {
                alert("User deletiong failed, status: " + res.status.toString());
            }
            return;
        }

        const delIdx = users.findIndex((x) => x.loginId == userEntry.loginId);
        if (delIdx !== -1) {
            const newUsers = [...users];
            newUsers.splice(delIdx, 1);
            setUsers(newUsers);
        }
    };

    const columDefs: ColumnDef<UserEntry>[] = [
        { name: "Name", dataKey: "userName", canSort: true },
        { name: "Discord ID", dataKey: "loginId" },
        { name: "Permissions", dataKey: "permissions" },
    ];

    const actions: ActionDef<UserEntry>[] = [
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

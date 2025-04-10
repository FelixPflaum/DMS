import type { ChatInputCommandInteraction, CacheType, GuildMember } from "discord.js";
import { BotCommandBase } from "./BotCommandBase";
import { getConfig } from "../config";
import { AccPermissions } from "@/shared/permissions";
import { addUser } from "../database/tableFunctions/users";
import { addSystemAuditEntry } from "../database/tableFunctions/audit";
import { getDynamicSetting } from "../configDynamic";

export class RegisterCommand extends BotCommandBase {
    constructor() {
        super("register", "Register your discord account with the website.");
    }

    async execute(interaction: ChatInputCommandInteraction<CacheType>): Promise<void> {
        const guildId = interaction.guildId;

        try {
            await interaction.deferReply({ ephemeral: true });
        } catch (error) {
            this.logger.logError("Interaction defer failed.", error);
            this.replyError(interaction, "Could not set up interaction.");
            return;
        }

        if (!guildId) {
            await this.replyError(interaction, "Not in a guild!");
            return;
        }

        const member = interaction.member as GuildMember | undefined;

        if (!member) {
            this.replyError(interaction, "Can't get guild member data.");
            return;
        }

        const id = interaction.user.id;
        const isAdminId = id == getConfig().adminLoginId;

        if (!isAdminId) {
            const roleSettingRes = await getDynamicSetting("discordAllowedRoles");
            if (roleSettingRes.dbError || !roleSettingRes.value) return;
            const allwoedRoles = roleSettingRes.value;
            const hasValidRole = member.roles.cache.some((role) => {
                for (const allowed of allwoedRoles) {
                    if (allowed == role.name) return true;
                }
                return false;
            });

            if (!hasValidRole) {
                this.replyError(interaction, "You have no valid role.");
                return;
            }
        }

        const name =
            (interaction.member as GuildMember | undefined)?.displayName ??
            interaction.user.displayName ??
            interaction.user.username;
        let perms = AccPermissions.NONE;

        if (isAdminId) {
            this.logger.log(`Admin account registration: ${id} - ${name}`);
            perms = AccPermissions.ADMIN;
        } else {
            const permSettingRes = await getDynamicSetting("defaultPerms");
            if (permSettingRes.dbError) {
                this.replyError(interaction, "Database error.");
                return;
            }
            if (permSettingRes.value) perms = permSettingRes.value;
        }

        const insertRes = await addUser(id, name, perms);
        if (insertRes.isError) {
            this.replyError(interaction, "Registration failed due to a DB error.");
        } else if (insertRes.duplicate) {
            this.replyError(interaction, "Registration failed. Account seems to exist already.");
            return;
        }
        await addSystemAuditEntry("Self registration via bot", `Id: ${id}, Name: ${name}, Permissions: ${perms}`);
        this.replySuccess(interaction, "Registered successfully.");
    }
}

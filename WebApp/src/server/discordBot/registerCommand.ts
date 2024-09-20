import { ChatInputCommandInteraction, CacheType, GuildMember } from "discord.js";
import { BotCommandBase } from "./commandBase";
import { getConfig } from "../config";
import { auditDb, authDb } from "../database/database";
import { AccPermissions } from "@/shared/enums";

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

        const hasValidRole = member.roles.cache.some((role) => {
            const allwoedRoles = getConfig().discordAllowedRoles;
            for (const allowed of allwoedRoles) {
                if (allowed == role.name) return true;
            }
            return false;
        });

        if (!hasValidRole) {
            this.replyError(interaction, "You have no valid role.");
            return;
        }

        const id = interaction.user.id;
        const name =
            (interaction.member as GuildMember | undefined)?.displayName ??
            interaction.user.displayName ??
            interaction.user.username;

        try {
            const isAdminId = id == getConfig().adminLoginId;
            if (isAdminId) this.logger.log(`Admin account registration: ${id} - ${name}`);
            const perms = id == getConfig().adminLoginId ? AccPermissions.ALL : AccPermissions.NONE;
            const success = await authDb.createEntry(id, name, perms);
            if (!success) {
                this.replyError(interaction, "Registration failed. Account seems to exist already.");
                return;
            }
            await auditDb.addEntry("-", "-", `Self registration via bot: ${id} - ${name}, Permissions: ${perms}`);
            this.replySuccess(interaction, "Registered successfully.");
        } catch (error) {
            this.logger.logError("DB error.", error);
            this.replyError(interaction, "Registration failed due to a DB error.");
        }
    }
}

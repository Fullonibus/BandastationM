/// Central owns token persistence and the round-local requests, including across reconnects.
/datum/controller/subsystem/central
	/// Whitelisted role IDs and their existing roundstart rulesets.
	var/static/list/antag_token_roles = list(
		"traitor" = /datum/dynamic_ruleset/roundstart/traitor,
		"brother" = /datum/dynamic_ruleset/roundstart/blood_brother,
		"changeling" = /datum/dynamic_ruleset/roundstart/changeling,
		"blood_worm" = /datum/dynamic_ruleset/roundstart/blood_worm,
		"heretic" = /datum/dynamic_ruleset/roundstart/heretic,
		"vampire" = /datum/dynamic_ruleset/roundstart/vampire,
	)
	/// Ckey -> selected role ID. This is never saved to player preferences.
	var/list/antag_token_requests = list()
	/// Ckey -> last SQL snapshot, used only for display, never for debiting.
	var/list/antag_token_balances = list()
	/// Ckeys with a display refresh in flight.
	var/list/antag_token_loading = list()
	/// Ckeys currently submitting a menu selection.
	var/list/antag_token_selecting = list()
	/// Monotonic selection ID, so an old SQL response cannot revive a cancelled/replaced request.
	var/antag_token_selection_id = 0
	/// Ckey -> most recent selection error.
	var/list/antag_token_messages = list()

/** Read an account without creating an empty row. A null result means SQL is unavailable. */
/datum/controller/subsystem/central/proc/load_antag_tokens(player_ckey)
	player_ckey = ckey(player_ckey)
	if(!player_ckey || !SSdbcore.Connect())
		return null
	var/datum/db_query/query = SSdbcore.NewQuery(
		{"SELECT tokens, DATE_FORMAT(DATE_ADD(last_token_at, INTERVAL 1 MONTH), '%d.%m.%Y %H:%i UTC')
		FROM [format_table_name("antag_tokens")] WHERE ckey = :ckey"},
		list("ckey" = player_ckey),
	)
	if(!query.Execute())
		qdel(query)
		return null
	var/list/result = list("tokens" = 0, "next_token_at" = null)
	if(query.NextRow())
		result["tokens"] = text2num(query.item[1])
		result["next_token_at"] = query.item[2]
	qdel(query)
	result["updated_at"] = world.time
	antag_token_balances[player_ckey] = result
	return result

/** Refresh a cosmetic snapshot; callers spending tokens always use an atomic SQL update instead. */
/datum/controller/subsystem/central/proc/refresh_antag_tokens(player_ckey)
	set waitfor = FALSE
	if(!player_ckey || (player_ckey in antag_token_loading))
		return
	antag_token_loading += player_ckey
	var/list/data = load_antag_tokens(player_ckey)
	if(!data)
		data = list("tokens" = null, "next_token_at" = null)
	data["updated_at"] = world.time
	antag_token_balances[player_ckey] = data
	antag_token_loading -= player_ckey
	update_antag_token_lobby(player_ckey)
	SStgui.update_uis(src)

/** Send the player's own balance and request indicator to the lobby button. */
/datum/controller/subsystem/central/proc/update_antag_token_lobby(player_ckey)
	var/client/player = GLOB.directory[player_ckey]
	if(!player || !isnewplayer(player.mob))
		return
	var/list/account = antag_token_balances[player_ckey]
	SStitle.title_output(player, json_encode(list("tokens" = account?["tokens"], "selected" = !!antag_token_requests[player_ckey])), "updateAntagTokens")

/**
 * Atomically change a balance. Subscription grants advance the monthly eligibility date.
 * The SQL predicate, rather than a cached balance or timestamp, protects against concurrent servers/logins.
 */
/datum/controller/subsystem/central/proc/update_antag_token_balance(player_ckey, amount, subscription_grant = FALSE, client/admin)
	PROTECTED_PROC(TRUE)
	var/admin_adjustment = !isnull(admin)
	player_ckey = ckey(player_ckey)
	if(!player_ckey || !isnum(amount) || !amount || amount != round(amount) || !SSdbcore.Connect())
		return FALSE
	if(admin_adjustment && admin?.holder?.rank_flags() != R_EVERYTHING)
		return FALSE
	var/datum/db_query/query
	if(amount < 0)
		query = SSdbcore.NewQuery(
			"UPDATE [format_table_name("antag_tokens")] SET tokens = tokens - :amount WHERE ckey = :ckey AND tokens >= :amount",
			list("ckey" = player_ckey, "amount" = -amount),
		)
	else
		query = SSdbcore.NewQuery(
			{"INSERT INTO [format_table_name("antag_tokens")] (ckey, tokens, last_token_at)
			VALUES (:ckey, :amount, IF(:subscription_grant, UTC_TIMESTAMP(), NULL))
			ON DUPLICATE KEY UPDATE
			tokens = tokens + IF(NOT :subscription_grant OR last_token_at IS NULL OR DATE_ADD(last_token_at, INTERVAL 1 MONTH) <= UTC_TIMESTAMP(), :amount, 0),
			last_token_at = IF(:subscription_grant AND (last_token_at IS NULL OR DATE_ADD(last_token_at, INTERVAL 1 MONTH) <= UTC_TIMESTAMP()), UTC_TIMESTAMP(), last_token_at)"},
			list("ckey" = player_ckey, "amount" = amount, "subscription_grant" = subscription_grant),
		)
	var/success = query.Execute() && query.affected > 0
	qdel(query)
	refresh_antag_tokens(player_ckey)
	return success

/** Grant the current subscription's monthly allotment after a successful login-time check. */
/datum/controller/subsystem/central/proc/grant_monthly_antag_tokens(client/player)
	if(!player || player.donator_level < DONATOR_TIER_4)
		return FALSE
	var/amount = player.donator_level >= DONATOR_TIER_5 ? 3 : 1
	return update_antag_token_balance(player.ckey, amount, subscription_grant = TRUE)

/** Debit exactly one token, provided the authoritative balance is positive. */
/datum/controller/subsystem/central/proc/consume_antag_token(player_ckey)
	return update_antag_token_balance(player_ckey, -1)

/** Return a confirmed debit when role assignment could not complete. */
/datum/controller/subsystem/central/proc/refund_antag_token(player_ckey)
	if(update_antag_token_balance(player_ckey, 1))
		return TRUE
	message_admins("ANTAG TOKENS: не удалось вернуть токен [player_ckey]. Проверьте баланс после восстановления БД.")
	stack_trace("Antag token refund failed for [player_ckey].")
	return FALSE

/** Manual adjustments require every administrator flag and cannot overdraw an account. */
/datum/controller/subsystem/central/proc/adjust_antag_tokens(client/admin, player_ckey, amount)
	if(!admin?.holder || admin.holder.rank_flags() != R_EVERYTHING)
		return FALSE
	player_ckey = ckey(player_ckey)
	if(!player_ckey || !isnum(amount) || !amount || abs(amount) > 1000 || amount != round(amount))
		return FALSE
	var/admin_name = key_name(admin)
	var/admin_notice_name = key_name_admin(admin)
	if(!update_antag_token_balance(player_ckey, amount, admin = admin))
		return FALSE
	if(amount > 0)
		log_admin("[admin_name] granted [amount] antag tokens to [player_ckey].")
		message_admins("[admin_notice_name] начислил [amount] антаг токенов игроку [player_ckey].")
	else
		log_admin("[admin_name] removed [-amount] antag tokens from [player_ckey].")
		message_admins("[admin_notice_name] списал [-amount] антаг токенов у игрока [player_ckey].")
	return TRUE

/** Share the amount prompt and permission revalidation between verbs and the individual player panel. */
/datum/controller/subsystem/central/proc/prompt_antag_token_adjustment(client/admin, player_ckey, remove = FALSE)
	player_ckey = ckey(player_ckey)
	if(!player_ckey || admin?.holder?.rank_flags() != R_EVERYTHING)
		return
	var/amount = tgui_input_number(admin, "Сколько токенов [remove ? "списать у" : "начислить для"] [player_ckey]?", "Антаг токены", default = 1, min_value = 1, max_value = 1000, round_value = TRUE)
	if(!isnum(amount) || amount < 1 || amount > 1000 || amount != round(amount) || admin?.holder?.rank_flags() != R_EVERYTHING)
		return
	if(!adjust_antag_tokens(admin, player_ckey, remove ? -amount : amount))
		to_chat(admin, span_warning("Баланс не изменён. Проверьте доступность БД, права администратора и наличие достаточного количества токенов для списания."))
		return
	to_chat(admin, span_notice("[remove ? "Списано" : "Начислено"] [amount] антаг токенов [remove ? "у" : "для"] [player_ckey]."))

ADMIN_VERB(grant_antag_tokens, R_PERMISSIONS, "Grant Antag Tokens", "Начислить антаг токены игроку. Требуются все флаги администратора.", ADMIN_CATEGORY_MAIN)
	if(user.holder?.rank_flags() != R_EVERYTHING)
		return
	var/player_ckey = ckey(tgui_input_text(user, "Ckey получателя", "Антаг токены"))
	if(!player_ckey || user.holder?.rank_flags() != R_EVERYTHING)
		return
	SScentral.prompt_antag_token_adjustment(user, player_ckey)

ADMIN_VERB(remove_antag_tokens, R_PERMISSIONS, "Remove Antag Tokens", "Списать антаг токены у игрока. Требуются все флаги администратора.", ADMIN_CATEGORY_MAIN)
	if(user.holder?.rank_flags() != R_EVERYTHING)
		return
	var/player_ckey = ckey(tgui_input_text(user, "Ckey игрока", "Антаг токены"))
	if(!player_ckey || user.holder?.rank_flags() != R_EVERYTHING)
		return
	SScentral.prompt_antag_token_adjustment(user, player_ckey, remove = TRUE)

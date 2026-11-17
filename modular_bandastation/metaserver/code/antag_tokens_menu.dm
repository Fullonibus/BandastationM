/** The token menu is private to the requesting lobby player. */
/datum/controller/subsystem/central/ui_state(mob/user)
	return GLOB.new_player_state

/datum/controller/subsystem/central/ui_status(mob/user, datum/ui_state/state)
	if(!user.client || user.client.interviewee)
		return UI_CLOSE
	return ..()

/datum/controller/subsystem/central/ui_interact(mob/user, datum/tgui/ui)
	if(!isnewplayer(user) || !user.client || user.client.interviewee)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AntagTokens", "Антаг токены")
		ui.open()

/datum/controller/subsystem/central/ui_static_data(mob/user)
	var/list/roles = list()
	for(var/role_id in antag_token_roles)
		var/datum/dynamic_ruleset/role = antag_token_roles[role_id]
		roles += list(list("id" = role_id, "name" = initial(role.name)))
	return list("roles" = roles)

/datum/controller/subsystem/central/ui_data(mob/user)
	var/list/account = antag_token_balances[user.ckey]
	if(!account || world.time >= account["updated_at"] + 10 SECONDS)
		refresh_antag_tokens(user.ckey)
	return list(
		"tokens" = account?["tokens"],
		"available" = isnum(account?["tokens"]),
		"storage_enabled" = CONFIG_GET(flag/sql_enabled),
		"loading" = (user.ckey in antag_token_loading) || (user.ckey in antag_token_selecting),
		"next_token_at" = account?["next_token_at"],
		"selected" = antag_token_requests[user.ckey],
		"enabled" = SSdynamic.antag_tokens_enabled,
		"can_select" = can_select_antag_token(user),
		"message" = antag_token_messages[user.ckey],
	)

/** Check the live lobby state without rewriting ordinary antagonist preferences. */
/datum/controller/subsystem/central/proc/can_select_antag_token(mob/dead/new_player/player)
	if(!istype(player) || !player.client || player.client.interviewee || !SSdynamic.antag_tokens_enabled)
		return FALSE
	if(!SSticker || SSticker.current_state > GAME_STATE_PREGAME)
		return FALSE
	if(CONFIG_GET(flag/force_discord_verification) && isnull(player.client.persistent_client?.discord_id))
		return FALSE
	return TRUE

/datum/controller/subsystem/central/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/dead/new_player/player = ui.user
	if(!istype(player) || !player.client || player.client.interviewee)
		return
	var/player_ckey = player.ckey
	switch(action)
		if("refresh")
			refresh_antag_tokens(player_ckey)
			return TRUE
		if("cancel")
			if(!can_select_antag_token(player))
				return
			antag_token_requests -= player_ckey
			antag_token_selecting -= player_ckey
			antag_token_messages -= player_ckey
			update_antag_token_lobby(player_ckey)
			return TRUE
		if("select")
			var/role_id = params["role"]
			if(!istext(role_id) || !(role_id in antag_token_roles) || !can_select_antag_token(player) || (player_ckey in antag_token_selecting))
				return
			antag_token_selection_id++
			var/selection_id = antag_token_selection_id
			antag_token_selecting[player_ckey] = selection_id
			var/list/account = load_antag_tokens(player_ckey)
			if(antag_token_selecting[player_ckey] != selection_id)
				return TRUE
			if(!player || player.client?.ckey != player_ckey || !can_select_antag_token(player))
				antag_token_selecting -= player_ckey
				return TRUE
			if(!account || account["tokens"] < 1)
				antag_token_messages[player_ckey] = account ? "На балансе нет токенов." : "База данных недоступна. Попробуйте обновить баланс."
				antag_token_selecting -= player_ckey
				return TRUE
			var/role_type = antag_token_roles[role_id]
			var/datum/dynamic_ruleset/roundstart/role = new role_type(SSdynamic.get_config())
			role.antag_token_ckey = player_ckey
			var/eligible = !(role.type in SSdynamic.admin_disabled_rulesets) && length(role.trim_candidates(list(player)))
			qdel(role)
			if(antag_token_selecting[player_ckey] != selection_id)
				return TRUE
			// Role bans can query SQL and yield; the lobby and global switch must still agree.
			if(player && player.client?.ckey == player_ckey && can_select_antag_token(player))
				if(eligible)
					antag_token_requests[player_ckey] = role_id
					antag_token_messages -= player_ckey
				else
					antag_token_messages[player_ckey] = "Роль недоступна: проверьте ограничения расы, возраст аккаунта и баны на роли."
			antag_token_selecting -= player_ckey
			update_antag_token_lobby(player_ckey)
			return TRUE

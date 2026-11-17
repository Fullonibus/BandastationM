/datum/controller/subsystem/dynamic
	/// Separate from ordinary antag events and the tier's random ruleset budget.
	var/antag_tokens_enabled = TRUE
	/// Prepared paid rulesets, owned here until assignment or cancellation.
	var/list/datum/dynamic_ruleset/roundstart/antag_token_rulesets = list()
	/// Prevent re-entry while a debit or role assignment yields.
	var/antag_token_execution_started = FALSE
	/// Before-job restrictions to restore when a prepared request is cancelled.
	var/list/antag_token_previous_occupations = list()
	/// Borrowed candidate list only while roundstart selection is running.
	var/list/antag_token_candidates

/** Release reservations when token spawning is cancelled during roundstart preparation. */
/datum/controller/subsystem/dynamic/proc/cancel_antag_token_rulesets()
	// An in-flight debit owns its ruleset until it can revalidate and refund.
	if(antag_token_execution_started)
		return
	for(var/datum/dynamic_ruleset/roundstart/ruleset as anything in antag_token_rulesets)
		var/datum/mind/player_mind = ruleset.selected_minds[1]
		var/list/previous_restrictions = antag_token_previous_occupations[ruleset]
		var/list/restrictions = LAZYACCESS(SSjob.prevented_occupations, player_mind)
		if(!restrictions)
			restrictions = list()
		var/list/token_restrictions = ruleset.get_blacklisted_roles()
		if(previous_restrictions)
			token_restrictions -= previous_restrictions
		restrictions -= token_restrictions
		if(previous_restrictions)
			restrictions |= previous_restrictions
		if(length(restrictions))
			LAZYSET(SSjob.prevented_occupations, player_mind, restrictions)
		else
			LAZYREMOVE(SSjob.prevented_occupations, player_mind)
		if(antag_token_candidates)
			for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
				if(player.mind == player_mind && player.ready == PLAYER_READY_TO_PLAY)
					antag_token_candidates |= player
					break
		qdel(ruleset)
	antag_token_rulesets.Cut()
	antag_token_previous_occupations.Cut()

/** Reserve eligible token users without consuming any ordinary ruleset slots. */
/datum/controller/subsystem/dynamic/proc/prepare_antag_token_rulesets(list/mob/antag_candidates)
	antag_token_execution_started = FALSE
	cancel_antag_token_rulesets()
	antag_token_candidates = antag_candidates
	if(!antag_tokens_enabled)
		antag_token_candidates = null
		return
	for(var/mob/dead/new_player/player as anything in antag_candidates.Copy())
		var/player_ckey = player.ckey
		var/role_id = SScentral.antag_token_requests[player_ckey]
		if(!role_id)
			continue
		var/role_type = SScentral.antag_token_roles[role_id]
		if(!role_type || !player.client || player.ready != PLAYER_READY_TO_PLAY)
			continue
		var/list/account = SScentral.load_antag_tokens(player_ckey)
		if(!antag_tokens_enabled || !player || player.client?.ckey != player_ckey || player.ready != PLAYER_READY_TO_PLAY || SScentral.antag_token_requests[player_ckey] != role_id)
			continue
		if(!account || account["tokens"] < 1 || (role_type in admin_disabled_rulesets))
			to_chat(player, span_warning("Антаг токен не использован: баланс или выбранная роль недоступны."))
			continue
		var/datum/dynamic_ruleset/roundstart/ruleset = new role_type(dynamic_config)
		var/datum/mind/player_mind = player.mind
		var/list/previous_restrictions = LAZYACCESS(SSjob.prevented_occupations, player_mind)
		previous_restrictions = previous_restrictions?.Copy()
		ruleset.antag_token_ckey = player_ckey
		ruleset.min_antag_cap = 1
		ruleset.max_antag_cap = 1
		if(!ruleset.prepare_execution(length(antag_candidates), list(player)))
			to_chat(player, span_warning("Антаг токен не использован: персонаж не подходит для выбранной роли."))
			qdel(ruleset)
			continue
		if(!antag_tokens_enabled || !player || player.client?.ckey != player_ckey || player.ready != PLAYER_READY_TO_PLAY || SScentral.antag_token_requests[player_ckey] != role_id)
			if(previous_restrictions)
				LAZYSET(SSjob.prevented_occupations, player_mind, previous_restrictions)
			else
				LAZYREMOVE(SSjob.prevented_occupations, player_mind)
			qdel(ruleset)
			continue
		antag_token_rulesets += ruleset
		antag_token_previous_occupations[ruleset] = previous_restrictions
		antag_candidates -= player
		log_dynamic("Antag token: [player_ckey] reserved [ruleset.config_tag] in addition to ordinary roundstart rulesets.")

/** Revalidate the character after job assignment and after every SQL wait. */
/datum/controller/subsystem/dynamic/proc/can_assign_token_role(datum/dynamic_ruleset/roundstart/ruleset, datum/mind/player_mind)
	if(!antag_tokens_enabled || !player_mind || QDELETED(player_mind) || (ruleset.type in admin_disabled_rulesets))
		return FALSE
	var/role_id = SScentral.antag_token_requests[ruleset.antag_token_ckey]
	if(!role_id || SScentral.antag_token_roles[role_id] != ruleset.type)
		return FALSE
	var/mob/living/carbon/human/player = player_mind.current
	if(!istype(player) || QDELETED(player) || player.stat == DEAD || player.ckey != ruleset.antag_token_ckey || !player.client || player.client.interviewee || length(player_mind.antag_datums))
		return FALSE
	if(!player_mind.assigned_role || (player_mind.assigned_role.title in ruleset.get_blacklisted_roles()))
		return FALSE
	if(player.client.get_remaining_days(ruleset.minimum_required_age) > 0)
		return FALSE
	if(istype(ruleset, /datum/dynamic_ruleset/roundstart/blood_worm) && !CAN_HAVE_BLOOD(player))
		return FALSE
	if(istype(ruleset, /datum/dynamic_ruleset/roundstart/vampire) && !player.dna.species.is_vampire_compatible())
		return FALSE
	return TRUE

/** Execute the existing role lifecycle, charging only a still-valid request with a positive SQL balance. */
/datum/controller/subsystem/dynamic/proc/execute_antag_token_rulesets()
	if(antag_token_execution_started)
		return
	antag_token_execution_started = TRUE
	for(var/datum/dynamic_ruleset/roundstart/ruleset as anything in antag_token_rulesets)
		var/player_ckey = ruleset.antag_token_ckey
		var/datum/mind/player_mind = ruleset.selected_minds[1]
		if(!can_assign_token_role(ruleset, player_mind))
			qdel(ruleset)
			continue
		var/banned = is_banned_from(player_ckey, list(ROLE_SYNDICATE, ruleset.jobban_flag || ruleset.pref_flag))
		if(banned || !can_assign_token_role(ruleset, player_mind) || !SScentral.consume_antag_token(player_ckey))
			to_chat(player_mind, span_warning("Антаг токен не использован: роль или баланс недоступны."))
			qdel(ruleset)
			continue
		banned = is_banned_from(player_ckey, list(ROLE_SYNDICATE, ruleset.jobban_flag || ruleset.pref_flag))
		if(banned || !can_assign_token_role(ruleset, player_mind))
			SScentral.refund_antag_token(player_ckey)
			qdel(ruleset)
			continue
		ruleset.execute()
		if(!player_mind.has_antag_datum(ruleset.preview_antag_datum))
			SScentral.refund_antag_token(player_ckey)
			log_dynamic("Antag token: role assignment failed for [player_ckey] ([ruleset.config_tag]); refund requested.")
			qdel(ruleset)
			continue
		executed_rulesets += ruleset
		log_dynamic("Antag token: [player_ckey] spent one token on [ruleset.config_tag].")
		log_admin("[player_ckey] spent one antag token on [ruleset.config_tag].")
		to_chat(player_mind, span_notice("За роль [ruleset.name] списан 1 антаг токен."))
	antag_token_rulesets.Cut()
	antag_token_previous_occupations.Cut()
	SScentral.antag_token_requests.Cut()

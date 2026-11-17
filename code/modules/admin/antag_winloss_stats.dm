/datum/admins
	/// Cached Antagonist Win/Loss Stats TGUI panel owned by this admin holder.
	var/datum/antag_winloss_panel/antag_winloss_panel

/**
 * Opens the Antagonist Win/Loss Stats TGUI panel for the calling admin.
 *
 * Arguments:
 * * user - Optional mob opening the panel; falls back to `owner?.mob`.
 */
/datum/admins/proc/open_antag_winloss_stats(mob/user)
	if(!check_rights(R_ADMIN))
		return
	var/mob/target_user = user || owner?.mob
	if(QDELETED(target_user))
		return
	if(!antag_winloss_panel)
		antag_winloss_panel = new(src)
	if(!SStgui.get_open_ui(target_user, antag_winloss_panel))
		antag_winloss_panel.history_needs_reload = TRUE
	antag_winloss_panel.ui_interact(target_user)

/**
 * # Antagonist Win/Loss Panel
 *
 * Admin TGUI controller displaying current-round antagonist progress and
 * read-only historical win/loss statistics from the `feedback` database table.
 */
/datum/antag_winloss_panel
	/// Owning admin holder datum.
	var/datum/admins/holder
	/// Number of past rounds to fetch from the database (1..100).
	var/history_limit = 25
	/// Cached serialized historical statistics from the latest completed DB query.
	var/list/cached_history_data
	/// Whether opening the panel should trigger an asynchronous history reload.
	var/history_needs_reload = TRUE
	/// Whether an asynchronous history query is currently in flight.
	var/history_loading = FALSE
	/// Monotonic request counter used to discard stale async query results.
	var/history_request_id = 0
	/// Remaining retry attempts for pushing updates to uninitialized UI windows.
	var/history_push_attempts = 0

/**
 * Initializes the panel datum and stores its owning admin holder.
 *
 * Arguments:
 * * holder - The `/datum/admins` datum that owns this panel.
 */
/datum/antag_winloss_panel/New(datum/admins/holder)
	. = ..()
	src.holder = holder

/datum/antag_winloss_panel/Destroy()
	SStgui.close_uis(src)
	if(holder?.antag_winloss_panel == src)
		holder.antag_winloss_panel = null
	holder = null
	cached_history_data = null
	history_loading = FALSE
	history_request_id++
	return ..()

/datum/antag_winloss_panel/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/antag_winloss_panel/ui_interact(mob/user, datum/tgui/ui)
	if(history_needs_reload && !history_loading)
		request_history_reload()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AntagWinLossPanel")
		ui.set_autoupdate(FALSE)
		ui.open()

/**
 * Builds a brief human-readable context string for an objective's current state.
 *
 * Arguments:
 * * obj - The `/datum/objective` to inspect.
 */
/datum/antag_winloss_panel/proc/get_objective_context(datum/objective/obj)
	if(!istype(obj) || QDELETED(obj))
		return null

	var/list/context_parts = list()

	if(istype(obj, /datum/objective/escape))
		if(!SSshuttle?.emergency)
			context_parts += "Шаттл: недоступен"
		else
			switch(SSshuttle.emergency.mode)
				if(SHUTTLE_IDLE)
					context_parts += "Шаттл не вызван"
				if(SHUTTLE_CALL)
					context_parts += "Шаттл в пути"
				if(SHUTTLE_PREARRIVAL)
					context_parts += "Шаттл заходит на посадку"
				if(SHUTTLE_DOCKED)
					context_parts += "Шаттл на станции"
				if(SHUTTLE_IGNITING)
					context_parts += "Шаттл взлетает"
				if(SHUTTLE_ESCAPE)
					context_parts += "Шаттл улетел к ЦК"
				if(SHUTTLE_ENDGAME)
					context_parts += "Шаттл на ЦК"
				if(SHUTTLE_RECALL)
					context_parts += "Шаттл отозван"
				if(SHUTTLE_STRANDED)
					context_parts += "Шаттл заблокирован"
				if(SHUTTLE_DISABLED)
					context_parts += "Шаттл отключен"
				else
					context_parts += "Шаттл: [SSshuttle.emergency.mode]"
	else if(istype(obj, /datum/objective/nuclear))
		context_parts += GLOB.station_was_nuked ? "Боеголовка детонирована" : "Боеголовка не взорвана"

	if(istype(obj.target, /datum/mind) || ismob(obj.target))
		var/mob/target_mob
		if(istype(obj.target, /datum/mind))
			var/datum/mind/target_mind = obj.target
			target_mob = target_mind.current
		else
			target_mob = obj.target

		if(QDELETED(target_mob))
			context_parts += "Цель: тело уничтожено"
		else if(target_mob.stat == DEAD)
			context_parts += "Цель: мертв(а)"
		else
			var/list/states = list()
			if(target_mob.stat == SOFT_CRIT || target_mob.stat == HARD_CRIT)
				states += "в крите"
			if(iscarbon(target_mob))
				var/mob/living/carbon/carbon_mob = target_mob
				if(carbon_mob.handcuffed)
					states += "в наручниках"
			if(!target_mob.client)
				states += "SSD"

			if(states.len)
				context_parts += "Цель: [states.Join(", ")]"
			else
				context_parts += "Цель: жив(а)"

	return context_parts.len ? context_parts.Join(" | ") : null

/**
 * Evaluates a list of objectives and serializes them for TGUI display.
 *
 * Arguments:
 * * objectives - List of `/datum/objective` datums to evaluate.
 */
/datum/antag_winloss_panel/proc/evaluate_objectives(list/datum/objective/objectives)
	var/list/serialized_objs = list()
	var/all_completed = TRUE

	for(var/datum/objective/obj as anything in objectives)
		if(!istype(obj) || QDELETED(obj))
			continue
		// Negative values such as CULT_NARSIE_KILLED (-1) are truthy in DM, so require > 0.
		var/completion_result = obj.check_completion()
		var/is_completed = (isnum(completion_result) && completion_result > 0)
		if(!is_completed)
			all_completed = FALSE
		serialized_objs += list(list(
			"text" = format_text(obj.explanation_text) || "(Цель без описания)",
			"completed" = is_completed,
			"context" = get_objective_context(obj),
		))

	var/outcome = serialized_objs.len ? (all_completed ? 1 : 0) : -1
	return list("outcome" = outcome, "objectives" = serialized_objs)

/**
 * Starts an asynchronous reload of historical antagonist statistics from the DB.
 */
/datum/antag_winloss_panel/proc/request_history_reload()
	history_needs_reload = FALSE
	history_request_id++
	var/request_id = history_request_id

	if(!SSdbcore.Connect())
		cached_history_data = null
		history_loading = FALSE
		push_history_update()
		return

	history_loading = TRUE
	push_history_update()
	INVOKE_ASYNC(src, PROC_REF(fetch_history), request_id)

/**
 * Pushes updated dynamic data to all open UI windows,
 * retrying briefly if a newly opened window has not finished initializing yet.
 *
 * Arguments:
 * * reset_retries - Whether to reset the retry counter for uninitialized windows.
 */
/datum/antag_winloss_panel/proc/push_history_update(reset_retries = TRUE)
	if(QDELETED(src) || !LAZYLEN(open_uis))
		return
	if(reset_retries)
		history_push_attempts = 10
	var/has_uninitialized = FALSE
	for(var/datum/tgui/ui as anything in open_uis)
		if(ui.closing || !ui.user?.client || !ui.window)
			continue
		if(!ui.initialized)
			has_uninitialized = TRUE
			ui.window.send_message("update", ui.get_payload(with_data = TRUE))
			continue
		ui.send_update(force = TRUE)
	if(has_uninitialized && history_push_attempts > 0)
		history_push_attempts--
		addtimer(CALLBACK(src, PROC_REF(push_history_update), FALSE), 0.5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)

/**
 * Executes a read-only SELECT query for historical antagonist feedback and caches the result.
 *
 * Arguments:
 * * request_id - Request generation token used to ignore superseded async results.
 */
/datum/antag_winloss_panel/proc/fetch_history(request_id)
	if(QDELETED(src) || request_id != history_request_id)
		return

	var/sanitized_limit = isnum(history_limit) ? clamp(round(history_limit), 1, 100) : 25
	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT round_id, CAST(datetime AS CHAR), CAST(json AS CHAR)
		FROM [format_table_name("feedback")]
		WHERE key_name = 'antagonists'
		ORDER BY round_id DESC
		LIMIT [sanitized_limit]
	"})

	if(!query || !query.Execute(async = TRUE))
		qdel(query)
		if(!QDELETED(src) && request_id == history_request_id)
			cached_history_data = null
			history_loading = FALSE
			push_history_update()
		return

	if(QDELETED(src) || request_id != history_request_id)
		qdel(query)
		return

	var/list/rounds_data = list()
	var/hist_total = 0
	var/hist_wins = 0
	var/hist_losses = 0
	var/list/role_stats = list()

	while(query.NextRow())
		var/r_id = isnum(query.item[1]) ? query.item[1] : text2num("[query.item[1]]")
		var/r_time = "[query.item[2]]"
		var/raw_json = query.item[3]

		var/list/decoded = islist(raw_json) ? raw_json : (istext(raw_json) ? safe_json_decode(raw_json) : null)
		if(!islist(decoded) || !islist(decoded["data"]))
			continue

		var/list/data_list = decoded["data"]
		var/round_antags = 0
		var/round_wins = 0
		var/round_losses = 0

		for(var/entry_id in data_list)
			var/list/antag_entry = islist(entry_id) ? entry_id : data_list[entry_id]
			if(!islist(antag_entry))
				continue

			var/raw_role = antag_entry["antagonist_name"] || antag_entry["antagonist_type"] || "Неизвестно"
			var/role_name = (istext(raw_role) && format_text(raw_role)) || "Неизвестно"
			var/list/objs = antag_entry["objectives"]
			var/outcome = -1
			if(islist(objs) && objs.len > 0)
				var/has_valid_obj = FALSE
				var/all_success = TRUE
				for(var/list/obj_info as anything in objs)
					if(!islist(obj_info))
						continue
					has_valid_obj = TRUE
					if(obj_info["result"] != "SUCCESS")
						all_success = FALSE
						break
				if(has_valid_obj)
					outcome = all_success ? 1 : 0

			round_antags++
			hist_total++
			if(outcome == 1)
				round_wins++
				hist_wins++
			else if(outcome == 0)
				round_losses++
				hist_losses++

			if(!role_stats[role_name])
				role_stats[role_name] = list("total" = 0, "wins" = 0, "losses" = 0)
			role_stats[role_name]["total"]++
			if(outcome == 1)
				role_stats[role_name]["wins"]++
			else if(outcome == 0)
				role_stats[role_name]["losses"]++

		var/r_eval = round_wins + round_losses
		var/r_wr = r_eval ? round((round_wins / r_eval) * 100, 0.1) : null

		rounds_data += list(list(
			"round_id" = r_id,
			"datetime" = r_time,
			"total" = round_antags,
			"wins" = round_wins,
			"losses" = round_losses,
			"winrate" = r_wr,
		))

	qdel(query)

	var/list/serialized_roles = list()
	for(var/role_name in role_stats)
		var/list/rdata = role_stats[role_name]
		var/r_eval = rdata["wins"] + rdata["losses"]
		var/r_wr = r_eval ? round((rdata["wins"] / r_eval) * 100, 0.1) : null
		serialized_roles += list(list(
			"name" = role_name,
			"total" = rdata["total"],
			"wins" = rdata["wins"],
			"losses" = rdata["losses"],
			"winrate" = r_wr,
		))

	var/overall_eval = hist_wins + hist_losses
	var/overall_wr = overall_eval ? round((hist_wins / overall_eval) * 100, 0.1) : null

	cached_history_data = list(
		"total_rounds" = rounds_data.len,
		"total_antags" = hist_total,
		"total_wins" = hist_wins,
		"total_losses" = hist_losses,
		"overall_winrate" = overall_wr,
		"roles" = serialized_roles,
		"rounds" = rounds_data,
	)
	history_loading = FALSE
	push_history_update()

/datum/antag_winloss_panel/ui_data(mob/user)
	if(!check_rights_for(CLIENT_FROM_VAR(user), R_ADMIN))
		return list()
	. = list()
	var/round_started = SSticker && SSticker.HasRoundStarted()
	.["round_started"] = round_started

	var/total_antags = 0
	var/total_wins = 0
	var/total_losses = 0
	var/total_unconditional = 0

	var/list/antags_by_cat = list()
	var/list/cat_stats = list()

	if(round_started)
		for(var/datum/antagonist/antag as anything in GLOB.antagonists)
			if(QDELETED(antag) || QDELETED(antag.owner))
				continue

			var/datum/mind/owner_mind = antag.owner
			var/datum/team/antag_team = antag.get_team()

			var/list/all_objectives = list()
			if(antag.objectives?.len)
				for(var/datum/objective/obj as anything in antag.objectives)
					if(istype(obj) && !QDELETED(obj))
						all_objectives += obj
			if(antag_team?.objectives?.len)
				for(var/datum/objective/team_obj as anything in antag_team.objectives)
					if(istype(team_obj) && !QDELETED(team_obj) && !(team_obj in all_objectives))
						all_objectives += team_obj

			var/list/eval = evaluate_objectives(all_objectives)
			var/outcome = eval["outcome"]
			var/list/serialized_objs = eval["objectives"]

			total_antags++
			if(outcome == 1)
				total_wins++
			else if(outcome == 0)
				total_losses++
			else
				total_unconditional++

			var/category = format_text(antag.roundend_category) || "Другие антагонисты"
			if(!antags_by_cat[category])
				antags_by_cat[category] = list()
				cat_stats[category] = list("total" = 0, "wins" = 0, "losses" = 0, "unconditional" = 0)

			cat_stats[category]["total"]++
			if(outcome == 1)
				cat_stats[category]["wins"]++
			else if(outcome == 0)
				cat_stats[category]["losses"]++
			else
				cat_stats[category]["unconditional"]++

			var/mob/antag_mob = owner_mind.current
			if(QDELETED(antag_mob))
				antag_mob = null

			var/status = "alive"
			if(!antag_mob)
				status = "body_destroyed"
			else if(antag_mob.stat == DEAD)
				status = "dead"
			else if(!antag_mob.client)
				status = "no_client"
			else
				status = "alive"

			var/raw_char_name = antag_mob ? (antag_mob.real_name || antag_mob.name || owner_mind.name) : owner_mind.name
			var/char_name = (istext(raw_char_name) && format_text(raw_char_name)) || "Неизвестно"
			var/team_name = (antag_team && istext(antag_team.name)) ? (format_text(antag_team.name) || null) : null

			var/list/antag_data = list(
				"key" = owner_mind.key || "(Ключ неизвестен)",
				"ckey" = owner_mind.key ? ckey(owner_mind.key) : null,
				"char_name" = char_name,
				"role" = format_text(antag.name) || "Антагонист",
				"team" = team_name,
				"status" = status,
				"objectives" = serialized_objs,
				"outcome" = outcome,
				"mob_ref" = antag_mob ? REF(antag_mob) : null,
				"mind_ref" = REF(owner_mind),
			)

			antags_by_cat[category] += list(antag_data)

	var/evaluated_total = total_wins + total_losses
	var/overall_winrate = evaluated_total ? round((total_wins / evaluated_total) * 100, 0.1) : null

	.["summary"] = list(
		"total" = total_antags,
		"wins" = total_wins,
		"losses" = total_losses,
		"unconditional" = total_unconditional,
		"winrate" = overall_winrate,
	)

	var/list/categories_data = list()
	for(var/category in antags_by_cat)
		var/list/cstat = cat_stats[category]
		var/cat_eval = cstat["wins"] + cstat["losses"]
		var/cat_wr = cat_eval ? round((cstat["wins"] / cat_eval) * 100, 0.1) : null
		categories_data += list(list(
			"name" = capitalize(category),
			"total" = cstat["total"],
			"wins" = cstat["wins"],
			"losses" = cstat["losses"],
			"unconditional" = cstat["unconditional"],
			"winrate" = cat_wr,
			"antagonists" = antags_by_cat[category],
		))

	.["categories"] = categories_data

	var/list/teams_data = list()
	if(round_started && GLOB.antagonist_teams?.len)
		for(var/datum/team/team_inst as anything in GLOB.antagonist_teams)
			if(QDELETED(team_inst))
				continue

			var/members_count = 0
			var/members_alive = 0
			var/list/serialized_members = list()
			if(team_inst.members?.len)
				for(var/datum/mind/member_mind as anything in team_inst.members)
					if(!istype(member_mind) || QDELETED(member_mind))
						continue
					members_count++
					var/mob/living_mob = member_mind.current
					if(QDELETED(living_mob))
						living_mob = null
					var/is_alive = (living_mob && living_mob.stat != DEAD) ? TRUE : FALSE
					if(is_alive)
						members_alive++
					var/raw_member_name = living_mob ? (living_mob.real_name || living_mob.name) : member_mind.name
					var/member_name = (istext(raw_member_name) && format_text(raw_member_name)) || "Неизвестно"
					serialized_members += list(list(
						"key" = member_mind.key || "(Ключ неизвестен)",
						"ckey" = member_mind.key ? ckey(member_mind.key) : null,
						"name" = member_name,
						"alive" = is_alive,
						"stat" = living_mob ? living_mob.stat : DEAD,
						"mob_ref" = living_mob ? REF(living_mob) : null,
						"mind_ref" = REF(member_mind),
					))

			var/list/team_eval = team_inst.objectives?.len ? evaluate_objectives(team_inst.objectives) : list("outcome" = -1, "objectives" = list())

			teams_data += list(list(
				"name" = (istext(team_inst.name) && format_text(team_inst.name)) || "Команда",
				"members_count" = members_count,
				"members_alive" = members_alive,
				"members" = serialized_members,
				"objectives" = team_eval["objectives"],
				"outcome" = team_eval["outcome"],
			))

	.["teams"] = teams_data
	.["db_connected"] = SSdbcore.IsConnected() ? TRUE : FALSE
	.["history_limit"] = history_limit
	.["history_loading"] = history_loading
	.["history"] = cached_history_data

/**
 * Safely resolves a mob reference within `GLOB.mob_list`.
 *
 * Arguments:
 * * mob_ref - Text reference string from UI params.
 */
/datum/antag_winloss_panel/proc/locate_mob(mob_ref)
	if(!istext(mob_ref) || !length(mob_ref))
		return null
	var/mob/target_mob = locate(mob_ref) in GLOB.mob_list
	if(!ismob(target_mob) || QDELETED(target_mob))
		return null
	return target_mob

/**
 * Safely resolves a mind reference within `SSticker.minds`.
 *
 * Arguments:
 * * mind_ref - Text reference string from UI params.
 */
/datum/antag_winloss_panel/proc/locate_mind(mind_ref)
	if(!istext(mind_ref) || !length(mind_ref) || !SSticker?.minds)
		return null
	var/datum/mind/target_mind = locate(mind_ref) in SSticker.minds
	if(!istype(target_mind) || QDELETED(target_mind))
		return null
	return target_mind

/datum/antag_winloss_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	if(!check_rights(R_ADMIN))
		return FALSE

	switch(action)
		if("pm")
			var/target_ckey = params["ckey"]
			if(!istext(target_ckey) || !length(target_ckey))
				return FALSE
			usr.client?.cmd_admin_pm(target_ckey)
			return TRUE

		if("follow")
			var/mob/target_mob = locate_mob(params["mob_ref"])
			if(!target_mob)
				return FALSE
			usr.client?.admin_follow(target_mob)
			return TRUE

		if("player_panel")
			var/mob/target_mob = locate_mob(params["mob_ref"])
			if(!target_mob)
				var/datum/mind/target_mind = locate_mind(params["mind_ref"])
				if(target_mind && !QDELETED(target_mind.current))
					target_mob = target_mind.current
			if(!target_mob)
				return FALSE
			SSadmin_verbs.dynamic_invoke_verb(usr, /datum/admin_verb/show_player_panel, target_mob)
			return TRUE

		if("traitor_panel")
			var/datum/mind/target_mind = locate_mind(params["mind_ref"])
			if(target_mind)
				target_mind.traitor_panel()
				return TRUE
			var/mob/target_mob = locate_mob(params["mob_ref"])
			if(target_mob && !QDELETED(target_mob.mind))
				target_mob.mind.traitor_panel()
				return TRUE
			return FALSE

		if("vv")
			if(!check_rights(R_DEBUG))
				return FALSE
			var/target_ref = params["target_ref"]
			var/datum/target = locate_mob(target_ref) || locate_mind(target_ref) || locate_mob(params["mob_ref"]) || locate_mind(params["mind_ref"])
			if(QDELETED(target))
				return FALSE
			usr.client?.debug_variables(target)
			return TRUE

		if("check_teams")
			usr.client?.holder?.check_teams()
			return TRUE

		if("refresh_current")
			return TRUE

		if("refresh_history")
			if(!history_loading)
				request_history_reload()
			return TRUE

		if("set_limit")
			var/raw_limit = params["limit"]
			var/new_limit = isnum(raw_limit) ? raw_limit : (istext(raw_limit) ? text2num(raw_limit) : null)
			if(!isnum(new_limit))
				return FALSE
			new_limit = round(new_limit)
			if(!(new_limit >= 1 && new_limit <= 100))
				return FALSE
			if(new_limit != history_limit)
				history_limit = new_limit
				request_history_reload()
			else if(history_needs_reload && !history_loading)
				request_history_reload()
			return TRUE

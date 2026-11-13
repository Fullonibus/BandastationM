/datum/admins
	/// Cached Antagonist Win/Loss Stats TGUI panel owned by this admin holder.
	var/datum/antag_winloss_panel/antag_winloss_panel

/// Opens this holder's antagonist statistics panel.
/datum/admins/proc/open_antag_winloss_stats()
	var/mob/user = owner?.mob
	if(QDELETED(user) || owner.holder != src || !check_rights_for(owner, R_ADMIN))
		return
	if(!antag_winloss_panel)
		antag_winloss_panel = new(src)
	antag_winloss_panel.ui_interact(user)

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
	/// State of the current history request, including its result when finished.
	var/history_status = "idle"

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
	return ..()

/datum/antag_winloss_panel/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/datum/antag_winloss_panel/ui_status(mob/user, datum/ui_state/state)
	if(!can_view_panel(user?.client))
		return UI_CLOSE
	return ..()

/datum/antag_winloss_panel/ui_interact(mob/user, datum/tgui/ui)
	if(!can_view_panel(user?.client))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AntagWinLossPanel")
		ui.set_autoupdate(FALSE)
		ui.open()

/// Checks both the owning holder and its current permissions.
/datum/antag_winloss_panel/proc/can_view_panel(client/viewer)
	return viewer && holder && viewer.holder == holder && check_rights_for(viewer, R_ADMIN)

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
 * * objective_rows - Serialized objective rows shared by this snapshot.
 * * objectives - List of `/datum/objective` datums to evaluate.
 */
/datum/antag_winloss_panel/proc/evaluate_objectives(list/datum/objective/objectives, list/objective_rows)
	var/list/serialized_objs = list()
	var/outcome = -1

	for(var/datum/objective/obj as anything in objectives)
		if(!istype(obj) || QDELETED(obj))
			continue
		var/list/row = objective_rows[obj]
		if(!row)
			var/is_completed
			if(!obj.no_failure)
				// A negative result such as CULT_NARSIE_KILLED is a failure.
				is_completed = obj.check_completion_read_only() > 0
			else if(obj.completed)
				// Scripted successes such as the Grand Ritual use a custom objective.
				is_completed = TRUE
			row = list(
				"text" = format_text(obj.explanation_text) || "(Цель без описания)",
				"completed" = is_completed,
				"context" = get_objective_context(obj),
			)
			objective_rows[obj] = row
		serialized_objs += list(row)
		var/is_completed = row["completed"]
		if(!isnull(is_completed) && outcome != 0)
			outcome = is_completed ? 1 : 0

	return list("outcome" = outcome, "objectives" = serialized_objs)

/// Starts at most one history request at a time.
/datum/antag_winloss_panel/proc/request_history_reload()
	if(history_status == "loading")
		return
	history_status = "loading"
	cached_history_data = null
	push_history_update()
	INVOKE_ASYNC(src, PROC_REF(fetch_history))

/// Returns the history fields independently of the current-round snapshot.
/datum/antag_winloss_panel/proc/history_payload()
	return list(
		"history" = cached_history_data,
		"history_limit" = history_limit,
		"history_status" = history_status,
	)

/// Updates history without reevaluating the objectives in the current round.
/datum/antag_winloss_panel/proc/push_history_update()
	var/list/data = history_payload()
	for(var/datum/tgui/ui as anything in open_uis)
		if(ui.closing || !ui.window || !can_view_panel(ui.user?.client))
			continue
		if(!ui.initialized)
			// The window queues messages until its browser is ready.
			ui.window.send_message("update", list("data" = data))
			continue
		ui.send_update(custom_data = data, force = TRUE)

/// Fetches the latest recorded antagonist feedback without blocking the TGUI action.
/datum/antag_winloss_panel/proc/fetch_history()
	if(QDELETED(src))
		return
	if(!can_view_panel(holder?.owner))
		history_status = "idle"
		return
	if(SSdbcore.shutting_down || !SSdbcore.Connect())
		history_status = "unavailable"
		push_history_update()
		return

	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT round_id, CAST(datetime AS CHAR), CAST(json AS CHAR)
		FROM [format_table_name("feedback")]
		WHERE key_name = 'antagonists' AND round_id IS NOT NULL
		ORDER BY round_id DESC, id DESC
		LIMIT :round_limit
	"}, list("round_limit" = history_limit))
	var/query_succeeded = query?.Execute(async = TRUE)
	if(QDELETED(src))
		qdel(query)
		return
	if(!can_view_panel(holder?.owner))
		qdel(query)
		history_status = "idle"
		return
	if(!query_succeeded)
		qdel(query)
		history_status = SSdbcore.IsConnected() ? "error" : "unavailable"
		push_history_update()
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
			var/list/antag_entry
			if(islist(entry_id))
				antag_entry = entry_id
			else if(istext(entry_id))
				antag_entry = data_list[entry_id]
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
					switch(obj_info["result"])
						if("SUCCESS")
							has_valid_obj = TRUE
						if("FAIL")
							has_valid_obj = TRUE
							all_success = FALSE
					if(!all_success)
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
	history_status = "ready"
	push_history_update()

/datum/antag_winloss_panel/ui_data(mob/user)
	var/client/viewer = user?.client
	if(!can_view_panel(viewer))
		return list()
	. = history_payload()
	.["can_view_variables"] = check_rights_for(viewer, R_DEBUG)
	var/list/objective_rows = list()
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

			var/list/eval = evaluate_objectives(all_objectives, objective_rows)
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
				"antag_ref" = REF(antag),
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

			var/list/team_eval = evaluate_objectives(team_inst.objectives, objective_rows)

			teams_data += list(list(
				"name" = (istext(team_inst.name) && format_text(team_inst.name)) || "Команда",
				"members_count" = members_count,
				"members_alive" = members_alive,
				"members" = serialized_members,
				"objectives" = team_eval["objectives"],
				"outcome" = team_eval["outcome"],
			))

	.["teams"] = teams_data

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

	var/client/viewer = usr?.client
	if(usr != ui.user || !can_view_panel(viewer) || (params && !islist(params)))
		return FALSE

	switch(action)
		if("pm")
			var/target_ckey = params?["ckey"]
			if(istext(target_ckey) && length(target_ckey) && target_ckey == ckey(target_ckey))
				viewer.cmd_admin_pm(target_ckey)

		if("follow")
			var/mob/target_mob = locate_mob(params?["mob_ref"])
			if(target_mob)
				viewer.admin_follow(target_mob)

		if("player_panel")
			var/datum/mind/target_mind = locate_mind(params?["mind_ref"])
			var/mob/target_mob = target_mind ? target_mind.current : locate_mob(params?["mob_ref"])
			if(!QDELETED(target_mob))
				SSadmin_verbs.dynamic_invoke_verb(viewer, /datum/admin_verb/show_player_panel, target_mob)

		if("traitor_panel")
			var/datum/mind/target_mind = locate_mind(params?["mind_ref"])
			if(target_mind)
				target_mind.traitor_panel()

		if("vv")
			if(!check_rights_for(viewer, R_DEBUG))
				return FALSE
			var/target_ref = params?["target_ref"]
			var/datum/target = locate_mob(target_ref) || locate_mind(target_ref)
			if(!QDELETED(target))
				viewer.debug_variables(target)

		if("check_teams")
			holder.check_teams()

		if("refresh_current")
			return TRUE

		if("load_history")
			if(history_status == "idle")
				request_history_reload()

		if("refresh_history")
			request_history_reload()

		if("set_limit")
			var/new_limit = params?["limit"]
			if(history_status == "loading" || !isnum(new_limit) || !(new_limit >= 1 && new_limit <= 100) || new_limit != round(new_limit))
				return FALSE
			if(new_limit != history_limit)
				history_limit = new_limit
				request_history_reload()

	return FALSE

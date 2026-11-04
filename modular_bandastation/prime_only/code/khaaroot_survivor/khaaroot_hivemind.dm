/// Retained journal entries, newest first.
#define KHAAROOT_EVENT_LIMIT 50
/// Maximum length of an optional blocked-task explanation.
#define KHAAROOT_REPLY_LIMIT 256
/// Task states shared with KhaarootHivemind.
#define KHAAROOT_TASK_ASSIGNED "assigned"
#define KHAAROOT_TASK_ACCEPTED "accepted"
#define KHAAROOT_TASK_COMPLETED "completed"
#define KHAAROOT_TASK_BLOCKED "blocked"

/// Main controller for Khaaroot hivemind pseudo-antagonist system.
/// Attached to the infector (Apex Field Officer), manages thralls and provides TGUI control interface.
/datum/khaaroot_hivemind
	/// Weakref to the infector's mind
	var/datum/weakref/infector_ref
	/// List of weakrefs to thrall minds
	var/list/datum/weakref/thralls = list()
	/// Team datum for shared HUD
	var/datum/team/khaaroot_hivemind/team
	/// Whether the hivemind is active
	var/active = TRUE
	/// Newest-first journal containing only text and numeric values.
	var/list/events = list()
	/// Monotonic event ID, independent of journal retention.
	var/next_event_id = 0

/datum/khaaroot_hivemind/New(datum/mind/infector)
	infector_ref = WEAKREF(infector)
	team = new(infector)
	team.hivemind_ref = WEAKREF(src)
	infector.add_antag_datum(/datum/antagonist/khaaroot_source, team)

/datum/khaaroot_hivemind/Destroy()
	active = FALSE
	SStgui.close_uis(src)
	for(var/datum/weakref/ref as anything in thralls.Copy())
		var/datum/mind/thrall = ref.resolve()
		if(thrall)
			remove_thrall(thrall, silent = TRUE)
	thralls.Cut()
	var/datum/mind/infector = get_infector()
	var/datum/antagonist/khaaroot_source/source_antag = infector?.has_antag_datum(/datum/antagonist/khaaroot_source)
	if(source_antag?.team == team)
		infector.remove_antag_datum(/datum/antagonist/khaaroot_source)
	QDEL_NULL(team)
	events.Cut()
	infector_ref = null
	return ..()

/// Returns the infector mind, or null
/datum/khaaroot_hivemind/proc/get_infector()
	return infector_ref?.resolve()

/// Resolve the private notification recipient only while its current source role belongs to this hive.
/datum/khaaroot_hivemind/proc/get_infector_mob()
	var/datum/mind/mind = get_infector()
	return is_infector(mind?.current) ? mind.current : null

/// Infects a target mob, making them a thrall
/datum/khaaroot_hivemind/proc/infect(mob/living/carbon/human/target, mob/living/infector)
	if(!active || QDELETED(target) || !is_infector(infector) || target.stat == DEAD)
		return FALSE
	if(!target.mind)
		to_chat(infector, span_warning("Цель не имеет разума для подчинения."))
		return FALSE
	if(HAS_MIND_TRAIT(target, TRAIT_UNCONVERTABLE))
		to_chat(infector, span_warning("Разум цели защищён от воздействия Кхаарут."))
		return FALSE
	if(HAS_TRAIT(target, TRAIT_MINDSHIELD))
		to_chat(infector, span_warning("Щит разума цели блокирует проникновение вируса."))
		return FALSE
	if(target.mind.has_antag_datum(/datum/antagonist/khaaroot_thrall))
		to_chat(infector, span_warning("Цель уже является частью улья Кхаарут."))
		return FALSE
	if(target.mind.has_antag_datum(/datum/antagonist/khaaroot_source))
		to_chat(infector, span_warning("Невозможно заразить источник улья."))
		return FALSE

	thralls += WEAKREF(target.mind)
	target.mind.add_antag_datum(/datum/antagonist/khaaroot_thrall, team)

	RegisterSignal(target.mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_thrall_mind_transferred))
	add_event("[target.mind.name] принят в Улей Кхаарут.")

	to_chat(target, span_userdanger("Чужеродная воля пронзает ваш разум! Вы чувствуете непреодолимую связь с источником улья Кхаарут..."))
	to_chat(infector, span_notice("Вы успешно внедрили вирус Кхаарут в сознание [target.declent_ru(GENITIVE)]."))
	target.do_alert_animation()

	return TRUE

/// Removes a thrall from the hivemind
/datum/khaaroot_hivemind/proc/remove_thrall(datum/mind/thrall_mind, silent = FALSE)
	var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(thrall_mind)
	if(!antag)
		return FALSE
	antag.silent_removal = silent
	return thrall_mind.remove_antag_datum(/datum/antagonist/khaaroot_thrall)

/// Detach subscriptions even when an administrator removes or deletes the antag datum directly.
/datum/khaaroot_hivemind/proc/detach_thrall(datum/mind/thrall_mind, silent = FALSE)
	if(!thrall_mind || !(thrall_mind.weak_reference in thralls))
		return
	thralls -= thrall_mind.weak_reference
	UnregisterSignal(thrall_mind, COMSIG_MIND_TRANSFERRED)
	add_event("[thrall_mind.name] исключён из улья Кхаарут.")
	if(active && !silent)
		broadcast_message("[thrall_mind.name] исключён из улья Кхаарут.")

/// Kill a thrall remotely
/datum/khaaroot_hivemind/proc/kill_thrall(datum/mind/thrall_mind)
	var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(thrall_mind)
	if(!antag || antag.execution_timer)
		return FALSE
	var/mob/living/target = thrall_mind?.current
	if(!target)
		return FALSE
	if(target.stat == DEAD)
		return FALSE

	to_chat(target, span_userdanger("Ваша связь с ульем Кхаарут резко обрывается! Вирус в вашей крови начинает разрушать организм изнутри!"))
	target.visible_message(
		span_danger("[target.real_name] внезапно хватается за голову и падает!"),
		blind_message = span_hear("Вы слышите мучительный крик.")
	)

	target.adjust_oxy_loss(200, forced = TRUE)
	target.adjust_tox_loss(200, forced = TRUE)
	target.emote("scream", intentional = FALSE)

	antag.execution_timer = addtimer(CALLBACK(src, PROC_REF(finish_kill), WEAKREF(thrall_mind), WEAKREF(target), WEAKREF(antag)), 3 SECONDS, TIMER_STOPPABLE)
	return TRUE

/// Finish only the execution that was started on this membership's current body.
/datum/khaaroot_hivemind/proc/finish_kill(datum/weakref/mind_ref, datum/weakref/target_ref, datum/weakref/antag_ref)
	var/datum/mind/thrall_mind = mind_ref?.resolve()
	var/mob/living/target = target_ref?.resolve()
	var/datum/antagonist/khaaroot_thrall/antag = antag_ref?.resolve()
	if(!active || !target || !antag || get_thrall_antag(thrall_mind) != antag || thrall_mind.current != target)
		return
	antag.execution_timer = null
	if(target.stat != DEAD)
		target.death(FALSE)
	remove_thrall(thrall_mind, silent = TRUE)
	broadcast_message("[thrall_mind.name] был умерщвлён через разрыв связи улья.")

/// Send a command/message to a specific thrall from the infector
/datum/khaaroot_hivemind/proc/send_command(datum/mind/thrall_mind, message, mob/living/sender)
	if(!thrall_mind?.current)
		return
	to_chat(thrall_mind.current, span_hypnophrase("<b>Источник улья приказывает:</b><br>«[message]»"))
	if(sender != thrall_mind.current)
		log_directed_talk(sender, thrall_mind.current, message, LOG_SAY, "khaaroot hivemind command")

/// Broadcast a message to all thralls and the infector
/datum/khaaroot_hivemind/proc/broadcast_message(message, mob/living/sender)
	var/is_infector_message = is_infector(sender)
	var/formatted
	if(is_infector_message)
		formatted = "<i><font color='#ff5500' size='+3'>\[Улей Кхаарут\] [sender]: [message]</font></i>"
	else
		formatted = "<i><font color='#ff5500'>\[Улей Кхаарут\] [sender ? "[sender]: " : ""][message]</font></i>"

	var/mob/living/infector_mob = get_infector_mob()

	if(infector_mob)
		to_chat(infector_mob, formatted, type = MESSAGE_TYPE_RADIO, avoid_highlighting = infector_mob == sender)
		if(sender)
			sender.cast_tts(infector_mob, message, is_local = FALSE, effects = list(/datum/singleton/sound_effect/telepathy), channel_override = CHANNEL_TTS_TELEPATHY, check_deafness = FALSE)

	for(var/datum/weakref/ref in thralls)
		var/datum/mind/thrall = ref.resolve()
		var/mob/living/thrall_mob = thrall?.current
		if(thrall_mob)
			to_chat(thrall_mob, formatted, type = MESSAGE_TYPE_RADIO, avoid_highlighting = thrall_mob == sender)
			if(sender)
				sender.cast_tts(thrall_mob, message, is_local = FALSE, effects = list(/datum/singleton/sound_effect/telepathy), channel_override = CHANNEL_TTS_TELEPATHY, check_deafness = FALSE)

	for(var/mob/recipient as anything in GLOB.dead_mob_list)
		var/sender_link = sender ? "[FOLLOW_LINK(recipient, sender)] " : ""
		to_chat(recipient, "[sender_link][formatted]", type = MESSAGE_TYPE_RADIO)

/// Resolve only a registered member belonging to this hive, including one without a body.
/datum/khaaroot_hivemind/proc/get_thrall_antag(datum/mind/thrall)
	if(QDELETED(thrall) || !(WEAKREF(thrall) in thralls))
		return null
	var/datum/antagonist/khaaroot_thrall/antag = thrall.has_antag_datum(/datum/antagonist/khaaroot_thrall)
	return !QDELETED(antag) && antag.team == team ? antag : null

/// Serialize current member state without removing minds whose bodies are absent.
/datum/khaaroot_hivemind/proc/get_thralls_data(datum/mind/only_member)
	var/list/data = list()
	for(var/datum/weakref/ref as anything in thralls)
		var/datum/mind/thrall = ref.resolve()
		if(only_member && thrall != only_member)
			continue
		var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(thrall)
		if(!antag)
			continue
		var/mob/living/body = thrall.current
		if(QDELETED(body))
			body = null
		var/area/location = body ? get_area(body) : null
		data += list(list(
			"name" = thrall.name,
			"ref" = REF(thrall),
			"status" = !body ? "Нет тела" : (body.stat == DEAD ? "Мёртв" : (IS_UNCONSCIOUS(body) ? "Без сознания" : (body.health <= body.crit_threshold ? "Критическое" : "Активен"))),
			"health" = body?.maxHealth ? round((body.health / body.maxHealth) * 100, 1) : 0,
			"location" = location ? location.name : "Неизвестно",
			"objective" = get_thrall_objective(thrall),
			"has_mob" = !!body,
			"has_objective" = !!length(antag.thrall_objective),
			"objective_status" = antag.objective_status,
			"objective_revision" = antag.objective_revision,
			"objective_reply" = antag.objective_reply,
		))
	return data

/// Handler for thrall mind transfer
/datum/khaaroot_hivemind/proc/on_thrall_mind_transferred(datum/mind/source, mob/old_body)
	SIGNAL_HANDLER
	if(!get_thrall_antag(source))
		return
	add_event("[source.name]: смена тела.")
	broadcast_message("Сигнал [source.name] изменился.")

/// Record only state transitions; multiple health/stat/death signals must not duplicate an alert.
/datum/khaaroot_hivemind/proc/update_thrall_state(datum/mind/thrall, mob/living/body)
	var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(thrall)
	if(!active || !antag || thrall.current != body || QDELETED(body))
		return
	var/is_dead = body.stat == DEAD
	var/is_critical = !is_dead && body.health <= body.crit_threshold
	if(is_dead && !antag.was_dead)
		add_event("[thrall.name]: смерть.", "danger", alert_source = TRUE)
	else if(is_critical && !antag.was_critical)
		add_event("[thrall.name]: критическое состояние.", "warning", alert_source = TRUE)
	antag.was_dead = is_dead
	antag.was_critical = is_critical

/// Append a bounded value-only event and optionally notify just the source.
/datum/khaaroot_hivemind/proc/add_event(text, kind = "info", alert_source = FALSE)
	if(!active)
		return
	events.Insert(1, list(list("id" = ++next_event_id, "time" = round_timestamp(), "text" = text, "kind" = kind)))
	if(length(events) > KHAAROOT_EVENT_LIMIT)
		events.Cut(KHAAROOT_EVENT_LIMIT + 1)
	if(alert_source)
		to_chat(get_infector_mob(), span_warning("\[Улей Кхаарут\] [text]"))
	update_ui()

/// Checks if the given mob is the infector
/datum/khaaroot_hivemind/proc/is_infector(mob/user)
	if(QDELETED(user) || !active)
		return FALSE
	var/datum/mind/infector = get_infector()
	var/datum/antagonist/khaaroot_source/antag = infector?.has_antag_datum(/datum/antagonist/khaaroot_source)
	return infector?.current == user && !QDELETED(antag) && antag.team == team

/// Only the current source may manage this hive, including after asynchronous prompts.
/datum/khaaroot_hivemind/proc/can_manage(mob/user)
	return is_infector(user)

/// Only conscious hive participants in their current body may open the panel.
/datum/khaaroot_hivemind/proc/can_interact(mob/user)
	if(!active || QDELETED(user))
		return FALSE
	return isliving(user) && !IS_UNCONSCIOUS_OR_CRIT(user) && (is_infector(user) || (user.mind?.current == user && get_thrall_antag(user.mind)))

/// Updates all open UIs
/datum/khaaroot_hivemind/proc/update_ui()
	SStgui.update_uis(src)

/// Returns the current objective for a thrall
/datum/khaaroot_hivemind/proc/get_thrall_objective(datum/mind/thrall)
	var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(thrall)
	return antag?.thrall_objective || "Нет текущей цели"

/// Sets a new objective for a thrall
/datum/khaaroot_hivemind/proc/set_thrall_objective(datum/mind/thrall, objective_text, mob/actor, expected_revision, datum/antagonist/khaaroot_thrall/expected_antag)
	var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(thrall)
	if(!can_manage(actor) || !can_interact(actor) || !antag || antag != expected_antag || antag.objective_revision != expected_revision || !istext(objective_text) || !length(objective_text))
		return FALSE
	antag.thrall_objective = objective_text
	antag.objective_revision++
	antag.objective_status = KHAAROOT_TASK_ASSIGNED
	antag.objective_reply = ""
	to_chat(thrall.current, span_hypnophrase("<b>Источник улья ставит новую цель:</b><br>«[objective_text]»"))
	add_event("[thrall.name]: новая задача — [objective_text]", "task")
	return TRUE

/// Check the current self-owned task and its allowed transition at the moment of a response.
/datum/khaaroot_hivemind/proc/can_respond_to_objective(mob/user, status, revision, datum/antagonist/khaaroot_thrall/expected_antag)
	if(!can_interact(user) || !isliving(user) || IS_UNCONSCIOUS_OR_CRIT(user) || user.mind?.current != user)
		return FALSE
	var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(user.mind)
	if(!antag || antag != expected_antag || !length(antag.thrall_objective) || !isnum(revision) || antag.objective_revision != revision)
		return FALSE
	switch(antag.objective_status)
		if(KHAAROOT_TASK_ASSIGNED)
			return status == KHAAROOT_TASK_ACCEPTED || status == KHAAROOT_TASK_BLOCKED
		if(KHAAROOT_TASK_ACCEPTED)
			return status == KHAAROOT_TASK_COMPLETED || status == KHAAROOT_TASK_BLOCKED
		if(KHAAROOT_TASK_BLOCKED)
			return status == KHAAROOT_TASK_ACCEPTED
	return FALSE

/// Apply a validated self response; stale, duplicate, and replaced-membership responses have no side effects.
/datum/khaaroot_hivemind/proc/respond_to_objective(mob/user, status, revision, reply = "", datum/antagonist/khaaroot_thrall/expected_antag)
	if(!can_respond_to_objective(user, status, revision, expected_antag) || !istext(reply) || length_char(reply) > KHAAROOT_REPLY_LIMIT)
		return FALSE
	expected_antag.objective_status = status
	expected_antag.objective_reply = status == KHAAROOT_TASK_BLOCKED ? reply : ""
	var/response_text
	switch(status)
		if(KHAAROOT_TASK_ACCEPTED)
			response_text = "задача принята"
		if(KHAAROOT_TASK_COMPLETED)
			response_text = "задача выполнена"
		if(KHAAROOT_TASK_BLOCKED)
			response_text = "не могу выполнить задачу[length(reply) ? ": [reply]" : ""]"
	add_event("[user.mind.name]: [response_text].", "task")
	return TRUE

// TGUI INTERACTION

/datum/khaaroot_hivemind/ui_interact(mob/user, datum/tgui/ui)
	if(!can_interact(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "KhaarootHivemind", "Улей Кхаарут")
		ui.open()

/datum/khaaroot_hivemind/ui_state(mob/user)
	return GLOB.always_state

/datum/khaaroot_hivemind/ui_status(mob/user, datum/ui_state/state)
	if(!can_interact(user))
		return UI_CLOSE
	return ..()

/datum/khaaroot_hivemind/ui_static_data(mob/user)
	return list()

/datum/khaaroot_hivemind/ui_data(mob/user)
	var/manage = can_manage(user) && can_interact(user)
	var/list/member_data = list()
	if(manage)
		member_data = get_thralls_data()
	else if(can_interact(user) && get_thrall_antag(user.mind))
		member_data = get_thralls_data(user.mind)
	return list(
		"can_manage" = manage,
		"thralls" = member_data,
		"thrall_count" = length(member_data),
		"events" = manage ? events : list(),
	)

/datum/khaaroot_hivemind/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!islist(params))
		return
	var/mob/actor = ui.user
	if(!can_interact(actor))
		return
	if(action == "refresh")
		update_ui()
		return TRUE
	if(action == "respond_objective")
		var/datum/antagonist/khaaroot_thrall/antag = get_thrall_antag(actor.mind)
		var/response_status = params["status"]
		var/revision = params["revision"]
		if(!can_respond_to_objective(actor, response_status, revision, antag))
			return
		var/reply = ""
		if(response_status == KHAAROOT_TASK_BLOCKED)
			var/datum/weakref/antag_ref = WEAKREF(antag)
			antag = null
			reply = tgui_input_text(actor, "Что мешает выполнить задачу? Причину можно оставить пустой.", "Ответ улью", max_length = KHAAROOT_REPLY_LIMIT)
			if(isnull(reply))
				return
			antag = antag_ref.resolve()
		return respond_to_objective(actor, response_status, revision, reply, antag)
	if(!can_manage(actor))
		return
	var/datum/mind/target = find_thrall_mind(params["ref"])
	var/datum/antagonist/khaaroot_thrall/target_antag = get_thrall_antag(target)
	if(!target_antag)
		return
	var/revision = target_antag.objective_revision
	var/datum/weakref/body_ref = WEAKREF(target.current)
	var/datum/weakref/target_ref = WEAKREF(target)
	var/datum/weakref/target_antag_ref = WEAKREF(target_antag)
	var/target_name = target.name
	var/has_body = !QDELETED(target.current)
	target = null
	target_antag = null

	switch(action)
		if("send_command")
			if(!has_body)
				return
			var/message = tgui_input_text(actor, "Введите команду для [target_name]:", "Команда улья", max_length = MAX_MESSAGE_LEN)
			target = target_ref.resolve()
			target_antag = target_antag_ref.resolve()
			if(!message || !can_manage(actor) || !can_interact(actor) || !target || !target_antag || get_thrall_antag(target) != target_antag || target_antag.objective_revision != revision || QDELETED(target.current) || target.current != body_ref?.resolve())
				return
			send_command(target, message, actor)
			return TRUE

		if("set_objective")
			var/objective = tgui_input_text(actor, "Введите цель для [target_name]:", "Цель улья", max_length = MAX_MESSAGE_LEN)
			target = target_ref.resolve()
			target_antag = target_antag_ref.resolve()
			return set_thrall_objective(target, objective, actor, revision, target_antag)

		if("kill_thrall")
			if(!has_body)
				return
			var/confirm = tgui_alert(actor, "Вы уверены, что хотите умертвить [target_name]? Это необратимо.", "Подтверждение", list("Да", "Нет"))
			target = target_ref.resolve()
			target_antag = target_antag_ref.resolve()
			if(confirm != "Да" || !can_manage(actor) || !can_interact(actor) || !target || !target_antag || get_thrall_antag(target) != target_antag || target_antag.objective_revision != revision || QDELETED(target.current) || target.current != body_ref?.resolve())
				return
			kill_thrall(target)
			return TRUE

/// Find a thrall mind by its REF string
/datum/khaaroot_hivemind/proc/find_thrall_mind(ref_string)
	for(var/datum/weakref/ref in thralls)
		var/datum/mind/mind = ref.resolve()
		if(mind && REF(mind) == ref_string && get_thrall_antag(mind))
			return mind
	return null


// ============================================================
//  ANTAGONIST DATUMS
// ============================================================

/// Hidden antagonist datum for the infector — provides HUD icon, team membership, and hivemind communication.
/// Does NOT appear in round-end reports or regular antagonist lists.
/datum/antagonist/khaaroot_source
	name = "источник Улья Кхаарут"
	roundend_category = "Улей Кхаарут"
	show_in_roundend = FALSE
	antagpanel_category = "Улей Кхаарут"
	show_in_antagpanel = FALSE
	show_to_ghosts = FALSE
	hud_icon = 'modular_bandastation/prime_only/icons/antag_hud.dmi'
	antag_hud_name = "khaaroot_source"
	ui_name = null
	pref_flag = NONE
	jobban_flag = NONE
	replace_banned = FALSE
	can_elimination_hijack = ELIMINATION_NEUTRAL

	/// Reference to the team
	var/datum/team/khaaroot_hivemind/team
	/// Antag-owned actions are recreated on transfer and removed with the role.
	var/datum/action/cooldown/khaaroot_hivemind_comm/comm_action
	/// Source control panel action.
	var/datum/action/cooldown/khaaroot_hivemind_panel/panel_action
	/// Exact-role-owned full mutation set, rebound concealed on body transfer.
	var/datum/khaaroot_mutations/mutations

/datum/antagonist/khaaroot_source/create_team(datum/team/kh_team)
	team = kh_team

/datum/antagonist/khaaroot_source/get_team()
	return team

/** Release the exact source role's body effects and owned mutation controller. */
/datum/antagonist/khaaroot_source/Destroy()
	if(owner?.current)
		remove_innate_effects(owner.current)
	QDEL_NULL(comm_action)
	QDEL_NULL(panel_action)
	QDEL_NULL(mutations)
	team = null
	return ..()

/** Recreate source actions on the current body, retaining its full role-owned mutation set. */
/datum/antagonist/khaaroot_source/apply_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/target = mob_override || owner.current
	add_team_hud(target, /datum/antagonist/khaaroot_thrall)
	ADD_TRAIT(target, TRAIT_UNCONVERTABLE, REF(src))
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	if(hivemind)
		comm_action = new(hivemind, src)
		comm_action.Grant(target)
		panel_action = new(hivemind, src)
		panel_action.Grant(target)
		mutations ||= new(src)
		mutations.bind(target)

/// Remove body-bound source effects on both role removal and mind transfer.
/datum/antagonist/khaaroot_source/remove_innate_effects(mob/living/mob_override)
	mutations?.unbind()
	var/mob/living/target = mob_override || owner?.current
	if(target)
		REMOVE_TRAIT(target, TRAIT_UNCONVERTABLE, REF(src))
	QDEL_NULL(comm_action)
	QDEL_NULL(panel_action)
	QDEL_NULL(team_hud_ref)
	return ..()


/// Antagonist datum for Khaaroot-infected thralls — provides HUD icon, team membership, hivemind communication, and configurable objective.
/datum/antagonist/khaaroot_thrall
	name = "заражённый Ульем Кхаарут"
	roundend_category = "Улей Кхаарут"
	show_in_roundend = FALSE
	antagpanel_category = "Улей Кхаарут"
	show_in_antagpanel = FALSE
	show_to_ghosts = FALSE
	hud_icon = 'modular_bandastation/prime_only/icons/antag_hud.dmi'
	antag_hud_name = "khaaroot_thrall"
	ui_name = null
	pref_flag = NONE
	jobban_flag = NONE
	replace_banned = FALSE
	can_elimination_hijack = ELIMINATION_NEUTRAL

	/// Reference to the team
	var/datum/team/khaaroot_hivemind/team

	/// Custom objective set by the infector
	var/thrall_objective
	/// Version of the current assignment; old dialogs cannot answer a replacement task.
	var/objective_revision = 0
	/// Current task state shared with the source and this member only.
	var/objective_status = KHAAROOT_TASK_ASSIGNED
	/// Optional explanation of an obstacle, cleared on a new assignment or acceptance.
	var/objective_reply = ""
	/// Last observed critical state for transition deduplication.
	var/was_critical = FALSE
	/// Last observed death state for transition deduplication.
	var/was_dead = FALSE
	/// Preserve remove_thrall()'s silent broadcast contract during antag removal.
	var/silent_removal = FALSE
	/// Current subscribed body; no strong reference survives deletion.
	var/datum/weakref/observed_body_ref
	/// Stop a queued execution when its body or membership changes.
	var/execution_timer
	/// Antag-owned telepathy action.
	var/datum/action/cooldown/khaaroot_hivemind_comm/comm_action
	/// Self-only task panel action.
	var/datum/action/cooldown/khaaroot_hivemind_panel/panel_action
	/// Membership-owned mutations retain the chosen specialization across body transfers.
	var/datum/khaaroot_mutations/mutations

/datum/antagonist/khaaroot_thrall/create_team(datum/team/kh_team)
	team = kh_team

/datum/antagonist/khaaroot_thrall/get_team()
	return team

/datum/antagonist/khaaroot_thrall/Destroy()
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	hivemind?.detach_thrall(owner, silent_removal)
	remove_innate_effects(owner?.current)
	QDEL_NULL(mutations)
	team = null
	return ..()

/datum/antagonist/khaaroot_thrall/apply_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/target = mob_override || owner.current
	add_team_hud(target, type)
	ADD_TRAIT(target, TRAIT_FEARLESS, REF(src))
	observed_body_ref = WEAKREF(target)
	was_dead = target.stat == DEAD
	was_critical = !was_dead && target.health <= target.crit_threshold
	RegisterSignals(target, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_MOB_STATCHANGE, COMSIG_LIVING_DEATH), PROC_REF(on_body_state_changed))
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_body_deleted))
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	if(hivemind)
		comm_action = new(hivemind, src)
		comm_action.Grant(target)
		panel_action = new(hivemind, src)
		panel_action.Grant(target)
		mutations ||= new(src)
		mutations.bind(target)

/// Release old-body subscriptions and actions before applying the role to another body.
/datum/antagonist/khaaroot_thrall/remove_innate_effects(mob/living/mob_override)
	mutations?.unbind()
	if(execution_timer)
		deltimer(execution_timer)
		execution_timer = null
	var/mob/living/observed_body = observed_body_ref?.resolve()
	if(observed_body)
		UnregisterSignal(observed_body, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_MOB_STATCHANGE, COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	observed_body_ref = null
	var/mob/living/target = mob_override || owner?.current
	if(target)
		REMOVE_TRAIT(target, TRAIT_FEARLESS, REF(src))
	QDEL_NULL(comm_action)
	QDEL_NULL(panel_action)
	QDEL_NULL(team_hud_ref)
	return ..()

/// Forward real body transitions to the owning controller without yielding.
/datum/antagonist/khaaroot_thrall/proc/on_body_state_changed(mob/living/source)
	SIGNAL_HANDLER
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	hivemind?.update_thrall_state(owner, source)

/// Losing a body closes its actions but keeps the mind, task, and transfer subscription.
/datum/antagonist/khaaroot_thrall/proc/on_body_deleted(mob/living/source)
	SIGNAL_HANDLER
	mutations?.unbind()
	if(execution_timer)
		deltimer(execution_timer)
		execution_timer = null
	UnregisterSignal(source, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_MOB_STATCHANGE, COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	observed_body_ref = null
	QDEL_NULL(comm_action)
	QDEL_NULL(panel_action)
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	hivemind?.update_ui()

/datum/antagonist/khaaroot_thrall/on_gain()
	. = ..()
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	if(hivemind)
		hivemind.broadcast_message("[owner.name] принят в Улей Кхаарут.")

/datum/antagonist/khaaroot_thrall/on_removal()
	var/datum/khaaroot_hivemind/hivemind = team?.hivemind_ref?.resolve()
	hivemind?.detach_thrall(owner, silent_removal)
	. = ..()


// ============================================================
//  TEAM DATUM
// ============================================================

/// Team datum for Khaaroot hivemind — enables shared HUD icons between infector and thralls.
/datum/team/khaaroot_hivemind
	name = "\improper Khaaroot Hivemind"
	member_name = "участник улья"
	show_roundend_report = FALSE
	/// Weakref back to the hivemind controller
	var/datum/weakref/hivemind_ref

#undef KHAAROOT_EVENT_LIMIT
#undef KHAAROOT_REPLY_LIMIT
#undef KHAAROOT_TASK_ASSIGNED
#undef KHAAROOT_TASK_ACCEPTED
#undef KHAAROOT_TASK_COMPLETED
#undef KHAAROOT_TASK_BLOCKED

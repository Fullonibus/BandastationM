/**
 * # Artifact analyser
 *
 * Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/machines/artifact_analyzer.dm,
 * rewritten for Voidcrew. Machine art from Nova's machinery.dmi (by way of TauCetiClassic),
 * CC BY-SA 3.0; see icons/study.dmi.
 *
 * - A tgui instrument instead of Nova's HTML window: a live trace of the find on the pad, the last
 *   reading, and a paper tape of everything the pad sensed while the crew tested it.
 * - A scan claims the find with try_lock() and lets go on finish, halt, power loss, the find
 *   leaving the pad, and Destroy(). Nova's halt never let go, which jammed the find for good.
 * - The report is lab paperwork: serial, condition, and one report_line() per emission. It names
 *   what the find gives off, never what it does.
 * - The first full analysis of a dug find pays research once, as notes (research.dm).
 */

/// Sent on a scan pad (scanpad.dm) when a large find arrives on it or leaves it, or the pad itself
/// changes: (). Defined here because this file compiles first; the harvester listens for it too.
#define COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED "xenoarch_pad_specimen_changed"

/// Lines the tape keeps before the oldest scrolls off.
#define ANALYSER_TAPE_LENGTH 12
/// A repeated tape line within this long adds to the line before instead of printing again.
#define ANALYSER_TAPE_REPEAT_WINDOW (20 SECONDS)

// Tape line tones, for the screen.
#define TAPE_NOTE "note"
#define TAPE_RESPONSE "response"
#define TAPE_QUIET "quiet"
#define TAPE_FAULT "fault"

/obj/machinery/artifact_analyser
	name = "анализатор артефактов"
	desc = "Настольная консоль с медленным зелёным экраном и узкой щелью принтера. Сзади к полу уходит кабель."
	icon = 'modular_bandastation/xenoarchaeology/icons/study.dmi'
	icon_state = "analyser"
	base_icon_state = "analyser"
	density = TRUE
	anchored = TRUE
	circuit = /obj/item/circuitboard/machine/artifact_analyser
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	/// The scan pad it reads through
	var/obj/machinery/artifact_scanpad/pad
	/// The find on that pad whose stirrings go on the tape
	var/obj/machinery/artifact/watched
	/// The find being scanned, which this analyser holds the lock on
	var/obj/machinery/artifact/scan_target
	/// Who started the scan, for the research log
	var/datum/weakref/scan_operator
	/// world.time the scan began
	var/scan_started = 0
	/// How long a scan takes; better scanning modules shorten it
	var/scan_time = 10 SECONDS
	/// Timer that ends the scan
	var/scan_timer
	/// The last completed reading, as the screen shows it
	var/list/reading
	/// The find that reading belongs to
	var/datum/weakref/reading_of
	/// The tape: list(list("time", "text", "tone", "count", "at"))
	var/list/tape = list()
	/// Reports printed, for the report number
	var/reports_printed = 0
	/// Delay between the printer starting and the paper coming out
	var/print_delay = 1.5 SECONDS
	/// list(name, text, research points) of a report still in the printer
	var/list/pending_printout
	/// Wakes waiting to go on the tape after whatever stimulus caused them
	var/list/pending_lines
	COOLDOWN_DECLARE(tear_cooldown)

/obj/machinery/artifact_analyser/post_machine_initialize()
	. = ..()
	find_pad()

/obj/machinery/artifact_analyser/Destroy()
	eject_printout()
	abort_scan(quiet = TRUE)
	set_watched(null, quiet = TRUE)
	set_pad(null)
	reading = null
	reading_of = null
	scan_operator = null
	pending_lines = null
	return ..()

/obj/machinery/artifact_analyser/RefreshParts()
	. = ..()
	// Two stock modules make a ten-second scan; the best modules cut it to six.
	var/rating = 0
	for(var/datum/stock_part/scanning_module/part in component_parts)
		rating += part.tier
	rating = max(rating, 2)
	scan_time = max(6 SECONDS, 10 SECONDS - (rating - 2) * (4 SECONDS / 6))

// ===== The pad =====

/// Finds a scan pad next to it, preferring the one it faces.
/obj/machinery/artifact_analyser/proc/find_pad()
	if(pad && !QDELETED(pad) && get_dist(src, pad) <= 1)
		return pad
	var/obj/machinery/artifact_scanpad/found = locate() in get_step(src, dir)
	if(!found)
		for(var/obj/machinery/artifact_scanpad/nearby in orange(1, src))
			found = nearby
			break
	set_pad(found)
	return pad

/obj/machinery/artifact_analyser/proc/set_pad(obj/machinery/artifact_scanpad/new_pad)
	if(new_pad == pad)
		return
	if(pad)
		abort_scan("Площадка потеряна. Скан остановлен.")
		UnregisterSignal(pad, list(COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED, COMSIG_QDELETING))
	pad = new_pad
	if(pad)
		RegisterSignal(pad, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED, PROC_REF(on_pad_changed))
		RegisterSignal(pad, COMSIG_QDELETING, PROC_REF(on_pad_deleted))
	refresh_watch()

/obj/machinery/artifact_analyser/proc/on_pad_deleted(datum/source)
	SIGNAL_HANDLER
	set_pad(null)
	SStgui.update_uis(src)

/obj/machinery/artifact_analyser/proc/on_pad_changed(datum/source)
	SIGNAL_HANDLER
	if(pad && get_dist(src, pad) > 1)
		set_pad(null)
	else
		refresh_watch()
	SStgui.update_uis(src)

/obj/machinery/artifact_analyser/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(pad && get_dist(src, pad) > 1)
		set_pad(null)

/// Ready to read the pad: powered, bolted down, closed up.
/obj/machinery/artifact_analyser/proc/can_operate()
	return is_operational && anchored && !panel_open

// ===== Watching the find on the pad =====

/// Follows whatever now stands on the pad, and drops a scan whose find has gone.
/obj/machinery/artifact_analyser/proc/refresh_watch()
	var/obj/machinery/artifact/on_pad = (pad && !QDELETED(pad)) ? pad.get_specimen() : null
	if(scan_target && (scan_target != on_pad || !pad.can_scan()))
		abort_scan(scan_target == on_pad ? "Площадка отключена. Скан остановлен." : "Образец сдвинут. Скан потерян.")
	set_watched(on_pad)

/obj/machinery/artifact_analyser/proc/set_watched(obj/machinery/artifact/find, quiet = FALSE)
	if(find == watched)
		return
	if(watched)
		UnregisterSignal(watched, list(
			COMSIG_ARTIFACT_STIMULATED,
			COMSIG_ARTIFACT_EFFECT_ACTIVATED,
			COMSIG_ARTIFACT_EFFECT_DEACTIVATED,
			COMSIG_ARTIFACT_LABEL_CHANGED,
			COMSIG_QDELETING,
		))
		if(!quiet && !find)
			add_tape("Площадка свободна.", TAPE_NOTE)
	watched = find
	pending_lines = null
	if(!watched)
		return
	RegisterSignal(watched, COMSIG_ARTIFACT_STIMULATED, PROC_REF(on_stimulated))
	RegisterSignal(watched, COMSIG_ARTIFACT_EFFECT_ACTIVATED, PROC_REF(on_effect_woke))
	RegisterSignal(watched, COMSIG_ARTIFACT_EFFECT_DEACTIVATED, PROC_REF(on_effect_slept))
	RegisterSignal(watched, COMSIG_ARTIFACT_LABEL_CHANGED, PROC_REF(on_label_changed))
	RegisterSignal(watched, COMSIG_QDELETING, PROC_REF(on_watched_deleted))
	if(!quiet)
		add_tape("На площадке: [specimen_name(watched)].", TAPE_NOTE)
		if(watched.is_active())
			add_tape("Активен при поступлении.", TAPE_RESPONSE)

/obj/machinery/artifact_analyser/proc/on_watched_deleted(datum/source)
	SIGNAL_HANDLER
	if(scan_target == source)
		abort_scan("Образец потерян. Скан остановлен.")
	set_watched(null)
	SStgui.update_uis(src)

/// "Kappa-4412", or a plain description for a find nobody tagged.
/obj/machinery/artifact_analyser/proc/specimen_name(obj/machinery/artifact/find)
	return find.is_dug() ? find.serial : "Находка без метки"

/// "Основное" or "Вторичное": which of the find's emissions an effect is.
/obj/machinery/artifact_analyser/proc/channel_name(datum/artifact_effect/effect)
	if(watched && effect == watched.second_effect)
		return "Вторичное"
	return "Основное"

/// A stimulus reached the find: the tape records it, and whether anything answered.
/obj/machinery/artifact_analyser/proc/on_stimulated(datum/source, trigger, mob/living/user, woke)
	SIGNAL_HANDLER
	if(!can_operate())
		return
	add_tape("[artifact_trigger_name(trigger)]. [woke ? "Есть реакция." : "Реакции нет."]", woke ? TAPE_RESPONSE : TAPE_QUIET)
	var/obj/machinery/artifact/find = source
	find.journal_note(user, "Воздействие на площадке: [artifact_trigger_name(trigger)] — [woke ? "есть реакция" : "реакции нет"].")
	if(woke)
		flick("[base_icon_state]_alert", src)
		playsound(src, 'sound/machines/beep/twobeep.ogg', 25, FALSE)

/// An emission rose. Held a moment, so the stimulus that caused it prints first.
/obj/machinery/artifact_analyser/proc/on_effect_woke(datum/source, datum/artifact_effect/effect)
	SIGNAL_HANDLER
	if(!can_operate())
		return
	LAZYADD(pending_lines, "[channel_name(effect)] излучение растёт.")
	addtimer(CALLBACK(src, PROC_REF(flush_pending_lines)), 1, TIMER_UNIQUE)

/obj/machinery/artifact_analyser/proc/on_effect_slept(datum/source, datum/artifact_effect/effect)
	SIGNAL_HANDLER
	if(!can_operate())
		return
	add_tape("[channel_name(effect)] излучение угасает.", TAPE_QUIET)
	SStgui.update_uis(src)

/obj/machinery/artifact_analyser/proc/flush_pending_lines()
	for(var/line in pending_lines)
		add_tape(line, TAPE_RESPONSE)
	pending_lines = null
	SStgui.update_uis(src)

/obj/machinery/artifact_analyser/proc/on_label_changed(datum/source)
	SIGNAL_HANDLER
	SStgui.update_uis(src)

/// Prints a line on the tape, folding a quick repeat into the line before.
/obj/machinery/artifact_analyser/proc/add_tape(text, tone = TAPE_NOTE)
	var/list/last = length(tape) ? tape[length(tape)] : null
	if(last && last["text"] == text && world.time - last["at"] < ANALYSER_TAPE_REPEAT_WINDOW)
		last["count"] += 1
		last["at"] = world.time
		last["time"] = round_timestamp("hh:mm:ss")
	else
		tape += list(list(
			"time" = round_timestamp("hh:mm:ss"),
			"text" = text,
			"tone" = tone,
			"count" = 1,
			"at" = world.time,
		))
		if(length(tape) > ANALYSER_TAPE_LENGTH)
			tape.Cut(1, 2)
	SStgui.update_uis(src)

// ===== Scanning =====

/// Starts a scan of the find on the pad. Returns TRUE if one began.
/obj/machinery/artifact_analyser/proc/start_scan(mob/user)
	if(scan_target || !can_operate())
		return FALSE
	find_pad()
	if(!pad)
		say("Площадка не подключена.")
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 30, FALSE)
		return FALSE
	if(!pad.can_scan())
		say("Площадка отключена.")
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 30, FALSE)
		return FALSE
	var/obj/machinery/artifact/find = pad.get_specimen()
	if(!find)
		if(catalogue_small_find(user))
			return FALSE
		say("На площадке ничего нет.")
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 30, FALSE)
		return FALSE
	if(!find.try_lock(src))
		say("Слишком сильные помехи.")
		add_tape("Помехи. Скан отклонён.", TAPE_FAULT)
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 30, FALSE)
		return FALSE
	set_watched(find)
	scan_target = find
	scan_operator = user ? WEAKREF(user) : null
	scan_started = world.time
	scan_timer = addtimer(CALLBACK(src, PROC_REF(finish_scan)), scan_time, TIMER_STOPPABLE | TIMER_DELETE_ME)
	pad.set_beam(TRUE)
	update_use_power(ACTIVE_POWER_USE)
	update_appearance()
	playsound(src, 'sound/machines/terminal/terminal_processing.ogg', 30, FALSE)
	add_tape("Скан начат.", TAPE_NOTE)
	return TRUE

/// Stops a scan before it finishes and lets go of the find.
/obj/machinery/artifact_analyser/proc/abort_scan(reason, quiet = FALSE)
	if(!scan_target)
		return
	if(scan_timer)
		deltimer(scan_timer)
		scan_timer = null
	var/obj/machinery/artifact/find = scan_target
	scan_target = null
	scan_operator = null
	if(!QDELETED(find))
		find.release_lock(src)
	if(pad && !QDELETED(pad))
		pad.set_beam(FALSE)
	if(QDELETED(src))
		return
	update_use_power(IDLE_POWER_USE)
	update_appearance()
	if(quiet)
		return
	if(reason)
		add_tape(reason, TAPE_FAULT)
	playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 30, FALSE)
	SStgui.update_uis(src)

/// The scan ran its full length: read the find, print the report, pay research once.
/obj/machinery/artifact_analyser/proc/finish_scan()
	scan_timer = null
	var/obj/machinery/artifact/find = scan_target
	if(QDELETED(find) || !pad || QDELETED(pad) || pad.get_specimen() != find || !pad.can_scan() || !can_operate())
		abort_scan("Образец потерян. Скан остановлен.")
		return
	var/mob/operator = scan_operator?.resolve()
	reading = build_reading(find)
	reading_of = WEAKREF(find)
	var/report_text = report_text(find)
	var/report_name = "отчёт анализа ([specimen_name(find)])"
	// Research is claimed now, while the find is still locked to us, and printed with the report.
	var/research_points = xenoarch_claim_analysis(find, src, operator)
	if(research_points)
		xenoarch_record_study(find.main_effect?.energy_kind)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_CATALOGUED, find, operator, src)
	find.journal_note(operator, "Анализ: основное излучение — [find.main_effect ? find.main_effect.report_line() : "не обнаружено"]; второе — [find.second_effect ? find.second_effect.report_line() : "не обнаружено"].")
	scan_target = null
	scan_operator = null
	find.release_lock(src)
	pad.set_beam(FALSE)
	update_use_power(IDLE_POWER_USE)
	update_appearance()
	say("Анализ завершён.")
	playsound(src, 'sound/machines/ping.ogg', 30, FALSE)
	playsound(src, 'sound/machines/printer.ogg', 35, FALSE)
	add_tape(research_points ? "Скан завершён. Отчёт и данные напечатаны." : "Скан завершён. Отчёт напечатан.", TAPE_NOTE)
	// Held on the machine until it prints, so a console torn down mid-print still drops it.
	eject_printout()
	pending_printout = list(report_name, report_text, research_points)
	if(print_delay)
		addtimer(CALLBACK(src, PROC_REF(eject_printout)), print_delay)
	else
		eject_printout()

/// Drops the waiting report, and the research notes if that analysis paid any.
/obj/machinery/artifact_analyser/proc/eject_printout()
	if(!pending_printout)
		return
	var/report_name = pending_printout[1]
	var/report_text = pending_printout[2]
	var/research_points = pending_printout[3]
	pending_printout = null
	var/turf/out = drop_location()
	if(!out)
		return
	var/obj/item/paper/artifact_report/report = new(out)
	report.name = report_name
	report.add_raw_text(report_text, advanced_html = TRUE)
	report.update_appearance()
	INVOKE_ASYNC(report, TYPE_PROC_REF(/obj/item/paper/artifact_report, stamp_report))
	if(research_points)
		xenoarch_print_analysis_notes(out, research_points)

/// What the screen shows for a finished reading.
/obj/machinery/artifact_analyser/proc/build_reading(obj/machinery/artifact/find)
	var/list/channels = list()
	if(find.main_effect)
		channels += list(effect_reading("Основное", find.main_effect))
	if(find.second_effect)
		channels += list(effect_reading("Вторичное", find.second_effect))
	return list(
		"serial" = specimen_name(find),
		"name" = find.name,
		"damaged" = find.damaged,
		"channels" = channels,
	)

/obj/machinery/artifact_analyser/proc/effect_reading(channel, datum/artifact_effect/effect)
	var/list/parts = effect.report_parts()
	return list(
		"channel" = channel,
		"kind" = parts["kind"],
		"kind_key" = effect.energy_kind,
		"release" = parts["release"],
		"release_key" = effect.release_method,
		"family" = parts["family"],
	)

/// The printed report: lab paperwork with blanks for the analyst.
/obj/machinery/artifact_analyser/proc/report_text(obj/machinery/artifact/find)
	reports_printed++
	var/list/lines = list()
	lines += "<center><b>КСЕНОАРХЕОЛОГИЯ</b><br>Отчёт анализа № [reports_printed]<br><small>[round_timestamp("hh:mm")]</small></center>"
	lines += "<hr>"
	lines += "<b>Образец:</b> [specimen_name(find)], [find.name]<br>"
	lines += "<b>Состояние:</b> [find.damaged ? "с трещинами" : "целый"]<br>"
	lines += "<br>"
	if(!find.main_effect && !find.second_effect)
		lines += "Излучений не обнаружено.<br>"
	else
		lines += "<b>Основное излучение:</b> [find.main_effect ? find.main_effect.report_line() : "не обнаружено."]<br>"
		lines += "<b>Вторичное излучение:</b> [find.second_effect ? find.second_effect.report_line() : "не обнаружено."]<br>"
	lines += "<hr>"
	lines += "<b>Наблюдения:</b> \[____________________________________\]<br>"
	lines += "\[____________________________________________________\]<br>"
	lines += "<b>Аналитик:</b> \[____________________\]"
	return lines.Join("\n")

/// Tears the tape off as a paper slip.
/obj/machinery/artifact_analyser/proc/tear_tape(mob/user)
	if(!length(tape) || !COOLDOWN_FINISHED(src, tear_cooldown))
		return FALSE
	COOLDOWN_START(src, tear_cooldown, 2 SECONDS)
	var/obj/item/paper/artifact_tape/slip = new(drop_location())
	var/list/lines = list()
	for(var/list/entry as anything in tape)
		lines += "[entry["time"]]  [entry["text"]][entry["count"] > 1 ? " (x[entry["count"]])" : ""]"
	slip.add_raw_text("<tt>[lines.Join("<br>\n")]</tt>", advanced_html = TRUE)
	slip.update_appearance()
	tape.Cut()
	playsound(src, 'sound/items/poster/poster_ripped.ogg', 30, TRUE)
	if(user)
		user.put_in_hands(slip)
	return TRUE

// ===== Power, tools and looks =====

/obj/machinery/artifact_analyser/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		abort_scan("Питание потеряно. Скан остановлен.")
	update_appearance()

/obj/machinery/artifact_analyser/update_icon_state()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
	else if(!is_operational)
		icon_state = "[base_icon_state]_off"
	else if(scan_target)
		icon_state = "[base_icon_state]_working"
	else
		icon_state = base_icon_state
	return ..()

/obj/machinery/artifact_analyser/update_overlays()
	. = ..()
	if(!panel_open && is_operational)
		. += emissive_appearance(icon, "[base_icon_state]_screen", src, alpha = 120)

/obj/machinery/artifact_analyser/screwdriver_act(mob/living/user, obj/item/tool)
	if(!default_deconstruction_screwdriver(user, "[base_icon_state]_open", base_icon_state, tool))
		return NONE
	if(panel_open)
		abort_scan("Панель открыта. Скан остановлен.")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/artifact_analyser/crowbar_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_crowbar(tool))
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/machinery/artifact_analyser/wrench_act(mob/living/user, obj/item/tool)
	if(scan_target)
		balloon_alert(user, "идёт скан!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool) == SUCCESSFUL_UNFASTEN)
		find_pad()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/artifact_analyser/examine(mob/user)
	. = ..()
	if(!pad)
		. += "Лампа площадки не горит."
	else if(scan_target)
		. += span_notice("По экрану бегут цифры.")

// ===== tgui =====

/obj/machinery/artifact_analyser/ui_interact(mob/user, datum/tgui/ui)
	find_pad()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoarchAnalyser", name)
		ui.open()

/obj/machinery/artifact_analyser/ui_static_data(mob/user)
	var/list/colors = list()
	for(var/key in GLOB.artifact_energy_kinds)
		var/datum/artifact_energy_kind/kind = GLOB.artifact_energy_kinds[key]
		colors[key] = kind.color
	return list("kind_colors" = colors)

/obj/machinery/artifact_analyser/ui_data(mob/user)
	var/list/data = list()
	data["powered"] = can_operate()
	if(!pad || QDELETED(pad))
		data["pad"] = "none"
	else
		data["pad"] = pad.can_scan() ? "ready" : "offline"
	data["scanning"] = !!scan_target
	data["progress"] = scan_target ? clamp(round((world.time - scan_started) / scan_time * 100), 0, 100) : 0
	data["specimen"] = null
	if(watched && !QDELETED(watched))
		data["specimen"] = list(
			"serial" = specimen_name(watched),
			"name" = watched.name,
			"awake" = !!watched.is_active() && !watched.suppressed,
			"resting" = !!watched.all_awake_resting(),
			"label" = watched.label ? "[watched.label.effect_name] / [watched.label.trigger_name] / [watched.label.second_name]" : null,
		)
	data["reading"] = null
	if(reading)
		var/obj/machinery/artifact/subject = reading_of?.resolve()
		var/current = !!(subject && subject == watched)
		var/list/shown = reading.Copy()
		shown["current"] = current
		// While the read find is on the pad, each emission's trace follows it live.
		var/list/channels = list()
		for(var/list/channel as anything in reading["channels"])
			var/list/live = channel.Copy()
			var/datum/artifact_effect/effect = null
			if(current)
				effect = channel["channel"] == "Вторичное" ? subject.second_effect : subject.main_effect
			live["awake"] = !!(effect?.activated && !subject.suppressed)
			live["resting"] = !!(effect?.activated && effect.exhausted)
			channels += list(live)
		shown["channels"] = channels
		data["reading"] = shown
	var/list/tape_lines = list()
	for(var/list/entry as anything in tape)
		tape_lines += list(list("time" = entry["time"], "text" = entry["text"], "tone" = entry["tone"], "count" = entry["count"]))
	data["tape"] = tape_lines
	return data

/obj/machinery/artifact_analyser/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	switch(action)
		if("scan")
			if(start_scan(user))
				return TRUE
		if("halt")
			if(scan_target)
				say("Скан прерван.")
				abort_scan("Скан прерван.")
				return TRUE
		if("tear")
			return tear_tape(user)
	return FALSE

// ===== Paperwork =====

/// The printed analysis report.
/obj/item/paper/artifact_report
	name = "отчёт анализа"

/// The analyser's stamp across the report.
/obj/item/paper/artifact_report/proc/stamp_report()
	var/datum/asset/spritesheet_batched/sheet = get_asset_datum(/datum/asset/spritesheet/simple/stamps)
	if(QDELETED(src) || !sheet)
		return
	add_stamp(sheet.icon_class_name("stamp-rd"), rand(260, 330), rand(20, 70), rand(-15, 15), "stamp-rd")
	update_appearance()

/// A length of tape torn off the analyser.
/obj/item/paper/artifact_tape
	name = "лента анализатора"
	desc = "Завиток узкой ленты принтера."

/obj/item/circuitboard/machine/artifact_analyser
	name = "Анализатор артефактов"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/artifact_analyser
	req_components = list(
		/datum/stock_part/scanning_module = 2,
		/obj/item/stack/sheet/glass = 1,
	)

#undef ANALYSER_TAPE_LENGTH
#undef ANALYSER_TAPE_REPEAT_WINDOW
#undef TAPE_NOTE
#undef TAPE_RESPONSE
#undef TAPE_QUIET
#undef TAPE_FAULT

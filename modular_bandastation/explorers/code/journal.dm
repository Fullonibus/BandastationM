/// Bounds shared player text kept for the whole round.
#define EXPEDITION_JOURNAL_MAX_GOALS 100
#define EXPEDITION_JOURNAL_GOAL_LENGTH 256

/**
 * The station's corps archive: it survives the loss of ships and devices, and never reads hidden properties.
 * Journals on PDAs keep their own memory and swap entries with it while they are on the station.
 */
GLOBAL_DATUM_INIT(expedition_journal, /datum/expedition_journal, new)
/// Every documented discovery by ID, whoever's journal lists it; goal reports resolve their links here.
GLOBAL_LIST_EMPTY(expedition_records)

/** A discovery documented by the corps; facts come only from completed player actions. */
/datum/expedition_record
	/// Permanent discovery identity.
	var/id
	/// Original location, captured before transport.
	var/origin
	/// Text snapshots of completed actions; never references to actors.
	var/list/observations = list()

/**
 * Append an observed fact. The discovery goes into the journals the actor carries, and straight into the
 * station archive when the fact is recorded on the station.
 */
/datum/expedition_record/proc/log_observation(mob/user, atom/location, text)
	var/turf/tile = get_turf(location)
	var/place = tile ? "[get_area(tile)] ([tile.x], [tile.y], [tile.z])" : "место не установлено"
	observations += "[round_timestamp()] — [user?.real_name || "неизвестный оператор"] — [place]: [text]"
	GLOB.expedition_records[id] = src
	for(var/datum/computer_file/program/expedition_journal/journal as anything in expedition_journals_carried_by(user))
		journal.memory.records[id] = src
	if(tile && is_station_level(tile.z))
		GLOB.expedition_journal.records[id] = src

/// Journal programs on the devices `user` carries.
/proc/expedition_journals_carried_by(mob/user)
	. = list()
	if(!user)
		return
	for(var/obj/item/modular_computer/computer in user.get_all_contents())
		for(var/datum/computer_file/program/expedition_journal/journal in computer.stored_files)
			. += journal

/** Render escaped facts without inventing results or revealing hidden rewards. */
/datum/expedition_record/proc/report_text()
	var/list/lines = list("<b>Протокол [html_encode(id)]</b>", "Место обнаружения: [html_encode(origin)]")
	for(var/observation in observations)
		lines += html_encode(observation)
	return lines.Join("<br>")

/datum/expedition_journal
	/// Discoveries players have actually worked with, by stable ID; untouched sites are never listed.
	var/list/datum/expedition_record/records = list()
	/// Goals by ID, in creation order.
	var/list/datum/expedition_goal/goals = list()
	/// Round-local goal serial.
	var/goal_serial = 0
	/// Status keys accepted from the client, with their report wording.
	var/static/list/statuses = list("open" = "открыта", "done" = "выполнена", "failed" = "не выполнена")

/** A goal the corps sets for the expedition. */
/datum/expedition_goal
	/// Stable round-local ID used by the client and reports.
	var/id
	/// Goal wording as entered by its author.
	var/text
	/// Author's name as written at creation.
	var/author
	/// Station time of creation.
	var/created
	/// Key of the journal's status list.
	var/status = "open"
	/// Player's editable conclusions; recorded facts stay in the linked protocols.
	var/conclusion = ""
	/// Linked discovery IDs, resolved through the journal.
	var/list/record_ids = list()

/** Snapshot for the paper report: escaped player text plus the current protocols of linked finds. */
/datum/expedition_goal/proc/report_text(mob/user)
	var/list/lines = list(
		"<b>Отчёт экспедиционного корпуса по цели [html_encode(id)]</b>",
		"Цель экспедиции: [html_encode(text)]",
		"Поставлена: [html_encode(created)] — [html_encode(author)]",
		"Статус: [GLOB.expedition_journal.statuses[status]]",
		"Выводы: [length(conclusion) ? html_encode(conclusion) : "не записаны"]",
		"Составлен: [round_timestamp()] — [html_encode(user.real_name)]",
	)
	for(var/record_id in record_ids)
		var/datum/expedition_record/record = GLOB.expedition_records[record_id]
		lines += "<br>[record.report_text()]"
	return lines.Join("<br>")

/** Corps journal: read recorded facts, keep goals and conclusions, print reports for the station fax. */
/datum/computer_file/program/expedition_journal
	filename = "expjournal"
	filedesc = "Журнал экспедиции"
	downloader_category = PROGRAM_CATEGORY_SCIENCE
	program_open_overlay = "research"
	extended_desc = "Журнал экспедиционного корпуса: протоколы находок и цели экспедиции. Работает без сети и хранит записи в памяти устройства; на станции обменивается ими с архивом корпуса. Отчёты печатаются для отправки факсом со станции."
	program_flags = PROGRAM_ON_NTNET_STORE
	can_run_on_flags = PROGRAM_ALL
	download_access = list(ACCESS_EXPLORER)
	run_access = list(ACCESS_EXPLORER)
	size = 4
	program_icon = "book"
	tgui_id = "NtosExpeditionJournal"
	/// Records and goals in this device's memory.
	var/datum/expedition_journal/memory

/datum/computer_file/program/expedition_journal/New()
	. = ..()
	memory = new

/**
 * On the station, uploads this device's entries to the corps archive and takes everyone else's.
 * Returns TRUE if the device is on the station.
 */
/datum/computer_file/program/expedition_journal/proc/sync_with_station()
	var/turf/here = get_turf(computer)
	if(!here || !is_station_level(here.z))
		return FALSE
	var/datum/expedition_journal/archive = GLOB.expedition_journal
	for(var/id in memory.records)
		archive.records[id] = memory.records[id]
	for(var/id in memory.goals)
		archive.goals[id] = memory.goals[id]
	memory.records = archive.records.Copy()
	memory.goals = archive.goals.Copy()
	return TRUE

/datum/computer_file/program/expedition_journal/ui_data(mob/user)
	var/connected = sync_with_station()
	var/datum/expedition_journal/journal = memory
	var/list/records = list()
	for(var/id in journal.records)
		var/datum/expedition_record/record = journal.records[id]
		records += list(list(
			"id" = id,
			"origin" = record.origin,
			"observations" = record.observations,
		))
	var/list/goals = list()
	for(var/id in journal.goals)
		var/datum/expedition_goal/goal = journal.goals[id]
		goals += list(list(
			"id" = id,
			"text" = goal.text,
			"author" = goal.author,
			"created" = goal.created,
			"status" = goal.status,
			"conclusion" = goal.conclusion,
			"records" = goal.record_ids,
		))
	return list("records" = records, "goals" = goals, "connected" = connected)

/datum/computer_file/program/expedition_journal/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	// The ID may have been removed after the program was opened.
	if(!can_run(user, loud = TRUE))
		return FALSE
	sync_with_station()
	var/datum/expedition_journal/journal = memory
	if(action == "add_goal")
		var/text = istext(params["text"]) && trim(params["text"], EXPEDITION_JOURNAL_GOAL_LENGTH)
		if(!length(text))
			return FALSE
		if(length(journal.goals) >= EXPEDITION_JOURNAL_MAX_GOALS)
			to_chat(user, span_warning("Журнал заполнен."))
			return FALSE
		var/datum/expedition_goal/goal = new
		// The archive's serial keeps IDs unique across every device.
		goal.id = "Ц-[++GLOB.expedition_journal.goal_serial]"
		goal.text = text
		goal.author = user.real_name
		goal.created = round_timestamp()
		journal.goals[goal.id] = goal
		return TRUE
	// A non-text key would index the list by position.
	var/datum/expedition_goal/goal = istext(params["goal"]) && journal.goals[params["goal"]]
	if(!goal)
		return FALSE
	if(action == "print")
		if(!computer.print_text(goal.report_text(user), "отчёт по цели [goal.id]"))
			to_chat(user, span_warning("В [computer] нет бумаги."))
		return TRUE
	var/record_id = istext(params["record"]) && params["record"]
	switch(action)
		if("set_status")
			if(!(params["status"] in journal.statuses))
				return FALSE
			goal.status = params["status"]
		if("set_conclusion")
			if(!istext(params["text"]))
				return FALSE
			goal.conclusion = trim(params["text"], MAX_MESSAGE_LEN)
		if("link_record")
			if(!(record_id in journal.records))
				return FALSE
			goal.record_ids |= record_id
		if("unlink_record")
			goal.record_ids -= record_id
		else
			return FALSE
	return TRUE

#undef EXPEDITION_JOURNAL_MAX_GOALS
#undef EXPEDITION_JOURNAL_GOAL_LENGTH

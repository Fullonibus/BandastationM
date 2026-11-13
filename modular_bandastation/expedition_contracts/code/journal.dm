// The corps journal carries the orders tab and rings on order news.

/datum/computer_file/program/expedition_journal
	alert_able = TRUE

/datum/computer_file/program/expedition_journal/New()
	. = ..()
	GLOB.expedition_journal_programs += src

/datum/computer_file/program/expedition_journal/Destroy()
	GLOB.expedition_journal_programs -= src
	return ..()

/datum/computer_file/program/expedition_journal/ui_data(mob/user)
	. = ..()
	.["contracts"] = GLOB.expedition_contracts.journal_data()
	.["can_decide"] = GLOB.expedition_contracts.can_decide(user, src)

/datum/computer_file/program/expedition_journal/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || (action != "accept_contract" && action != "decline_contract"))
		return
	// The ID may have been removed after the program was opened; the parent already said so.
	if(!can_run(ui.user))
		return FALSE
	return GLOB.expedition_contracts.act(action, params["contract"], ui.user, src)

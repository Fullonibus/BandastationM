/// A physical console closes when its user leaves reach. Silicons keep their native access rules.
/obj/machinery/proc/overmap_console_status(mob/user, current_status)
	if(isAdminGhostAI(user) || issilicon(user))
		return current_status
	if(isobserver(user))
		return z && z == user.z ? ui_status_only_living(user, src) : UI_CLOSE
	return Adjacent(user) ? current_status : UI_CLOSE

/// Always update an existing window so TGUI can close it after a change in access.
/obj/machinery/proc/open_overmap_console(mob/user, datum/tgui/ui, interface, title)
	if(SStgui.try_update_ui(user, src, ui) || ui_status(user, ui_state(user)) < UI_UPDATE)
		return
	ui = new(user, src, interface, title || name)
	if(!ui.open())
		qdel(ui)

/// Access for a list or text prompt opened from a physical console.
/datum/ui_state/overmap_console_prompt
	/// The machine that opened the prompt.
	var/datum/weakref/console_ref

/datum/ui_state/overmap_console_prompt/New(obj/machinery/computer/console)
	console_ref = WEAKREF(console)
	return ..()

/datum/ui_state/overmap_console_prompt/can_use_topic(src_object, mob/user)
	var/obj/machinery/computer/console = console_ref?.resolve()
	if(!console?.can_interact(user) || console.panel_open)
		return UI_CLOSE
	return console.overmap_console_status(user, UI_INTERACTIVE)

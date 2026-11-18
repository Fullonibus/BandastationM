/// A contact transfer observes both participants, so moving away and back cannot evade cancellation.
/datum/ipc_os_transmission
	/// Existing held connector, with one shared charging/hacking/transmission reservation.
	var/obj/item/ipc_power_cord/cord
	/// Physical bodies, never inferred again from a transferred mind.
	var/mob/living/carbon/human/attacker
	var/mob/living/carbon/human/victim
	/// Exact cores present when transmission began.
	var/datum/ipc_os/source_os
	var/datum/ipc_os/target_os
	/// The armed payload is fixed for the duration of the progress bar.
	var/virus
	/// Persistently remembers any movement, even if both bodies later return.
	var/interrupted = FALSE
	/// Movement of containing vehicles also invalidates physical stationary contact.
	var/list/atom/movable/observed = list()
	/// The particular running activation, not just a reinstalled catalog instance.
	var/activation_id

/datum/ipc_os_transmission/New(obj/item/ipc_power_cord/cord, mob/living/carbon/human/attacker, mob/living/carbon/human/victim, virus)
	. = ..()
	src.cord = cord
	src.attacker = attacker
	src.victim = victim
	src.virus = virus
	source_os = attacker.get_ipc_os()
	target_os = victim.get_ipc_os()
	var/datum/ipc_os_program/virus_kit/kit = source_os.programs["virus_kit"]
	activation_id = kit.activation_id
	for(var/mob/body in list(attacker, victim))
		var/atom/location = body
		while(ismovable(location))
			observed |= location
			location = location.loc
		RegisterSignal(body, COMSIG_LIVING_DEATH, PROC_REF(on_invalidated))
	RegisterSignal(attacker, COMSIG_MOB_LOGOUT, PROC_REF(on_invalidated))
	for(var/atom/movable/location as anything in observed)
		RegisterSignal(location, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(source_os.core, COMSIG_ORGAN_REMOVED, PROC_REF(on_invalidated))
	RegisterSignal(target_os.core, COMSIG_ORGAN_REMOVED, PROC_REF(on_invalidated))

/datum/ipc_os_transmission/Destroy()
	for(var/atom/movable/location as anything in observed)
		UnregisterSignal(location, COMSIG_MOVABLE_MOVED)
	observed = null
	for(var/mob/body in list(attacker, victim))
		if(body)
			UnregisterSignal(body, list(COMSIG_LIVING_DEATH, COMSIG_MOB_LOGOUT))
	if(source_os?.core)
		UnregisterSignal(source_os.core, COMSIG_ORGAN_REMOVED)
	if(target_os?.core)
		UnregisterSignal(target_os.core, COMSIG_ORGAN_REMOVED)
	if(!QDELETED(cord))
		cord.drawing_power = FALSE
	cord = null
	attacker = null
	victim = null
	source_os = null
	target_os = null
	return ..()

/datum/ipc_os_transmission/proc/on_moved(atom/movable/source, atom/old_loc)
	SIGNAL_HANDLER
	if(source.loc != old_loc)
		interrupted = TRUE

/datum/ipc_os_transmission/proc/on_invalidated()
	SIGNAL_HANDLER
	interrupted = TRUE

/// Revalidate actual cores, held hardware, software and contact after every asynchronous gap.
/datum/ipc_os_transmission/proc/valid_contact()
	if(interrupted || QDELETED(attacker) || QDELETED(victim) || QDELETED(cord) || QDELETED(source_os) || QDELETED(target_os))
		return FALSE
	if(attacker == victim || source_os != attacker.get_ipc_os() || target_os != victim.get_ipc_os() || !attacker.Adjacent(victim))
		return FALSE
	var/datum/ipc_os_program/virus_kit/kit = source_os.programs["virus_kit"]
	return cord.can_use_software(attacker, victim, "virus_kit", activation_id) && kit.selected_virus == virus && target_os.has_valid_chassis()

/// Native progress, then one Firewall roll and one non-stacking insertion at the server boundary.
/datum/ipc_os_transmission/proc/execute_transfer()
	var/completed = FALSE
	if(valid_contact() && do_after(attacker, 10 SECONDS, target = victim, timed_action_flags = IGNORE_SLOWDOWNS, extra_checks = CALLBACK(src, PROC_REF(valid_contact))))
		if(valid_contact() && !target_os.infections[virus])
			completed = TRUE
			if(target_os.blocks_virus())
				source_os.error_message = "Firewall+ заблокировал передачу."
			else if(target_os.infect(virus, source_os.core))
				source_os.error_message = "Передача завершена."
				log_combat(attacker, victim, "infected with [virus] using VirusKit")
				if(virus == "neural_hijack")
					var/datum/ipc_os_program/virus_kit/kit = source_os.programs["virus_kit"]
					kit.hijack_targets |= WEAKREF(target_os.core)
	if(!completed && !QDELETED(source_os))
		source_os.error_message = "Передача прервана."
	qdel(src)

/// Reserve the native connector, consuming only explicit VirusKit arming, not installed storage.
/obj/item/ipc_power_cord/proc/try_virus_kit(mob/living/carbon/human/victim, mob/living/carbon/human/user)
	if(!can_use_software(user, victim, "virus_kit"))
		return NONE
	var/datum/ipc_os/os = user.get_ipc_os()
	var/datum/ipc_os_program/virus_kit/kit = os.programs["virus_kit"]
	var/datum/ipc_os/target_os = victim.get_ipc_os()
	if(!kit.armed)
		balloon_alert(user, "сначала подготовьте передачу в ОС!")
		return ITEM_INTERACT_BLOCKING
	if(drawing_power)
		balloon_alert(user, "разъём занят!")
		return ITEM_INTERACT_BLOCKING
	if(user == victim || !target_os?.has_valid_chassis())
		balloon_alert(user, "нет рабочего КПБ для заражения!")
		return ITEM_INTERACT_BLOCKING
	if(target_os.infections[kit.selected_virus])
		balloon_alert(user, "этот вирус уже установлен!")
		return ITEM_INTERACT_BLOCKING
	kit.armed = FALSE
	os.error_message = "Передача выполняется: сохраняйте неподвижность обоих КПБ."
	var/connection_message = span_danger("[user.get_visible_name()] подключает кабель к [victim.get_visible_name()]!")
	to_chat(user, connection_message)
	to_chat(victim, connection_message)
	drawing_power = TRUE
	var/datum/ipc_os_transmission/transfer = new(src, user, victim, kit.selected_virus)
	INVOKE_ASYNC(transfer, TYPE_PROC_REF(/datum/ipc_os_transmission, execute_transfer))
	return ITEM_INTERACT_SUCCESS

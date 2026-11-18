#define IPC_OS_DEFRAG_INTERVAL_SECONDS 25
#define IPC_OS_DEFRAG_DRAIN_PER_SECOND (NUTRITION_LEVEL_FULL * 0.03 / 20)

/// Raw delay adjustment avoids Primera's additional scaling of ordinary TG movement modifiers.
/datum/movespeed_modifier/ipc_os_power_save
	variable = TRUE

/datum/movespeed_modifier/ipc_os_power_save/get_rp_speed()
	return multiplicative_slowdown

/datum/ipc_os_program/power_save
	/// Updating our own modifier emits the same movement signal.
	var/syncing_speed = FALSE

/datum/ipc_os_program/power_save/start()
	if(!..())
		return FALSE
	RegisterSignal(os.host, COMSIG_MOB_MOVESPEED_UPDATED, PROC_REF(sync_speed))
	os.host.add_movespeed_modifier(/datum/movespeed_modifier/ipc_os_power_save)
	return TRUE

/datum/ipc_os_program/power_save/stop()
	if(running && os.host)
		UnregisterSignal(os.host, COMSIG_MOB_MOVESPEED_UPDATED)
		os.host.remove_movespeed_modifier(/datum/movespeed_modifier/ipc_os_power_save)
	return ..()

/datum/ipc_os_program/power_save/proc/sync_speed()
	SIGNAL_HANDLER
	if(syncing_speed || !running)
		return
	var/datum/movespeed_modifier/ipc_os_power_save/modifier = os.host.has_movespeed_modifier(/datum/movespeed_modifier/ipc_os_power_save)
	if(!modifier)
		return
	syncing_speed = TRUE
	var/base_delay = os.host.cached_multiplicative_slowdown - modifier.get_rp_speed()
	// OverClock applies its percentage after this penalty; exclude it to prevent feedback between both modifiers.
	var/datum/movespeed_modifier/ipc_os_overclock/overclock = os.host.has_movespeed_modifier(/datum/movespeed_modifier/ipc_os_overclock)
	if(overclock && !(os.host.movement_type & (FLYING|FLOATING)))
		base_delay -= overclock.get_rp_speed()
	os.host.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/ipc_os_power_save, multiplicative_slowdown = max(base_delay, 0) * (1 / 0.85 - 1))
	syncing_speed = FALSE

/// Calculate ordinary microbattery drain independently from each program's additional charge costs.
/datum/ipc_os/proc/power_multiplier()
	if(!is_operational())
		return 1
	var/datum/ipc_os_program/power_save = programs["power_save"]
	var/datum/ipc_os_program/defrag = programs["defrag"]
	var/datum/ipc_os_program/ghost_mode = programs["ghost_mode"]
	return (power_save.running ? 0.7 : 1) * (defrag.running ? 1.35 : 1) * (ghost_mode.running ? 1.3 : 1)

/// An incoming valid new infection makes exactly one roll, after its transmission finishes.
/datum/ipc_os/proc/blocks_virus()
	var/datum/ipc_os_program/firewall = programs["firewall"]
	return is_operational() && firewall.installed && prob(50)

/datum/ipc_os_program/defrag
	/// Completed running time only; repeated toggles cannot create healing intervals.
	var/heal_elapsed = 0

/datum/ipc_os_program/defrag/stop()
	. = ..()
	heal_elapsed = 0

/datum/ipc_os_program/defrag/tick(seconds_per_tick)
	var/obj/item/organ/heart/ipc/battery = os.working_battery()
	if(!battery)
		stop()
		return
	var/datum/ipc_os_program/power_save = os.programs["power_save"]
	battery.adjust_charge(-IPC_OS_DEFRAG_DRAIN_PER_SECOND * seconds_per_tick * (power_save.running ? (1 / 3) : 1))
	if(os.host.nutrition <= 0)
		stop()
		return
	heal_elapsed += seconds_per_tick
	while(heal_elapsed >= IPC_OS_DEFRAG_INTERVAL_SECONDS)
		heal_elapsed -= IPC_OS_DEFRAG_INTERVAL_SECONDS
		os.host.heal_overall_damage(brute = 2, required_bodytype = BODYTYPE_ROBOTIC)

/datum/ipc_os_program/signal_boost
	/// Native signaling hardware is owned by this program, not accessible as loot.
	var/obj/item/assembly/signaler/internal/signaler
	/// Settings survive stopping, while the radio subscription does not.
	var/frequency = FREQ_SIGNALER
	/// Existing signaler protocol code.
	var/code = DEFAULT_SIGNALER_CODE
	COOLDOWN_DECLARE(send_cooldown)

/datum/ipc_os_program/signal_boost/start()
	if(!..())
		return FALSE
	signaler = new(os.host)
	signaler.set_frequency(frequency)
	signaler.code = code
	return TRUE

#undef IPC_OS_DEFRAG_INTERVAL_SECONDS
#undef IPC_OS_DEFRAG_DRAIN_PER_SECOND

/datum/ipc_os_program/signal_boost/stop()
	QDEL_NULL(signaler)
	return ..()

/// Validate settings and send through the actual SSradio signaler implementation.
/datum/ipc_os_program/signal_boost/proc/command(action, list/params)
	if(!running || !signaler || !os.can_use(usr))
		return FALSE
	switch(action)
		if("signal_freq")
			var/value = text2num("[params["value"]]")
			if(isnull(value))
				return FALSE
			frequency = sanitize_frequency(round(value), TRUE)
			signaler.set_frequency(frequency)
		if("signal_code")
			var/value = text2num("[params["value"]]")
			if(isnull(value))
				return FALSE
			code = clamp(round(value), 1, 100)
			signaler.code = code
		if("signal_send")
			if(!COOLDOWN_FINISHED(src, send_cooldown))
				return FALSE
			COOLDOWN_START(src, send_cooldown, 1 SECONDS)
			INVOKE_ASYNC(signaler, TYPE_PROC_REF(/obj/item/assembly/signaler, signal))
	return TRUE

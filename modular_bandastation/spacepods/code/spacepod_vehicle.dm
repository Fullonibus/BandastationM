/// Paradise spacepods use the sealed vehicle's occupant and action bookkeeping.
/obj/vehicle/sealed/spacepod
	name = "space pod"
	desc = "Космический челнок, предназначенный для путешествий в открытом космосе."
	icon = 'modular_bandastation/spacepods/icons/pods.dmi'
	icon_state = "pod_civ"
	bound_width = 64
	bound_height = 64
	layer = BELOW_MOB_LAYER
	max_integrity = 250
	armor_type = /datum/armor/none
	move_resist = MOVE_FORCE_EXTREMELY_STRONG
	move_force = MOVE_FORCE_VERY_STRONG
	resistance_flags = ACID_PROOF
	movement_type = FLYING
	enter_delay = 4 SECONDS
	enter_sound = 'sound/machines/airlock/airlock.ogg'
	exit_sound = 'sound/machines/airlock/airlock.ogg'
	/// Only this occupant can operate the console; the other seats are passengers.
	var/mob/living/pilot
	var/list/mob/living/passengers = list()
	var/max_passengers = 0
	var/list/installed_modules = list()
	var/obj/item/spacepod_equipment/weaponry/weapon_system
	var/obj/item/spacepod_equipment/misc/misc_system
	var/obj/item/spacepod_equipment/cargo/cargo_system
	var/obj/item/spacepod_equipment/sec_cargo/sec_cargo_system
	var/obj/item/spacepod_equipment/lock/lock_system
	var/obj/item/spacepod_equipment/locators/locator_system
	var/battery_type = /obj/item/stock_parts/power_store/cell/high
	var/obj/item/stock_parts/power_store/cell/battery
	var/datum/gas_mixture/cabin_air
	var/obj/machinery/portable_atmospherics/canister/internal_tank
	var/use_internal_tank = TRUE
	var/hatch_open = FALSE
	var/unlocked = TRUE
	var/lights = FALSE
	var/lights_power = 6
	var/can_paint = FALSE
	/// Paint is indexed by actual overlay state, avoiding an invalid selection index.
	var/list/paint_colors = list()
	var/melting_down = FALSE
	/// Owns continuous flight independently of cabin life support.
	var/datum/spacepod_flight/flight
	/// An attached rear flame is visible only while the main thruster is firing.
	var/thruster_flame_active = FALSE
	/// Optional expiry for a finite thruster pulse.
	var/thruster_flame_timer
	/// One native sound loop per cabin listener, so stopping it also cuts the current sample.
	var/list/engine_sounds = list()
	/// Expires when the last successful movement finishes gliding.
	var/engine_sound_timer
	COOLDOWN_DECLARE(cooldown_emp)

/obj/vehicle/sealed/spacepod/Initialize(mapload)
	. = ..()
	battery = new battery_type(src)
	cabin_air = new(200)
	cabin_air.temperature = T20C
	cabin_air.set_gas(/datum/gas/oxygen, ONE_ATMOSPHERE * O2STANDARD * cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	cabin_air.set_gas(/datum/gas/nitrogen, ONE_ATMOSPHERE * N2STANDARD * cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	internal_tank = new /obj/machinery/portable_atmospherics/canister/air(src)
	RegisterSignal(internal_tank, COMSIG_QDELETING, PROC_REF(clear_internal_tank))
	flight = new(src)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_flight_moved))
	RegisterSignal(src, COMSIG_QDELETING, PROC_REF(stop_cabin_alerts))
	GLOB.spacepods_list += src
	AddElement(/datum/element/hostile_machine)
	START_PROCESSING(SSobj, src)
	update_appearance()

/obj/vehicle/sealed/spacepod/Destroy()
	STOP_PROCESSING(SSobj, src)
	stop_cabin_alerts()
	set_thruster_flame(FALSE)
	stop_engine_sound()
	QDEL_NULL(flight)
	SStgui.close_uis(src)
	GLOB.spacepods_list -= src
	// Polymorphing an occupant can leave its replacement only in contents.
	for(var/mob/occupant in (contents | occupants))
		mob_exit(occupant, silent = TRUE)
	pilot = null
	passengers.Cut()
	for(var/obj/item/spacepod_equipment/module as anything in installed_modules.Copy())
		qdel(module)
	installed_modules.Cut()
	weapon_system = null
	misc_system = null
	cargo_system = null
	sec_cargo_system = null
	lock_system = null
	locator_system = null
	QDEL_NULL(battery)
	if(cabin_air && loc)
		loc.assume_air(cabin_air)
	QDEL_NULL(cabin_air)
	if(internal_tank)
		UnregisterSignal(internal_tank, COMSIG_QDELETING)
		QDEL_NULL(internal_tank)
	return ..()

/// Direct cabin audio remains audible in vacuum; the native loop owns and stops its reserved channel.
/datum/looping_sound/spacepod_engine
	mid_sounds = 'sound/vehicles/rocketlaunch.ogg'
	mid_length = 6.2 SECONDS
	volume = 15
	pressure_affected = FALSE

/obj/vehicle/sealed/spacepod/get_cell()
	return battery

/obj/vehicle/sealed/spacepod/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == internal_tank)
		clear_internal_tank(gone)
	if(gone == battery)
		set_thruster_flame(FALSE)
		stop_engine_sound()
		battery = null
	if(istype(gone, /obj/item/spacepod_equipment))
		var/obj/item/spacepod_equipment/module = gone
		if(module.my_atom == src && module.loc != src)
			module.removed(null)
			detach_equipment(module)
			occupant_sanity_check()

/obj/vehicle/sealed/spacepod/process(seconds_per_tick)
	process_life_support(seconds_per_tick)
	if(QDELETED(src))
		return
	give_air()
	regulate_temp(seconds_per_tick)
	occupant_sanity_check()
	process_cabin_alerts()

/obj/vehicle/sealed/spacepod/return_air()
	if(use_internal_tank && cabin_air)
		return cabin_air
	return ..()

/obj/vehicle/sealed/spacepod/remove_air(amount)
	if(use_internal_tank && cabin_air)
		return cabin_air.remove(amount)
	return ..()

/obj/vehicle/sealed/spacepod/assume_air(datum/gas_mixture/giver)
	if(use_internal_tank && cabin_air)
		return cabin_air.merge(giver)
	return ..()

/obj/vehicle/sealed/spacepod/return_analyzable_air()
	return return_air()

/obj/vehicle/sealed/spacepod/return_temperature()
	return return_air()?.return_temperature()

/// The cabin regulator has the donor's one-atmosphere target and finite tank.
/obj/vehicle/sealed/spacepod/proc/give_air()
	if(!cabin_air || !internal_tank || cabin_air.temperature <= 0)
		return
	var/datum/gas_mixture/tank_air = internal_tank.return_air()
	if(QDELETED(tank_air))
		return
	var/cabin_pressure = cabin_air.return_pressure()
	var/pressure_delta = min(ONE_ATMOSPHERE - cabin_pressure, (tank_air.return_pressure() - cabin_pressure) / 2)
	if(pressure_delta > 0 && tank_air.temperature > 0)
		var/transfer_moles = pressure_delta * cabin_air.volume / (cabin_air.temperature * R_IDEAL_GAS_EQUATION)
		var/datum/gas_mixture/removed = tank_air.remove(transfer_moles)
		cabin_air.merge(removed)
		qdel(removed)
		return
	if(pressure_delta >= 0)
		return
	var/turf/location = get_turf(src)
	var/datum/gas_mixture/external_air = location?.return_air()
	pressure_delta = cabin_pressure - ONE_ATMOSPHERE
	if(external_air)
		pressure_delta = min(pressure_delta, cabin_pressure - external_air.return_pressure())
	if(pressure_delta <= 0)
		return
	var/transfer_moles = pressure_delta * cabin_air.volume / (cabin_air.temperature * R_IDEAL_GAS_EQUATION)
	var/datum/gas_mixture/removed = cabin_air.remove(transfer_moles)
	if(location)
		location.assume_air(removed)
	qdel(removed)

/obj/vehicle/sealed/spacepod/proc/regulate_temp(seconds_per_tick)
	if(!cabin_air || cabin_air.volume <= 0)
		return
	// Paradise regulates once per two-second object processing interval.
	var/delta = cabin_air.temperature - T20C
	cabin_air.temperature = max(0, cabin_air.temperature - clamp(round(delta / 4, 0.1), -10, 10) * seconds_per_tick / 2)

/// Sealed vehicles block hands themselves; only additional restraint blocks controls.
/obj/vehicle/sealed/spacepod/proc/can_control(mob/living/user)
	return !melting_down && !QDELETED(user) && user == pilot && user.loc == src && is_driver(user) && !user.incapacitated && !HAS_TRAIT(user, TRAIT_RESTRAINED) && (!HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || HAS_TRAIT_FROM_ONLY(user, TRAIT_HANDS_BLOCKED, VEHICLE_TRAIT))

/obj/vehicle/sealed/spacepod/auto_assign_occupant_flags(mob/living/occupant)
	if(!pilot && !occupant.incapacitated && occupant.stat == STABLE)
		pilot = occupant
		add_control_flags(occupant, VEHICLE_CONTROL_DRIVE | VEHICLE_CONTROL_EQUIPMENT | VEHICLE_CONTROL_SETTINGS)
	else
		passengers |= occupant

/obj/vehicle/sealed/spacepod/after_add_occupant(mob/living/occupant)
	. = ..()
	ADD_TRAIT(occupant, TRAIT_RUNECHAT_HIDDEN, REF(src))
	occupant.reset_perspective(src)
	RegisterSignal(occupant, COMSIG_MOB_LOGOUT, PROC_REF(on_occupant_logout))
	RegisterSignal(occupant, COMSIG_MOB_LOGIN, PROC_REF(on_occupant_login))
	RegisterSignal(occupant, COMSIG_MOB_RESET_PERSPECTIVE, PROC_REF(on_occupant_view_changed))
	on_occupant_login(occupant)
	if(occupant == pilot)
		RegisterSignal(occupant, COMSIG_MOVABLE_KEYBIND_FACE_DIR, PROC_REF(on_pilot_turn))

/obj/vehicle/sealed/spacepod/after_remove_occupant(mob/living/occupant)
	. = ..()
	stop_cabin_alert_for(occupant)
	REMOVE_TRAIT(occupant, TRAIT_RUNECHAT_HIDDEN, REF(src))
	SStgui.close_user_uis(occupant, src)
	UnregisterSignal(occupant, list(COMSIG_MOB_LOGOUT, COMSIG_MOB_LOGIN, COMSIG_MOB_RESET_PERSPECTIVE))
	if(occupant.client)
		UnregisterSignal(occupant.client, COMSIG_CLIENT_SET_EYE)
	flight?.release_camera(occupant)
	if(occupant == pilot)
		flight?.set_input(NONE)
		flight?.aim(null)
		set_thruster_flame(FALSE)
		stop_engine_sound()
		UnregisterSignal(occupant, COMSIG_MOVABLE_KEYBIND_FACE_DIR)
		pilot = null
	else
		stop_engine_sound(occupant)
	passengers -= occupant
	occupant.reset_perspective()

/obj/vehicle/sealed/spacepod/proc/on_pilot_turn(mob/living/user, direction)
	SIGNAL_HANDLER
	if(can_control(user))
		flight.aim(dir2angle(direction))
	// Keep the client's movement lock: the pod has no mech-style pivot step.
	return NONE

/obj/vehicle/sealed/spacepod/setDir(newdir)
	. = ..()
	if(flight && animate_movement != NO_STEPS)
		flight.heading = dir2angle(newdir)
	if(!QDELETED(src) && thruster_flame_active)
		update_appearance(UPDATE_OVERLAYS)
		if(QDELETED(src))
			return
	for(var/mob/living/occupant as anything in occupants)
		occupant.setDir(newdir)

/// Reach any hull tile using the acting mob's normal window and diagonal pass checks.
/obj/vehicle/sealed/spacepod/Adjacent(atom/neighbor, atom/target, atom/movable/mover)
	if(QDELETED(src) || QDELETED(neighbor))
		return FALSE
	if(neighbor == loc || neighbor.loc == src)
		return TRUE
	if(!isturf(loc) || (!isturf(neighbor) && !isturf(neighbor.loc)))
		return FALSE
	target ||= src
	if(!mover && ismovable(neighbor))
		mover = neighbor
	for(var/turf/hull_turf as anything in locs)
		if(hull_turf.Adjacent(neighbor, target = target, mover = mover))
			return TRUE
	return FALSE

/// Native clicks and drags need hull reach before the ordinary ranged-reach fallback.
/obj/vehicle/sealed/spacepod/CheckReachableAdjacency(atom/movable/reacher, reacher_range)
	return Adjacent(reacher) || ..()

/obj/vehicle/sealed/spacepod/enter_checks(mob/living/user)
	if(!ishuman(user) || user.incapacitated || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || user.has_buckled_mobs() || user.buckled)
		return FALSE
	if(!Adjacent(user) || (lock_system && !unlocked) || melting_down)
		return FALSE
	if(length(user.get_all_contents_type(/obj/item/disk/nuclear)))
		return FALSE
	max_occupants = 1 + max_passengers
	return ..()

/obj/vehicle/sealed/spacepod/proc/enter_pod(mob/living/user)
	if(lock_system && !unlocked)
		balloon_alert(user, "двери заблокированы!")
		return FALSE
	return mob_try_enter(user)

/obj/vehicle/sealed/spacepod/mob_enter(mob/living/user, silent = FALSE)
	// The final check also closes simultaneous boarding and mid-action locking races.
	if(!enter_checks(user))
		return FALSE
	. = ..()
	if(.)
		add_fingerprint(user)

/obj/vehicle/sealed/spacepod/mouse_drop_receive(atom/dropping, mob/living/user, params)
	if(!isliving(user) || user.incapacitated || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || !Adjacent(user))
		return
	if(dropping == user)
		return enter_pod(user)
	if(istype(dropping, /obj/machinery/portable_atmospherics/canister))
		return install_internal_tank(user, dropping)
	if(isliving(dropping))
		var/mob/living/passenger = dropping
		if(!can_load_passenger(user, passenger))
			return
		if(!do_after(user, 5 SECONDS, passenger, extra_checks = CALLBACK(src, PROC_REF(can_load_passenger), user, passenger)))
			return
		if(!can_load_passenger(user, passenger))
			return
		passenger.forceMove(src)
		add_occupant(passenger, forced = TRUE)
		return
	if(isobj(dropping))
		load_cargo(user, dropping)

/obj/vehicle/sealed/spacepod/proc/can_load_passenger(mob/living/user, mob/living/passenger)
	return !QDELETED(user) && !QDELETED(passenger) && !user.incapacitated && !HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) && Adjacent(user) && user.Adjacent(passenger) && !passenger.buckled && !passenger.has_buckled_mobs() && passenger.incapacitated && unlocked && !melting_down && length(passengers) < max_passengers && !is_occupant(passenger) && !length(passenger.get_all_contents_type(/obj/item/disk/nuclear))

/obj/vehicle/sealed/spacepod/mob_try_exit(mob/living/leaving, mob/user, silent = FALSE, randomstep = FALSE)
	if(leaving != user)
		return FALSE
	return exit_pod(leaving)

/obj/vehicle/sealed/spacepod/container_resist_act(mob/living/user)
	exit_pod(user)

/obj/vehicle/sealed/spacepod/proc/exit_pod(mob/living/user)
	if(!is_occupant(user) || user.loc != src || user.stat != STABLE || IS_UNCONSCIOUS(user))
		return FALSE
	if(HAS_TRAIT(user, TRAIT_RESTRAINED) || (HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) && !HAS_TRAIT_FROM_ONLY(user, TRAIT_HANDS_BLOCKED, VEHICLE_TRAIT)))
		to_chat(user, span_notice("Вы пытаетесь выбраться из челнока. Это займёт две минуты."))
		if(pilot && pilot != user)
			to_chat(pilot, span_warning("[user] пытается выбраться из челнока."))
		if(!do_after(user, 2 MINUTES, src, timed_action_flags = IGNORE_HELD_ITEM))
			return FALSE
		if(!is_occupant(user) || user.loc != src || user.stat != STABLE || IS_UNCONSCIOUS(user))
			return FALSE
	return mob_exit(user)

/obj/vehicle/sealed/spacepod/proc/eject_pilot()
	if(pilot)
		mob_exit(pilot)

/obj/vehicle/sealed/spacepod/proc/eject_passenger(mob/living/passenger)
	if(passenger in passengers)
		mob_exit(passenger)

/obj/vehicle/sealed/spacepod/proc/occupant_sanity_check()
	// Native remove_occupant() uses LAZYREMOVE and nulls the last occupant's list.
	for(var/mob/living/occupant as anything in occupants?.Copy())
		if(QDELETED(occupant) || occupant.loc != src)
			remove_occupant(occupant)
	// Deleted or forcibly relocated seats cannot leave somebody in a nonexistent seat.
	while(length(passengers) > max_passengers)
		var/mob/living/overflow = passengers[length(passengers)]
		if(!QDELETED(overflow) && overflow.loc == src)
			mob_exit(overflow, silent = TRUE)
		else
			passengers -= overflow

// Continuous flight owns inertia; native per-tile drift must not also move this cabin.
/obj/vehicle/sealed/spacepod/Process_Spacemove(movement_dir = NONE, continuous_move = FALSE)
	return TRUE

/obj/vehicle/sealed/spacepod/proc/on_flight_moved(datum/source, atom/old_loc, direction, forced)
	SIGNAL_HANDLER
	if(forced && !inertia_moving)
		flight?.reset_motion()

/obj/vehicle/sealed/spacepod/proc/on_occupant_view_changed(mob/listener)
	SIGNAL_HANDLER
	flight?.release_camera(listener)
	flight?.attach_camera(listener)

/obj/vehicle/sealed/spacepod/proc/on_occupant_login(mob/listener)
	SIGNAL_HANDLER
	if(listener.client)
		RegisterSignal(listener.client, COMSIG_CLIENT_SET_EYE, PROC_REF(on_cabin_eye_changed))
	flight?.attach_camera(listener)
	process_cabin_alerts()

/obj/vehicle/sealed/spacepod/proc/on_cabin_eye_changed(client/viewer, atom/old_eye, atom/new_eye)
	SIGNAL_HANDLER
	var/mob/listener = viewer.mob
	if(!is_occupant(listener))
		return
	flight?.release_camera(listener)
	if(new_eye == src)
		flight?.attach_camera(listener)

/obj/vehicle/sealed/spacepod/proc/on_occupant_logout(mob/listener)
	SIGNAL_HANDLER
	stop_cabin_alert_for(listener)
	flight?.release_camera(listener)
	if(listener.client)
		UnregisterSignal(listener.client, COMSIG_CLIENT_SET_EYE)
	if(listener == pilot && flight)
		flight.set_input(NONE)
		flight.aim(null)
		set_thruster_flame(FALSE)

/obj/vehicle/sealed/spacepod/Move(atom/newloc, direct, glide_size_override = 0, update_dir = TRUE)
	var/collect_drifting_ore = inertia_moving && !moving_diagonally
	var/atom/old_loc = loc
	. = ..()
	// A blocked diagonal may still slide one tile; sector transfers may reset diagonal state.
	if(collect_drifting_ore && !QDELETED(src) && loc != old_loc && isturf(loc) && cargo_system)
		cargo_system.passover(locs)

/obj/vehicle/sealed/spacepod/relaymove(mob/living/user, direction)
	if(user != pilot)
		return FALSE
	return vehicle_move(direction)

/obj/vehicle/sealed/spacepod/vehicle_move(direction)
	if(!can_control(pilot) || !direction)
		set_thruster_flame(FALSE)
		stop_engine_sound()
		return FALSE
	if(direction != UP && direction != DOWN)
		return flight.set_input(direction)
	if(!COOLDOWN_FINISHED(src, cooldown_vehicle_move))
		if(!battery?.charge || !COOLDOWN_FINISHED(src, cooldown_emp))
			set_thruster_flame(FALSE)
			stop_engine_sound()
		return FALSE
	if(melting_down || !battery || !COOLDOWN_FINISHED(src, cooldown_emp))
		stop_engine_sound()
		COOLDOWN_START(src, cooldown_vehicle_move, 0.5 SECONDS)
		balloon_alert(pilot, !battery ? "нет батареи!" : "системы не отвечают!")
		return FALSE
	if(!isturf(loc) || !battery.use(SPACEPOD_ENERGY_UNIT))
		if(!QDELETED(src))
			set_thruster_flame(FALSE)
			stop_engine_sound()
			COOLDOWN_START(src, cooldown_vehicle_move, 0.5 SECONDS)
		return FALSE
	if(QDELETED(src))
		return FALSE
	var/turf/previous_turf = loc
	var/movement_multiplier = flight.turbo ? 2 : 1
	var/calculated_delay = 0.5 SECONDS / movement_multiplier
	set_glide_size(DELAY_TO_GLIDE_SIZE(calculated_delay))
	. = try_step_multiz(direction)
	calculated_delay = CEILING(calculated_delay, world.tick_lag)
	set_glide_size(DELAY_TO_GLIDE_SIZE(calculated_delay))
	COOLDOWN_START(src, cooldown_vehicle_move, calculated_delay)
	if(.)
		emit_thrust_effect(previous_turf, calculated_delay)
	else
		set_thruster_flame(FALSE)
		stop_engine_sound()
	if(!QDELETED(src) && . && cargo_system)
		cargo_system.passover(locs)

/obj/vehicle/sealed/spacepod/proc/emit_thrust_effect(turf/previous_turf, glide_duration)
	if(!previous_turf || !isturf(loc) || previous_turf == loc || previous_turf.has_gravity() || has_gravity())
		stop_engine_sound()
		return FALSE
	start_engine_sound(glide_duration)
	return TRUE

/// Flight ticks own the flame directly; finite impulses may supply an expiry.
/obj/vehicle/sealed/spacepod/proc/set_thruster_flame(active, duration = 0)
	deltimer(thruster_flame_timer)
	thruster_flame_timer = null
	if(QDELETED(src))
		thruster_flame_active = FALSE
		return
	if(active && (!can_control(pilot) || !battery?.charge || !COOLDOWN_FINISHED(src, cooldown_emp)))
		active = FALSE
	if(thruster_flame_active != active)
		thruster_flame_active = active
		update_appearance(UPDATE_OVERLAYS)
	if(!QDELETED(src) && thruster_flame_active && duration > 0)
		thruster_flame_timer = addtimer(CALLBACK(src, PROC_REF(set_thruster_flame), FALSE), duration, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// Repeated movement extends the current loops instead of layering another sample over them.
/obj/vehicle/sealed/spacepod/proc/start_engine_sound(glide_duration)
	if(!can_control(pilot) || !battery?.charge || !COOLDOWN_FINISHED(src, cooldown_emp))
		stop_engine_sound()
		return
	for(var/mob/living/occupant as anything in occupants)
		if(!QDELETED(occupant) && occupant.loc == src && !engine_sounds[occupant])
			var/datum/looping_sound/spacepod_engine/engine_sound = new(occupant, _direct = TRUE)
			engine_sound.sound_channel = SSsounds.reserve_sound_channel_for_datum(engine_sound)
			engine_sounds[occupant] = engine_sound
			engine_sound.start()
	deltimer(engine_sound_timer)
	// Match the movement cooldown's clock; real-time timers only resolve whole deciseconds.
	engine_sound_timer = addtimer(CALLBACK(src, PROC_REF(stop_engine_sound)), glide_duration, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// A departing passenger stops only their own channel; losing the pilot stops the whole engine.
/obj/vehicle/sealed/spacepod/proc/stop_engine_sound(mob/living/listener)
	if(listener)
		var/datum/looping_sound/spacepod_engine/engine_sound = engine_sounds[listener]
		engine_sounds -= listener
		qdel(engine_sound)
		return
	deltimer(engine_sound_timer)
	engine_sound_timer = null
	QDEL_LIST_ASSOC_VAL(engine_sounds)

/obj/vehicle/sealed/spacepod/can_z_move(direction, turf/start, turf/destination, z_move_flags = ZMOVE_FLIGHT_FLAGS, mob/living/rider)
	var/turf/target = ..()
	if(!target)
		return FALSE
	// Native z movement checks only the origin; the whole cabin must clear the deck.
	for(var/turf/footprint as anything in locs)
		var/turf/target_part = locate(target.x + footprint.x - x, target.y + footprint.y - y, target.z)
		if(!target_part || !(footprint.zPassOut(direction) && target_part.zPassIn(direction)) || !target_part.Enter(src))
			return FALSE
	return target

/obj/vehicle/sealed/spacepod/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(user.combat_mode)
		return ..()
	if(user.incapacitated || !Adjacent(user) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return ITEM_INTERACT_BLOCKING
	if(istype(tool, /obj/item/stock_parts/power_store/cell))
		if(!hatch_open || battery)
			balloon_alert(user, hatch_open ? "нет места!" : "технический люк закрыт!")
			return ITEM_INTERACT_BLOCKING
		if(user.transferItemToLoc(tool, src))
			battery = tool
			add_fingerprint(user)
			balloon_alert(user, "батарея установлена")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/pod_paint_bucket))
		apply_paint(user)
		return ITEM_INTERACT_SUCCESS
	var/result = equipment_interaction(user, tool, modifiers)
	if(result)
		return result
	return ..()

/obj/vehicle/sealed/spacepod/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || user.incapacitated || !Adjacent(user))
		return
	if(user.combat_mode && unlocked && length(occupants))
		var/mob/living/target = pilot || passengers[1]
		if(!target || !do_after(user, 5 SECONDS, src))
			return
		if(user.incapacitated || !Adjacent(user) || !unlocked || !is_occupant(target) || target.loc != src)
			return
		mob_exit(target)
		target.Stun(2 SECONDS)
		user.visible_message(span_warning("[user] вытаскивает [target] из челнока!"))
		return
	if(!hatch_open)
		if(!can_service_cargo(user) || user.get_active_held_item())
			return
		var/obj/item/spacepod_equipment/sec_cargo/loot_box/loot = sec_cargo_system
		var/has_loot = istype(loot) && loot.my_atom == src && loot.loc == src
		var/obj/item/spacepod_equipment/cargo/cargo = cargo_system
		var/has_cargo = !QDELETED(cargo) && cargo.my_atom == src && cargo.loc == src && !QDELETED(cargo.storage)
		if(has_loot && has_cargo)
			var/selection = tgui_input_list(user, "Какой грузовой отсек открыть?", "Груз челнока", list("Открыть малый отсек", "Выгрузить ящик"))
			if(!selection || QDELETED(src) || !can_service_cargo(user) || user.get_active_held_item())
				return
			if(selection == "Открыть малый отсек" && !QDELETED(loot) && sec_cargo_system == loot)
				loot.check_storage(user)
			else if(selection == "Выгрузить ящик" && !QDELETED(cargo) && cargo_system == cargo)
				unload(user)
		else if(has_loot)
			loot.check_storage(user)
		else if(has_cargo)
			unload(user)
		else
			balloon_alert(user, cargo ? "грузовой отсек пуст" : "нет грузового модуля!")
		return
	var/list/choices = list()
	if(battery)
		choices["[battery.name] (батарея)"] = battery
	if(internal_tank)
		choices["[internal_tank.name] (воздушный баллон)"] = internal_tank
	for(var/obj/item/spacepod_equipment/module as anything in installed_modules)
		choices["[module.name] ([module.slot])"] = module
	var/choice = tgui_input_list(user, "Какое оборудование извлечь?", "Технический люк", choices)
	if(!choice || user.incapacitated || !Adjacent(user) || !hatch_open || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return
	var/atom/movable/selected = choices[choice]
	if(QDELETED(selected) || selected.loc != src)
		return
	if(selected == internal_tank)
		remove_internal_tank(user)
		return
	if(selected == battery)
		user.put_in_hands(battery)
		return
	var/obj/item/spacepod_equipment/module = selected
	if(module in installed_modules)
		remove_equipment(user, module, module.slot)

/obj/vehicle/sealed/spacepod/crowbar_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return
	if(lock_system && !unlocked && !hatch_open)
		balloon_alert(user, "люк заблокирован!")
		return TRUE
	if(tool.use_tool(src, user, 0, volume = 50))
		sec_cargo_system?.atom_storage?.close_all()
		hatch_open = !hatch_open
		balloon_alert(user, hatch_open ? "люк открыт" : "люк закрыт")
	return TRUE

/obj/vehicle/sealed/spacepod/welder_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return
	if(melting_down || get_integrity() >= max_integrity || DOING_INTERACTION(user, src))
		return TRUE
	if(!tool.tool_start_check(user, amount = 1, heat_required = HIGH_TEMPERATURE_REQUIRED))
		return TRUE
	while(!melting_down && get_integrity() < max_integrity)
		if(!tool.use_tool(src, user, 2 SECONDS, volume = 50))
			break
		if(QDELETED(src) || melting_down || user.incapacitated || !Adjacent(user))
			break
		repair_damage(10)
	return TRUE

/obj/vehicle/sealed/spacepod/proc/toggle_internal_tank(mob/living/user)
	if(!can_control(user))
		return FALSE
	use_internal_tank = !use_internal_tank
	to_chat(user, span_notice("Подача воздуха: [use_internal_tank ? "из баллона" : "снаружи"]."))
	return TRUE

/obj/vehicle/sealed/spacepod/proc/lock_pod(mob/living/user, external = FALSE)
	if(!external && !can_control(user))
		return FALSE
	if(external && (user.incapacitated || !Adjacent(user) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED)))
		return FALSE
	if(!lock_system)
		unlocked = TRUE
		balloon_alert(user, "нет системы блокировки!")
		return FALSE
	sec_cargo_system?.atom_storage?.close_all()
	unlocked = !unlocked
	balloon_alert(user, unlocked ? "двери разблокированы" : "двери заблокированы")
	return TRUE

/obj/vehicle/sealed/spacepod/proc/toggleLights(mob/living/user)
	if(!can_control(user))
		return FALSE
	lights = !lights
	var/static/list/light_colors = list("pod_civ" = COLOR_WHITE, "pod_dece" = COLOR_WHITE, "pod_mil" = "#bbf093", "pod_synd" = "#ff6666", "pod_gold" = COLOR_WHITE, "pod_black" = "#3b8fe5", "pod_industrial" = "#cccc00")
	set_light_color(paint_colors["LIGHTS"] || light_colors[icon_state] || COLOR_WHITE)
	set_light(lights ? lights_power : 0)
	return TRUE

/obj/vehicle/sealed/spacepod/proc/toggleDoors(mob/living/user)
	if(!can_control(user))
		return FALSE
	for(var/obj/machinery/door/poddoor/door in range(3, src))
		var/has_access = door.allowed(user)
		for(var/mob/living/passenger as anything in passengers)
			if(door.allowed(passenger))
				has_access = TRUE
		if(!has_access)
			continue
		if(door.density)
			door.open()
		else
			door.close()
		return TRUE
	balloon_alert(user, "нет доступного шлюза рядом!")
	return FALSE

/obj/vehicle/sealed/spacepod/proc/checkSeat(mob/living/user)
	if(!can_control(user))
		return
	if(!do_after(user, 4 SECONDS, src, timed_action_flags = IGNORE_HELD_ITEM) || !can_control(user))
		return
	if(sec_cargo_system?.atom_storage)
		sec_cargo_system.check_storage(user)
		return
	var/list/loose_items = list()
	for(var/obj/item/item in contents)
		if(item != battery && !(item in installed_modules))
			loose_items += item
	if(!length(loose_items))
		balloon_alert(user, "под сиденьем пусто")
		return
	var/obj/item/found = pick(loose_items)
	user.put_in_hands(found)

/obj/vehicle/sealed/spacepod/proc/apply_paint(mob/living/user)
	if(!can_paint || user.incapacitated || !Adjacent(user))
		return
	var/list/parts = list("Фары" = "LIGHTS", "Окантовка" = "RIM", "Основной цвет" = "PAINT", "Стёкла" = "Windows")
	var/part = tgui_input_list(user, "Выберите элемент", "Покраска челнока", parts)
	if(!part || !parts[part] || user.incapacitated || !Adjacent(user))
		return
	var/color = tgui_color_picker(user, "Выберите цвет", "Цвет")
	if(!color || user.incapacitated || !Adjacent(user) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return
	paint_colors[parts[part]] = color
	if(parts[part] == "LIGHTS")
		set_light_color(color)
	update_appearance()

/obj/vehicle/sealed/spacepod/update_overlays()
	. = ..()
	for(var/state in paint_colors)
		var/mutable_appearance/paint = mutable_appearance(icon, state)
		paint.color = paint_colors[state]
		. += paint
	if(get_integrity() <= max_integrity / 2)
		. += "pod_damage"
	if(get_integrity() <= max_integrity / 4)
		. += "pod_fire"
	if(thruster_flame_active)
		var/mutable_appearance/flame = make_mutable_appearance_directional(mutable_appearance('icons/effects/effects.dmi', "jetfire"), NORTH)
		var/cardinal_heading = dir2angle(dir)
		// Jetfire occupies the bottom four pixels of its 32px canvas.
		flame.pixel_x = 16 - 20 * sin(cardinal_heading)
		flame.pixel_y = 16 - 20 * cos(cardinal_heading)
		flame.transform = matrix().Turn(cardinal_heading)
		. += flame

/obj/vehicle/sealed/spacepod/on_update_integrity(old_value, new_value)
	. = ..()
	update_appearance()
	if(new_value > 0)
		process_cabin_alerts()

/obj/vehicle/sealed/spacepod/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	if(melting_down)
		return 0
	return ..()

/obj/vehicle/sealed/spacepod/repair_damage(amount)
	if(melting_down)
		return 0
	return ..()

/obj/vehicle/sealed/spacepod/atom_destruction(damage_flag, finalize_destruction = FALSE)
	if(finalize_destruction)
		return ..(damage_flag)
	if(melting_down)
		return
	melting_down = TRUE
	set_thruster_flame(FALSE)
	stop_engine_sound()
	to_chat(occupants, span_userdanger("Критическое разрушение корпуса! Взрыв ядра!"))
	detonate(damage_flag)

/obj/vehicle/sealed/spacepod/proc/detonate(damage_flag)
	if(QDELETED(src))
		return
	for(var/mob/living/occupant in (contents | occupants))
		occupant.adjust_brute_loss(300)
	var/turf/location = get_turf(src)
	if(location)
		explosion(location, light_impact_range = 2, adminlog = FALSE)
	leave_wreckage()
	atom_destruction(damage_flag, finalize_destruction = TRUE)

/obj/vehicle/sealed/spacepod/ex_act(severity, target)
	if(QDELETED(src))
		return
	if(severity == EXPLODE_DEVASTATE)
		for(var/mob/living/occupant in (contents | occupants))
			mob_exit(occupant, silent = TRUE)
			occupant.ex_act(EXPLODE_HEAVY)
		leave_wreckage()
		qdel(src)
	else if(severity == EXPLODE_HEAVY)
		take_damage(100, BRUTE, BOMB)
	else if(severity == EXPLODE_LIGHT && prob(40))
		take_damage(50, BRUTE, BOMB)

/obj/vehicle/sealed/spacepod/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	set_thruster_flame(FALSE)
	stop_engine_sound()
	if(battery?.charge > 0)
		battery.use(battery.charge / (6 * severity))
	if(QDELETED(src))
		return
	for(var/obj/item/spacepod_equipment/module as anything in installed_modules.Copy())
		module.emp_act(severity)
	take_damage(80 / severity, BURN)
	if(QDELETED(src))
		return
	if(COOLDOWN_TIMELEFT(src, cooldown_emp) < 80 SECONDS / severity)
		COOLDOWN_START(src, cooldown_emp, 80 SECONDS / severity)
	to_chat(occupants, span_warning("Консоль челнока мигает: ОБНАРУЖЕНА ЭМИ-ВОЛНА!"))

/obj/vehicle/sealed/spacepod/civilian
	desc = "Стильный гражданский космический челнок."
	can_paint = TRUE

/obj/vehicle/sealed/spacepod/sec
	name = "security spacepod"
	desc = "Бронированный челнок службы безопасности с усиленной бронёй."
	icon_state = "pod_dece"
	max_integrity = 600

/obj/vehicle/sealed/spacepod/sec/Initialize(mapload)
	. = ..()
	install_equipment(new /obj/item/spacepod_equipment/weaponry/taser(src), "weapon_system")
	install_equipment(new /obj/item/spacepod_equipment/misc/tracker(src), "misc_system")
	install_equipment(new /obj/item/spacepod_equipment/sec_cargo/chair(src), "sec_cargo_system")
	install_equipment(new /obj/item/spacepod_equipment/lock/keyed(src), "lock_system")
	lock_system.id = 100000

/obj/vehicle/sealed/spacepod/syndi
	name = "syndicate spacepod"
	desc = "Челнок, окрашенный в цвета Синдиката."
	icon_state = "pod_synd"
	max_integrity = 400
	unlocked = FALSE

/obj/vehicle/sealed/spacepod/syndi/unlocked
	unlocked = TRUE

/obj/vehicle/sealed/spacepod/syndicate
	parent_type = /obj/vehicle/sealed/spacepod/syndi

/obj/vehicle/sealed/spacepod/random
	icon_state = "pod_civ"

/obj/vehicle/sealed/spacepod/random/Initialize(mapload)
	. = ..()
	icon_state = pick("pod_civ", "pod_black", "pod_mil", "pod_synd", "pod_gold", "pod_industrial")
	update_appearance()

/obj/vehicle/sealed/spacepod/civilian/damaged
	desc = "Сильно повреждённый челнок."

/obj/vehicle/sealed/spacepod/civilian/damaged/Initialize(mapload)
	. = ..()
	take_damage(200)

/obj/item/pod_paint_bucket
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 0.5)
	name = "space pod paintkit"
	desc = "Набор для окрашивания корпуса, стёкол и фар гражданского челнока."
	icon = 'icons/obj/art/paint.dmi'
	icon_state = "paint_red"

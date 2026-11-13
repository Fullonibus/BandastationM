/**
 * Engine sound of one hull: idle and thrust loops inside and outside it, following the drive's actual work.
 *
 * Idle runs while the drive is lit; the thrust layer follows the commanded thrust times the output the engines deliver,
 * never the hull speed, so a drifting hull with cold engines stays silent. Levels glide towards their targets and reach
 * listeners only past a step threshold, so a steady drive sends nothing. Loops never restart on an update.
 */
/datum/stationtrauma_engine_sound
	/// Owning navigation; its hull and engines are the sound sources.
	var/datum/stationtrauma_overmap/space/map
	/// Hull-only idle loop heard by the crew aboard.
	var/datum/sound_token/stationtrauma_ship_interior/engine/interior_idle
	/// Hull-only thrust loop heard by the crew aboard.
	var/datum/sound_token/stationtrauma_ship_interior/engine/interior_thrust
	/// Idle loop at a nozzle, heard only outside the hull.
	var/datum/sound_token/stationtrauma_engine_exterior/exterior_idle
	/// Thrust loop at a nozzle, heard only outside the hull.
	var/datum/sound_token/stationtrauma_engine_exterior/exterior_thrust
	/// Hull-only roar of atmospheric flight, independent of the drive.
	var/datum/sound_token/stationtrauma_ship_interior/engine/entry_roar
	/// Whether the drive is audibly lit.
	var/running = FALSE
	/// Smoothed idle level from 0 to 1.
	var/idle_level = 0
	/// Smoothed thrust level from 0 to 1; it also raises the pitch of both layers.
	var/thrust_level = 0
	/// Idle level last sent to listeners.
	var/sent_idle = -1
	/// Thrust level last sent to listeners.
	var/sent_thrust = -1
	/// Smoothed atmospheric roar level from 0 to 1.
	var/entry_level = 0
	/// Roar level last sent to listeners.
	var/sent_entry = -1
	/// Loop heard aboard through atmospheric flight.
	var/entry_roar_sound = 'sound/runtime/hyperspace/hyperspace_progress.ogg'
	/// Clip heard aboard when the drive lights.
	var/interior_start_sound = 'modular_bandastation/space_overmap/sound/engine/engine_interior_start.ogg'
	/// Loop heard aboard while the drive idles.
	var/interior_idle_sound = 'modular_bandastation/space_overmap/sound/engine/engine_interior_idle.ogg'
	/// Loop heard aboard over the idle while the drive thrusts.
	var/interior_thrust_sound = 'modular_bandastation/space_overmap/sound/engine/engine_interior_thrust.ogg'
	/// Clip heard aboard when the drive goes out.
	var/interior_stop_sound = 'modular_bandastation/space_overmap/sound/engine/engine_interior_stop.ogg'
	/// Clip heard outside when the drive lights.
	var/exterior_start_sound = 'modular_bandastation/space_overmap/sound/engine/engine_exterior_start.ogg'
	/// Loop heard outside while the drive idles.
	var/exterior_idle_sound = 'modular_bandastation/space_overmap/sound/engine/engine_exterior_idle.ogg'
	/// Loop heard outside over the idle while the drive thrusts.
	var/exterior_thrust_sound = 'modular_bandastation/space_overmap/sound/engine/engine_exterior_thrust.ogg'
	/// Clip heard outside when the drive goes out.
	var/exterior_stop_sound = 'modular_bandastation/space_overmap/sound/engine/engine_exterior_stop.ogg'

/datum/stationtrauma_engine_sound/New(datum/stationtrauma_overmap/space/owner)
	map = owner
	return ..()

/datum/stationtrauma_engine_sound/Destroy()
	release()
	map = null
	return ..()

/**
 * Follow the drive state.
 *
 * Arguments:
 * * seconds_per_tick - Time the levels glide for; zero applies only start and stop transitions
 */
/datum/stationtrauma_engine_sound/proc/update(seconds_per_tick)
	var/obj/docking_port/mobile/stationtrauma_space/vessel = map.vessel
	var/available = vessel.engines_running ? map.engine_fraction() : 0
	var/lit = vessel.engines_running && available > 0
	if(lit && !running)
		running = TRUE
		create_layers()
		play_once(interior_start_sound, exterior_start_sound)
	else if(!lit && running)
		running = FALSE
		play_once(interior_stop_sound, exterior_stop_sound)
	// Idle rumble grows with the share of the drive that delivers.
	var/idle_target = lit ? 0.4 + 0.6 * available : 0
	var/thrust_target = lit ? map.commanded_thrust() * available : 0
	var/entry_target = map.entry_heat()
	var/step = ST_ENGINE_SOUND_GLIDE * seconds_per_tick
	idle_level += clamp(idle_target - idle_level, -step, step)
	thrust_level += clamp(thrust_target - thrust_level, -step, step)
	entry_level += clamp(entry_target - entry_level, -step, step)
	if(!running && idle_level <= 0 && thrust_level <= 0 && entry_level <= 0)
		release()
		return
	if(running)
		create_layers()
	if(entry_level > 0 && QDELETED(entry_roar))
		entry_roar = new(map.vessel, entry_roar_sound, map.radius * 2 + 2, 1, _repeating = TRUE)
		sent_entry = -1
	if(abs(entry_level - sent_entry) >= ST_ENGINE_SOUND_STEP || (entry_level == entry_target && entry_level != sent_entry))
		sent_entry = entry_level
		// The roar deepens as the air thickens around the hull.
		set_layer(entry_roar, 75 * entry_level, 0.75 + 0.15 * entry_level)
	// Small changes wait for the next threshold step, but a settled level is always sent exactly.
	var/idle_due = abs(idle_level - sent_idle) >= ST_ENGINE_SOUND_STEP || (idle_level == idle_target && idle_level != sent_idle)
	var/thrust_due = abs(thrust_level - sent_thrust) >= ST_ENGINE_SOUND_STEP || (thrust_level == thrust_target && thrust_level != sent_thrust)
	if(!idle_due && !thrust_due)
		return
	sent_idle = idle_level
	sent_thrust = thrust_level
	// Higher thrust spins both layers up; frequency is a playback rate multiplier.
	set_layer(interior_idle, 32 * idle_level, 0.85 + 0.3 * thrust_level)
	set_layer(interior_thrust, 40 * thrust_level, 0.9 + 0.25 * thrust_level)
	set_layer(exterior_idle, 50 * idle_level, 0.85 + 0.3 * thrust_level)
	set_layer(exterior_thrust, 60 * thrust_level, 0.9 + 0.25 * thrust_level)

/** Create missing loops; a destroyed nozzle takes its exterior loops with it, so they move to a surviving one. */
/datum/stationtrauma_engine_sound/proc/create_layers()
	var/obj/docking_port/mobile/stationtrauma_space/vessel = map.vessel
	var/created = FALSE
	if(QDELETED(interior_idle))
		interior_idle = new(vessel, interior_idle_sound, map.radius * 2 + 2, 1, _repeating = TRUE)
		created = TRUE
	if(QDELETED(interior_thrust))
		interior_thrust = new(vessel, interior_thrust_sound, map.radius * 2 + 2, 1, _repeating = TRUE)
		created = TRUE
	if(QDELETED(exterior_idle) || QDELETED(exterior_thrust))
		var/obj/machinery/power/shuttle_engine/nozzle = nozzle()
		var/range = max(vessel.width, vessel.height) + 10
		if(nozzle && QDELETED(exterior_idle))
			exterior_idle = new(nozzle, exterior_idle_sound, range, 1, _falloff_distance = 5, _repeating = TRUE)
			created = TRUE
		if(nozzle && QDELETED(exterior_thrust))
			exterior_thrust = new(nozzle, exterior_thrust_sound, range, 1, _falloff_distance = 5, _repeating = TRUE)
			created = TRUE
	if(created)
		sent_idle = sent_thrust = -1

/** Middle intact nozzle of the hull, the outside source of the drive's sound. */
/datum/stationtrauma_engine_sound/proc/nozzle()
	var/list/engines = list()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in map.vessel.engine_list)
		if(!QDELETED(engine))
			engines += engine
	return length(engines) ? engines[CEILING(length(engines) / 2, 1)] : null

/** Update a loop in place: a silent layer is muted rather than stopped, so it resumes without restarting. */
/datum/stationtrauma_engine_sound/proc/set_layer(datum/sound_token/layer, volume, frequency)
	if(QDELETED(layer))
		return
	layer.sound.frequency = frequency
	layer.sound_status = volume < 1 ? SOUND_MUTE : NONE
	layer.set_volume(max(1, volume))

/** Play a start or stop clip to the listeners of the matching layer. */
/datum/stationtrauma_engine_sound/proc/play_once(interior_clip, exterior_clip)
	if(!QDELETED(interior_idle))
		for(var/mob/listener as anything in interior_idle.listeners)
			if(!(interior_idle.listeners[listener] & SOUND_MUTE))
				listener.playsound_local(get_turf(listener), interior_clip, 45, pressure_affected = FALSE, use_reverb = FALSE, volume_preference = /datum/preference/numeric/volume/sound_ship_ambience_volume)
	if(!QDELETED(exterior_idle))
		var/turf/source = get_turf(exterior_idle.source)
		for(var/mob/listener as anything in exterior_idle.listeners)
			if(!(exterior_idle.listeners[listener] & SOUND_MUTE))
				listener.playsound_local(source, exterior_clip, 75, max_distance = exterior_idle.range, falloff_distance = 5, pressure_affected = FALSE)

/** Free every loop and its sound channel. */
/datum/stationtrauma_engine_sound/proc/release()
	QDEL_NULL(interior_idle)
	QDEL_NULL(interior_thrust)
	QDEL_NULL(exterior_idle)
	QDEL_NULL(exterior_thrust)
	QDEL_NULL(entry_roar)
	sent_idle = sent_thrust = sent_entry = -1

/** Cut the drive sound at once, with its stop clip when it was running; for a hull leaving processing. */
/datum/stationtrauma_engine_sound/proc/silence()
	if(running)
		running = FALSE
		play_once(interior_stop_sound, exterior_stop_sound)
	idle_level = thrust_level = entry_level = 0
	release()

/// Engine loops start muted, so the first send already plays them and later updates only unmute.
/datum/sound_token/stationtrauma_ship_interior/engine
	sound_status = SOUND_MUTE

/// Exterior engine loop at a nozzle; listeners inside the hull hear the interior layers instead.
/datum/sound_token/stationtrauma_engine_exterior
	sound_status = SOUND_MUTE

/**
 * Native range and level tracking, but only the listener's air carries the sound: the nozzle tile itself is open to space,
 * so the native minimum of both pressures would silence the drive even for listeners in a pressurised station.
 * shortcut: the listener's pressure is read on native updates only, so leaving the air keeps the loop until the next one.
 */
/datum/sound_token/stationtrauma_engine_exterior/update_listener(mob/listener_mob, update_sound = TRUE)
	if(QDELETED(src) || isnull(listeners[listener_mob]))
		return
	var/turf/source_turf = get_turf(source)
	var/turf/listener_turf = get_turf(listener_mob)
	if(!source_turf || !listener_turf)
		return
	var/obj/machinery/power/shuttle_engine/engine = source
	var/obj/docking_port/mobile/stationtrauma_space/ship = engine.connected_ship
	var/aboard = ship?.shuttle_areas[get_area(listener_mob)] && ship.is_in_shuttle_bounds(listener_mob)
	var/muted = aboard || source_turf.z != listener_turf.z || get_dist_euclidean(source_turf, listener_turf) > range || HAS_TRAIT(listener_mob, TRAIT_DEAF) || listener_turf.return_air()?.return_pressure() < SOUND_MINIMUM_PRESSURE
	if(muted && (listeners[listener_mob] & SOUND_MUTE))
		return
	set_listener_status(listener_mob, muted ? SOUND_MUTE : NONE)
	sound.status = sound_status | listeners[listener_mob] | (update_sound ? SOUND_UPDATE : NONE)
	if(!update_sound)
		sound.offset = calculate_offset()
	// Kept playing muted: the native unmute is an in-place update, and a first send must start the loop.
	if(muted || !listener_mob.playsound_local(source_turf, vol = volume, falloff_exponent = falloff_exponent, channel = sound_channel, sound_to_use = sound, max_distance = range, falloff_distance = falloff_distance, pressure_affected = FALSE))
		sound.status = sound_status | SOUND_MUTE | (update_sound ? SOUND_UPDATE : NONE)
		SEND_SOUND(listener_mob, sound)
	sound.offset = null

/** The native token tracks movement/login/logout; interior ambience is non-positional and hull-only. */
/datum/sound_token/stationtrauma_ship_interior/update_listener(mob/listener_mob, update_sound = TRUE)
	if(QDELETED(src) || isnull(listeners[listener_mob]))
		return
	var/obj/docking_port/mobile/stationtrauma_space/ship = source
	var/was_muted = listeners[listener_mob] & SOUND_MUTE
	if(!listener_mob.client || isobserver(listener_mob) || HAS_TRAIT(listener_mob, TRAIT_DEAF) || !ship.shuttle_areas[get_area(listener_mob)] || !ship.is_in_shuttle_bounds(listener_mob) || !listener_mob.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume))
		set_listener_status(listener_mob, SOUND_MUTE)
		if(!was_muted)
			SEND_SOUND(listener_mob, null_sound)
		return
	set_listener_status(listener_mob, NONE)
	sound.status = sound_status | (update_sound && !was_muted ? SOUND_UPDATE : NONE)
	if(!(sound.status & SOUND_UPDATE))
		sound.offset = calculate_offset()
	listener_mob.playsound_local(get_turf(listener_mob), vol = volume, channel = sound_channel, sound_to_use = sound, pressure_affected = FALSE, use_reverb = FALSE, volume_preference = /datum/preference/numeric/volume/sound_ship_ambience_volume)
	sound.offset = null

/area/shuttle/stationtrauma_space/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(ismob(arrived))
		var/mob/crew = arrived
		crew.stop_sound_channel(CHANNEL_AMBIENCE)

/datum/stationtrauma_overmap/space
	/// Owned engine sound following the drive's actual work.
	var/datum/stationtrauma_engine_sound/engine_sound
	/// Owned ambience token restricted to listeners inside the physical hull.
	var/datum/sound_token/stationtrauma_ship_interior/interior_audio

/** Create the hull-owned ambience and engine audio resources. */
/datum/stationtrauma_overmap/space/proc/initialize_ship_audio()
	engine_sound = new(src)
	interior_audio = new(vessel, 'sound/ambience/general/shipambience.ogg', radius * 2 + 2, 22, _repeating = TRUE)
	refresh_engine_audio()

/** Switch main propulsion without erasing drift. */
/datum/stationtrauma_overmap/space/proc/set_engines_running(enabled)
	if(!(enabled in list(FALSE, TRUE)) || !is_operational() || (enabled && (preparing || relocating)))
		return FALSE
	if(vessel.engines_running == enabled)
		return TRUE
	if(enabled)
		// Picks up converters and plasma heaters rebuilt during the round.
		var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = vessel.fusion_core?.resolve()
		reactor?.bind_converters()
		vessel.bind_plasma_heaters()
		if(engine_fraction() <= 0)
			return FALSE
	vessel.engines_running = enabled
	if(!enabled)
		command_course(ordered_course)
		throttle = 0
		braking = FALSE
		maneuver_direction = NONE
		helm_engaged = speed > ST_NAV_STOPPED_SPEED
	refresh_engine_audio()
	return TRUE

/**
 * Refresh the exhaust and the engine sound.
 *
 * Arguments:
 * * seconds_per_tick - Time the sound levels glide for; zero applies only start and stop transitions
 */
/datum/stationtrauma_overmap/space/proc/refresh_engine_audio(seconds_per_tick = 0)
	refresh_engine_exhaust()
	engine_sound?.update(seconds_per_tick)

/** Main-engine demand from the pilot or the automatic landing, ascent and docking manoeuvre, from 0 to 1. */
/datum/stationtrauma_overmap/space/proc/commanded_thrust()
	if(approach_started)
		if(approach_departing)
			return (approach_site?.landing ? 1 : 0.5) * clamp((world.time - approach_started) / ST_SPACE_DEPARTURE_DELAY, 0, 1)
		return approach_site?.landing ? 1 : 0.15
	if(!helm_engaged || docked)
		return 0
	return max(abs(throttle) / 100, !!braking, !!maneuver_direction)

/** Show each firing nozzle's actual converter palette and fusion overdrive state. */
/datum/stationtrauma_overmap/space/proc/refresh_engine_exhaust()
	var/thrusting = vessel.engines_running && commanded_thrust() > 0
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = vessel.fusion_core?.resolve()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list)
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
		var/boosted = reactor?.overdrive_active() && !reactor.is_electric && feed?.core?.resolve() == reactor
		engine.set_exhaust(thrusting && engine_output(engine) > 0, boosted, feed?.exhaust_gradient)

/** Docking latch; a remote seam also has listeners on the destination level, physical docking needs only one emission. */
/datum/stationtrauma_overmap/space/proc/play_maneuver_audio(atom/remote)
	var/clip = 'sound/machines/airlock/airlock_latch_hiss.ogg'
	playsound(vessel, clip, 25, FALSE, extrarange = radius, pressure_affected = FALSE)
	if(!QDELETED(remote) && remote.z != vessel.z)
		playsound(remote, clip, 12, FALSE, extrarange = radius, pressure_affected = FALSE)

/** A short launch roar or release of docking latches, with a visual jolt aboard the departing hull. */
/datum/stationtrauma_overmap/space/proc/play_departure_effects(planetary = FALSE)
	if(planetary)
		playsound(vessel, 'sound/vehicles/rocketlaunch.ogg', 50, TRUE, extrarange = radius, pressure_affected = FALSE)
	else
		play_maneuver_audio()
	for(var/mob/crew as anything in SSmobs.clients_by_zlevel[vessel.z])
		if(vessel.is_in_shuttle_bounds(crew))
			shake_camera(crew, 0.5 SECONDS, 1)

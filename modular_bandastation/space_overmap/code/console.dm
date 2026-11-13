/** Navigation and helm console. */
/obj/machinery/computer/stationtrauma_space_navigation
	name = "навигационная консоль"
	desc = "Орбитальная карта, управление тягой и стыковкой корабля."
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/computer/stationtrauma_space_navigation
	/// Physical hull controlled by this navigation instance or console.
	var/obj/docking_port/mobile/stationtrauma_space/vessel

/** Circuit board kept when the helm console is dismantled or wrecked. */
/obj/item/circuitboard/computer/stationtrauma_space_navigation
	name = "навигационная консоль"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/stationtrauma_space_navigation

/datum/design/board/shuttle/stationtrauma_space_navigation
	name = "Плата навигационной консоли"
	desc = "Плата консоли, управляющей полётом корабля, в котором она установлена."
	build_path = /obj/item/circuitboard/computer/stationtrauma_space_navigation

/datum/techweb_node/shuttle_engineering/New()
	. = ..()
	unlocked_designs += list(
		/datum/design/board/shuttle/stationtrauma_space_navigation,
		/datum/design/board/stationtrauma_bluespace_drive,
		/datum/design/board/stationtrauma_engine,
		/datum/design/board/stationtrauma_engine/left,
		/datum/design/board/stationtrauma_engine/right,
		/datum/design/board/stationtrauma_engine/burst,
		/datum/design/board/stationtrauma_engine/burst_left,
		/datum/design/board/stationtrauma_engine/burst_right,
		/datum/design/board/stationtrauma_engine/huge,
		/datum/design/board/stationtrauma_large_engine,
		/datum/design/board/stationtrauma_large_converter,
		/datum/design/board/stationtrauma_ship_generator,
		/datum/design/board/stationtrauma_plasma_core,
		/datum/design/board/stationtrauma_plasma_converter,
	)

/obj/machinery/computer/stationtrauma_space_navigation/post_machine_initialize()
	. = ..()
	connect_to_shuttle(FALSE, SSshuttle.get_containing_shuttle(src))

/// A console rebuilt aboard takes over the helm of the hull it stands in.
/obj/machinery/computer/stationtrauma_space_navigation/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/ship = port
	if(istype(ship) && ship.is_in_shuttle_bounds(src))
		vessel = ship

/obj/machinery/computer/stationtrauma_space_navigation/Destroy()
	vessel = null
	return ..()

/obj/machinery/computer/stationtrauma_space_navigation/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!vessel?.overmap || !can_interact(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SpaceNavigation", name)
		ui.open()

/obj/machinery/computer/stationtrauma_space_navigation/ui_data(mob/user)
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(!map)
		return list()
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = vessel.fusion_core?.resolve()
	var/engine_fraction = map.engine_fraction()
	var/engine_fault = reactor ? reactor.tripped : engine_fraction <= 0
	if(reactor?.output && !engine_fault)
		engine_fault = engine_fraction <= 0 || vessel.current_engine_power < vessel.initial_engine_power
		for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list)
			if(engine_fault)
				break
			if(!engine.requires_combustion)
				continue
			var/obj/machinery/atmospherics/components/unary/ship_engine_heater/feed = engine.combustion_feed?.resolve()
			engine_fault = !feed || !!feed.unavailable_reason()
	var/datum/stationtrauma_overmap_sector/space/sector = map.sector
	var/datum/stationtrauma_overmap_site/space/target = map.sites[map.selected_destination]
	if(!map.knows_site(target))
		target = null
	var/distance = target ? map.distance_to(target) : 0
	var/list/data = list(
		"vessel_name" = vessel.name,
		"au_scale" = ST_SPACE_AU_SCALE,
		"status" = map.status,
		"sector" = sector?.id, "sector_name" = sector?.name,
		"jumping" = !!map.jump_target,
		"star" = list("x" = 0, "y" = 0, "name" = sector?.star_name, "radius" = sector?.star_radius || 10),
		"celestial_bodies" = sector?.celestial_bodies,
		"x" = map.pos_x, "y" = map.pos_y,
		"vx" = map.velocity_x, "vy" = map.velocity_y, "trajectory" = map.predict_trajectory(),
		"course" = map.course, "ordered_course" = map.ordered_course,
		"speed" = map.speed, "throttle" = map.approach_started ? round(100 * map.commanded_thrust()) * vessel.engines_running : map.throttle, "speed_scale" = ST_SPACE_MAX_SPEED,
		"maneuver_direction" = map.maneuver_direction,
		"braking" = map.braking, "braking_distance" = map.get_braking_distance(),
		"emergency_braking" = map.emergency_braking && vessel.has_power(),
		"ship_power" = vessel.has_power(),
		"engines" = round(engine_fraction * 100),
		"engines_running" = vessel.engines_running,
		"core_overdrive" = !!reactor?.overdrive_active(),
		"afterburner" = !!reactor?.overdrive,
		"can_afterburner" = !!reactor && reactor.active && !reactor.tripped,
		"core_heat" = reactor ? round(reactor.heat) : null,
		"fuel" = vessel.fuel_gauges(),
		"engine_fault" = engine_fault,
		"can_start_engines" = engine_fraction > 0,
		"helm" = map.helm_engaged, "autopilot" = map.autopilot,
		"preparing" = map.preparing, "planning" = map.planning,
		"relocating" = map.relocating, "landed" = !!map.docked?.landing,
		"selected" = map.selected_destination, "docked" = map.docked?.id,
		"coupled" = !!map.ship_docking,
		"docking_request" = map.ship_docking_request_data(),
		"station_docking" = map.station_docking_data(target),
		"can_request_ship_dock" = map.available_for_ship_docking(),
		"dockable_contacts" = map.dockable_ship_contacts(),
		"landing" = target?.landing, "distance" = distance,
		"eta" = target && map.get_target_speed() > 0 ? max(0, distance - map.radius - target.radius) / map.get_target_speed() : null,
		"scan_ready" = !map.preparing && !map.relocating && map.is_operational() && world.time >= map.next_scan && !panel_open && !(machine_stat & (NOPOWER|BROKEN)),
		"can_dock" = !map.preparing && !map.docked && !map.helm_engaged && map.speed <= ST_NAV_STOPPED_SPEED \
			&& (!map.station_clearance_required(target) || map.has_station_clearance(target)) && map.can_dock(target, map.control_revision),
		"routes" = map.known_sites(), "path" = map.autopilot_path,
		"zones" = map.encounter_data(), "terrain" = map.terrain_data(),
		"ship_contacts" = map.ship_echo_data(),
		"encounter" = map.encounter_status, "sensor_range" = map.sensor_range,
		"interference" = round(map.interference, 0.05),
		"scan_age" = isnull(map.last_ping) ? null : (world.time - map.last_ping) / (1 SECONDS),
		"approach" = null,
	)
	var/list/hull = vessel.compartment_report()
	data["compartments"] = hull["rooms"]
	data["hull"] = hull["rows"]
	var/datum/stationtrauma_overmap_site/space/approach_site = map.approach_site
	var/datum/stationtrauma_ship_docking/pair = map.ship_docking
	var/datum/stationtrauma_overmap/space/peer = pair ? (pair.first == map ? pair.second : pair.first) : null
	if(map.approach_started && (!QDELETED(approach_site) || !QDELETED(peer)))
		var/datum/stationtrauma_overmap_site/space/planet/approach_planet = approach_site
		data["approach"] = list(
			"elapsed" = (world.time - map.approach_started) / (1 SECONDS),
			"duration" = map.approach_duration / (1 SECONDS),
			"departing" = map.approach_departing,
			"site" = !QDELETED(approach_site) ? map.site_label(approach_site) : peer.vessel?.name || "Корабль",
			"scene" = istype(approach_planet) ? "planet" : approach_site?.approach_scene || "station",
			"biome" = istype(approach_planet) ? approach_planet.ruin_biome : null,
			"loading" = !!approach_site?.loading_map,
		)
	if(istype(target, /datum/stationtrauma_overmap_site/space/planet) && map.knows_site(target))
		var/datum/stationtrauma_overmap_site/space/planet/planet = target
		data["planet"] = planet.survey_data()
	return data

/** Validate and dispatch a helm command. */
/obj/machinery/computer/stationtrauma_space_navigation/proc/navigation_command(action, value)
	var/datum/stationtrauma_overmap/space/map = vessel?.overmap
	if(!map || panel_open || (machine_stat & (NOPOWER|BROKEN)))
		return FALSE
	// The pilot may relinquish clearance until the physical move consumes it.
	if(action == "cancel_station_dock")
		return istext(value) && value == map.selected_destination && map.cancel_station_docking()
	if(map.relocating || map.approach_started)
		return FALSE
	if((map.jump_target || map.dispatch_target) && action != "stop")
		return FALSE
	map.advance()
	switch(action)
		if("ship_dock")
			return map.request_ship_docking(value)
		if("accept_ship_dock", "decline_ship_dock")
			return map.respond_ship_docking(value, action == "accept_ship_dock")
		if("request_station_dock")
			return istext(value) && value == map.selected_destination && map.request_station_docking(value)
		if("engine")
			if(!(value in list(0, 1)))
				return FALSE
			return map.set_engines_running(value == 1)
		if("afterburner")
			var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = vessel.fusion_core?.resolve()
			return reactor?.toggle_overdrive()
		if("maneuver")
			var/direction = value
			return IS_FINITE(direction) && map.command_maneuver(direction)
		if("scan")
			if(!map.scan_sector())
				return FALSE
			playsound(src, 'sound/machines/radar-ping.ogg', 50, FALSE)
			return TRUE
		if("stop")
			map.request_brake()
		if("emergency_brake")
			return map.command_emergency_brake()
		if("select")
			return istext(value) && map.select_site(value)
		if("turn", "throttle")
			var/number = value
			if(!IS_FINITE(number) || !vessel.engines_running || map.ship_docking)
				return FALSE
			if(action == "turn")
				if(!(number in list(-15, 15)))
					return FALSE
				map.command_course(map.ordered_course + number)
			else
				return map.command_throttle(number)
		if("depart")
			map.command_course(map.ordered_course)
			return map.sail()
		if("autopilot")
			if(map.preparing || map.ship_docking || map.planning || map.throttle <= 0 || map.docked?.id == map.selected_destination)
				return FALSE
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap, engage_autopilot))
		if("dock")
			if(!isnull(value) && (!istext(value) || value != map.selected_destination))
				return FALSE
			var/datum/stationtrauma_overmap_site/space/target = map.sites[map.selected_destination]
			if(map.station_clearance_required(target) && (isnull(value) || !map.has_station_clearance(target)))
				return FALSE
			INVOKE_ASYNC(map, TYPE_PROC_REF(/datum/stationtrauma_overmap/space, dock))
		else
			return FALSE
	return TRUE

/** TGUI permissions and machine interaction checks precede every helm command. */
/obj/machinery/computer/stationtrauma_space_navigation/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!can_interact(ui.user))
		return FALSE
	if(action == "interface_click")
		return TRUE
	return navigation_command(action, params["value"])

/** Navigation buttons use the supplied tone; the throttle lever keeps the native mechanical click. */
/obj/machinery/computer/stationtrauma_space_navigation/play_ui_sound(action, list/params)
	if(action == "throttle" && params?["button"] != TRUE)
		return ..()
	playsound(src, 'modular_bandastation/space_overmap/sound/navigation_button.wav', 10, FALSE, FALSE)

GLOBAL_VAR_INIT(stationtrauma_ship_commissioning, FALSE)
/// Reuse a flight level if a construction order is cancelled after the level is allocated.
GLOBAL_VAR_INIT(stationtrauma_available_flight_z, 0)

/// A player-built ship needs its own APC and power grid.
/area/shuttle/stationtrauma_space/player
	requires_power = TRUE

/// Commissioned player-built hulls can replace a lost core at their existing vessel.
/obj/docking_port/mobile/stationtrauma_space/player
	ship_class = ST_SHIP_SMALL
	area_type = /area/shuttle/stationtrauma_space/player
	/// Installed navigation core used to authorize a new docking maneuver.
	var/datum/weakref/ship_core

/obj/docking_port/mobile/stationtrauma_space/player/permits_docking(datum/stationtrauma_overmap_site/space/site)
	. = ..()
	if(!.)
		return
	var/obj/machinery/computer/stationtrauma_ship_core/core = ship_core?.resolve()
	return !QDELETED(core) && core.hull_class == ship_class && core.anchored && !(core.machine_stat & BROKEN) && is_in_shuttle_bounds(core)

/// A private berth where a new ship is constructed. It disappears after the first launch.
/obj/docking_port/stationary/stationtrauma_space_construction
	name = "Строительная стоянка"
	shuttle_id = "stationtrauma_space_construction"
	hidden = TRUE

/datum/stationtrauma_overmap/space
	/// The construction berth is private to this ship and is never published to the sector.
	var/datum/stationtrauma_overmap_site/space/construction_site

/// Release the private berth once the hull has left or the navigation instance is deleted.
/datum/stationtrauma_overmap/space/proc/clear_construction_site()
	if(!construction_site)
		return
	if(construction_site.berth)
		qdel(construction_site.berth, force = TRUE)
	QDEL_NULL(construction_site)

/obj/item/circuitboard/computer/stationtrauma_ship_core
	name = "ядро корабля класса S"
	build_path = /obj/machinery/computer/stationtrauma_ship_core

/obj/item/circuitboard/computer/stationtrauma_ship_core/medium
	name = "ядро корабля класса M"
	build_path = /obj/machinery/computer/stationtrauma_ship_core/medium

/obj/item/circuitboard/computer/stationtrauma_space_navigation
	name = "навигационная консоль"
	build_path = /obj/machinery/computer/stationtrauma_space_navigation

/datum/design/board/stationtrauma_ship_core
	name = "Плата ядра корабля класса S"
	desc = "Плата для активации корпуса класса S на строительном каркасе шаттла."
	build_path = /obj/item/circuitboard/computer/stationtrauma_ship_core
	category = list(RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/stationtrauma_ship_core/medium
	name = "Плата ядра корабля класса M"
	desc = "Плата для активации корпуса класса M на строительном каркасе шаттла."
	build_path = /obj/item/circuitboard/computer/stationtrauma_ship_core/medium

/datum/design/board/stationtrauma_space_navigation
	name = "Плата навигационной консоли корабля"
	desc = "Плата консоли управления кораблём и стыковкой."
	build_path = /obj/item/circuitboard/computer/stationtrauma_space_navigation
	category = list(RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/obj/machinery/computer/stationtrauma_space_navigation
	circuit = /obj/item/circuitboard/computer/stationtrauma_space_navigation

/obj/machinery/computer/stationtrauma_space_navigation/on_construction(mob/user)
	. = ..()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	if(istype(ship))
		vessel = ship

/// Activates a completed frame or replaces an absent core on a hull of the same class.
/obj/machinery/computer/stationtrauma_ship_core
	name = "ядро корабля класса S"
	desc = "Активирует завершённый строительный каркас шаттла класса S. После активации кораблём управляет навигационная консоль."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/stationtrauma_dispatch")
	icon_screen = "shuttle"
	use_power = NO_POWER_USE
	circuit = /obj/item/circuitboard/computer/stationtrauma_ship_core
	/// Class recorded on the hull after frame conversion.
	var/hull_class = ST_SHIP_SMALL
	/// Crew-facing abbreviation for the class.
	var/class_label = "S"
	/// Short and long dimensions of a compatible berth.
	var/hull_width = ST_STANDARD_S_WIDTH
	var/hull_height = ST_STANDARD_S_HEIGHT
	/// Optional tile limit for this class. Null uses the configured custom shuttle limit.
	var/frame_tile_limit

/obj/machinery/computer/stationtrauma_ship_core/medium
	name = "ядро корабля класса M"
	desc = "Активирует завершённый строительный каркас шаттла класса M. После активации кораблём управляет навигационная консоль."
	circuit = /obj/item/circuitboard/computer/stationtrauma_ship_core/medium
	hull_class = ST_SHIP_MEDIUM
	class_label = "M"
	hull_width = ST_STANDARD_M_WIDTH
	hull_height = ST_STANDARD_M_HEIGHT
	frame_tile_limit = ST_STANDARD_M_WIDTH * ST_STANDARD_M_HEIGHT

/obj/machinery/computer/stationtrauma_ship_core/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	update_use_power(NO_POWER_USE)
	commission(user)

/// Validate the real native frame and attach its hull before exposing it to navigation.
/obj/machinery/computer/stationtrauma_ship_core/proc/commission(mob/user)
	if(!can_commission(user))
		return null
	var/obj/docking_port/mobile/occupied = SSshuttle.get_containing_shuttle(src)
	var/obj/docking_port/mobile/stationtrauma_space/player/commissioned
	if(occupied)
		commissioned = occupied
		if(!istype(commissioned))
			balloon_alert(user, "корпус уже зарегистрирован")
			return null
		if(commissioned.ship_class != hull_class)
			balloon_alert(user, "нужно ядро класса корабля")
			return null
		var/obj/machinery/computer/stationtrauma_ship_core/installed = commissioned.ship_core?.resolve()
		if(installed && installed != src)
			balloon_alert(user, "на корабле уже есть ядро")
			return null
		if(commissioned.overmap)
			commissioned.ship_core = WEAKREF(src)
			balloon_alert(user, "ядро подключено")
			return commissioned
	if(GLOB.stationtrauma_ship_commissioning)
		balloon_alert(user, "уже активируется другой корабль")
		return null
	var/turf/origin = get_turf(src)
	var/datum/stationtrauma_overmap_sector/space/home/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(!isfloorturf(origin) || !is_station_level(origin.z) || !sector?.ready || !SSmapping.current_map.allow_custom_shuttles)
		balloon_alert(user, "стройте корабль у станции")
		return null
	var/list/turfs = list()
	var/list/areas = list()
	if(!commissioned)
		var/problem = candidate_problem(origin, turfs, areas)
		if(problem)
			balloon_alert(user, problem)
			return null
	GLOB.stationtrauma_ship_commissioning = TRUE
	var/obj/docking_port/mobile/stationtrauma_space/player/ship
	try
		ship = complete_commission(user, origin, sector, commissioned)
	catch(var/exception/failure)
		GLOB.stationtrauma_ship_commissioning = FALSE
		throw failure
	GLOB.stationtrauma_ship_commissioning = FALSE
	if(!QDELETED(src) && !QDELETED(user) && ship)
		balloon_alert(user, "корабль зарегистрирован")
	return ship

/// A player still has to reach the installed core after the flight level has been prepared.
/obj/machinery/computer/stationtrauma_ship_core/proc/can_commission(mob/user)
	return !QDELETED(src) && isliving(user) && !QDELETED(user) && in_range(src, user) && can_interact(user) && anchored && !(machine_stat & BROKEN)

/// Collect a fresh frame using the native size, count and area restrictions.
/obj/machinery/computer/stationtrauma_ship_core/proc/candidate_problem(turf/origin, list/turfs, list/areas)
	if(shuttle_build_check(origin, turfs, areas, frame_tile_limit) || !length(turfs))
		return "каркас недоступен или превышен лимит кораблей"
	return frame_problem(origin, turfs)

/// Check the frame boundary and its designated exterior hatch before assigning any ship areas.
/obj/machinery/computer/stationtrauma_ship_core/proc/frame_problem(turf/origin, list/turfs)
	var/min_x = origin.x
	var/min_y = origin.y
	var/max_x = origin.x
	var/max_y = origin.y
	var/list/hatches = list()
	for(var/turf/tile as anything in turfs)
		if(tile.z != origin.z || !(isfloorturf(tile) || isclosedturf(tile)))
			return "достройте одну палубу каркаса"
		if(SSshuttle.get_containing_shuttle(tile))
			return "каркас пересекает другой корабль"
		min_x = min(min_x, tile.x)
		min_y = min(min_y, tile.y)
		max_x = max(max_x, tile.x)
		max_y = max(max_y, tile.y)
		for(var/obj/machinery/computer/stationtrauma_ship_core/other_core in tile)
			if(other_core != src)
				return "оставьте на каркасе одно ядро"
		for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch in tile)
			hatches += hatch
	var/width = max_x - min_x + 1
	var/height = max_y - min_y + 1
	if(min(width, height) > hull_width || max(width, height) > hull_height)
		return "корпус превышает размер класса [class_label]"
	if(length(SSshuttle.get_dock_overlap(min_x, min_y, max_x, max_y, origin.z)) || (locate(/obj/docking_port/stationary) in origin))
		return "каркас пересекает причал"
	for(var/obj/machinery/door/airlock/stationtrauma_docking/ship/hatch as anything in hatches)
		if(!hatch.anchored || !(hatch.dir in GLOB.cardinals) || !isfloorturf(get_turf(hatch)))
			continue
		if((width > hull_width && (hatch.dir & (EAST|WEST))) || (height > hull_width && (hatch.dir & (NORTH|SOUTH))))
			continue
		var/turf/inside = get_step(hatch, REVERSE_DIR(hatch.dir))
		var/turf/outside = get_step(hatch, hatch.dir)
		if(!(inside in turfs) || !isfloorturf(inside) || inside.is_blocked_turf(exclude_mobs = TRUE))
			continue
		while(!(outside in turfs) && stationtrauma_standard_dock_clear_space(outside))
			if(!ISINRANGE(outside.x, min_x, max_x) || !ISINRANGE(outside.y, min_y, max_y))
				return null
			outside = get_step(outside, hatch.dir)
	return "нужен внешний шлюз со свободным выходом с борта"

/// Prepare the flight level before any frame mutation, and recheck after that work yields.
/obj/machinery/computer/stationtrauma_ship_core/proc/complete_commission(mob/user, turf/origin, datum/stationtrauma_overmap_sector/space/home/sector, obj/docking_port/mobile/stationtrauma_space/player/ship)
	if(!GLOB.stationtrauma_available_flight_z)
		var/datum/space_level/flight_level = SSmapping.add_new_zlevel("Орбита построенного корабля", ZTRAITS_AWAY)
		GLOB.stationtrauma_available_flight_z = flight_level.z_value
		stationtrauma_space_vacuum(flight_level.z_value)
	if(!can_commission(user) || get_turf(src) != origin || QDELETED(sector) || !sector.ready || !SSmapping.current_map.allow_custom_shuttles)
		return null
	if(ship)
		if(QDELETED(ship) || SSshuttle.get_containing_shuttle(src) != ship)
			return null
	else
		var/list/turfs = list()
		var/list/areas = list()
		var/problem = candidate_problem(origin, turfs, areas)
		if(problem)
			balloon_alert(user, problem)
			return null
		ship = create_hull(user, origin, turfs, areas)
	if(QDELETED(ship))
		return null
	if(!QDELETED(src))
		ship.ship_core = WEAKREF(src)
	var/obj/docking_port/stationary/stationtrauma_space_construction/berth = ship.get_docked()
	if(!istype(berth))
		return null
	var/list/config = SSmapping.current_map.space_overmap
	var/datum/stationtrauma_overmap_site/space/station = sector.sites[config?["station_id"]]
	if(!QDELETED(station))
		ship.overmap_x = station.pos_x
		ship.overmap_y = station.pos_y
	var/datum/stationtrauma_overmap_site/space/construction = new
	construction.name = berth.name
	construction.physical_docking = TRUE
	construction.berth = berth
	var/turf/flight_position = locate(round(world.maxx / 2), round(world.maxy / 2), GLOB.stationtrauma_available_flight_z)
	if(!sector.attach(ship, construction, flight_position))
		var/datum/stationtrauma_overmap/space/navigation = ship.overmap
		if(navigation?.construction_site == construction)
			navigation.construction_site = null
			navigation.docked = null
			qdel(navigation)
		qdel(construction)
		if(!QDELETED(src) && !QDELETED(user))
			balloon_alert(user, "регистрация прервана, попробуйте снова")
		return null
	GLOB.stationtrauma_available_flight_z = 0
	return ship

/// Apply native frame conversion with a local berth at the original anchor.
/obj/machinery/computer/stationtrauma_ship_core/proc/create_hull(mob/user, turf/origin, list/turfs, list/areas)
	var/obj/docking_port/stationary/stationtrauma_space_construction/berth = new(origin)
	var/obj/docking_port/mobile/stationtrauma_space/player/ship = create_shuttle(
		user,
		origin,
		turfs,
		areas,
		NORTH,
		area_type = /area/shuttle/stationtrauma_space/player,
		docking_port_type = /obj/docking_port/mobile/stationtrauma_space/player,
		dock_at = berth,
		name = "Корабль класса [class_label]",
		id = "overmap_player_[REF(src)]",
	)
	if(QDELETED(ship))
		qdel(berth, force = TRUE)
		return null
	ship.ship_class = hull_class
	berth.width = ship.width
	berth.height = ship.height
	berth.dwidth = ship.dwidth
	berth.dheight = ship.dheight
	return ship

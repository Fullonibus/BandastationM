/** Mapper-declared scenario: extra hull templates are loaded before the shared destinations. */
/obj/effect/landmark/stationtrauma_space_sector
	name = "space overmap sector"
	/// Additional hull template paths loaded for this mapped sector scenario.
	var/list/ship_templates = list()

/** Resident star system with shared destinations and separate per-crew charts. */
/datum/stationtrauma_overmap_sector/space
	/// Stable sector key used by jump routes and mapped hulls.
	var/id = "frontier"
	/// Navigation display name, independent of the central star.
	var/name = "ST 220 AB-C d1-1"
	/// Arrival coordinates in virtual sector units.
	var/entry_x = 200
	/// Arrival ordinate in virtual sector units.
	var/entry_y = -400
	/// Sector IDs reachable through the bluespace terminal.
	var/list/jump_routes = list("epsilon_eridani")
	/// True only after every physical destination has finished loading.
	var/ready = FALSE
	/// Per-hull discoveries retained between sector visits; contains no vessel references.
	var/list/ship_charts = list()
	/// Sector-owned encounter regions.
	var/list/zones = list()
	/// Chart-only bodies: name, position, symbol radius and orbit centre; never landing targets.
	var/list/celestial_bodies = list()
	/// Points already given to round-random destinations and hazards, the arrival point included.
	var/list/taken_positions
	/// Centre of the asteroid belt; the asteroid field destination lies inside it.
	var/belt_x = 1250
	/// Northing of the asteroid belt centre.
	var/belt_y = -450
	/// Chart name of the central star; null leaves it unlabelled.
	var/star_name
	/// Chart radius of the central star symbol.
	var/star_radius = 10

/datum/stationtrauma_overmap_sector/space/Destroy()
	for(var/ship_id in station_docking_requests.Copy())
		qdel(station_docking_requests[ship_id])
	. = ..()
	ship_charts.Cut()
	QDEL_LIST(zones)

/** Epsilon Eridani station sector, sharing the native station map rather than a copy. */
/datum/stationtrauma_overmap_sector/space/home
	id = "epsilon_eridani"
	name = "Эпсилон Эридана"
	star_name = "Эпсилон"
	star_radius = 18
	jump_routes = list("frontier")
	celestial_bodies = list(
		list("name" = "Лазис Ардакс", "x" = 1000, "y" = -240, "radius" = 22, "kind" = "lava", "orbit_x" = 0, "orbit_y" = 0),
		list("name" = "Эгир", "x" = 1320, "y" = -400, "radius" = 7, "kind" = "moon", "orbit_x" = 1000, "orbit_y" = -240),
	)

/** The sector retains each hull's static chart between visits, without retaining the hull itself. */
/datum/stationtrauma_overmap_sector/space/register(id, datum/stationtrauma_overmap/space/navigation)
	if(!istype(navigation) || !..())
		return FALSE
	var/list/chart = ship_charts[id]
	if(!chart)
		chart = list(list(), list(), list())
		ship_charts[id] = chart
	navigation.discovered_sites = chart[1]
	navigation.visited_sites = chart[2]
	navigation.charted_zones = chart[3]
	navigation.zones = zones
	return TRUE

/datum/stationtrauma_overmap_sector/space/unregister(datum/stationtrauma_overmap/space/navigation)
	if(navigation.sector == src)
		navigation.cancel_station_docking()
	if(!..())
		return FALSE
	navigation.discovered_sites = list()
	navigation.visited_sites = list()
	navigation.charted_zones = list()
	navigation.zones = list()
	return TRUE

/** Register a hull and prepare its flight level and consoles. Player construction supplies a separate flight berth. */
/datum/stationtrauma_overmap_sector/space/proc/attach(obj/docking_port/mobile/stationtrauma_space/vessel, datum/stationtrauma_overmap_site/space/construction, turf/flight_position, defer_starting_dock = FALSE)
	if(QDELETED(vessel) || vessel.width < 1 || vessel.height < 1 || !length(vessel.shuttle_areas))
		return FALSE
	if(vessel.overmap)
		return vessel.overmap.sector == src
	vessel.measure_hull()
	if(!(vessel.ship_class in list(ST_SHIP_SMALL, ST_SHIP_MEDIUM, ST_SHIP_CAPITAL)))
		stack_trace("Overmap hull [vessel.shuttle_id] has an invalid ship_class: [vessel.ship_class]")
		return FALSE
	if(construction && (QDELETED(construction.berth) || vessel.get_docked() != construction.berth || !flight_position || flight_position.z == vessel.z))
		return FALSE
	var/flight_z = construction ? flight_position.z : vessel.z
	var/list/reserved_levels = construction ? list(flight_z) : vessel.owned_z_levels.Copy()
	if(!length(reserved_levels))
		reserved_levels += flight_z
	// Every deck has its own exterior; no other independent hull may claim any of them.
	for(var/id in ships)
		var/datum/stationtrauma_overmap/space/other = ships[id]
		var/list/other_levels = length(other.flight_levels) ? other.flight_levels : list(other.flight_berth.z)
		if(length(reserved_levels & other_levels))
			stack_trace("Overmap hull [vessel.shuttle_id] shares a flight level with [other.vessel.shuttle_id]")
			return FALSE
	if(!vessel.registered)
		vessel.register()
	if(construction)
		// Native frame conversion notifies fitted engines before linkup registers all equipment.
		for(var/obj/machinery/power/shuttle_engine/engine as anything in vessel.engine_list.Copy())
			engine.unsync_ship()
		vessel.initial_engine_power = 0
		vessel.current_engine_power = 0
	vessel.linkup(null)
	var/datum/stationtrauma_overmap/space/navigation = new(vessel)
	if(!register(vessel.shuttle_id, navigation))
		qdel(navigation)
		return FALSE
	vessel.overmap = navigation
	navigation.flight_levels = reserved_levels
	if(construction)
		navigation.flight_berth.forceMove(flight_position)
		navigation.construction_site = construction
		navigation.docked = construction
		construction.docking_owner = navigation
	navigation.zones = zones
	// A hull without a mapped start enters where jumps arrive, not on the star at the origin.
	var/unplaced = !vessel.overmap_x && !vessel.overmap_y
	navigation.pos_x = unplaced ? entry_x : vessel.overmap_x
	navigation.pos_y = unplaced ? entry_y : vessel.overmap_y
	navigation.course = vessel.overmap_course
	navigation.ordered_course = vessel.overmap_course
	if(construction)
		construction.pos_x = navigation.pos_x
		construction.pos_y = navigation.pos_y
	var/area/space/stationtrauma_space_home/exterior = new
	exterior.navigation_ref = WEAKREF(navigation)
	var/datum/stationtrauma_work_budget/budget = new
	for(var/deck in reserved_levels)
		for(var/turf/open/space/tile in block(locate(1, 1, deck), locate(world.maxx, world.maxy, deck)))
			var/area/old_area = get_area(tile)
			if(old_area.type == /area/space)
				tile.change_area(old_area, exterior)
			budget.yield()
			if(QDELETED(vessel) || QDELETED(navigation) || QDELETED(src))
				return FALSE
	navigation.exterior = exterior
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/console in ship_area)
			if(vessel.is_in_shuttle_bounds(console))
				console.vessel = vessel
	navigation.encounter_x = navigation.pos_x
	navigation.encounter_y = navigation.pos_y
	navigation.preparing = FALSE
	navigation.initialize_ship_audio()
	if(!navigation.register_carrier_docks() || (!defer_starting_dock && !navigation.place_starting_dock()))
		qdel(navigation)
		return FALSE
	navigation.update_parallax()
	return TRUE

/** Physical destinations belong to the sector and are loaded exactly once. */
/datum/stationtrauma_overmap_sector/space/proc/load_locations()
	if(ready || length(sites))
		return ready
	if(istype(src, /datum/stationtrauma_overmap_sector/space/home))
		if(!(locate(/obj/docking_port/stationary/stationtrauma_space_station) in SSshuttle.stationary_docking_ports))
			return FALSE
		var/static/list/trade_maps = list(
			"Промышленный узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_industrial.dmm',
			"Медицинский узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_medical.dmm',
			"Аграрный узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_agricultural.dmm',
			"Научный узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_research.dmm',
			"Охранный узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_security.dmm',
			"Сервисный узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_service.dmm',
			"Корпоративный узел" = 'modular_bandastation/space_overmap/maps/trade_outpost_corporate.dmm',
		)
		var/list/trade_levels = list()
		for(var/outpost_name in trade_maps)
			var/datum/map_template/stationtrauma_space/outpost = new(trade_maps[outpost_name], outpost_name)
			var/datum/space_level/trade_level = outpost.load_new_z()
			qdel(outpost)
			if(!trade_level)
				log_mapping("Failed to load Epsilon Eridani trade outpost [outpost_name]")
				return FALSE
			trade_levels += trade_level.z_value
		// The map loader connects the cable nets after machine initialization.
		for(var/obj/machinery/power/solar_control/controller as anything in SSmachines.get_machines_by_type(/obj/machinery/power/solar_control))
			if(!(controller.z in trade_levels))
				continue
			controller.search_for_connected()
			controller.set_panels(SSsun.azimuth)
		taken_positions = list()
		for(var/obj/docking_port/stationary/stationtrauma_space_station/port in SSshuttle.stationary_docking_ports)
			if(port.host_ship_id)
				continue
			var/datum/stationtrauma_overmap_site/space/site = new
			site.id = port.site_id
			site.name = port.station_name
			site.pos_x = port.overmap_x
			site.pos_y = port.overmap_y
			site.physical_docking = TRUE
			site.berth = port
			sites[site.id] = site
			taken_positions += list(list(site.pos_x, site.pos_y))
		if(!length(sites))
			return FALSE
		for(var/list/body as anything in celestial_bodies)
			taken_positions += list(list(body["x"], body["y"]))
		// A few charted wrecks around the station for short runs and for crew lost overboard.
		load_ruin_sector(4)
		ready = TRUE
		return ready
	// Every round charts a new system: its name, and where its planets, ruins and hazards lie.
	name = "[pick("HD ", "HIP ", "Gliese ", "Kepler-", "TOI-", "Wolf ", "Ross ", "LHS ")][rand(100, 9999)]"
	taken_positions = list(list(entry_x, entry_y))
	var/list/belt = random_position(1100, 1700, 600)
	belt_x = belt[1]
	belt_y = belt[2]
	var/list/cargo = random_position(600, 1200, 350)
	var/list/locations = list(
		list("asteroid_field", "Астероидное поле", belt_x, belt_y, 'modular_bandastation/space_overmap/maps/asteroid_field.dmm', /atom/movable/screen/parallax_layer/random/asteroids, "asteroids"),
		list("drift_cargo", "Дрейфующий груз", cargo[1], cargo[2], 'modular_bandastation/space_overmap/maps/drift_cargo.dmm', /atom/movable/screen/parallax_layer/layer_3, "cargo"),
	)
	for(var/list/location as anything in locations)
		var/datum/stationtrauma_overmap_site/space/site = new
		site.id = location[1]
		site.name = location[2]
		site.pos_x = location[3]
		site.pos_y = location[4]
		site.discovered = FALSE
		site.needs_scan = TRUE
		site.approach_scene = location[7]
		site.map_loader = CALLBACK(src, PROC_REF(load_location), site, location[5], location[6])
		sites[site.id] = site
	var/list/positions = list()
	for(var/index in 1 to 5)
		positions += list(random_position(700, 2000, 450))
	var/list/profiles = shuffle(list(/datum/stationtrauma_overmap_site/space/planet, /datum/stationtrauma_overmap_site/space/planet/frozen, /datum/stationtrauma_overmap_site/space/planet/frozen/plain, /datum/stationtrauma_overmap_site/space/planet/arid, /datum/stationtrauma_overmap_site/space/planet/lush, /datum/stationtrauma_overmap_site/space/planet/lava, /datum/stationtrauma_overmap_site/space/planet/dead))
	var/static/list/planet_letters = list("b", "c", "d", "e", "f")
	var/first_seed = rand(1, 1000001 - length(positions))
	for(var/index in 1 to length(positions))
		var/profile = profiles[index]
		// Planets farther from the arrival point roll stronger dangers and rewards.
		var/modifier_level = sqrt((positions[index][1] - entry_x) ** 2 + (positions[index][2] - entry_y) ** 2) / 500
		var/datum/stationtrauma_overmap_site/space/planet/planet = create_stationtrauma_planet(seed = first_seed + index - 1, planet_id = "planet_[index]", planet_name = "[name] [planet_letters[index]]", planet_type = profile, modifier_level = modifier_level)
		if(!planet)
			return FALSE
		planet.pos_x = positions[index][1]
		planet.pos_y = positions[index][2]
		sites[planet.id] = planet
	if(!load_ruin_sector())
		return null
	build_encounters()
	ready = TRUE
	return TRUE

/** Load a charted fixed location on its own level; the first approach runs this. */
/**
 * A free point on a ring around the star, at least `gap` from every point already taken; it is taken in turn.
 *
 * Gives up spacing after a few tries rather than fail the sector, so a crowded ring still places everything.
 */
/datum/stationtrauma_overmap_sector/space/proc/random_position(min_radius, max_radius, gap)
	var/list/point
	for(var/attempt in 1 to 30)
		var/angle = rand(0, 359)
		var/distance = rand(min_radius, max_radius)
		point = list(round(distance * sin(angle)), round(distance * cos(angle)))
		var/clear = TRUE
		for(var/list/taken as anything in taken_positions)
			if((point[1] - taken[1]) ** 2 + (point[2] - taken[2]) ** 2 < gap ** 2)
				clear = FALSE
				break
		if(clear)
			break
	taken_positions += list(point)
	return point

/datum/stationtrauma_overmap_sector/space/proc/load_location(datum/stationtrauma_overmap_site/space/site, map_path, parallax)
	var/datum/map_template/stationtrauma_space/template = new(map_path, site.name)
	var/datum/space_level/level = template.load_new_z()
	if(!level)
		qdel(template)
		return FALSE
	level.space_parallax_background = parallax
	var/right_edge = round((world.maxx - template.width) / 2) + template.width
	site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 1, round(world.maxy / 2), level.z_value))
	qdel(template)
	return TRUE

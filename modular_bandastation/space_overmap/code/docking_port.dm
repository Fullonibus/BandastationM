/** Native shuttle hull participating in the overmap. */
/obj/docking_port/mobile/stationtrauma_space
	name = "Корабль"
	shuttle_id = "overmap_ship"
	area_type = /area/shuttle/stationtrauma_space
	/// Owned virtual navigation instance attached to this physical hull.
	var/datum/stationtrauma_overmap/space/overmap
	/// Navigation metres and heading; physical coordinates are supplied by the native port.
	var/overmap_x = 0
	/// Mapped starting northing in virtual sector units.
	var/overmap_y = 0
	/// Mapped initial compass heading in degrees.
	var/overmap_course = 90
	/// Optional sector site ID to dock at during scenario initialization.
	var/starting_dock
	/// Mapped starting sector ID.
	var/overmap_sector = "epsilon_eridani"
	/// Crew main-engine switch; propulsion requires this and intact engines.
	var/engines_running = FALSE
	/// Mapped fusion core powering the grid and feeding the converters; ordinary ships keep their existing propulsion model.
	var/datum/weakref/fusion_core
	/// Bluespace drive aboard; without a charged one the hull cannot leave the system.
	var/datum/weakref/bluespace_drive
	/// Mapper-declared role; physical berth compatibility still uses the actual hull dimensions.
	var/ship_class = ST_SHIP_MEDIUM
	/// Whether this hull may use planetary surface berths.
	var/can_land = TRUE
	/// Connected transponder consoles; each console unregisters during teardown.
	var/list/transponders = list()
	/// Hull tiles inside the ship's own areas, measured once at registration.
	var/hull_mass = 0
	/// Physical deck reservations owned by this vessel, retained independently from native guest movement.
	var/list/owned_z_levels = list()
	/// Source DMM used to find an already loaded template, including ships from the startup fleet.
	var/source_template
	/// Multideck hulls stay on their orbital maps and cannot use one-deck native relocation.
	var/orbital_only = FALSE

/obj/docking_port/mobile/stationtrauma_space/Initialize(mapload, list/areas)
	. = ..()
	classify_decks()

/** A reserved multideck map must never enter the one-deck native movement pipeline. */
/obj/docking_port/mobile/stationtrauma_space/proc/classify_decks()
	if(length(owned_z_levels) <= 1)
		return
	orbital_only = TRUE
	ship_class = ST_SHIP_CAPITAL
	can_land = FALSE

/** A single-deck guest follows its current native position while a multideck hull owns its reserved levels. */
/obj/docking_port/mobile/stationtrauma_space/proc/contains_deck(level)
	return length(owned_z_levels) > 1 ? (level in owned_z_levels) : level == z

/** Native containment normally checks only the anchor's level. */
/obj/docking_port/mobile/stationtrauma_space/is_in_shuttle_bounds(atom/thing)
	if(length(owned_z_levels) <= 1)
		return ..()
	var/turf/tile = get_turf(thing)
	if(!tile || !contains_deck(tile.z) || !shuttle_areas[get_area(tile)])
		return FALSE
	var/list/bounds = return_coords()
	return ISINRANGE(tile.x, min(bounds[1], bounds[3]), max(bounds[1], bounds[3])) \
		&& ISINRANGE(tile.y, min(bounds[2], bounds[4]), max(bounds[2], bounds[4]))

/obj/docking_port/mobile/stationtrauma_space/canMove()
	. = ..()
	return . && !orbital_only

/** Check mapped hull class and landing capability against the destination kind. */
/obj/docking_port/mobile/stationtrauma_space/proc/permits_docking(datum/stationtrauma_overmap_site/space/site)
	if(orbital_only || QDELETED(site))
		return FALSE
	if(ship_class == ST_SHIP_CAPITAL)
		return !site.landing && !site.physical_docking
	return (ship_class == ST_SHIP_SMALL || ship_class == ST_SHIP_MEDIUM) && (!site.landing || can_land)

/** Pair converters after the native pass has registered every nozzle, regardless of map order. */
/obj/docking_port/mobile/stationtrauma_space/linkup(obj/docking_port/stationary/dock)
	. = ..()
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = fusion_core?.resolve()
	reactor?.bind_converters()
	bind_plasma_heaters()

/** Plasma heaters have no controller; search the rear edge of the nozzle's full footprint. */
/obj/docking_port/mobile/stationtrauma_space/proc/bind_plasma_heaters()
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_list)
		if(!engine.requires_combustion || engine.combustion_feed?.resolve())
			continue
		for(var/turf/nozzle_tile as anything in engine.locs)
			var/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/heater = locate() in get_step(nozzle_tile, REVERSE_DIR(engine.dir))
			if(heater && is_in_shuttle_bounds(heater) && heater.bind_nozzle(src))
				break

/** Measure every owned deck and classify multideck hulls before navigation admits docking commands. */
/obj/docking_port/mobile/stationtrauma_space/proc/measure_hull()
	hull_mass = 0
	var/derive_levels = !length(owned_z_levels)
	for(var/area/hull_area as anything in shuttle_areas)
		for(var/list/deck_turfs as anything in hull_area.get_zlevel_turf_lists())
			for(var/turf/tile as anything in deck_turfs)
				if(derive_levels)
					owned_z_levels |= tile.z
				if(derive_levels || contains_deck(tile.z))
					hull_mass++
	classify_decks()
	return hull_mass

/**
 * Whether a metered compartment has equipment power; wholly unmetered hulls retain free power.
 * Unmetered engine bays must not hide a ship-grid blackout on a mixed hull.
 */
/obj/docking_port/mobile/stationtrauma_space/proc/has_power()
	var/requires_grid = FALSE
	for(var/area/ship_area as anything in shuttle_areas)
		if(!ship_area.requires_power)
			continue
		requires_grid = TRUE
		if(ship_area.powered(AREA_USAGE_EQUIP))
			return TRUE
	return !requires_grid && length(shuttle_areas) > 0

/** Pilot fuel gauges: the fusion core's tritium, otherwise the plasma heaters' supply; null for unfuelled drives. */
/obj/docking_port/mobile/stationtrauma_space/proc/fuel_gauges()
	var/obj/machinery/atmospherics/components/binary/stationtrauma_fusion_core/reactor = fusion_core?.resolve()
	if(reactor)
		return reactor.fuel_reserve()
	var/list/networks = list()
	var/heaters = 0
	for(var/obj/machinery/power/shuttle_engine/engine as anything in engine_list)
		var/obj/machinery/atmospherics/components/unary/ship_engine_heater/plasma/heater = engine.combustion_feed?.resolve()
		if(!istype(heater))
			continue
		heaters++
		if(heater.parents[1])
			networks |= heater.parents[1]
	return heaters ? stationtrauma_fuel_gauges(networks, list(/datum/gas/plasma = "Плазма")) : null

/obj/docking_port/mobile/stationtrauma_space/Destroy(force)
	if(!force)
		return QDEL_HINT_LETMELIVE
	for(var/obj/machinery/computer/stationtrauma_transponder/device as anything in transponders)
		device.vessel = null
	transponders.Cut()
	owned_z_levels.Cut()
	fusion_core = null
	QDEL_NULL(overmap)
	QDEL_LIST_ASSOC_VAL(docking_surfaces)
	docking_layer_indices.Cut()
	return ..()

/** Physical anchor for a destination connected by a remote map seam. */
/obj/docking_port/stationary/stationtrauma_space_site
	name = "Стыковочная площадка"

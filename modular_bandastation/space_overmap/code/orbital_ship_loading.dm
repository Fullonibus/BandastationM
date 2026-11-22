/** Ship templates reserve every deck before native loading initializes the map. */
/datum/map_template/stationtrauma_space/ship
	/// Number of contiguous decks declared by the source map.
	var/depth = 0
	/// Source coordinates must start at one and fit the existing world dimensions.
	var/valid_source_bounds = FALSE
	/// Exact managed levels reserved for this load, including an empty deck.
	var/list/loaded_levels = list()
	/// Native centered footprint captured before loading can yield or expand the world.
	var/loaded_min_x
	var/loaded_min_y
	/// Ordered single-deck hulls can reuse a cleaned staging level after a rejected arrival.
	var/reuse_dispatch_level = FALSE

/datum/map_template/stationtrauma_space/ship/Destroy()
	loaded_levels?.Cut()
	loaded_levels = null
	return ..()

/datum/map_template/stationtrauma_space/ship/preload_size(path, cache = FALSE)
	var/list/bounds = ..()
	if(!bounds)
		return
	depth = bounds[MAP_MAXZ]
	valid_source_bounds = bounds[MAP_MINX] == 1 && bounds[MAP_MINY] == 1 && bounds[MAP_MINZ] == 1 \
		&& ISINTEGER(width) && width > 0 && width <= world.maxx \
		&& ISINTEGER(height) && height > 0 && height <= world.maxy && ISINTEGER(depth) && depth > 0
	return bounds

/datum/map_template/stationtrauma_space/ship/load_new_z(secret = FALSE)
	if(!valid_source_bounds)
		log_mapping("Overmap ship template [mappath] requires valid bounds starting at 1,1,1 within the world dimensions")
		return null
	loaded_levels = list()
	loaded_min_x = round((world.maxx - width) / 2) + 1
	loaded_min_y = round((world.maxy - height) / 2) + 1
	var/datum/space_level/first_level
	for(var/deck in 1 to depth)
		var/list/traits = secret ? ZTRAITS_AWAY_SECRET : ZTRAITS_AWAY
		if(deck > 1)
			traits[ZTRAIT_DOWN] = TRUE
		if(deck < depth)
			traits[ZTRAIT_UP] = TRUE
		var/level_name = depth == 1 ? name : "[name] — палуба [deck]"
		var/datum/space_level/level
		if(reuse_dispatch_level && depth == 1 && SSstationtrauma_space_voyage.dispatch_staging_level)
			level = SSmapping.get_level(SSstationtrauma_space_voyage.dispatch_staging_level)
			SSstationtrauma_space_voyage.dispatch_staging_level = null
		else
			level = SSmapping.add_new_zlevel(level_name, traits, contain_turfs = FALSE)
		loaded_levels += level.z_value
		if(!first_level)
			first_level = level
		if(level.z_value != first_level.z_value + deck - 1)
			log_mapping("Overmap ship [mappath] could not reserve contiguous managed decks")
			discard_loaded_ship()
			return null
	var/datum/parsed_map/parsed = load_map(
		file(mappath),
		loaded_min_x,
		loaded_min_y,
		first_level.z_value,
		no_changeturf = (SSatoms.initialized == INITIALIZATION_INSSATOMS),
		place_on_top = should_place_on_top,
		new_z = TRUE,
	)
	var/list/bounds = parsed?.bounds
	if(!bounds)
		discard_loaded_ship()
		return null
	// ChangeTurf inherits the empty level's baseturf. Restore the deck material before turf and mapping-helper initialization.
	for(var/turf/tile as anything in block(bounds[MAP_MINX], bounds[MAP_MINY], bounds[MAP_MINZ], bounds[MAP_MAXX], bounds[MAP_MAXY], bounds[MAP_MAXZ]))
		if(tile.baseturfs == /turf/baseturf_bottom)
			tile.baseturfs = initial(tile.baseturfs)
		CHECK_TICK
	require_area_resort()
	initTemplateBounds(bounds)
	for(var/z_level in loaded_levels)
		smooth_zlevel(z_level)
	log_game("Overmap ship [name] loaded on [depth] managed decks starting at [loaded_min_x],[loaded_min_y],[first_level.z_value]")
	return first_level

/** Remove a rejected load only from this template's reserved levels and original footprint. */
/datum/map_template/stationtrauma_space/ship/proc/discard_loaded_ship()
	if(!length(loaded_levels))
		return
	var/list/levels = loaded_levels.Copy()
	loaded_levels.Cut()
	var/area/space/exterior = GLOB.areas_by_type[/area/space]
	if(QDELETED(exterior))
		exterior = new /area/space
	var/list/areas = list()
	var/datum/stationtrauma_work_budget/budget = new
	// Geometry changes can move loose items onto cells already visited by cooperative cleanup.
	var/list/to_delete = list()
	for(var/z_level in levels)
		for(var/turf/tile as anything in block(locate(loaded_min_x, loaded_min_y, z_level), locate(loaded_min_x + width - 1, loaded_min_y + height - 1, z_level)))
			budget.yield()
			for(var/atom/movable/content in tile.get_all_contents())
				to_delete[content] = TRUE
	for(var/atom/movable/content as anything in to_delete)
		budget.yield()
		if(!QDELETED(content))
			qdel(content, force = TRUE)
	to_delete.Cut()
	for(var/z_level in levels)
		for(var/turf/tile as anything in block(locate(loaded_min_x, loaded_min_y, z_level), locate(loaded_min_x + width - 1, loaded_min_y + height - 1, z_level)))
			budget.yield()
			areas |= get_area(tile)
			tile.empty(/turf/open/space, /turf/open/space, flags = CHANGETURF_FORCEOP | CHANGETURF_NO_AREA_CHANGE | CHANGETURF_IGNORE_AIR)
			// Native empty() preserves ports, landmarks and observers. They also belong to this rejected load.
			for(var/atom/movable/remaining in tile.get_all_contents())
				if(!QDELETED(remaining))
					qdel(remaining, force = TRUE)
			tile.change_area(get_area(tile), exterior)
			var/turf/open/space/vacuum = tile
			vacuum.air ||= vacuum.space_gas
	// Replacing a support turf can spawn wall-mount debris on an already cleared neighbouring cell.
	for(var/z_level in levels)
		for(var/turf/tile as anything in block(locate(loaded_min_x, loaded_min_y, z_level), locate(loaded_min_x + width - 1, loaded_min_y + height - 1, z_level)))
			budget.yield()
			for(var/atom/movable/debris in tile.get_all_contents())
				to_delete[debris] = TRUE
	for(var/atom/movable/debris as anything in to_delete)
		budget.yield()
		if(!QDELETED(debris))
			qdel(debris, force = TRUE)
	if(reuse_dispatch_level && length(levels) == 1)
		var/staging_z = levels[1]
		// Sector attachment adopts the vacuum outside the map footprint too.
		for(var/turf/open/space/tile in block(locate(1, 1, staging_z), locate(world.maxx, world.maxy, staging_z)))
			budget.yield()
			var/area/old_area = get_area(tile)
			if(istype(old_area, /area/space/stationtrauma_space_home))
				areas |= old_area
				tile.change_area(old_area, exterior)
		SSstationtrauma_space_voyage.dispatch_staging_level = staging_z
	for(var/area/old_area as anything in areas)
		if(old_area != exterior && !QDELETED(old_area) && !old_area.has_contained_turfs())
			qdel(old_area)
	exterior.reg_in_areas_in_z()
	require_area_resort()

/** Keep loading and optional midround sector attachment inside the same rejected-template cleanup boundary. */
/proc/load_stationtrauma_space_ship(map_path, attach_to_sector = FALSE, datum/callback/place_ship)
	var/datum/map_template/stationtrauma_space/ship/template = new(map_path, "Overmap ship")
	template.reuse_dispatch_level = !!place_ship
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	try
		vessel = template.load_ship()
		if(vessel)
			vessel.source_template = map_path
		if(vessel && attach_to_sector)
			var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[vessel.overmap_sector]
			// Registration can suffix an ID even after its previous owner has been deleted.
			if(sector?.ready && !vessel.registered)
				vessel.register()
			var/valid_hosts = TRUE
			for(var/obj/docking_port/stationary/stationtrauma_space_station/slot in SSshuttle.stationary_docking_ports)
				if((slot.z in vessel.owned_z_levels) && slot.host_ship_id && slot.host_ship_id != vessel.shuttle_id)
					valid_hosts = FALSE
					break
			if(!valid_hosts || !sector?.ready || !sector.attach(vessel, defer_starting_dock = !!place_ship))
				log_mapping("Could not attach overmap ship [map_path]: unavailable sector, conflicting carrier IDs or invalid hull")
				vessel = null
			else if(place_ship && !place_ship.Invoke(vessel))
				if(!(vessel.z in template.loaded_levels))
					template.reuse_dispatch_level = FALSE
				vessel = null
	catch(var/exception/failure)
		if(vessel && !(vessel.z in template.loaded_levels))
			template.reuse_dispatch_level = FALSE
		template.discard_loaded_ship()
		qdel(template)
		throw failure
	if(!vessel)
		template.discard_loaded_ship()
	qdel(template)
	return vessel

/datum/controller/subsystem/stationtrauma_space_voyage
	/// Only one midround template load may allocate decks and register its mapped IDs at a time.
	var/loading_ship_template = FALSE
	/// Empty, cleaned flight level available for the next one-deck delivery.
	var/dispatch_staging_level

/** Server-owned ship files offered alongside the ordinary lazy templates. */
/datum/controller/subsystem/stationtrauma_space_voyage/proc/ship_template_choices()
	var/map_directory = "_maps/map_files/overmap_ships/"
	var/list/choices = list()
	for(var/file_name in sort_list(flist(map_directory)))
		if(copytext(file_name, -4) == ".dmm")
			choices["Overmap — [copytext(file_name, 1, -4)]"] = "[map_directory][file_name]"
	return choices

/** Reuse a live template instance or load and attach it after sectors are ready. */
/datum/controller/subsystem/stationtrauma_space_voyage/proc/load_ship_template(map_path)
	var/allowed = FALSE
	var/list/choices = ship_template_choices()
	for(var/label in choices)
		if(choices[label] == map_path)
			allowed = TRUE
			break
	if(!allowed || loading_ship_template || !initialized || loading || !length(sectors))
		return null
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in SSshuttle.mobile_docking_ports)
		if(vessel.source_template == map_path)
			var/datum/stationtrauma_overmap/space/navigation = vessel.overmap
			var/datum/stationtrauma_overmap_sector/space/sector = navigation?.sector
			return !QDELETED(navigation) && navigation.is_operational() && sector?.ready && sector.ships[vessel.shuttle_id] == navigation ? vessel : null
	for(var/id in sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = sectors[id]
		if(!sector.ready)
			return null
	loading_ship_template = TRUE
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	try
		vessel = load_stationtrauma_space_ship(map_path, attach_to_sector = TRUE)
	catch(var/exception/failure)
		loading_ship_template = FALSE
		throw failure
	loading_ship_template = FALSE
	return vessel

/** Collect the whole ship before its one native mobile port is initialized. */
/datum/map_template/stationtrauma_space/ship/proc/load_ship()
	var/datum/space_level/first_level = load_new_z()
	if(!first_level)
		return null
	var/list/areas = list()
	var/list/obj/docking_port/mobile/mobiles = list()
	var/datum/stationtrauma_work_budget/budget = new
	for(var/z_level in loaded_levels)
		for(var/turf/tile as anything in block(locate(loaded_min_x, loaded_min_y, z_level), locate(loaded_min_x + width - 1, loaded_min_y + height - 1, z_level)))
			budget.yield()
			areas |= get_area(tile)
			for(var/obj/docking_port/mobile/mobile in tile)
				mobiles += mobile
	if(length(mobiles) != 1 || QDELETED(mobiles[1]) || !istype(mobiles[1], /obj/docking_port/mobile/stationtrauma_space))
		log_mapping("Overmap ship [mappath] requires exactly one overmap mobile docking port across all decks")
		return null
	var/obj/docking_port/mobile/stationtrauma_space/vessel = mobiles[1]
	vessel.owned_z_levels = loaded_levels.Copy()
	for(var/area/ship_area as anything in areas)
		if(istype(ship_area, vessel.area_type))
			vessel.shuttle_areas[ship_area] = TRUE
	if(!length(vessel.shuttle_areas))
		log_mapping("Overmap ship [mappath] has no areas matching its declared hull area type")
		return null
	vessel.calculate_docking_port_information()
	SSatoms.InitializeAtoms(list(vessel))
	return vessel

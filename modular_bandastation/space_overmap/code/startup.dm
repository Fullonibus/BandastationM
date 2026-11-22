/// Mapped vessel ports opt into the shared sector without checking a primary map name.
SUBSYSTEM_DEF(stationtrauma_space_voyage)
	name = "StationTrauma space voyage"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/lighting,
		/datum/controller/subsystem/shuttle,
		/datum/controller/subsystem/icon_smooth,
	)

	/// Owned sector ID to resident sector instance mapping.
	var/list/sectors = list()
	/// Prevents overlapping sector preparation.
	var/loading = FALSE

/** All small destinations are resident before any vessel can enter the sector network. */
/datum/controller/subsystem/stationtrauma_space_voyage/proc/load_sectors()
	if(loading)
		return FALSE
	if(length(sectors))
		for(var/id in sectors)
			var/datum/stationtrauma_overmap_sector/space/sector = sectors[id]
			if(!sector.ready)
				return FALSE
		return TRUE
	loading = TRUE
	for(var/sector_type in list(/datum/stationtrauma_overmap_sector/space/home, /datum/stationtrauma_overmap_sector/space))
		var/datum/stationtrauma_overmap_sector/space/sector = new sector_type
		sectors[sector.id] = sector
		if(!sector.load_locations())
			return FALSE
	loading = FALSE
	return TRUE

/datum/controller/subsystem/stationtrauma_space_voyage/Initialize()
	var/list/vessels = list()
	var/list/config = SSmapping.current_map.space_overmap
	var/station_id
	if(config)
		station_id = config["station_id"]
		var/list/fleet = config["ships"]
		if(!istext(station_id) || !length(station_id) || !islist(fleet) || !length(fleet))
			log_mapping("Overmap station requires a mapped station site ID and an expedition fleet")
			return SS_INIT_FAILURE
		// Atom initialization needs its native cleanup even when one mapped atom fails.
		for(var/list/ship_config as anything in fleet)
			if(!islist(ship_config))
				log_mapping("Invalid expedition ship profile")
				return SS_INIT_FAILURE
			var/map_path = ship_config["template"]
			if(!istext(map_path) || !fexists(map_path))
				log_mapping("Missing expedition ship template [map_path]")
				return SS_INIT_FAILURE
			var/obj/docking_port/mobile/stationtrauma_space/ship = load_stationtrauma_space_ship(map_path)
			if(!ship)
				log_mapping("Failed to load expedition ship [map_path]")
				return SS_INIT_FAILURE
			if(ship_config["starts_docked"])
				ship.starting_dock = station_id
				ship.overmap_x = 1000
	// Only startup scans the world: mapped hulls join SSshuttle.mobile_docking_ports in register(), which runs here.
	// Navigation processing uses the sector registry.
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel in world)
		if(!vessel.registered)
			vessel.register()
		vessels += vessel
	if(!length(vessels))
		return SS_INIT_NO_NEED
	for(var/obj/effect/landmark/stationtrauma_space_sector/scenario in GLOB.landmarks_list)
		for(var/map_path in scenario.ship_templates)
			var/obj/docking_port/mobile/stationtrauma_space/extra = load_stationtrauma_space_ship(map_path)
			if(!extra)
				log_mapping("Failed to load sector ship [map_path]")
				return SS_INIT_FAILURE
			extra.register()
			vessels += extra
	if(!load_sectors())
		log_mapping("Failed to load sector destinations")
		return SS_INIT_FAILURE
	if(station_id)
		var/datum/stationtrauma_overmap_sector/space/home/home_sector = sectors["epsilon_eridani"]
		var/datum/stationtrauma_overmap_site/space/station = home_sector.sites[station_id]
		if(QDELETED(station?.berth) || !is_station_level(station.berth.z) || station.berth.get_docked())
			log_mapping("Overmap station site [station_id] requires a free mapped station berth")
			return SS_INIT_FAILURE
		// Each station deck loops onto itself without the border mirage, which would show the far side's buildings at every edge.
		for(var/z_level in SSmapping.levels_by_trait(ZTRAIT_STATION))
			for(var/side in GLOB.cardinals)
				stationtrauma_set_edge(z_level, side, z_level, mirage = FALSE)
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in vessels)
		var/datum/stationtrauma_overmap_sector/space/sector = sectors[vessel.overmap_sector]
		if(!sector?.ready)
			stack_trace("Unknown or unavailable sector [vessel.overmap_sector]")
			return SS_INIT_FAILURE
		if(!sector.attach(vessel, defer_starting_dock = TRUE))
			stack_trace("Failed to register sector ship [vessel.shuttle_id]")
			return SS_INIT_FAILURE
	// A guest may be listed before its carrier in the fleet configuration.
	for(var/obj/docking_port/stationary/stationtrauma_space_station/port in SSshuttle.stationary_docking_ports)
		if(port.host_ship_id && QDELETED(port.host))
			log_mapping("Overmap berth [port.site_id] has no registered carrier [port.host_ship_id]")
			return SS_INIT_FAILURE
	for(var/obj/docking_port/mobile/stationtrauma_space/vessel as anything in vessels)
		if(!vessel.overmap.place_starting_dock())
			stack_trace("Failed to place sector ship [vessel.shuttle_id] at [vessel.starting_dock]")
			return SS_INIT_FAILURE
	log_mapping("Space sectors ready: [length(sectors)] sectors, [length(vessels)] ships")
	return SS_INIT_SUCCESS

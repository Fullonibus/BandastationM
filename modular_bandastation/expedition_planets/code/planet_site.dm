// Barren environment profile adapted from SierraBay, AGPL-3.0; terrain generation uses local TG/rust-g.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/barren.dm
/** Shared planetary surface area with native gravity and locally generated terrain. */
/area/expedition_planet/barren
	name = "Каменистая поверхность экзопланеты"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags_mapping = UNIQUE_AREA
	ambientsounds = list(null)

/** Generated surface destination with a persistent landing berth and environmental survey. */
/datum/stationtrauma_overmap_site/space/planet
	name = "Каменистая экзопланета"
	landing = TRUE
	needs_scan = FALSE
	discovered = TRUE
	/// Retained for admin diagnostics; navigation never publishes the generation seed.
	var/seed
	/// Modifier budget/difficulty used when charting, retained after the generator is released.
	var/modifier_level = 1
	/// Square generated surface side length in turfs.
	var/surface_width = 128
	/// Measured time spent preparing the physical surface, in seconds.
	var/generation_seconds
	/// Terrain generator type for this planetary environment profile.
	var/generator_type = /datum/map_generator/expedition_barren
	/// Native-size orbital artwork for this environment profile.
	var/parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet
	/// Crew-facing summary of the surface environment.
	var/biome = "Безжизненные равнины, базальтовые поля и рудные горы"
	/// Crew-facing gas and pressure summary from the environment profile.
	var/atmosphere = "Вакуум, 0 кПа"
	/// Ambient surface temperature in kelvin.
	var/surface_temperature = TCMB
	/// Whether the environment profile supports unprotected human breathing.
	var/breathable = FALSE
	/// Survey lines of the modifiers rolled for this planet.
	var/list/modifier_names = list()
	/// Names of the modifiers rolled for this planet, for admin logs.
	var/list/modifier_log = list()
	/// Charted generator awaiting the first landing; null once the surface is built or has failed.
	var/datum/map_generator/expedition_barren/generator

/** Serialize environment observations without exposing the planet generation seed. */
/datum/stationtrauma_overmap_site/space/planet/proc/survey_data()
	return list("biome" = biome, "atmosphere" = atmosphere, "temperature" = surface_temperature, "breathable" = breathable, "modifiers" = modifier_names)

/**
 * Chart a planet without building it; the first landing generates its surface.
 *
 * Modifiers are rolled here so orbital surveys report them before anyone lands.
 * `modifier_level` sets the planet modifier budgets; sectors derive it from the distance to their arrival point.
 * Optional selected_modifiers selects exact compatible traits for admin generation; null preserves random rolls.
 */
/proc/create_stationtrauma_planet(seed = rand(1, 1000000), planet_id = "moon", planet_name = "Каменистая экзопланета", planet_type = /datum/stationtrauma_overmap_site/space/planet, modifier_level = 1, list/selected_modifiers = null)
	if(!ispath(planet_type, /datum/stationtrauma_overmap_site/space/planet))
		CRASH("Invalid expedition planet profile [planet_type]")
	var/datum/stationtrauma_overmap_site/space/planet/site = new planet_type
	site.id = planet_id
	site.name = planet_name
	site.seed = seed
	site.modifier_level = modifier_level
	site.generator = new site.generator_type(seed)
	// A large town or complex widens the surface around it; the template itself is chosen when the surface is built.
	if(prob(site.generator.large_ruin_chance))
		site.generator.width = site.generator.large_surface_width
		site.generator.large_slot = TRUE
	site.surface_width = site.generator.width
	site.modifier_names = site.generator.apply_modifiers(modifier_level, selected_modifiers)
	if(isnull(site.modifier_names))
		QDEL_NULL(site.generator)
		qdel(site)
		return null
	site.modifier_log = site.generator.modifier_log.Copy()
	return site

/datum/stationtrauma_overmap_site/space/planet/awaits_map()
	return !!generator

/** Build the surface once; subsequent landings only move the vessel onto the retained native berth. */
/datum/stationtrauma_overmap_site/space/planet/load_map()
	if(!generator || loading_map)
		return
	loading_map = TRUE
	failed = !build_surface()
	QDEL_NULL(generator)
	loading_map = FALSE
	if(!failed)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_SITE_LOADED, src)

/** Generate every level of the surface, yielding between work slices; returns whether the planet is ready for landing. */
/datum/stationtrauma_overmap_site/space/planet/proc/build_surface()
	var/start_time = REALTIMEOFDAY
	var/datum/stationtrauma_work_budget/budget = new
	// Landings generate beside live gameplay; a quarter of each tick builds the surface within the descent.
	budget.allowance = 25
	generator.budget = budget
	// The clearing fits every hull allowed to land, with a margin of open ground around it; the rest is terrain.
	var/list/extents = landing_extents()
	var/margin = 5
	generator.camp_x = 5
	generator.camp_y = 5
	generator.camp_width = extents[1] + extents[2] + margin * 2
	generator.camp_height = extents[3] + extents[4] + margin * 2
	// Ruins keep out of the camp's quadrant, so the clearing must stay inside it.
	if(generator.camp_x + generator.camp_width > round(generator.width / 2) - 1 || generator.camp_y + generator.camp_height > round(generator.width / 2) - 1)
		CRASH("Landing hulls do not fit the expedition camp quadrant")
	var/list/traits = ZTRAITS_AWAY
	// The storm trait also drives weather sounds, so the endless storm keeps it.
	if(generator.storms || generator.endless_storm)
		traits[generator.storm_trait] = TRUE
	var/datum/space_level/caves
	// Multi-z links adjacent z values, so the cave level is created immediately below the surface.
	if(generator.underground)
		caves = SSmapping.add_new_zlevel("[name]: пещеры", ZTRAITS_AWAY + list(ZTRAIT_UP = TRUE))
		traits[ZTRAIT_DOWN] = TRUE
	var/datum/space_level/level = SSmapping.add_new_zlevel(name, traits)
	generator.origin_x = round((world.maxx - generator.width) / 2) + 1
	generator.origin_y = round((world.maxy - generator.width) / 2) + 1
	var/list/ruins = prepare_ruins(generator)
	if(!ruins)
		return FALSE
	var/turf/bottom = locate(generator.origin_x, generator.origin_y, level.z_value)
	var/list/turfs = block(bottom, locate(bottom.x + generator.width - 1, bottom.y + generator.width - 1, bottom.z))
	var/area/expedition_planet/barren/surface = new
	surface.name = "[name]: поверхность"
	// Storms only reach outdoor areas, the landing clearing included; ruins and landed vessels keep their own sheltered areas.
	surface.outdoors = generator.storms || generator.endless_storm
	// Only the open surface is lit; ruins, landed vessels and the cave level keep their own areas and lighting.
	if(generator.light_alpha)
		surface.set_base_lighting(generator.sky_color, generator.light_alpha)
	generator.generate_terrain(turfs, surface)
	// Native berths face north, so the hull rectangle starts dwidth and dheight below the port.
	var/obj/docking_port/stationary/stationtrauma_space_surface/pad = new(locate(bottom.x + generator.camp_x - 1 + margin + extents[1], bottom.y + generator.camp_y - 1 + margin + extents[3], bottom.z))
	pad.dwidth = extents[1]
	pad.width = extents[1] + extents[2]
	pad.dheight = extents[3]
	pad.height = extents[3] + extents[4]
	pad.name = "Посадочная площадка экспедиции"
	berth = pad
	budget.yield()
	if(!load_ruins(ruins, bottom, surface, budget))
		return FALSE
	generator.build_hive(bottom, surface)
	var/features = generator.place_features(bottom, surface)
	generator.place_nests(bottom)
	generator.place_megafauna(bottom)
	generator.place_craters(bottom)
	if(generator.populate_terrain(turfs, surface) != 3)
		CRASH("Expedition planet [seed] lacks its research sources")
	generator.place_dig_sites(turfs, surface, src, budget)
	generator.place_anomaly_fields(turfs, surface, src, budget)
	generator.place_planetary_anomalies(turfs, surface, src, budget)
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(berth))
	marker.site_id = id
	marker.name = name
	budget.yield()
	if(caves)
		if(!generator.generate_underground(bottom, caves, surface, name))
			CRASH("Expedition planet [seed] has no free surface for cave connectors")
		// Specimens resolve their site per level, so the caves carry the surface's site marker too.
		var/obj/effect/landmark/stationtrauma_research_site/cave_marker = new(locate(bottom.x, bottom.y, caves.z_value))
		cave_marker.site_id = id
		cave_marker.name = name
	SSmapping.reg_in_areas_in_z(list(surface))
	smooth_zlevel(level.z_value)
	// Storm traits are registered only once the surface is complete; SSweather then alternates storms with calm periods.
	// The endless storm starts once and is never scheduled, so periodic storms never stack on top of it.
	if(generator.endless_storm)
		SSweather.run_weather(generator.endless_storm_type, level.z_value)
	else
		SSweather.update_z_level(level)
	generation_seconds = ((REALTIMEOFDAY - start_time + MIDNIGHT_ROLLOVER) % MIDNIGHT_ROLLOVER) / 10
	log_mapping("Expedition planet ready: seed [seed], [generator.width]x[generator.width], z [level.z_value], [generation_seconds]s, features: [features], modifiers: [jointext(modifier_log, ", ")]")
	return TRUE

/**
 * Native berth extents fitting every hull allowed to land here: list(dwidth, width - dwidth, dheight, height - dheight).
 * Without such hulls the surface berth type's own size applies.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/landing_extents()
	var/list/extents
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/ship_id in sector.ships)
			var/datum/stationtrauma_overmap/space/navigation = sector.ships[ship_id]
			if(!istype(navigation) || QDELETED(navigation.vessel) || !navigation.vessel.permits_docking(src))
				continue
			var/obj/docking_port/mobile/stationtrauma_space/vessel = navigation.vessel
			var/list/hull = list(vessel.dwidth, vessel.width - vessel.dwidth, vessel.dheight, vessel.height - vessel.dheight)
			if(!extents)
				extents = hull
				continue
			for(var/index in 1 to 4)
				extents[index] = max(extents[index], hull[index])
	if(extents)
		return extents
	var/obj/docking_port/stationary/stationtrauma_space_surface/pad = /obj/docking_port/stationary/stationtrauma_space_surface
	return list(initial(pad.dwidth), initial(pad.width) - initial(pad.dwidth), initial(pad.dheight), initial(pad.height) - initial(pad.dheight))

/** Authored surface sites use the native ruin loader; the generator reserves their footprints first. */
/datum/map_template/ruin/expedition
	prefix = "_maps/map_files/overmap_ruins/planet/"
	ruin_type = "expedition_surface"
	allow_duplicates = FALSE
	/// Surface biome keys compatible with this ruin template; "waste" ruins stand on bombarded planets of any biome.
	var/list/planet_biomes = list("barren", "frozen", "arid", "lush", "lava")
	/// Arrival cells just outside the footprint, relative to tile (1,1). Unmarked templates protect the open footprint.
	var/list/surface_entrances
	/// Authored outside areas of a marked template, in west, south, east, north order.
	var/list/surface_open_areas

/datum/stationtrauma_overmap_site/space/planet
	/// Surface biome key used to select compatible ruin templates.
	var/ruin_biome = "barren"
	/// Loaded ruin IDs retained for this physical surface.
	var/list/ruin_ids = list()

/datum/stationtrauma_overmap_site/space/planet/frozen
	ruin_biome = "frozen"

/datum/stationtrauma_overmap_site/space/planet/arid
	ruin_biome = "arid"

/datum/stationtrauma_overmap_site/space/planet/lush
	ruin_biome = "lush"

/datum/map_generator/expedition_barren
	/// Number of small templates offered on a new surface, before checking for suitable spots.
	var/list/small_ruin_count = list(2, 5)
	/// Percent chance that this profile widens its surface around one large town or complex.
	var/large_ruin_chance = 0
	/// Biome key of the templates that may fill the large ruin slot.
	var/large_ruin_biome
	/// Square side length in turfs of a surface with room for a large ruin.
	var/large_surface_width = 176
	/// Whether this surface was widened for a large ruin when the planet was charted.
	var/large_slot = FALSE

/**
 * Roll ruins from the appropriate pool and retain the ones with a dry approach.
 * A widened surface may offer a town or complex wider than 54 turfs.
 *
 * Each template appears on one planet per round, so planets surveyed later may get fewer ruins, or none, once their biome's pool runs dry.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/prepare_ruins(datum/map_generator/expedition_barren/generator)
	var/list/biomes = list(ruin_biome)
	// Bombarded planets also carry the ruins of a radioactive wasteland.
	if(generator.craters)
		biomes += "waste"
	var/list/large = list()
	var/list/small = list()
	var/list/huge = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/expedition/template = SSmapping.ruins_templates[key]
		if(!istype(template) || template.unpickable || (template.loaded && !template.allow_duplicates))
			continue
		// Large towns and complexes only fill the large slot of a widened surface.
		if(template.width > 54 || template.height > 54)
			if(generator.large_slot && (generator.large_ruin_biome in template.planet_biomes))
				huge += template
			continue
		if(!length(template.planet_biomes & biomes))
			continue
		if(max(template.width, template.height) >= 25)
			large += template
		else
			small += template
	var/list/chosen = list()
	if(length(large))
		chosen += pick(large)
	for(var/index in 1 to min(rand(generator.small_ruin_count[1], generator.small_ruin_count[2]), length(small)))
		chosen += pick_n_take(small)
	var/list/placements = list()
	if(length(huge))
		var/datum/map_template/ruin/expedition/town = pick(huge)
		var/list/spot = generator.reserve_ruin(town.width, town.height, town)
		if(spot)
			town.loaded++
			placements += list(list(town, spot[1], spot[2], spot[3], spot[4]))
	generator.reserve_hive()
	for(var/datum/map_template/ruin/expedition/template as anything in chosen)
		var/list/spot = generator.reserve_ruin(template.width, template.height, template)
		if(!spot)
			continue
		// Claimed on reservation, so surfaces generating side by side never take the same template.
		template.loaded++
		placements += list(list(template, spot[1], spot[2], spot[3], spot[4]))
	return placements

/** Reserve a site with a dry approach on the already planned terrain. */
/datum/map_generator/expedition_barren/proc/reserve_ruin(ruin_width, ruin_height, datum/map_template/ruin/expedition/template)
	if(ruin_width > width - 8 || ruin_height > width - 8)
		return null
	for(var/attempt in 1 to 90)
		budget?.yield()
		var/left = rand(5, width - 3 - ruin_width)
		var/bottom = rand(5, width - 3 - ruin_height)
		var/right = left + ruin_width - 1
		var/top = bottom + ruin_height - 1
		if(!ruin_fits_surface(left, bottom, right, top))
			continue
		var/list/approaches = ruin_approaches(left, bottom, right, top, template?.surface_entrances)
		if(!length(approaches))
			continue
		for(var/cell in approaches)
			protect_surface_route(cell)
		for(var/y in bottom to top)
			for(var/x in left to right)
				var/cell = (y - 1) * width + x
				ruin_interiors[cell] = TRUE
				surface_layout[cell] = TRUE
		if(!length(template?.surface_entrances))
			rough_ruin_clearance(left, bottom, right, top)
		for(var/list/yard as anything in template?.surface_open_areas)
			rough_ruin_clearance(left + yard[1] - 1, bottom + yard[2] - 1, left + yard[3] - 1, bottom + yard[4] - 1)
		refresh_surface_routes()
		var/entrance = approaches[1]
		return list(left, bottom, (entrance - 1) % width + 1, round((entrance - 1) / width) + 1)
	return null

/datum/map_generator/expedition_barren/proc/ruin_fits_surface(left, bottom, right, top)
	for(var/y in bottom - 1 to top + 1)
		for(var/x in left - 1 to right + 1)
			var/cell = (y - 1) * width + x
			if(surface_layout[cell])
				return FALSE
			var/terrain = surface_terrain[cell]
			if(!dry_surface_type(terrain) && !ispath(terrain, /turf/closed/mineral))
				return FALSE
	return TRUE
/datum/map_generator/expedition_barren/proc/ruin_approaches(left, bottom, right, top, list/entrances)
	var/list/approaches = list()
	if(length(entrances))
		for(var/list/entrance as anything in entrances)
			var/cell = (bottom + entrance[2] - 2) * width + left + entrance[1] - 1
			if(!ruin_route_clear(cell, left, bottom, right, top))
				return null
			approaches += cell
		return approaches
	for(var/x in left - 1 to right + 1)
		var/south = (bottom - 2) * width + x
		if(ruin_route_clear(south, left, bottom, right, top))
			return list(south)
		var/north = top * width + x
		if(ruin_route_clear(north, left, bottom, right, top))
			return list(north)
	for(var/y in bottom to top)
		var/row = (y - 1) * width
		if(ruin_route_clear(row + left - 1, left, bottom, right, top))
			return list(row + left - 1)
		if(ruin_route_clear(row + right + 1, left, bottom, right, top))
			return list(row + right + 1)
	return null

/** A route must reach the ruin from outside its authored footprint. */
/datum/map_generator/expedition_barren/proc/ruin_route_clear(cell, left, bottom, right, top)
	while(surface_routes[cell])
		var/x = (cell - 1) % width + 1
		var/y = round((cell - 1) / width) + 1
		if(x >= left && x <= right && y >= bottom && y <= top)
			return FALSE
		var/parent = surface_routes[cell]
		if(parent == cell)
			return TRUE
		cell = parent
	return FALSE

/** A noisy apron blends the protected open ground into the surrounding rock or vegetation. */
/datum/map_generator/expedition_barren/proc/rough_ruin_clearance(left, bottom, right, top)
	for(var/y in max(3, bottom - 4) to min(width - 2, top + 4))
		budget?.yield()
		for(var/x in max(3, left - 4) to min(width - 2, right + 4))
			var/cell = (y - 1) * width + x
			var/horizontal = max(left - x, x - right, 0)
			var/vertical = max(bottom - y, y - top, 0)
			var/distance = sqrt(horizontal ** 2 + vertical ** 2)
			if(max(horizontal, vertical) > 1 && distance > 1 + 3 * surface_noise(6000000, x, y, 6))
				continue
			var/terrain = surface_terrain[cell]
			if(!dry_surface_type(terrain) && !ispath(terrain, /turf/closed/mineral))
				continue
			if(!dry_surface_type(terrain))
				surface_terrain[cell] = floor_type
			surface_layout[cell] = TRUE


/**
 * Load reserved ruins and retain their IDs, yielding to `budget` between templates.
 *
 * Placeholder ground and rock inside a ruin take the planet's own types, as they do in surface features.
 */
/datum/stationtrauma_overmap_site/space/planet/proc/load_ruins(list/placements, turf/origin, area/surface, datum/stationtrauma_work_budget/budget)
	for(var/list/placement as anything in placements)
		var/datum/map_template/ruin/expedition/template = placement[1]
		var/turf/bottom = locate(origin.x + placement[2] - 1, origin.y + placement[3] - 1, origin.z)
		var/turf/center = locate(bottom.x + round(template.width / 2), bottom.y + round(template.height / 2), origin.z)
		if(!template.load(bottom))
			return FALSE
		var/list/covered = template.get_affected_turfs(bottom)
		generator.adapt_template_turfs(covered, surface)
		stationtrauma_fuel_cache(covered, ST_FUEL_CACHE_PLANET_CHANCE)
		new /obj/effect/landmark/ruin(center, template)
		ruin_ids += template.id
		budget?.yield()
	return TRUE

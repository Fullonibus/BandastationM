// Biome selection, tables and densities adapted from CeladonSS13/Shiptest, AGPL-3.0; contents use local TG types.
// https://github.com/CeladonSS13/Shiptest/tree/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary
/**
 * Sierra's airless, lifeless, mineral-rich profile, using TG's seeded rust-g noise.
 *
 * Height, heat and humidity noise choose Celadon biomes: mountains above [/datum/map_generator/expedition_barren/var/mountain_height]
 * use the cave table and keep ore-bearing rock around a native tunnel system. Biomes and mountains follow the seed; tunnels, ore veins,
 * flora and fauna use TG's random cave system, vein growth and biome population.
 */
/datum/map_generator/expedition_barren
	/// Deterministic terrain seed, between 1 and 1000000.
	var/seed
	/// Height, heat and humidity noise scale in turfs; larger values give wider biomes.
	var/biome_zoom = 65
	/// Height noise above which terrain becomes mountain rock with cave pockets. Celadon's moon uses 0.8; Sierra's barren profile stays mineral-rich.
	var/mountain_height = 0.5
	/// Initial open share of a tunnel system carved through the whole surface, as on native lavaland; null keeps separate mountains.
	var/surface_open_percent
	/// Surface biomes by heat band (coldest first), then humidity band (driest first).
	var/list/biome_table = list(
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar, /datum/biome/expedition/lunar),
		list(/datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar/rocky, /datum/biome/expedition/lunar),
	)
	/// Mountain cave biomes by cave heat band, then humidity band; a single biome type fills every cave.
	var/cave_biome_table = /datum/biome/expedition/lunar
	/// Mountain rock; ore veins are grown inside it after the terrain pass.
	var/rock_type = /turf/closed/mineral
	/// Percent chance that a mountain rock tile seeds an ore vein.
	var/mineral_chance = 11
	/// Weighted ore stacks for vein seeds; each ore's own vein type and size shape the deposit.
	var/list/ore_types = list(
		/obj/item/stack/ore/diamond = 5,
		/obj/item/stack/ore/gold = 15,
		/obj/item/stack/ore/silver = 20,
		/obj/item/stack/ore/uranium = 20,
		/obj/item/stack/ore/titanium = 30,
		/obj/item/stack/ore/iron = 150,
	)
	/// Generated open turfs of each biome, populated after the camp and ruins are placed.
	var/list/biome_turfs
	/// Distance in turfs around the camp where flora still grows but hostile fauna never starts.
	var/fauna_clearance = 15
	/// Whether this profile's biomes spawn fauna that modifiers can thin out or multiply.
	var/wildlife = FALSE
	/// Fauna density multiplier from modifiers, applied to this planet's own biome copies.
	var/fauna_multiplier = 1
	/// Names of the applied modifiers for admin logs; the survey shows only crew-facing lines.
	var/list/modifier_log = list()
	/// Applied modifiers placing surface objects through [/datum/map_generator/expedition_barren/proc/place_nests].
	var/list/datum/expedition_planet_modifier/nests = list()
	/// This planet's biome copies by type, so modifier densities never reach other planets.
	var/list/biomes
	/// Z-level trait of the profile's periodic storm weather, if it has one.
	var/storm_trait
	/// Whether a modifier enabled the periodic storm weather.
	var/storms = FALSE
	/// Endless variant of the profile's storm weather, if it has one.
	var/datum/weather/endless_storm_type
	/// Whether a modifier set the endless storm raging over the surface.
	var/endless_storm = FALSE
	/// Whether a modifier added a cave level beneath the surface.
	var/underground = FALSE
	/// Colour of the open surface's base light under this profile's sky.
	var/sky_color = "#d8e0ff"
	/// Base light alpha of the open surface from modifiers; zero keeps TG's dark planetary surface.
	var/light_alpha = 0
	/// Set while [/datum/map_generator/expedition_barren/proc/generate_terrain] fills the cave level instead of the surface.
	var/cave_level = FALSE
	/// Open space carrying this profile's atmosphere, used for drops into the cave level.
	var/turf/open/openspace/hole_type = /turf/open/openspace/airless/planetary
	/// Relative coordinates of surface ladders and drops; the cave level keeps a clearing beneath each.
	var/list/connector_points = list()
	/// Generated square side length in turfs.
	var/width = 128
	/// Greatest depth of the mineable cliff band inside the rim, as a fraction of half the width.
	var/edge_roughness = 0.25
	/// World X of the generated square southwest corner.
	var/origin_x
	/// World Y of the generated square southwest corner.
	var/origin_y
	/// Base camp southwest X relative to the generated square.
	var/camp_x
	/// Base camp southwest Y relative to the generated square.
	var/camp_y
	/// Reserved base camp width in turfs.
	var/camp_width
	/// Reserved base camp height in turfs.
	var/camp_height
	/// Reserved ruin rectangles excluded from terrain and flora placement.
	var/list/ruin_bounds = list()
	/// Default walkable ground type for this environment profile.
	var/turf/open/floor_type = /turf/open/misc/asteroid/airless
	/// Research source type placed on accessible surface terrain.
	var/source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_barren
	/// Optional tint applied to generated mineral terrain.
	var/rock_color
	/// Small surface feature maps with pick weights; placeholders adapt to this profile's ground and rock.
	var/list/feature_maps = list(
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater1.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater2.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater3.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater4.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater5.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_moon_crater6.dmm" = 1,
	)
	/// Surface features placed on each planet when free space allows.
	var/feature_count = 6
	/// Cave-level feature maps with pick weights; the default set of shacks, bunkers, wells and mushroom groves suits every profile.
	var/list/cave_feature_maps = list(
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_2.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_4.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_5.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_7.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_9.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_10.dmm" = 1,
	)
	/// Cave features placed on each cave level when free space allows.
	var/cave_feature_count = 6
	/// Research sources placed in each cave level's open pockets.
	var/cave_source_count = 2
	/// Turfs covered by placed features; flora and fauna never start on them.
	var/list/feature_turfs
	/// Work slice shared by every generation step of this surface.
	var/datum/stationtrauma_work_budget/budget

/datum/map_generator/expedition_barren/New(chosen_seed)
	. = ..()
	if(!ISINTEGER(chosen_seed) || chosen_seed < 1 || chosen_seed > 1000000)
		CRASH("Invalid expedition planet seed [chosen_seed]")
	seed = chosen_seed

/** Whether relative generator coordinates lie inside the reserved base camp. */
/datum/map_generator/expedition_barren/proc/in_camp(x, y)
	return x >= camp_x && x < camp_x + camp_width && y >= camp_y && y < camp_y + camp_height

/** Whether relative coordinates are reserved for a camp, access corridor or ruin. */
/datum/map_generator/expedition_barren/proc/is_reserved(x, y)
	if(in_camp(x, y) || abs(x - round(width / 2)) <= 1 || abs(y - round(width / 2)) <= 1)
		return TRUE
	// An open row links the camp to the cross, so mountains never wall the landing site in.
	if(y == camp_y + round(camp_height / 2) && x >= camp_x && x <= round(width / 2))
		return TRUE
	for(var/list/bounds as anything in ruin_bounds)
		if(x >= bounds[1] - 1 && x <= bounds[3] + 1 && y >= bounds[2] - 1 && y <= bounds[4] + 1)
			return TRUE
		if(y == round((bounds[2] + bounds[4]) / 2) && x >= min(round(width / 2), bounds[1]) && x <= max(round(width / 2), bounds[3]))
			return TRUE
	return FALSE

/** Celadon biome for relative coordinates, from the surface or mountain cave table. */
/datum/map_generator/expedition_barren/proc/biome_at(x, y, mountain)
	var/static/list/heat_bands = list(0.2, 0.4, 0.6, 0.65, 0.8)
	var/static/list/cave_heat_bands = list(0.25, 0.5, 0.75)
	var/static/list/humidity_bands = list(0.2, 0.4, 0.6, 0.8)
	var/table = mountain ? cave_biome_table : biome_table
	if(!islist(table))
		return local_biome(table)
	// Seed offsets keep consecutive planet seeds from sharing noise fields.
	var/heat = text2num(rustg_noise_get_at_coordinates("[seed + 1000000]", "[x / biome_zoom]", "[y / biome_zoom]"))
	var/humidity = text2num(rustg_noise_get_at_coordinates("[seed + 2000000]", "[x / biome_zoom]", "[y / biome_zoom]"))
	var/list/row = table[noise_band(heat, mountain ? cave_heat_bands : heat_bands)]
	return local_biome(row[noise_band(humidity, humidity_bands)])

/** This planet's own biome instance, with the modifier fauna density applied once. */
/datum/map_generator/expedition_barren/proc/local_biome(biome_type)
	var/datum/biome/biome = LAZYACCESS(biomes, biome_type)
	if(!biome)
		biome = new biome_type
		biome.fauna_density *= fauna_multiplier
		LAZYSET(biomes, biome_type, biome)
	return biome

/** One-based band of a noise value among ascending inclusive upper thresholds. */
/datum/map_generator/expedition_barren/proc/noise_band(value, list/thresholds)
	var/band = 1
	for(var/threshold in thresholds)
		if(value > threshold)
			band++
	return band

/datum/map_generator/expedition_barren/generate_terrain(list/turfs, area/generate_in)
	budget ||= new
	var/list/turf/closed/mineral/rocks = list()
	var/whole_surface = !cave_level && !isnull(surface_open_percent)
	var/cave_grid = cave_system_grid(whole_surface ? surface_open_percent : null)
	for(var/turf/tile as anything in turfs)
		budget.yield()
		tile.change_area(get_area(tile), generate_in)
		var/x = tile.x - origin_x + 1
		var/y = tile.y - origin_y + 1
		var/datum/biome/biome
		var/terrain = floor_type
		// The opaque rim bounds this surface within its otherwise empty z-level.
		if(x <= 2 || y <= 2 || x > width - 2 || y > width - 2)
			terrain = /turf/closed/indestructible/rock
		// The reservation and open cross keep landing, the laboratory and the field connected.
		else if(cave_level ? !in_clearing(x, y) : !is_reserved(x, y))
			// The cave level is one mountain; its own pocket noise keeps it from mirroring surface caves.
			var/mountain = cave_level || (!whole_surface && text2num(rustg_noise_get_at_coordinates("[seed]", "[x / biome_zoom]", "[y / biome_zoom]")) > mountain_height)
			biome = biome_at(x, y, mountain)
			terrain = biome.open_turf_type
			// Noisy cliffs inside the rim replace its straight edge; the camp, ruins and cross stay reserved.
			var/edge = max(abs(x - width / 2), abs(y - width / 2)) / (width / 2) + text2num(rustg_noise_get_at_coordinates("[seed + 4000000]", "[x / 16]", "[y / 16]")) * edge_roughness
			// Rock around the tunnel system keeps the mountain mineable.
			if(edge > 1 || ((mountain || whole_surface) && cave_grid[width * (y - 1) + x] != "1"))
				terrain = rock_type
		var/turf/generated = tile.ChangeTurf(terrain, floor_type, CHANGETURF_IGNORE_AIR)
		if(ismineralturf(generated))
			prepare_rock(generated)
			rocks += generated
		else if(biome)
			LAZYADDASSOCLIST(biome_turfs, biome, generated)
	// Veins spread into neighbouring rock, so they start only once the whole mountain exists.
	// The deeper cave level seeds half again as many veins.
	var/vein_chance = cave_level ? mineral_chance * 1.5 : mineral_chance
	// The typed loop skips tiles changed while the budget slept.
	for(var/turf/closed/mineral/rock in rocks)
		budget.yield()
		if(rock.mineral_type || !prob(vein_chance))
			continue
		var/obj/item/stack/ore/ore_type = pick_weight(ore_types)
		rock.change_ore(ore_type)
		if(prob(ore_type::spread_chance))
			rock.spread_vein(ore_type)

/**
 * Native rust-g cave system carved into mountains: BSP rooms joined by MST corridors with some loops, smoothed by cellular automata.
 *
 * Returns a width*width string of "1" (open) and "0" (rock), row-major from the bottom row. On the cave level the clearings beneath
 * the surface connectors join the network as open rooms; across a whole surface the camp and ruins do. The generator takes no seed,
 * so tunnels do not follow the planet seed.
 *
 * Arguments:
 * * open_percent - Initial open share; null uses the native lavaland value
 */
/datum/map_generator/expedition_barren/proc/cave_system_grid(open_percent)
	var/list/clearings = list()
	for(var/list/point as anything in connector_points)
		clearings += list(list("x" = point[1] - 2, "y" = point[2] - 2, "w" = 5, "h" = 5, "isEnclosed" = FALSE))
	if(!cave_level && !isnull(open_percent))
		clearings += list(list("x" = camp_x, "y" = camp_y, "w" = camp_width, "h" = camp_height, "isEnclosed" = FALSE))
		for(var/list/bounds as anything in ruin_bounds)
			clearings += list(list("x" = bounds[1], "y" = bounds[2], "w" = bounds[3] - bounds[1] + 1, "h" = bounds[4] - bounds[2] + 1, "isEnclosed" = FALSE))
	// Native lavaland settings, read as the native generator's initial values; dead edges keep the tunnels off the rim.
	var/datum/map_generator/cave_generator/native
	return rustg_cave_system_generator_generate("[width]", "[width]", json_encode(clearings), "[native::min_bsp_size]", "[native::max_ratio]", "[native::padding]", "[native::room_fill_percent]", "[native::corridor_width]", "[native::loop_percent]", "[isnull(open_percent) ? native::noise_percent : open_percent]", "[native::ca_steps]", "[native::birth_limit]", "[native::survival_limit]", "[FALSE]")

/** Native rock must expose this planet's ground, atmosphere and tint when mined. */
/datum/map_generator/expedition_barren/proc/prepare_rock(turf/closed/mineral/rock)
	rock.turf_type = floor_type
	rock.initial_gas_mix = initial(floor_type.initial_gas_mix)
	if(rock_color)
		rock.color = rock_color

/**
 * Swap template placeholder ground and rock for this profile's types and move carrier tiles into the planet surface area.
 *
 * Open ground mapped inside a ruin's own area joins the surface too, so it shares the sky light instead of staying dark.
 */
/datum/map_generator/expedition_barren/proc/adapt_template_turfs(list/turfs, area/surface)
	for(var/turf/tile as anything in turfs)
		var/area/tile_area = tile.loc
		if(tile_area != surface && (tile_area.type == /area/expedition_planet/barren || istype(tile, /turf/open/misc)))
			tile.change_area(tile_area, surface)
		if(tile.type == /turf/open/misc/asteroid/airless && floor_type != tile.type)
			tile.ChangeTurf(floor_type, floor_type, CHANGETURF_IGNORE_AIR)
		else if(tile.type == /turf/closed/mineral)
			prepare_rock(rock_type == tile.type ? tile : tile.ChangeTurf(rock_type, floor_type, CHANGETURF_IGNORE_AIR))

/**
 * Whether a feature fits at relative coordinates: clear of reserved terrain, the camp's fauna clearance
 * and earlier features, and mostly open so it does not vanish inside a mountain.
 */
/datum/map_generator/expedition_barren/proc/feature_fits(x, y, datum/map_template/template, list/placed, z)
	var/right = x + template.width - 1
	var/top = y + template.height - 1
	// Features may carry hostile fauna, so surface features stay outside the camp's fauna clearance.
	if(!cave_level && x < camp_x + camp_width + fauna_clearance && y < camp_y + camp_height + fauna_clearance)
		return FALSE
	for(var/list/bounds as anything in placed)
		if(x <= bounds[3] + 1 && right >= bounds[1] - 1 && y <= bounds[4] + 1 && top >= bounds[2] - 1)
			return FALSE
	var/open = 0
	for(var/tile_x in x to right)
		for(var/tile_y in y to top)
			if(cave_level ? in_clearing(tile_x, tile_y) : is_reserved(tile_x, tile_y))
				return FALSE
			if(isopenturf(locate(origin_x + tile_x - 1, origin_y + tile_y - 1, z)))
				open++
	// Cave features carve their own rooms into the mountain, so a third of open floor is enough there.
	if(cave_level)
		return open * 3 >= template.width * template.height
	return open * 4 >= template.width * template.height * 3

/** Load small features from `maps` at random free spots of the level at `bottom`; returns how many were placed. */
/datum/map_generator/expedition_barren/proc/place_features(turf/bottom, area/surface, list/maps = feature_maps, count = feature_count)
	var/static/list/templates = list()
	var/list/placed = list()
	for(var/attempt in 1 to count * 5)
		if(length(placed) >= count)
			break
		var/map = pick_weight(maps)
		var/datum/map_template/template = templates[map]
		if(!template)
			template = new(map)
			templates[map] = template
		var/x = rand(4, width - 3 - template.width)
		var/y = rand(4, width - 3 - template.height)
		if(!feature_fits(x, y, template, placed, bottom.z))
			continue
		var/turf/origin = locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z)
		if(!template.load(origin))
			continue
		var/list/covered = template.get_affected_turfs(origin)
		adapt_template_turfs(covered, surface)
		for(var/turf/tile as anything in covered)
			LAZYSET(feature_turfs, tile, TRUE)
		placed += list(list(x, y, x + template.width - 1, y + template.height - 1))
		budget?.yield()
	return length(placed)

/** Whether relative cave-level coordinates lie in the clearing beneath a surface ladder or drop. */
/datum/map_generator/expedition_barren/proc/in_clearing(x, y)
	for(var/list/point as anything in connector_points)
		if(abs(x - point[1]) <= 2 && abs(y - point[2]) <= 2)
			return TRUE
	return FALSE

/**
 * Fill the cave level beneath a finished surface and link the two with ladders and drops.
 *
 * Connectors sit on free open surface ground, apart from each other, the reservation and features.
 * Unbreakable ladders guarantee a way back up; drops are one-way open space into a cave clearing.
 * Returns the number of connectors.
 */
/datum/map_generator/expedition_barren/proc/generate_underground(turf/surface_bottom, datum/space_level/caves, area/surface, planet_name)
	var/ladders = 3
	var/drops = 2
	for(var/attempt in 1 to 200)
		if(length(connector_points) >= ladders + drops)
			break
		var/x = rand(8, width - 8)
		var/y = rand(8, width - 8)
		var/turf/tile = locate(origin_x + x - 1, origin_y + y - 1, surface_bottom.z)
		if(!isopenturf(tile) || isgroundlessturf(tile) || tile.loc != surface || is_reserved(x, y) || LAZYACCESS(feature_turfs, tile) || tile.is_blocked_turf(TRUE))
			continue
		var/near = FALSE
		for(var/list/point as anything in connector_points)
			if(max(abs(x - point[1]), abs(y - point[2])) < 16)
				near = TRUE
				break
		if(!near)
			connector_points += list(list(x, y))
	if(length(connector_points) <= drops)
		return 0
	var/turf/bottom = locate(surface_bottom.x, surface_bottom.y, caves.z_value)
	var/area/expedition_planet/barren/caves_area = new
	caves_area.name = "[planet_name]: пещеры"
	cave_level = TRUE
	var/list/cave_turfs = block(bottom, locate(bottom.x + width - 1, bottom.y + width - 1, bottom.z))
	generate_terrain(cave_turfs, caves_area)
	place_features(bottom, caves_area, cave_feature_maps, cave_feature_count)
	populate_biomes()
	// Research sources wait in open pockets away from the connectors and features.
	var/list/pockets = list()
	for(var/turf/open/tile in cave_turfs)
		if(tile.loc == caves_area && !isgroundlessturf(tile) && !LAZYACCESS(feature_turfs, tile) && !in_clearing(tile.x - origin_x + 1, tile.y - origin_y + 1) && !tile.is_blocked_turf(TRUE))
			pockets += tile
	for(var/index in 1 to min(cave_source_count, length(pockets)))
		new source_type(pick_n_take(pockets))
	for(var/index in 1 to length(connector_points))
		var/list/point = connector_points[index]
		var/turf/upper = locate(origin_x + point[1] - 1, origin_y + point[2] - 1, surface_bottom.z)
		if(index <= length(connector_points) - drops)
			var/obj/structure/ladder/unbreakable/lower_ladder = new(locate(upper.x, upper.y, caves.z_value))
			new /obj/structure/ladder/unbreakable(upper, null, lower_ladder)
		else
			upper.ChangeTurf(hole_type, hole_type, CHANGETURF_IGNORE_AIR)
	SSmapping.reg_in_areas_in_z(list(caves_area))
	smooth_zlevel(caves.z_value)
	return length(connector_points)

/** Populate the generated biomes with flora, then settle their fauna in packs; fauna never starts near the camp or on placed features. */
/datum/map_generator/expedition_barren/proc/populate_biomes()
	var/list/wild_by_biome = list()
	for(var/datum/biome/biome as anything in biome_turfs)
		var/list/near_camp = list()
		var/list/wild = list()
		for(var/turf/tile as anything in biome_turfs[biome])
			if(LAZYACCESS(feature_turfs, tile))
				continue
			var/x = tile.x - origin_x + 1
			var/y = tile.y - origin_y + 1
			if(x >= camp_x - fauna_clearance && x < camp_x + camp_width + fauna_clearance && y >= camp_y - fauna_clearance && y < camp_y + camp_height + fauna_clearance)
				near_camp += tile
			else
				wild += tile
		biome.populate_turfs(near_camp, flora_allowed = TRUE, features_allowed = TRUE, fauna_allowed = FALSE)
		biome.populate_turfs(wild, flora_allowed = TRUE, features_allowed = TRUE, fauna_allowed = FALSE)
		wild_by_biome[biome] = wild
	biome_turfs = null
	place_packs(wild_by_biome)

/datum/map_generator/expedition_barren/populate_terrain(list/turfs, area/generate_in)
	populate_biomes()
	var/sources = 0
	var/turf/origin = turfs[1]
	var/offset = 8 + seed % 6
	var/middle = round(width / 2)
	for(var/list/position as anything in list(list(offset, middle), list(middle, offset), list(width - offset, middle)))
		var/turf/tile = locate(origin_x + position[1] - 1, origin_y + position[2] - 1, origin.z)
		if(!istype(tile, floor_type) || get_area(tile) != generate_in)
			continue
		new source_type(tile)
		sources++
	return sources

/** Celadon planetary biome; its open turf must carry the atmosphere of every planet that uses it. */
/datum/biome/expedition

/** Place each rolled modifier's objects on free open ground, outside the camp's fauna clearance and its access corridors. */
/datum/map_generator/expedition_barren/proc/place_nests(turf/bottom)
	for(var/datum/expedition_planet_modifier/modifier as anything in nests)
		var/list/patch
		for(var/count in 1 to rand(modifier.nest_count[1], modifier.nest_count[2]))
			for(var/attempt in 1 to 30)
				var/x = patch ? patch[1] + rand(-modifier.nest_cluster, modifier.nest_cluster) : rand(4, width - 3)
				var/y = patch ? patch[2] + rand(-modifier.nest_cluster, modifier.nest_cluster) : rand(4, width - 3)
				if(x < 4 || y < 4 || x > width - 3 || y > width - 3 || is_reserved(x, y) || (x < camp_x + camp_width + fauna_clearance && y < camp_y + camp_height + fauna_clearance))
					continue
				var/turf/open/misc/tile = locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z)
				if(!istype(tile) || tile.is_blocked_turf())
					continue
				var/nest_type = islist(modifier.nest_type) ? pick(modifier.nest_type) : modifier.nest_type
				if(istype(src, /datum/map_generator/expedition_barren/dead) && ispath(nest_type, /obj/structure/spawner/stationtrauma_zombie_pit))
					var/datum/map_generator/expedition_barren/dead/dead_profile = src
					if(!dead_profile.in_zombie_region(tile))
						continue
				var/atom/nest = new nest_type(tile)
				// Spawner dens hold their kind from the start; mines and geysers stand alone.
				if(istype(nest, /obj/structure/spawner))
					raise_lair(nest)
				if(modifier.nest_cluster && !patch)
					patch = list(x, y)
				break

/// Xenomorph egg cluster hatching hunters, drones and sentinels until it is torn down.
/obj/structure/spawner/stationtrauma_xeno_hive
	name = "кладка ксеноморфов"
	desc = "Пульсирующая кладка яиц, вросшая в смолу. Изнутри что-то скребётся."
	icon = 'icons/mob/nonhuman-player/alien.dmi'
	icon_state = "egg"
	max_integrity = 200
	max_mobs = 4
	spawn_time = 60 SECONDS
	mob_types = list(/mob/living/basic/alien, /mob/living/basic/alien/drone, /mob/living/basic/alien/sentinel)
	spawn_text = "выбирается из"
	faction = list(ROLE_ALIEN)
	mob_gps_id = "XEN"
	spawner_gps_id = "Xenomorph Hive"

/// Stable bluespace anomaly anchored to its planet; signalling it frees the core.
/obj/effect/anomaly/bluespace/stationtrauma

/obj/effect/anomaly/bluespace/stationtrauma/Initialize(mapload, new_lifespan)
	. = ..()
	stabilize(anchor = TRUE)

/// Bone pit of a lost expedition, slower than the native pit so a landing party can reach it.
/obj/structure/spawner/skeleton/stationtrauma
	max_mobs = 5
	spawn_time = 40 SECONDS

/// Plague pit raising rotting dead until it is filled in.
/obj/structure/spawner/stationtrauma_zombie_pit
	name = "чумная яма"
	desc = "Яма, полная тел. Некоторые из них ещё шевелятся."
	icon = 'icons/mob/simple/lavaland/nest.dmi'
	icon_state = "hole"
	max_integrity = 150
	max_mobs = 5
	spawn_time = 45 SECONDS
	mob_types = list(/mob/living/basic/zombie/rotten/expedition)
	spawn_text = "выползает из"
	faction = list(FACTION_HOSTILE)
	mob_gps_id = "ZMB"
	spawner_gps_id = "Plague Pit"

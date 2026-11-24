/** Imported space templates excluded from ordinary station space ruin selection. */
/datum/map_template/ruin/space/expedition
	prefix = "_maps/map_files/overmap_ruins/space/"
	ruin_type = "expedition_space"
	/// Crew-facing chart name for this imported ruin.
	var/overmap_name

/// Ruin template keys already charted by any sector; templates load only on approach, so `loaded` cannot guard this round.
GLOBAL_LIST_EMPTY(stationtrauma_charted_ruins)

/** Only reviewed local templates participate; native blacklists and round duplicate limits still apply. */
/datum/stationtrauma_overmap_sector/space/proc/load_ruin_sector(count = 6)
	var/list/approved = list(
		/datum/map_template/ruin/space/oldstation = "Древняя космическая станция",
		/datum/map_template/ruin/space/deep_storage = "Автономный бункер",
		/datum/map_template/ruin/space/anomaly_research = "Аномальная исследовательская станция",
		/datum/map_template/ruin/space/zoo = "Биологическое хранилище",
		/datum/map_template/ruin/space/bigderelict1 = "Заброшенный торговый узел",
		/datum/map_template/ruin/space/derelict_sulaco = "Обломки военного корабля",
		/datum/map_template/ruin/space/mech_transport = "Транспорт CF Corsair",
		/datum/map_template/ruin/space/turreted_outpost = "Укреплённый аванпост",
		/datum/map_template/ruin/space/listeningstation = "Станция радиоперехвата",
		/datum/map_template/ruin/space/old_ai_sat = "Заброшенный ретранслятор",
		/datum/map_template/ruin/space/forgottenship = "Затерянный корабль",
		/datum/map_template/ruin/space/stationtrauma_icarus = "Исследовательский корабль SEV Icarus",
		/datum/map_template/ruin/space/stationtrauma_scav_mining = "Заброшенная шахтёрская база",
	)
	var/list/candidates = list()
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/template = SSmapping.ruins_templates[key]
		if(istype(template, /datum/map_template/ruin/space/expedition))
			var/datum/map_template/ruin/space/expedition/imported = template
			approved[template.type] = imported.overmap_name
		if(approved[template.type] && !template.unpickable && (!template.loaded || template.allow_duplicates) && !GLOB.stationtrauma_charted_ruins[key])
			candidates[key] = template
	if(!length(candidates))
		stack_trace("No eligible expedition ruins; check space ruin blacklists and already loaded templates")
		return FALSE
	count = min(count, length(candidates))
	// Templates are chosen now so the chart can name each signal; the first approach loads it.
	for(var/index in 1 to count)
		var/key = pick(candidates)
		var/datum/map_template/ruin/template = candidates[key]
		candidates -= key
		GLOB.stationtrauma_charted_ruins[key] = TRUE
		var/datum/stationtrauma_overmap_site/space/site = new
		site.id = "expedition_[index]"
		site.name = approved[template.type]
		var/list/position = random_position(600, 1700, 350)
		site.pos_x = position[1]
		site.pos_y = position[2]
		site.discovered = FALSE
		site.needs_scan = TRUE
		site.map_loader = CALLBACK(src, PROC_REF(load_ruin_site), site, index, key, template)
		sites[site.id] = site
		// Reserve separate moorings around the ruin for standard hulls.
		add_pads(site, 4)
	return TRUE

/** Load one charted ruin on its own level, berthing the approach right beside it, level with its entrance airlock. */
/datum/stationtrauma_overmap_sector/space/proc/load_ruin_site(datum/stationtrauma_overmap_site/space/site, index, key, datum/map_template/ruin/template)
	var/datum/space_level/level = SSmapping.add_new_zlevel("Экспедиционный сектор [index]", ZTRAITS_AWAY)
	seedRuins(list(level.z_value), 1, list(/area/space), list((key) = template), mineral_budget = 0, ruins_type = ZTRAIT_SPACE_RUINS, immediate_load = TRUE)
	var/turf/origin
	var/datum/map_template/ruin/placed
	for(var/turf/anchor as anything in SSmapping.active_ruins)
		if(anchor.z == level.z_value)
			origin = anchor
			placed = SSmapping.active_ruins[anchor]
			break
	if(!placed || !placed.loaded)
		stack_trace("Expedition ruin [key] failed to load on z [level.z_value]")
		return FALSE
	stationtrauma_space_vacuum(level.z_value)
	var/list/ruin_tiles = block(origin, locate(origin.x + placed.width - 1, origin.y + placed.height - 1, origin.z))
	stationtrauma_fuel_cache(ruin_tiles, ST_FUEL_CACHE_SPACE_CHANCE)
	var/left = INFINITY
	var/bottom = INFINITY
	var/right = 0
	var/top = 0
	var/list/obj/machinery/door/airlock/doors = list()
	for(var/turf/tile as anything in ruin_tiles)
		if(isspaceturf(tile) && !tile.is_blocked_turf())
			continue
		left = min(left, tile.x)
		bottom = min(bottom, tile.y)
		right = max(right, tile.x)
		top = max(top, tile.y)
		for(var/obj/machinery/door/airlock/door in tile)
			doors += door
	if(!right)
		return FALSE

	var/approach_x = round((left + right) / 2)
	var/approach_y = round((bottom + top) / 2)
	var/approach_side = EAST
	var/best_score = -INFINITY
	for(var/obj/machinery/door/airlock/door as anything in doors)
		for(var/direction in GLOB.cardinals)
			var/turf/exit = get_step(door, direction)
			// A door into a gap between two wings may face space without offering a clear approach.
			while(isspaceturf(exit) && !exit.is_blocked_turf() && ISINRANGE(exit.x, left, right) && ISINRANGE(exit.y, bottom, top))
				exit = get_step(exit, direction)
			if(!isspaceturf(exit) || exit.is_blocked_turf())
				continue
			var/score = door.x + (direction == EAST ? world.maxx : 0)
			if(score > best_score)
				best_score = score
				site.entrance = get_turf(door)
				approach_x = door.x
				approach_y = door.y
				approach_side = direction
	site.ruin_id = placed.id
	switch(approach_side)
		if(EAST)
			approach_x = right + 1
		if(WEST)
			approach_x = left - 1
		if(NORTH)
			approach_y = top + 1
		if(SOUTH)
			approach_y = bottom - 1
	site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(approach_x, approach_y, origin.z))
	site.berth.setDir(approach_side)
	// Every border loops onto the ruin's level.
	for(var/side in GLOB.cardinals)
		stationtrauma_set_edge(level.z_value, side, level.z_value)
	place_ruin_pads(site, left, bottom, right, top, origin.z, approach_side)
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(site.berth))
	marker.site_id = site.id
	marker.name = site.name
	return TRUE

/** Put independent moorings beside the occupied ruin, offering the closest candidates to its entrance first. */
/datum/stationtrauma_overmap_sector/space/proc/place_ruin_pads(datum/stationtrauma_overmap_site/space/site, left, bottom, right, top, ruin_z, entrance_side)
	var/margin = TRANSITIONEDGE + 3
	var/gap = 12
	var/far_x = world.maxx - margin - ST_STANDARD_M_WIDTH + 1
	var/far_y = world.maxy - margin - ST_STANDARD_M_HEIGHT + 1
	var/centre_x = site.entrance?.x || round((left + right) / 2)
	var/centre_y = site.entrance?.y || round((bottom + top) / 2)
	var/list/candidates = list(
		"[EAST]" = list(right + gap + 1, clamp(centre_y - round(ST_STANDARD_M_HEIGHT / 2), margin, far_y)),
		"[WEST]" = list(left - gap - ST_STANDARD_M_WIDTH, clamp(centre_y - round(ST_STANDARD_M_HEIGHT / 2), margin, far_y)),
		"[NORTH]" = list(clamp(centre_x - round(ST_STANDARD_M_WIDTH / 2), margin, far_x), top + gap + 1),
		"[SOUTH]" = list(clamp(centre_x - round(ST_STANDARD_M_WIDTH / 2), margin, far_x), bottom - gap - ST_STANDARD_M_HEIGHT),
	)
	var/list/choices = list()
	for(var/side in list(entrance_side, turn(entrance_side, 90), turn(entrance_side, -90), REVERSE_DIR(entrance_side)))
		var/list/point = candidates["[side]"]
		var/along_x = side == NORTH || side == SOUTH
		var/spacing = along_x ? ST_STANDARD_M_WIDTH : ST_STANDARD_M_HEIGHT
		// Short ruins can leave two adjacent berths overlapping. Slide along the same face to clear the first.
		for(var/offset in list(0, -spacing, spacing))
			var/x = along_x ? clamp(point[1] + offset, margin, far_x) : point[1]
			var/y = along_x ? point[2] : clamp(point[2] + offset, margin, far_y)
			if(!ISINRANGE(x, margin, far_x) || !ISINRANGE(y, margin, far_y))
				break
			var/dx = x + (ST_STANDARD_M_WIDTH - 1) / 2 - centre_x
			var/dy = y + (ST_STANDARD_M_HEIGHT - 1) / 2 - centre_y
			choices += list(list(x, y, dx ** 2 + dy ** 2))
	var/list/available = list()
	for(var/list/point as anything in sortTim(choices, GLOBAL_PROC_REF(cmp_stationtrauma_ruin_pad_distance)))
		var/x = point[1]
		var/y = point[2]
		var/clear = TRUE
		for(var/list/other as anything in available)
			if(abs(other[1] - x) < ST_STANDARD_M_WIDTH && abs(other[2] - y) < ST_STANDARD_M_HEIGHT)
				clear = FALSE
				break
		if(!clear)
			continue
		for(var/turf/tile as anything in block(x, y, ruin_z, x + ST_STANDARD_M_WIDTH - 1, y + ST_STANDARD_M_HEIGHT - 1, ruin_z))
			if(!isspaceturf(tile) || tile.is_blocked_turf())
				clear = FALSE
				break
		if(clear)
			available += list(point)
			if(length(available) >= length(site.pads))
				break
	for(var/index in 1 to length(site.pads))
		var/datum/stationtrauma_overmap_site/space/pad = site.pads[index]
		pad.ruin_id = site.ruin_id
		pad.entrance = site.entrance
		if(index > length(available))
			pad.failed = TRUE
			continue
		var/list/point = available[index]
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad/slot = new(locate(point[1], point[2], ruin_z))
		slot.name = "[site.name]: стоянка [index]"
		pad.berth = slot

/// Compare mooring centers by their distance to the selected entrance.
/proc/cmp_stationtrauma_ruin_pad_distance(list/first, list/second)
	return first[3] - second[3]

/**
 * Maybe leave a partly filled oxygen or tritium canister on free built floor among `turfs`.
 *
 * A find extends an expedition without replacing station supply: a tritium cache holds a few minutes of Raven's half thrust.
 */
/proc/stationtrauma_fuel_cache(list/turfs, chance)
	if(!prob(chance))
		return null
	var/list/floors = list()
	for(var/turf/open/floor/tile in turfs)
		if(!tile.is_blocked_turf())
			floors += tile
	if(!length(floors))
		return null
	var/cache_type = prob(40) ? /obj/machinery/portable_atmospherics/canister/tritium/cache : /obj/machinery/portable_atmospherics/canister/oxygen/cache
	return new cache_type(pick(floors))

/// Tritium left behind on a ruin: about a fifth of a full canister.
/obj/machinery/portable_atmospherics/canister/tritium/cache
	filled = 0.2

/// Oxygen left behind on a ruin: a partly emptied canister.
/obj/machinery/portable_atmospherics/canister/oxygen/cache
	filled = 0.35

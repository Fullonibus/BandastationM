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
		// Four corner pads moor S and M hulls on the ruin's own level once it loads; capital hulls keep the seam.
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
	var/right_edge = origin.x + placed.width - 1
	stationtrauma_fuel_cache(block(origin, locate(right_edge, origin.y + placed.height - 1, origin.z)), ST_FUEL_CACHE_SPACE_CHANCE)
	var/approach_y = origin.y + round(placed.height / 2)
	var/best_score = -INFINITY
	for(var/turf/tile as anything in block(origin, locate(right_edge, origin.y + placed.height - 1, origin.z)))
		for(var/obj/machinery/door/airlock/door in tile)
			for(var/direction in GLOB.cardinals)
				if(!isspaceturf(get_step(door, direction)))
					continue
				// The seam opens east of the ruin: east-facing airlocks are straight across, others rank by how far east they stand.
				var/score = door.x + (direction == EAST ? world.maxx : 0)
				if(score > best_score)
					best_score = score
					site.entrance = tile
					approach_y = door.y
				break
	site.ruin_id = placed.id
	// The seam lands crews on the column just outside the ruin, level with that airlock.
	site.berth = new /obj/docking_port/stationary/stationtrauma_space_site(locate(right_edge + 1, approach_y, origin.z))
	// Every border loops onto the level itself, so a hull moored in a corner has no edge to fly off.
	for(var/side in GLOB.cardinals)
		stationtrauma_set_edge(level.z_value, side, level.z_value)
	place_ruin_pads(site, origin, placed)
	var/obj/effect/landmark/stationtrauma_research_site/marker = new(get_turf(site.berth))
	marker.site_id = site.id
	marker.name = site.name
	return TRUE

/** Put the ruin's corner pads in the four corners of its level, just inside the looping borders, clear of the ruin itself. */
/datum/stationtrauma_overmap_sector/space/proc/place_ruin_pads(datum/stationtrauma_overmap_site/space/site, turf/origin, datum/map_template/ruin/placed)
	var/margin = TRANSITIONEDGE + 3
	var/far_x = world.maxx - margin - ST_STANDARD_M_WIDTH + 1
	var/far_y = world.maxy - margin - ST_STANDARD_M_HEIGHT + 1
	var/list/corners = list(list(margin, margin), list(far_x, margin), list(margin, far_y), list(far_x, far_y))
	for(var/index in 1 to length(site.pads))
		var/datum/stationtrauma_overmap_site/space/pad = site.pads[index]
		var/list/corner = corners[index]
		pad.ruin_id = site.ruin_id
		pad.entrance = site.entrance
		// A ruin sprawling into a corner leaves that pad out.
		if(corner[1] <= origin.x + placed.width && corner[1] + ST_STANDARD_M_WIDTH >= origin.x \
			&& corner[2] <= origin.y + placed.height && corner[2] + ST_STANDARD_M_HEIGHT >= origin.y)
			pad.failed = TRUE
			continue
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/ruin_pad/slot = new(locate(corner[1], corner[2], origin.z))
		slot.name = "[site.name]: стоянка [index]"
		pad.berth = slot

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

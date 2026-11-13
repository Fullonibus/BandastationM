/**
 * # Dig sites
 *
 * A pass after the surface is populated, once per planet. Each site is a short run of mountain
 * wall facing open ground: the walls get a vein overlay and one find each, and two or three survey
 * stakes and a spoil heap go on the ground in front, so a site reads from across the map. Random
 * draws first, then an exhaustive scan, keeping off the camp, its corridors and ruins, and spacing
 * sites XENOARCH_SITE_SPACING apart. Adapted from Voidcrew PR #506 for our expedition generator.
 */

/// Random tries for a site's spot before the exhaustive scan.
#define DIG_SITE_RANDOM_ATTEMPTS 250
/// Tiles of plain planet a site keeps between itself and reserved ground.
#define DIG_SITE_CLEARANCE 4
/// How far from its anchor tile a site's walls may run.
#define DIG_SITE_REACH 3

/**
 * Places the planet's dig sites on `surface`. Records go to `planet`, which owns them for the round.
 * Returns how many were placed.
 */
/datum/map_generator/expedition_barren/proc/place_dig_sites(list/turfs, area/surface, datum/stationtrauma_overmap_site/space/planet/planet, datum/stationtrauma_work_budget/budget)
	if(!length(turfs) || !planet)
		return 0
	var/band = xenoarch_band_for_level(planet.modifier_level)
	var/list/fauna = list()
	for(var/biome_type in biomes)
		var/datum/biome/biome = biomes[biome_type]
		if(biome.fauna_density > 0)
			fauna |= biome.fauna_types
	planet.dig_sites = list()
	var/list/placed_at = list()
	for(var/i in 1 to XENOARCH_SITES_PER_PLANET)
		var/datum/dig_site_record/site = new(band, xenoarch_pick_site_kind(planet.type))
		site.ambush_fauna = fauna
		var/list/spot = find_dig_site_spot(turfs, surface, site, placed_at, budget)
		if(!spot)
			continue
		build_dig_site(site, spot[1], spot[2])
		planet.dig_sites += site
		placed_at += spot[1]
	if(length(placed_at) < XENOARCH_SITES_PER_PLANET)
		log_world("[planet.name] dig site shortfall: [length(placed_at)]/[XENOARCH_SITES_PER_PLANET] sites placed.")
	return length(placed_at)

/// Finds an anchor (the open tile a site is worked from) and its walls. Returns list(anchor, walls) or null.
/datum/map_generator/expedition_barren/proc/find_dig_site_spot(list/turfs, area/surface, datum/dig_site_record/site, list/placed_at, datum/stationtrauma_work_budget/budget)
	var/needed = max(site.large_left + site.small_left, 1)
	for(var/attempt in 1 to DIG_SITE_RANDOM_ATTEMPTS + length(turfs))
		budget?.yield()
		var/turf/candidate = attempt <= DIG_SITE_RANDOM_ATTEMPTS ? pick(turfs) : turfs[attempt - DIG_SITE_RANDOM_ATTEMPTS]
		var/list/walls = dig_site_walls_at(candidate, surface, needed, placed_at)
		if(walls)
			return list(candidate, walls)
	return null

/// The walls a site anchored on `anchor` would use, or null if the spot is no good.
/datum/map_generator/expedition_barren/proc/dig_site_walls_at(turf/anchor, area/surface, needed, list/placed_at)
	if(!dig_site_ground_ok(anchor, surface))
		return null
	for(var/turf/taken as anything in placed_at)
		if(get_dist(anchor, taken) < XENOARCH_SITE_SPACING)
			return null
	if(!dig_site_clear(anchor, surface))
		return null
	return collect_dig_site_walls(anchor, surface, needed)

/// Open surface ground: not water, lava or chasm, nor reserved for the camp, its corridors or a ruin.
/datum/map_generator/expedition_barren/proc/dig_site_ground_ok(turf/ground, area/surface)
	if(!isopenturf(ground) || ground.loc != surface || isgroundlessturf(ground))
		return FALSE
	if(istype(ground, /turf/open/water) || istype(ground, /turf/open/lava))
		return FALSE
	if(is_reserved(ground.x - origin_x + 1, ground.y - origin_y + 1))
		return FALSE
	return !ground.is_blocked_turf(exclude_mobs = TRUE)

/// Plain surface rock that faces open ground and is not already a site wall, an ore vein or special rock.
/datum/map_generator/expedition_barren/proc/dig_site_wall_ok(turf/closed/mineral/wall, area/surface)
	if(!istype(wall) || wall.dig_find || wall.loc != surface || wall.mineral_type)
		return FALSE
	if(istype(wall, /turf/closed/mineral/gibtonite) || istype(wall, /turf/closed/mineral/strong))
		return FALSE
	for(var/direction in GLOB.cardinals)
		if(dig_site_ground_ok(get_step(wall, direction), surface))
			return TRUE
	return FALSE

/// A connected run of usable face walls within DIG_SITE_REACH of the anchor, or null if too short.
/datum/map_generator/expedition_barren/proc/collect_dig_site_walls(turf/anchor, area/surface, needed)
	var/list/queue = list()
	for(var/direction in GLOB.cardinals)
		var/turf/closed/mineral/wall = get_step(anchor, direction)
		if(dig_site_wall_ok(wall, surface))
			queue += wall
	var/list/walls = list()
	var/list/seen = list()
	while(length(queue) && length(walls) < needed)
		var/turf/closed/mineral/wall = queue[1]
		queue.Cut(1, 2)
		if(seen[wall])
			continue
		seen[wall] = TRUE
		walls += wall
		for(var/direction in GLOB.alldirs)
			var/turf/closed/mineral/next = get_step(wall, direction)
			if(!next || seen[next] || get_dist(next, anchor) > DIG_SITE_REACH)
				continue
			if(dig_site_wall_ok(next, surface))
				queue += next
	return length(walls) >= needed ? walls : null

/// Nothing within DIG_SITE_CLEARANCE is reserved ground or outside the surface.
/datum/map_generator/expedition_barren/proc/dig_site_clear(turf/anchor, area/surface)
	for(var/turf/near as anything in RANGE_TURFS(DIG_SITE_CLEARANCE, anchor))
		if(near.loc != surface || is_reserved(near.x - origin_x + 1, near.y - origin_y + 1))
			return FALSE
	return TRUE

/**
 * Flags the walls and dresses the ground in front:
 * stakes at the ends of the face and a spoil heap a step back.
 */
/datum/map_generator/expedition_barren/proc/build_dig_site(datum/dig_site_record/site, turf/anchor, list/walls)
	var/list/kinds = list()
	for(var/i in 1 to site.large_left)
		kinds += XENOARCH_FIND_LARGE
	for(var/i in 1 to site.small_left)
		kinds += XENOARCH_FIND_SMALL
	shuffle_inplace(kinds)
	for(var/i in 1 to min(length(kinds), length(walls)))
		var/turf/closed/mineral/wall = walls[i]
		wall.make_dig_site_wall(site, kinds[i])
	return dress_dig_site(site, anchor, walls)

/// Places stakes and the spoil heap around a site. Returns the decorations placed.
/proc/dress_dig_site(datum/dig_site_record/site, turf/anchor, list/walls)
	// Ground right against the face, where the work happens, and a ring a step back for the dressing.
	var/list/front = list()
	var/list/back = list()
	for(var/turf/closed/mineral/wall as anything in walls)
		for(var/direction in GLOB.cardinals)
			var/turf/side = get_step(wall, direction)
			if(dig_site_dressing_ok(side))
				front |= side
	for(var/turf/near as anything in RANGE_TURFS(2, anchor))
		if(!(near in front) && dig_site_dressing_ok(near))
			back += near
	. = list()

	// Stakes go on the two back tiles furthest apart, so the face is bracketed by them.
	if(length(back) >= 2)
		var/turf/stake_a
		var/turf/stake_b
		var/best = -1
		for(var/turf/one as anything in back)
			for(var/turf/two as anything in back)
				var/distance = get_dist(one, two)
				if(distance > best)
					best = distance
					stake_a = one
					stake_b = two
		back -= stake_a
		back -= stake_b
		var/tape = pick("orange", "red")
		. += new /obj/structure/xenoarch_stake(stake_a, tape)
		. += new /obj/structure/xenoarch_stake(stake_b, tape)
		if(length(back) && prob(50))
			. += new /obj/structure/xenoarch_stake(pick_n_take(back), tape)
	if(length(back))
		. += new /obj/structure/xenoarch_spoil_heap(pick_n_take(back))

/// A tile the dressing can stand on: open, walkable, unclaimed ground. Plants on it are cleared.
/proc/dig_site_dressing_ok(turf/tile)
	if(!isopenturf(tile) || isgroundlessturf(tile))
		return FALSE
	if(istype(tile, /turf/open/water) || istype(tile, /turf/open/lava))
		return FALSE
	if(locate(/obj/structure/xenoarch_boulder) in tile)
		return FALSE
	if(locate(/obj/structure/xenoarch_stake) in tile)
		return FALSE
	if(locate(/obj/structure/xenoarch_spoil_heap) in tile)
		return FALSE
	for(var/obj/structure/flora/plant in tile)
		qdel(plant)
	return !tile.is_blocked_turf(exclude_mobs = TRUE)

/**
 * # Survey stake
 *
 * A wooden stake with flagging tape, left by whoever marked the site out. Pull it up by hand.
 */
/obj/structure/xenoarch_stake
	name = "разметочный колышек"
	desc = "Деревянный колышек, вбитый в землю, с сигнальной лентой у верхушки."
	icon = 'modular_bandastation/xenoarchaeology/icons/dig_site.dmi'
	icon_state = "stake_orange"
	anchored = TRUE
	density = FALSE
	layer = BELOW_MOB_LAYER
	max_integrity = 30
	resistance_flags = FLAMMABLE

/obj/structure/xenoarch_stake/Initialize(mapload, tape_color)
	. = ..()
	if(tape_color)
		icon_state = "stake_[tape_color]"
	pixel_x = base_pixel_x + rand(-5, 5)
	pixel_y = base_pixel_y + rand(-3, 4)

/obj/structure/xenoarch_stake/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	user.visible_message(
		span_notice("[user] расшатывает [src] в земле."),
		span_notice("Вы начинаете расшатывать [src]."),
	)
	if(!do_after(user, 2 SECONDS, target = src))
		return TRUE
	playsound(src, 'sound/effects/shovel_dig.ogg', 30, TRUE)
	user.visible_message(span_notice("[user] выдёргивает [src] и отбрасывает в сторону."), span_notice("Вы выдёргиваете [src]."))
	qdel(src)
	return TRUE

/**
 * # Spoil heap
 *
 * Earth and broken rock shovelled out of the dig. Scenery; a shovel clears it.
 */
/obj/structure/xenoarch_spoil_heap
	name = "отвал породы"
	desc = "Куча земли и битого камня, выброшенная из раскопа."
	icon = 'modular_bandastation/xenoarchaeology/icons/dig_site.dmi'
	icon_state = "spoil1"
	anchored = TRUE
	density = FALSE
	layer = BELOW_OBJ_LAYER
	max_integrity = 60

/obj/structure/xenoarch_spoil_heap/Initialize(mapload)
	. = ..()
	icon_state = "spoil[rand(1, 2)]"
	pixel_x = base_pixel_x + rand(-4, 4)
	pixel_y = base_pixel_y + rand(-2, 3)

/obj/structure/xenoarch_spoil_heap/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour != TOOL_SHOVEL)
		return NONE
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_notice("[user] разравнивает [src]."), span_notice("Вы разравниваете [src]."))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

#undef DIG_SITE_RANDOM_ATTEMPTS
#undef DIG_SITE_CLEARANCE
#undef DIG_SITE_REACH

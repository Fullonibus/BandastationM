// Hives, lairs and fauna packs; grouped packs follow CrystallEdge's demiplane mob modifiers, no donor code is copied.
// https://github.com/crystallpunk-14/crystall-punk-14/blob/5b6108377e40235c768be3ac6ffadb37a085f441/Resources/Prototypes/_CP14/Procedural/Demiplane/Modifiers/Danger/mobs.yml

/// Least distance in turfs between the anchors of two fauna packs.
#define EXPEDITION_PACK_SPACING 24
/// Percent chance per turf that robotic guardians anchor a pack on a lifeless biome.
#define EXPEDITION_GUARDIAN_DENSITY 0.1
/// Footprint of a grown hive in turfs: width, then height.
#define EXPEDITION_GROWN_HIVE_SIZE list(25, 21)

/datum/map_generator/expedition_barren
	/// Smallest and largest ambient group; profiles with heavy mining fauna use solitary encounters.
	var/list/fauna_pack_size = list(1, 2)
	/// Danger level the modifiers were rolled at; a stronger level breeds a larger hive garrison.
	var/danger_level = 0
	/// Hive layouts this profile offers the xenomorph hive modifier: a key of [/datum/map_generator/expedition_barren/proc/hive_template] or "grown".
	var/list/hive_variants = list("native", "grown")
	/// Hive layout rolled by the xenomorph hive modifier from `hive_variants`; null without a hive.
	var/hive_variant
	/// Relative southwest corner reserved for the hive; null when no spot fitted.
	var/list/hive_spot
	/// Weighted megafauna the megafauna modifier picks from on this profile.
	var/list/megafauna_types = list()
	/// Whether the megafauna modifier set a boss on this planet.
	var/megafauna = FALSE
	/// Weighted robots the guardian modifier sends in packs among the wildlife; empty without guardians.
	var/list/guardian_types = list()

/** The native lavaland xenomorph nest, placed by the hive modifier rather than picked as an ordinary ruin. */
/datum/map_template/ruin/expedition/xeno_nest
	name = "Expedition Xenomorph Nest"
	id = "expedition_xeno_nest"
	description = "Native lavaland xenomorph nest with its queen, placed by the hive modifier."
	prefix = "_maps/RandomRuins/LavaRuins/"
	suffix = "lavaland_surface_xeno_nest.dmm"
	unpickable = TRUE
	allow_duplicates = TRUE

/** Celadon's overrun jungle outpost, the hive of jungle planets. */
/datum/map_template/ruin/expedition/celadon_jungle_nest
	name = "Expedition Celadon Jungle Nest"
	id = "celadon_jungle_nest"
	description = "Jungle outpost overrun by xenomorphs, placed by the hive modifier."
	suffix = "celadon_jungle_nest.dmm"
	unpickable = TRUE
	allow_duplicates = TRUE

/** Mapped template of the rolled hive layout, shared by every planet that rolls it; null for the grown chamber. */
/datum/map_generator/expedition_barren/proc/hive_template()
	var/static/list/templates
	templates ||= list("native" = new /datum/map_template/ruin/expedition/xeno_nest, "jungle" = new /datum/map_template/ruin/expedition/celadon_jungle_nest)
	return templates[hive_variant]

/** Reserve the hive footprint before ordinary ruins, so the largest structure always finds room. */
/datum/map_generator/expedition_barren/proc/reserve_hive()
	if(!hive_variant)
		return
	var/list/size = EXPEDITION_GROWN_HIVE_SIZE
	var/datum/map_template/template = hive_template()
	if(template)
		size = list(template.width, template.height)
	hive_spot = reserve_ruin(size[1], size[2])

/**
 * Build the reserved hive on the finished surface: a mapped nest with an egg clutch, or a grown resin chamber.
 *
 * Arguments:
 * * bottom - Southwest turf of the surface
 * * surface - Planet surface area the hive ground joins
 */
/datum/map_generator/expedition_barren/proc/build_hive(turf/bottom, area/surface)
	if(!hive_spot)
		return FALSE
	var/turf/origin = locate(bottom.x + hive_spot[1] - 1, bottom.y + hive_spot[2] - 1, bottom.z)
	var/datum/map_template/template = hive_template()
	if(template)
		if(!template.load(origin))
			return FALSE
		var/list/covered = template.get_affected_turfs(origin)
		// Lavaland ground carries lavaland air; the nest stands on this planet's own ground instead.
		for(var/turf/tile as anything in covered)
			if(istype(tile, /turf/open/misc/asteroid/basalt/lava_land_surface) || istype(tile, /turf/open/lava/smooth/lava_land_surface))
				tile.ChangeTurf(floor_type, floor_type, CHANGETURF_IGNORE_AIR)
		adapt_template_turfs(covered, surface)
		for(var/turf/tile as anything in covered)
			for(var/mob/living/basic/member in tile)
				member.add_expedition_help()
			for(var/obj/structure/spawner/den in tile)
				den.AddElement(/datum/element/stationtrauma_help_spawner)
		place_clutch(locate(origin.x + round(template.width / 2), origin.y + round(template.height / 2), origin.z))
		return TRUE
	grow_hive(origin)
	return TRUE

/**
 * Grow an irregular resin chamber: a ring of resin walls with an opening, weeds inside, cocooned victims, eggs and a garrison.
 *
 * Each hive is shaped and stocked anew; distant, more dangerous planets breed more xenomorphs and likelier a queen.
 */
/datum/map_generator/expedition_barren/proc/grow_hive(turf/origin)
	var/list/size = EXPEDITION_GROWN_HIVE_SIZE
	var/half_width = (size[1] - 1) / 2
	var/half_height = (size[2] - 1) / 2
	var/centre_x = origin.x + half_width
	var/centre_y = origin.y + half_height
	// The opening faces the surface centre, where the access cross runs.
	var/opening = get_dir(locate(centre_x, centre_y, origin.z), locate(origin_x + round(width / 2), origin_y + round(width / 2), origin.z))
	var/list/floor = list()
	for(var/turf/tile as anything in block(origin, locate(origin.x + size[1] - 1, origin.y + size[2] - 1, origin.z)))
		var/distance = ((tile.x - centre_x) / half_width) ** 2 + ((tile.y - centre_y) / half_height) ** 2 + rand(-12, 12) / 100
		if(distance > 1)
			continue
		if(!isopenturf(tile) || islava(tile))
			tile = tile.ChangeTurf(floor_type, floor_type, CHANGETURF_IGNORE_AIR)
		if(distance > 0.72)
			var/towards = get_dir(locate(centre_x, centre_y, origin.z), tile)
			if(towards == opening || (towards & opening && prob(50)))
				new /obj/structure/alien/weeds(tile)
				continue
			if(prob(20))
				new /obj/structure/alien/resin/membrane(tile)
			else
				new /obj/structure/alien/resin/wall(tile)
			continue
		new /obj/structure/alien/weeds(tile)
		floor += tile
	if(!length(floor))
		return
	place_clutch(locate(round(centre_x), round(centre_y), origin.z))
	for(var/index in 1 to 3)
		new /obj/structure/alien/weeds/node(pick(floor))
	for(var/index in 1 to rand(4, 7))
		if(!length(floor))
			return
		var/turf/cocoon = pick_n_take(floor)
		new /obj/structure/bed/nest(cocoon)
		new /obj/effect/mob_spawn/corpse/human/assistant(cocoon)
		new /obj/effect/decal/cleanable/blood/gibs/old(cocoon)
	for(var/index in 1 to rand(3, 5))
		if(!length(floor))
			return
		new /obj/structure/alien/egg/grown(pick_n_take(floor))
	var/static/list/garrison = list(/mob/living/basic/alien/drone = 3, /mob/living/basic/alien = 3, /mob/living/basic/alien/sentinel = 2)
	for(var/index in 1 to clamp(3 + round(danger_level), 3, 7))
		if(!length(floor))
			return
		var/xeno_type = pick_weight(garrison)
		var/mob/living/member = new xeno_type(pick_n_take(floor))
		member.add_expedition_help()
	if(length(floor) && prob(clamp(20 * danger_level, 10, 60)))
		var/mob/living/queen = new /mob/living/basic/alien/queen/large(pick_n_take(floor))
		queen.add_expedition_help()

/** The egg clutch keeps a hive breeding until it is destroyed. */
/datum/map_generator/expedition_barren/proc/place_clutch(turf/centre)
	var/turf/spot = centre
	if(!isopenturf(spot) || spot.is_blocked_turf())
		for(var/turf/open/tile in RANGE_TURFS(3, centre))
			if(!tile.is_blocked_turf())
				spot = tile
				break
	if(isopenturf(spot))
		var/obj/structure/spawner/hive = new /obj/structure/spawner/stationtrauma_xeno_hive(spot)
		hive.AddElement(/datum/element/stationtrauma_help_spawner)

/** Set the rolled boss on open ground at least 40 turfs from the camp, with room around it; returns the boss or null. */
/datum/map_generator/expedition_barren/proc/place_megafauna(turf/bottom)
	if(!megafauna || !length(megafauna_types))
		return null
	var/camp_centre_x = camp_x + round(camp_width / 2)
	var/camp_centre_y = camp_y + round(camp_height / 2)
	for(var/attempt in 1 to 60)
		var/x = rand(8, width - 8)
		var/y = rand(8, width - 8)
		if(is_reserved(x, y) || sqrt((x - camp_centre_x) ** 2 + (y - camp_centre_y) ** 2) < 40)
			continue
		var/turf/spot = locate(bottom.x + x - 1, bottom.y + y - 1, bottom.z)
		if(length(standing_ground(spot, 3)) < 30)
			continue
		var/boss_type = pick_weight(megafauna_types)
		return new boss_type(spot)
	return null

/** Free open ground within `radius` of `centre` where a creature or remains can stand. */
/datum/map_generator/expedition_barren/proc/standing_ground(turf/centre, radius)
	. = list()
	for(var/turf/open/tile in RANGE_TURFS(radius, centre))
		if(!isgroundlessturf(tile) && !islava(tile) && !tile.is_blocked_turf())
			. += tile

/** A den holds its kind from the start: a garrison around the spawner and the remains of their prey. */
/datum/map_generator/expedition_barren/proc/raise_lair(obj/structure/spawner/den)
	den.AddElement(/datum/element/stationtrauma_help_spawner)
	var/list/ground = standing_ground(get_turf(den), 3)
	var/list/kinds = den.mob_types
	for(var/index in 1 to rand(1, min(3, den.max_mobs)))
		if(!length(ground) || !length(kinds))
			break
		var/kind = pick(kinds)
		var/mob/living/member = new kind(pick_n_take(ground))
		member.add_expedition_help()
	var/static/list/remains = list(/obj/effect/decal/remains/human, /obj/effect/decal/cleanable/blood/gibs/old, /obj/effect/decal/cleanable/blood/old)
	for(var/index in 1 to 3)
		if(!length(ground))
			break
		var/remain_type = pick(remains)
		new remain_type(pick_n_take(ground))

/**
 * Settle the wild in small groups of one kind, with solitary encounters on profiles carrying heavy mining fauna.
 *
 * Each biome's fauna density is the chance that one of its turfs anchors a pack; the pack's kind comes from that biome.
 * On a planet with robotic guardians some packs are robots instead, and lifeless biomes are patrolled by robots alone.
 *
 * Arguments:
 * * wild_by_biome - Biome -> its turfs outside the camp clearance and features
 */
/datum/map_generator/expedition_barren/proc/place_packs(list/wild_by_biome)
	var/list/anchors = list()
	for(var/datum/biome/biome as anything in wild_by_biome)
		var/list/kinds = biome.fauna_density > 0 ? biome.fauna_types : list()
		var/density = length(kinds) ? biome.fauna_density : (length(guardian_types) ? EXPEDITION_GUARDIAN_DENSITY : 0)
		if(density <= 0)
			continue
		var/weighted = length(kinds) && isnum(kinds[kinds[1]])
		for(var/turf/tile as anything in shuffle(wild_by_biome[biome]))
			budget?.yield()
			if(!prob(density) || !isopenturf(tile) || tile.is_blocked_turf())
				continue
			var/near = FALSE
			for(var/turf/anchor as anything in anchors)
				if(get_dist(anchor, tile) < EXPEDITION_PACK_SPACING)
					near = TRUE
					break
			if(near)
				continue
			anchors += tile
			var/kind
			if(length(guardian_types) && (!length(kinds) || prob(40)))
				kind = pick_weight(guardian_types)
			else
				kind = weighted ? pick_weight(kinds) : pick(kinds)
			var/list/ground = standing_ground(tile, 2)
			// Summoners and spellcasting ice fauna are encounters, never whole packs of ranged attackers.
			var/solitary = ispath(kind, /mob/living/basic/mining/legion) || ispath(kind, /mob/living/basic/mining/ice_demon) || ispath(kind, /mob/living/basic/mining/ice_whelp)
			var/pack_size
			if(istype(src, /datum/map_generator/expedition_barren/dead) && ispath(kind, /mob/living/basic/zombie/rotten/expedition))
				var/datum/map_generator/expedition_barren/dead/dead_profile = src
				pack_size = dead_profile.next_zombie_pack_size(tile, length(ground))
			else
				pack_size = solitary ? 1 : rand(fauna_pack_size[1], fauna_pack_size[2])
			if(!pack_size)
				continue
			for(var/index in 1 to pack_size)
				if(!length(ground))
					break
				var/mob/living/member = new kind(pick_n_take(ground))
				member.add_expedition_help()

#undef EXPEDITION_PACK_SPACING
#undef EXPEDITION_GUARDIAN_DENSITY
#undef EXPEDITION_GROWN_HIVE_SIZE

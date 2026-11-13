// Dead world after an old war; biomes follow Celadon's waste planet generator on local TG parts, no donor code is copied.
// https://github.com/CeladonSS13/Shiptest/blob/4214796c7289b74779f10dd25df2d695c264aa8f/code/datums/mapgen/planetary/WasteGenerator.dm
/** Scorched world of an old war: unbreathable air, radioactive craters and the ruins of its towns. */
/datum/stationtrauma_overmap_site/space/planet/dead
	name = "Мёртвая экзопланета"
	generator_type = /datum/map_generator/expedition_barren/dead
	parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet/dead
	biome = "Выжженные равнины, ржавые свалки и радиоактивные воронки"
	atmosphere = "Азот и углекислый газ, 74 кПа; кислорода нет"
	surface_temperature = 278
	// Ordinary wrecks and outposts of lifeless worlds stand here beside the waste ruins.
	ruin_biome = "barren"

/** Bombarded terrain around one large town or complex, with scrap fields and scattered rotting dead. */
/datum/map_generator/expedition_barren/dead
	hole_type = /turf/open/openspace/expedition_dead
	wildlife = TRUE
	sky_color = "#c8b8a0"
	floor_type = /turf/open/misc/asteroid/expedition_dead
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_dead
	rock_color = "#6e665c"
	mountain_height = 0.75
	mineral_chance = 6
	craters = TRUE
	large_ruin_chance = 100
	large_ruin_biome = "dead"
	/// One compass district shared by ambient zombie packs and plague pits on both levels.
	var/zombie_region = NONE
	/// Ambient packs already placed; the cave pass does not get a second population budget.
	var/zombie_pack_count = 0
	/// Lazily rolled planet-wide pack cap, scaled by the existing fauna modifier.
	var/zombie_pack_limit = 0
	biome_table = list(
		list(/datum/biome/expedition/dead, /datum/biome/expedition/dead, /datum/biome/expedition/dead/scrap, /datum/biome/expedition/dead/scrap, /datum/biome/expedition/dead/rust),
		list(/datum/biome/expedition/dead, /datum/biome/expedition/dead/basalt, /datum/biome/expedition/dead, /datum/biome/expedition/dead/scrap, /datum/biome/expedition/dead/rust),
		list(/datum/biome/expedition/dead/scrap, /datum/biome/expedition/dead, /datum/biome/expedition/dead, /datum/biome/expedition/dead, /datum/biome/expedition/dead),
		list(/datum/biome/expedition/dead, /datum/biome/expedition/dead/basalt, /datum/biome/expedition/dead/rust, /datum/biome/expedition/dead, /datum/biome/expedition/dead/rust),
		list(/datum/biome/expedition/dead, /datum/biome/expedition/dead/basalt, /datum/biome/expedition/dead/basalt, /datum/biome/expedition/dead/scrap, /datum/biome/expedition/dead),
		list(/datum/biome/expedition/dead/rust, /datum/biome/expedition/dead/rust, /datum/biome/expedition/dead/scrap, /datum/biome/expedition/dead/rust, /datum/biome/expedition/dead/rust),
	)
	cave_biome_table = /datum/biome/expedition/dead/cave

/** Compass district in the outer thirds of the generated square; the middle district has no zombies. */
/datum/map_generator/expedition_barren/dead/proc/zombie_region_at(turf/tile)
	var/x = tile.x - origin_x + 1
	var/y = tile.y - origin_y + 1
	if(x < 1 || y < 1 || x > width || y > width)
		return NONE
	var/region = NONE
	if(x <= width / 3)
		region |= WEST
	else if(x > width * 2 / 3)
		region |= EAST
	if(y <= width / 3)
		region |= SOUTH
	else if(y > width * 2 / 3)
		region |= NORTH
	return region

/** The first viable zombie encounter chooses the district; later encounters keep that same geography. */
/datum/map_generator/expedition_barren/dead/proc/in_zombie_region(turf/tile)
	var/region = zombie_region_at(tile)
	if(!region)
		return FALSE
	if(!zombie_region)
		zombie_region = region
	return region == zombie_region

/** Fewer, larger ambient groups, with one finite pack budget shared by surface and caves. */
/datum/map_generator/expedition_barren/dead/proc/next_zombie_pack_size(turf/tile, available_ground)
	if(available_ground < 6 || !in_zombie_region(tile))
		return 0
	if(!zombie_pack_limit)
		zombie_pack_limit = max(1, round(rand(3, 4) * fauna_multiplier))
	if(zombie_pack_count >= zombie_pack_limit)
		return 0
	zombie_pack_count++
	return rand(6, min(10, available_ground))

/** Ashen ground carrying the dead profile atmosphere and preserving it beneath excavation. */
/turf/open/misc/asteroid/expedition_dead
	name = "выжженный грунт"
	desc = "Спёкшаяся земля, присыпанная пеплом и мелкими обломками."
	color = "#8a8074"
	initial_gas_mix = GAS_N2 + "=66;" + GAS_CO2 + "=14;TEMP=278"
	temperature = 278
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/expedition_dead
	turf_type = /turf/open/misc/asteroid/expedition_dead
	worm_chance = 0

/** Glassed rock in the dead profile atmosphere. */
/turf/open/misc/asteroid/basalt/expedition_dead
	name = "оплавленная порода"
	desc = "Порода, оплавленная давним жаром и застывшая тёмной коркой."
	color = "#5e5850"
	initial_gas_mix = /turf/open/misc/asteroid/expedition_dead::initial_gas_mix
	temperature = 278
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_dead
	turf_type = /turf/open/misc/asteroid/basalt/expedition_dead
	worm_chance = 0

/** Rusted remains of old plating in the dead profile atmosphere; torn up, it leaves the ashen ground. */
/turf/open/floor/plating/rust/expedition_dead
	initial_gas_mix = /turf/open/misc/asteroid/expedition_dead::initial_gas_mix
	temperature = 278
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/expedition_dead

/** Drop into the cave level that keeps this profile's surface atmosphere. */
/turf/open/openspace/expedition_dead
	initial_gas_mix = /turf/open/misc/asteroid/expedition_dead::initial_gas_mix
	planetary_atmos = TRUE

/** Celadon waste plain: ashen ground, scattered debris and the dead of the war. */
/datum/biome/expedition/dead
	open_turf_type = /turf/open/misc/asteroid/expedition_dead
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
		/obj/structure/flora/tree/dead/style_random = 1,
		/obj/effect/decal/cleanable/dirt = 3,
		/obj/effect/decal/remains/human = 2,
		/obj/item/shard = 1,
	)
	fauna_density = 0.5
	fauna_types = list(/mob/living/basic/zombie/rotten/expedition = 1)

/** Celadon basalt field of glassed rock. */
/datum/biome/expedition/dead/basalt
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_dead
	flora_density = 2

/** Celadon scrap field: girders, wreckage and the occasional sealed crate. */
/datum/biome/expedition/dead/scrap
	flora_density = 12
	flora_types = list(
		/obj/structure/girder = 3,
		/obj/structure/girder/displaced = 3,
		/obj/item/stack/cable_coil/cut = 3,
		/obj/effect/decal/cleanable/blood/gibs/robot_debris = 3,
		/obj/item/shard = 2,
		/obj/structure/flora/rock/pile/style_random = 2,
		/obj/structure/mecha_wreckage/ripley = 1,
		/obj/structure/closet/crate/secure/loot = 1,
	)
	fauna_density = 0.25

/** Celadon rust field of old plating. */
/datum/biome/expedition/dead/rust
	open_turf_type = /turf/open/floor/plating/rust/expedition_dead
	flora_density = 6
	flora_types = list(
		/obj/structure/girder = 2,
		/obj/item/stack/cable_coil/cut = 2,
		/obj/effect/decal/cleanable/dirt = 3,
		/obj/item/shard = 1,
	)
	fauna_density = 0.25

/** Dead world caves: bare ashen pockets with a few remains. */
/datum/biome/expedition/dead/cave
	flora_density = 2
	flora_types = list(
		/obj/structure/flora/rock/pile/style_random = 3,
		/obj/effect/decal/remains/human = 1,
	)
	fauna_density = 0.25

/** The dead world's plague carriers retain the weak carcass combat stats and infect through ordinary bites. */
/mob/living/basic/zombie/rotten/expedition
	infection_chance = 25

/** Finite research source: оплавленный обломок, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_dead
	name = "оплавленный обломок"
	desc = "Спёкшийся кусок металла и породы. Его можно обследовать и отобрать пробы."
	icon_state = "uranium"
	field_notes = "Металл сплавлен с породой в стекловидную массу. Обломок слабо излучает; по краям видны следы сильного жара."
	laboratory_notes = "В сплаве распознаются конструкционные металлы и продукты деления. Обломок образовался при взрыве большой мощности над поверхностью."

// Volcanic profile with biomes adapted from Celadon's lava planet generator (see planet_generator.dm); local TG turfs, flora and fauna.
// Donor grass and purple rock become ash and shale; moss, hell bushes, landmines, elite tumors, anomalies, ore veins, burrows and crystal fauna are omitted or replaced.
/// Fixed volcanic atmosphere; TG lavaland air is randomized per round and would contradict the survey.
#define EXPEDITION_VOLCANIC_ATMOS (GAS_CO2 + "=60;" + GAS_N2 + "=30;TEMP=380")

/** Hot oxygen-free volcanic surface profile with basalt plains, ash scrub and lava lakes. */
/datum/stationtrauma_overmap_site/space/planet/lava
	name = "Вулканическая экзопланета"
	generator_type = /datum/map_generator/expedition_barren/lava
	parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet/lava
	biome = "Базальтовые равнины, пепельные заросли и лавовые озёра"
	atmosphere = "Углекислый газ и азот, 114 кПа; кислорода нет"
	surface_temperature = 380
	ruin_biome = "lava"

/** Seeded volcanic terrain with volcanic ore walls. */
/datum/map_generator/expedition_barren/lava
	fauna_pack_size = list(1, 1)
	hole_type = /turf/open/openspace/expedition_lava
	wildlife = TRUE
	storm_trait = ZTRAIT_ASHSTORM
	endless_storm_type = /datum/weather/particle/ash_storm/expedition_endless
	sky_color = "#ff9060"
	floor_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_volcanic
	// Native lavaland density: basalt halls and ash thickets inside one tunnel maze instead of separate mountains.
	surface_open_percent = 51
	// The native lavaland megafauna weights.
	megafauna_types = list(
		/mob/living/simple_animal/hostile/megafauna/bubblegum = 6,
		/mob/living/simple_animal/hostile/megafauna/colossus = 2,
		/mob/living/simple_animal/hostile/megafauna/dragon = 4,
	)
	biome_table = list(
		list(/datum/biome/expedition/volcanic/forest, /datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic/forest/rocky, /datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic/plains/dense),
		list(/datum/biome/expedition/volcanic/plains, /datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic/plains/dense, /datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic),
		list(/datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic/lush, /datum/biome/expedition/volcanic/forest, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic/forest, /datum/biome/expedition/volcanic/plains/dense, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic/plains/dense/mixed, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic/forest/rocky, /datum/biome/expedition/volcanic/outback, /datum/biome/expedition/volcanic, /datum/biome/expedition/volcanic/nearlava, /datum/biome/expedition/volcanic_lava),
	)
	cave_biome_table = list(
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_cave/mossy),
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_lava, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave, /datum/biome/expedition/volcanic_cave/mossy, /datum/biome/expedition/volcanic_cave/obsidian, /datum/biome/expedition/volcanic_lava),
		list(/datum/biome/expedition/volcanic_cave/rocky, /datum/biome/expedition/volcanic_cave/mossy, /datum/biome/expedition/volcanic_cave/obsidian, /datum/biome/expedition/volcanic_lava, /datum/biome/expedition/volcanic_lava),
	)
	rock_type = /turf/closed/mineral/volcanic
	mineral_chance = 11
	// Volcanic worlds stand out by a varied, valuable mix rather than sheer ore volume.
	ore_types = list(
		/obj/item/stack/ore/diamond = 10,
		/obj/item/stack/ore/gold = 25,
		/obj/item/stack/ore/silver = 25,
		/obj/item/stack/ore/uranium = 25,
		/obj/item/stack/ore/titanium = 35,
		/obj/item/stack/ore/plasma = 30,
		/obj/item/stack/ore/iron = 100,
	)

/** Basalt ground carrying the volcanic profile atmosphere. */
/turf/open/misc/asteroid/basalt/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_volcanic
	turf_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	worm_chance = 0

/** Layered shale near lava, in the volcanic profile atmosphere. */
/turf/open/misc/asteroid/basalt/smooth/shale/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/smooth/shale/expedition_volcanic
	turf_type = /turf/open/misc/asteroid/basalt/smooth/shale/expedition_volcanic
	worm_chance = 0

/** Iron-red volcanic rock in the volcanic profile atmosphere. */
/turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	turf_type = /turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	worm_chance = 0

/** Volcanic ash drifts in the volcanic profile atmosphere; as walkable as the green grass it replaces. */
/turf/open/misc/ashplanet/ash/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_volcanic
	slowdown = 0

/** Lava lakes in the volcanic profile atmosphere. */
/turf/open/lava/smooth/expedition_volcanic
	initial_gas_mix = EXPEDITION_VOLCANIC_ATMOS
	planetary_atmos = TRUE
	baseturfs = /turf/open/lava/smooth/expedition_volcanic

#undef EXPEDITION_VOLCANIC_ATMOS

/** Celadon basalt plain hunted by volcanic predators. */
/datum/biome/expedition/volcanic
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/ash/fireblossom = 1,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/rock/pile/style_random = 3,
	)
	feature_density = 0.3
	feature_types = list(
		/obj/structure/flora/rock/volcano = 34,
		/obj/structure/geyser/random = 6,
	)
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/watcher = 40,
		/mob/living/basic/mining/legion = 30,
		/mob/living/basic/mining/goldgrub = 10,
		/mob/living/basic/mining/brimdemon = 20,
	)

/** Celadon dead forest on ash. */
/datum/biome/expedition/volcanic/forest
	open_turf_type = /turf/open/misc/ashplanet/ash/expedition_volcanic
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/tree/dead/style_random = 4,
		/obj/structure/flora/ash/stem_shroom = 1,
		/obj/structure/flora/ash/tall_shroom = 1,
		/obj/structure/flora/rock/pile/style_random = 2,
	)

/** Celadon rocky dead forest. */
/datum/biome/expedition/volcanic/forest/rocky
	flora_density = 25
	flora_types = list(
		/obj/structure/flora/rock/pile/style_random = 5,
		/obj/structure/flora/rock/volcano = 4,
		/obj/structure/flora/tree/dead/style_random = 10,
		/obj/structure/flora/ash/cacti = 1,
	)

/** Celadon ash plains. */
/datum/biome/expedition/volcanic/plains
	open_turf_type = /turf/open/misc/ashplanet/ash/expedition_volcanic
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/ash/fireblossom = 2,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/seraka = 1,
		/obj/structure/flora/rock/pile/style_random = 3,
	)

/** Celadon dense ash plains with scattered dead trees. */
/datum/biome/expedition/volcanic/plains/dense
	flora_density = 10
	feature_density = 5
	feature_types = list(/obj/structure/flora/tree/dead/style_random = 1)

/** Celadon mixed ash plains. */
/datum/biome/expedition/volcanic/plains/dense/mixed
	flora_density = 7

/** Celadon ash outback scrub. */
/datum/biome/expedition/volcanic/outback
	open_turf_type = /turf/open/misc/ashplanet/ash/expedition_volcanic
	flora_density = 15
	flora_types = list(
		/obj/structure/flora/ash/cacti = 4,
		/obj/structure/flora/ash/stem_shroom = 1,
		/obj/structure/flora/tree/dead/style_random = 3,
		/obj/structure/flora/rock/volcano = 2,
		/obj/structure/flora/rock/pile/style_random = 3,
	)

/** Celadon flowering ash meadow. */
/datum/biome/expedition/volcanic/lush
	open_turf_type = /turf/open/misc/ashplanet/ash/expedition_volcanic
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/ash/fireblossom = 3,
		/obj/structure/flora/tree/dead/style_random = 1,
		/obj/structure/flora/ash/leaf_shroom = 3,
		/obj/structure/flora/ash/cap_shroom = 3,
		/obj/structure/flora/ash/seraka = 2,
		/obj/structure/flora/ash/glowgrowth = 2,
	)

/** Celadon glassy shore of a lava lake. */
/datum/biome/expedition/volcanic/nearlava
	open_turf_type = /turf/open/misc/asteroid/basalt/smooth/shale/expedition_volcanic
	flora_density = 2
	flora_types = list(
		/obj/structure/flora/rock/volcano = 1,
		/obj/structure/flora/rock/pile/style_random = 1,
	)

/** Celadon lava lake; like the donor, nothing grows or spawns on lava. */
/datum/biome/expedition/volcanic_lava
	open_turf_type = /turf/open/lava/smooth/expedition_volcanic

/** Celadon basalt cave with mushrooms and cave predators. */
/datum/biome/expedition/volcanic_cave
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_volcanic
	flora_density = 1
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/ash/cacti = 1,
		/obj/structure/flora/ash/tall_shroom = 2,
	)
	fauna_density = 4
	fauna_types = list(
		/mob/living/basic/mining/goliath = 50,
		/mob/living/basic/mining/watcher = 40,
		/mob/living/basic/mining/legion = 30,
		/mob/living/basic/mining/goldgrub = 10,
	)

/** Celadon obsidian cave floor. */
/datum/biome/expedition/volcanic_cave/obsidian
	open_turf_type = /turf/open/misc/asteroid/basalt/smooth/shale/expedition_volcanic

/** Celadon rocky cave of iron-red stone. */
/datum/biome/expedition/volcanic_cave/rocky
	open_turf_type = /turf/open/misc/asteroid/basalt/smooth/siderite/expedition_volcanic
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/pile/style_random = 6,
		/obj/structure/flora/rock/volcano = 6,
	)

/** Celadon overgrown cave; mushroom thickets on ash replace the donor moss. */
/datum/biome/expedition/volcanic_cave/mossy
	open_turf_type = /turf/open/misc/ashplanet/ash/expedition_volcanic
	flora_density = 30
	flora_types = list(
		/obj/structure/flora/ash/glowgrowth = 1,
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/ash/cacti = 1,
		/obj/structure/flora/ash/tall_shroom = 2,
	)

/** Finite research source: застывший лавовый натёк, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_volcanic
	name = "застывший лавовый натёк"
	desc = "Волнистая корка остывшей лавы с газовыми пузырями и стекловатыми прожилками. Можно обследовать и отобрать пробу."
	icon_state = "plasma"
	field_notes = "Поверхность натёка покрыта застывшими волнами. Пузыри газа вытянуты по направлению течения; в трещинах заметен тонкий налёт серы."
	laboratory_notes = "Порода быстро остыла: в ней много вулканического стекла и мелких кристаллов. Газовые включения и сернистый налёт указывают на недавнюю вулканическую активность под поверхностью."

/** Drop into the cave level that keeps this profile's surface atmosphere. */
/turf/open/openspace/expedition_lava
	initial_gas_mix = /turf/open/misc/asteroid/basalt/expedition_volcanic::initial_gas_mix
	planetary_atmos = TRUE

/** Ash storm that never winds down, raised by the endless storm planet modifier. */
/datum/weather/particle/ash_storm/expedition_endless
	telegraph_duration = 0 SECONDS
	// Never scheduled at random, so other levels with the same storm trait keep their periodic storms.
	probability = 0
	weather_flags = parent_type::weather_flags | WEATHER_ENDLESS

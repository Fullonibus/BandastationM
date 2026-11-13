// Sierra's hot, mineral-rich desert profile; local TG terrain and atmosphere are used.
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/desert.dm
// Biomes adapted from Celadon's sand planet generator (see planet_generator.dm); donor ice caps, acid and lava pools,
// sulfur pools, ore veins, hermits, burrows and maintenance loot are omitted or replaced with local desert ground.
/** Hot oxygen-free surface profile with saline mineral research sources. */
/datum/stationtrauma_overmap_site/space/planet/arid
	name = "Пустынная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/arid
	parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet/arid
	biome = "Песчаные равнины, сухие русла и каменистые пустоши"
	atmosphere = "Азот и углекислый газ, 114 кПа; кислорода нет"
	surface_temperature = 330

/** Seeded desert terrain using a local oxygen-free planetary atmosphere. */
/datum/map_generator/expedition_barren/arid
	fauna_pack_size = list(1, 1)
	hole_type = /turf/open/openspace/expedition_arid
	wildlife = TRUE
	storm_trait = ZTRAIT_SANDSTORM
	endless_storm_type = /datum/weather/sand_storm/expedition_endless
	sky_color = "#ffd9a0"
	floor_type = /turf/open/misc/asteroid/expedition_arid
	source_type = /obj/structure/stationtrauma_research_source/mineral/expedition_arid
	rock_color = "#c6aa73"
	biome_zoom = 70
	mountain_height = 0.8
	mineral_chance = 8
	// Celadon's Whitesands sulfur pools return to the sulfur plains, with a rare dried oasis.
	feature_maps = list(
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_1.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_2.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_3.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_4.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_5.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_6.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_7.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_8.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_9.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_10.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_11.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_14.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_15.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_16.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_12.dmm" = 2,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_13.dmm" = 2,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_17.dmm" = 2,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_18.dmm" = 2,
		"modular_bandastation/expedition_planets/maps/features/celadon_sulfur_pool_19.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_oasis_1.dmm" = 1,
	)
	biome_table = list(
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand, /datum/biome/expedition/sand/grass/dead, /datum/biome/expedition/sand/flats, /datum/biome/expedition/sand/flats),
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand/riverbed, /datum/biome/expedition/sand/wasteland, /datum/biome/expedition/sand/wasteland, /datum/biome/expedition/sand/flats),
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand, /datum/biome/expedition/sand/riverbed, /datum/biome/expedition/sand, /datum/biome/expedition/sand),
		list(/datum/biome/expedition/sand, /datum/biome/expedition/sand/grass/dead, /datum/biome/expedition/sand/grass, /datum/biome/expedition/sand/grass, /datum/biome/expedition/sand/grass),
		list(/datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/riverbed, /datum/biome/expedition/sand/grass, /datum/biome/expedition/sand/grass),
		list(/datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand/sulfur, /datum/biome/expedition/sand),
	)
	cave_biome_table = list(
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave, /datum/biome/expedition/sand_cave),
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave),
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave, /datum/biome/expedition/sand_cave),
		list(/datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/dry, /datum/biome/expedition/sand_cave/deep, /datum/biome/expedition/sand_cave),
	)

/** Sand carrying the arid profile atmosphere and preserving it beneath excavation. */
/turf/open/misc/asteroid/expedition_arid
	name = "пустынный песок"
	desc = "Сухой песок с обломками выветренной породы."
	color = "#c6aa73"
	initial_gas_mix = GAS_N2 + "=82;" + GAS_CO2 + "=22;TEMP=330"
	temperature = 330
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/expedition_arid
	turf_type = /turf/open/misc/asteroid/expedition_arid
	worm_chance = 0

/** Weathered stony desert ground in the arid profile atmosphere. */
/turf/open/misc/asteroid/basalt/expedition_arid
	name = "каменистая пустошь"
	desc = "Выветренная порода, присыпанная песком."
	color = "#a08a68"
	initial_gas_mix = /turf/open/misc/asteroid/expedition_arid::initial_gas_mix
	temperature = 330
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/asteroid/basalt/expedition_arid
	turf_type = /turf/open/misc/asteroid/basalt/expedition_arid
	worm_chance = 0

/** Cracked dry riverbed in the arid profile atmosphere. */
/turf/open/misc/dirt/expedition_arid
	name = "высохшее русло"
	desc = "Растрескавшаяся корка давно высохшего ила."
	color = "#b89b72"
	initial_gas_mix = /turf/open/misc/asteroid/expedition_arid::initial_gas_mix
	temperature = 330
	planetary_atmos = TRUE
	baseturfs = /turf/open/misc/dirt/expedition_arid

/** Celadon sand plain with mushroom patches, geysers and desert predators. */
/datum/biome/expedition/sand
	open_turf_type = /turf/open/misc/asteroid/expedition_arid
	flora_density = 3
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 4,
		/obj/structure/flora/ash/cap_shroom = 4,
		/obj/structure/flora/ash/stem_shroom = 4,
	)
	feature_density = 0.1
	feature_types = list(/obj/structure/geyser/random = 1)
	fauna_density = 0.3
	fauna_types = list(
		/mob/living/basic/mining/goldgrub = 50,
		/mob/living/basic/mining/goliath = 10,
		/mob/living/basic/mining/basilisk = 20,
	)

/** Celadon wasteland with mushrooms and old remains. */
/datum/biome/expedition/sand/wasteland
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 4,
		/obj/structure/flora/ash/cap_shroom = 4,
		/obj/structure/flora/ash/stem_shroom = 4,
		/obj/effect/decal/remains/human = 4,
	)

/** Celadon scrubland; dry ground replaces the donor desert grass. */
/datum/biome/expedition/sand/grass
	open_turf_type = /turf/open/misc/dirt/expedition_arid
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/ash/cacti = 2,
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
	)
	fauna_density = 0

/** Celadon dead scrubland with withered trees. */
/datum/biome/expedition/sand/grass/dead
	flora_types = list(
		/obj/structure/flora/ash/leaf_shroom = 2,
		/obj/structure/flora/ash/cap_shroom = 2,
		/obj/structure/flora/ash/stem_shroom = 2,
		/obj/structure/flora/tree/dead/style_random = 4,
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
	)

/** Celadon ice-cap flats; rocky sand stands in for the donor snow. */
/datum/biome/expedition/sand/flats
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/style_random = 3,
		/obj/structure/flora/rock/pile/style_random = 3,
	)
	feature_density = 0
	fauna_density = 0.1

/** Celadon sulfur plains without their donor pools: bare sand where predators do not roam. */
/datum/biome/expedition/sand/sulfur
	flora_density = 0
	feature_density = 0
	fauna_density = 0

/** Celadon dry riverbed hunted by desert predators. */
/datum/biome/expedition/sand/riverbed
	open_turf_type = /turf/open/misc/dirt/expedition_arid
	flora_density = 0
	fauna_types = list(
		/mob/living/basic/mining/goldgrub = 50,
		/mob/living/basic/mining/goliath = 10,
		/mob/living/basic/mining/basilisk = 20,
	)

/** Celadon sand cave with rocks, geysers and burrowing grubs. */
/datum/biome/expedition/sand_cave
	open_turf_type = /turf/open/misc/asteroid/expedition_arid
	flora_density = 4
	flora_types = list(
		/obj/structure/flora/rock/style_random = 4,
		/obj/structure/flora/rock/pile/style_random = 4,
	)
	feature_density = 0.1
	feature_types = list(/obj/structure/geyser/random = 1)
	fauna_density = 0.3
	fauna_types = list(
		/mob/living/basic/mining/goliath = 10,
		/mob/living/basic/mining/basilisk = 20,
		/mob/living/basic/mining/goldgrub = 50,
	)

/** Celadon deep cave on stony ground with burrowing grubs. */
/datum/biome/expedition/sand_cave/deep
	open_turf_type = /turf/open/misc/asteroid/basalt/expedition_arid
	fauna_types = list(
		/mob/living/basic/mining/goliath = 10,
		/mob/living/basic/mining/basilisk = 20,
		/mob/living/basic/mining/goldgrub = 50,
	)

/** Celadon dry volcanic cave; dry ground replaces the donor acid and lava pools. */
/datum/biome/expedition/sand_cave/dry
	open_turf_type = /turf/open/misc/dirt/expedition_arid
	fauna_density = 0.15

/** Finite research source: полосчатое соляное отложение, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/mineral/expedition_arid
	name = "полосчатое соляное отложение"
	desc = "Светлая корка покрывает слоистую породу. Под ней различимы тёмные минеральные прожилки. Можно отобрать пробу."
	icon_state = "silver"
	field_notes = "Соляные слои пересечены минеральными прожилками. На поверхности видны следы ветровой эрозии; слои залегают почти горизонтально."
	laboratory_notes = "Последовательность солевых фракций указывает на многократное испарение древнего водоёма. Металлоносные прожилки образовались позднее и пересекают уже высохшие отложения."

/** Drop into the cave level that keeps this profile's surface atmosphere. */
/turf/open/openspace/expedition_arid
	initial_gas_mix = /turf/open/misc/asteroid/expedition_arid::initial_gas_mix
	planetary_atmos = TRUE

/** Celadon's Whitesands sulfur pools and oasis water, in the arid profile atmosphere. */
/turf/open/water/expedition_arid
	name = "сернистая вода"
	desc = "Мутная тёплая вода с резким запахом серы."
	initial_gas_mix = /turf/open/misc/asteroid/expedition_arid::initial_gas_mix
	baseturfs = /turf/open/water/expedition_arid

/** Whitesands pool spawners keep their donor chances and spawn local arid flora and fauna. */
/obj/effect/spawner/random/expedition_arid
	name = "arid pool spawner"

/// Ash mushrooms around a pool.
/obj/effect/spawner/random/expedition_arid/shroom
	spawn_loot_chance = 20
	loot = list(
		/obj/structure/flora/ash/leaf_shroom,
		/obj/structure/flora/ash/cap_shroom,
		/obj/structure/flora/ash/stem_shroom,
	)

/// Rocks and rock piles around a pool.
/obj/effect/spawner/random/expedition_arid/rock
	spawn_loot_chance = 70
	loot = list(
		/obj/structure/flora/rock/style_random,
		/obj/structure/flora/rock/pile/style_random,
	)

/// Cacti around a pool.
/obj/effect/spawner/random/expedition_arid/cactus
	spawn_loot_chance = 50
	loot = list(/obj/structure/flora/ash/cacti)

/// Goldgrubs or a basilisk by a pool.
/obj/effect/spawner/random/expedition_arid/fauna
	spawn_loot_chance = 40
	loot = list(
		/mob/living/basic/mining/goldgrub = 2,
		/mob/living/basic/mining/basilisk = 1,
	)

/** Sand storm that never winds down, raised by the endless storm planet modifier. */
/datum/weather/sand_storm/expedition_endless
	telegraph_duration = 0 SECONDS
	// Never scheduled at random, so other levels with the same storm trait keep their periodic storms.
	probability = 0
	weather_flags = parent_type::weather_flags | WEATHER_ENDLESS

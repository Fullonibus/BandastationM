// Sierra's lush surface profile; flora and fauna come from Celadon's jungle planet biomes (see planet_generator.dm).
// https://github.com/SierraBay/SierraBay12/blob/8623b35f6943130998002e94cf001a9c6ccb3f4c/code/modules/overmap/exoplanets/planet_types/grass.dm
// Donor kudzu, gardens, capybaras, chicken flocks, ore veins, burrows, anomalies and terrain patches are omitted.
/** Temperate breathable surface profile populated with jungle flora and wildlife. */
/datum/stationtrauma_overmap_site/space/planet/lush
	name = "Зелёная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/lush
	parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet/lush
	biome = "Джунгли, травянистые равнины, топкие низины и озёра"
	atmosphere = "Кислород и азот, 101 кПа"
	surface_temperature = T20C
	breathable = TRUE

/** Seeded jungle terrain with flora and wildlife excluded from reserved paths and ruins. */
/datum/map_generator/expedition_barren/lush
	hole_type = /turf/open/openspace/expedition_lush
	wildlife = TRUE
	storm_trait = ZTRAIT_RAINSTORM
	endless_storm_type = /datum/weather/particle/rain_storm/expedition_endless
	sky_color = "#e0ffc8"
	floor_type = /turf/open/misc/grass/jungle
	hive_variants = list("jungle", "grown")
	// Towns without radiation may stand in the jungle on a widened surface.
	large_ruin_chance = 25
	large_ruin_biome = "lush"
	source_type = /obj/structure/stationtrauma_research_source/expedition_lush
	mountain_height = 0.85
	mineral_chance = 5
	// Celadon jungle greebles; anomaly sites are rarer because neutralizing one yields an anomaly core.
	feature_maps = list(
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_1.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_2.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_3.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_4.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_5.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_6.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_7.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_8.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_9.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_10.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_11.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_12.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_13.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_14.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_15.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_16.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_17.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_18.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_19.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_20.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_21.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_22.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_23.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_24.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_25.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_26.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_27.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_28.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_29.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_30.dmm" = 3,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_1.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_2.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_3.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_4.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_5.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_6.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_7.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_8.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_9.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_10.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_11.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_jungle_anomaly_12.dmm" = 1,
	)
	feature_count = 8
	// Jungle caves also get the springs, overgrown dens and glowing pools of Celadon's jungle caves.
	cave_feature_maps = list(
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_1.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_2.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_3.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_4.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_5.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_6.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_7.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_8.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_9.dmm" = 1,
		"modular_bandastation/expedition_planets/maps/features/celadon_junglecave_10.dmm" = 1,
	)
	biome_table = list(
		list(/datum/biome/expedition/jungle_wasteland, /datum/biome/expedition/jungle_wasteland, /datum/biome/expedition/jungle/plains, /datum/biome/expedition/jungle/plains, /datum/biome/expedition/mudlands),
		list(/datum/biome/expedition/jungle_wasteland, /datum/biome/expedition/jungle/plains, /datum/biome/expedition/jungle, /datum/biome/expedition/mudlands, /datum/biome/expedition/mudlands),
		list(/datum/biome/expedition/jungle, /datum/biome/expedition/jungle, /datum/biome/expedition/mudlands, /datum/biome/expedition/mudlands, /datum/biome/expedition/jungle),
		list(/datum/biome/expedition/jungle/dense, /datum/biome/expedition/mudlands, /datum/biome/expedition/jungle_water, /datum/biome/expedition/jungle_water, /datum/biome/expedition/mudlands),
		list(/datum/biome/expedition/jungle, /datum/biome/expedition/jungle, /datum/biome/expedition/jungle/dense, /datum/biome/expedition/jungle/dense, /datum/biome/expedition/jungle/dense),
		list(/datum/biome/expedition/jungle/dense, /datum/biome/expedition/jungle/dense, /datum/biome/expedition/mudlands, /datum/biome/expedition/jungle_water, /datum/biome/expedition/jungle_water),
	)
	cave_biome_table = list(
		list(/datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave),
		list(/datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt),
		list(/datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave),
		list(/datum/biome/expedition/jungle_cave, /datum/biome/expedition/jungle_cave/dirt, /datum/biome/expedition/lush_cave, /datum/biome/expedition/lush_cave/bright, /datum/biome/expedition/lush_cave/bright),
	)

/** Celadon jungle: thick undergrowth with monkeys and fowl. */
/datum/biome/expedition/jungle
	open_turf_type = /turf/open/misc/grass/jungle
	flora_density = 75
	flora_types = list(
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
		/obj/structure/flora/tree/jungle/style_random = 3,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
		/obj/structure/flora/bush/jungle/a/style_random = 1,
		/obj/structure/flora/bush/jungle/b/style_random = 1,
		/obj/structure/flora/bush/jungle/c/style_random = 1,
		/obj/structure/flora/bush/large/style_random = 1,
	)
	fauna_density = 0.3
	fauna_types = list(
		/mob/living/carbon/human/species/monkey = 10,
		/mob/living/basic/chicken = 10,
	)

/** Celadon dense jungle on dark soil, home to gorillas. */
/datum/biome/expedition/jungle/dense
	open_turf_type = /turf/open/misc/dirt/jungle/dark
	flora_density = 85
	flora_types = list(
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
		/obj/structure/flora/tree/jungle/style_random = 5,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
		/obj/structure/flora/bush/jungle/a/style_random = 1,
		/obj/structure/flora/bush/jungle/b/style_random = 1,
		/obj/structure/flora/bush/jungle/c/style_random = 1,
		/obj/structure/flora/bush/large/style_random = 1,
	)
	fauna_density = 0.6
	fauna_types = list(
		/mob/living/basic/gorilla = 1,
		/mob/living/carbon/human/species/monkey = 6,
		/mob/living/basic/chicken = 4,
	)

/** Celadon jungle plains. */
/datum/biome/expedition/jungle/plains
	flora_density = 50
	fauna_density = 1
	fauna_types = list(
		/mob/living/carbon/human/species/monkey = 1,
		/mob/living/basic/chicken = 1,
	)

/** Celadon mudlands with rare tarantulas. */
/datum/biome/expedition/mudlands
	open_turf_type = /turf/open/misc/dirt/jungle/dark
	flora_density = 20
	flora_types = list(
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
	)
	fauna_density = 0.05
	fauna_types = list(/mob/living/basic/spider/giant/tarantula = 1)

/** Celadon barren jungle wasteland. */
/datum/biome/expedition/jungle_wasteland
	open_turf_type = /turf/open/misc/dirt/jungle/wasteland

/** Celadon jungle lake with carp. */
/datum/biome/expedition/jungle_water
	open_turf_type = /turf/open/water/jungle
	flora_density = 1
	flora_types = list(/obj/structure/flora/rock/style_random = 1)
	fauna_density = 1
	fauna_types = list(/mob/living/basic/carp = 1)

/** Celadon jungle cave with rocks, mushrooms and cave predators. */
/datum/biome/expedition/jungle_cave
	open_turf_type = /turf/open/misc/dirt/jungle
	flora_density = 5
	flora_types = list(
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
		/obj/structure/flora/rock/pile/style_random = 1,
		/obj/structure/flora/rock/style_random = 1,
		/obj/structure/flora/ash/leaf_shroom = 1,
		/obj/structure/flora/ash/cap_shroom = 1,
		/obj/structure/flora/ash/stem_shroom = 1,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/bear = 1,
		/mob/living/basic/bat = 5,
		/mob/living/basic/snake = 3,
	)

/** Celadon overgrown cave on bare dirt. */
/datum/biome/expedition/jungle_cave/dirt
	open_turf_type = /turf/open/misc/dirt/jungle/wasteland
	flora_types = list(
		/obj/structure/flora/bush/jungle/a/style_random = 1,
		/obj/structure/flora/bush/jungle/b/style_random = 1,
		/obj/structure/flora/bush/jungle/c/style_random = 1,
		/obj/structure/flora/bush/large/style_random = 1,
		/obj/structure/flora/rock/pile/jungle/large/style_random = 1,
		/obj/structure/flora/grass/jungle/a/style_random = 1,
		/obj/structure/flora/grass/jungle/b/style_random = 1,
	)

/** Celadon lush cavern with flowers, bees and walking mushrooms. */
/datum/biome/expedition/lush_cave
	open_turf_type = /turf/open/misc/grass/jungle
	flora_density = 50
	flora_types = list(
		/obj/structure/flora/tree/jungle/small/style_random = 1,
		/obj/structure/flora/bush/flowers_br/style_random = 1,
		/obj/structure/flora/bush/ferny/style_random = 1,
		/obj/structure/flora/bush/fullgrass/style_random = 1,
		/obj/structure/flora/bush/generic/style_random = 1,
		/obj/structure/flora/bush/grassy/style_random = 1,
		/obj/structure/flora/bush/lavendergrass/style_random = 2,
		/obj/structure/flora/bush/pale/style_random = 1,
		/obj/structure/flora/bush/pointy/style_random = 1,
		/obj/structure/flora/bush/flowers_pp/style_random = 1,
		/obj/structure/flora/bush/reed/style_random = 1,
		/obj/structure/flora/bush/sparsegrass/style_random = 1,
		/obj/structure/flora/bush/stalky/style_random = 2,
		/obj/structure/flora/bush/sunny/style_random = 1,
		/obj/structure/flora/bush/flowers_yw/style_random = 1,
		/obj/structure/flora/rock/pile/jungle/style_random = 1,
	)
	fauna_density = 1
	fauna_types = list(
		/mob/living/basic/bee = 1,
		/mob/living/basic/mushroom = 1,
	)

/** Celadon bright cavern lit by wandering lightgeists. */
/datum/biome/expedition/lush_cave/bright
	flora_density = 40
	fauna_types = list(/mob/living/basic/lightgeist = 1)

/** Finite research source: пластинчатая растительная колония, with authored survey and laboratory observations. */
/obj/structure/stationtrauma_research_source/expedition_lush
	name = "пластинчатая растительная колония"
	desc = "Плотные листовые пластины соединены влажными волокнами. Можно обследовать колонию и отобрать образец."
	icon = 'icons/obj/fluff/flora/jungleflora.dmi'
	icon_state = "bushb1"
	field_notes = "На освещённых пластинах заметен тёмный пигмент. Волокна уходят в почву и связывают несколько соседних побегов."
	laboratory_notes = "В образце обнаружены растительные клетки и симбиотические микроорганизмы. Пористые волокна удерживают влагу; чередование плотных и рыхлых слоёв отражает периоды пересыхания почвы."

/** Drop into the cave level that keeps this profile's surface atmosphere. */
/turf/open/openspace/expedition_lush
	initial_gas_mix = /turf/open/misc/grass/jungle::initial_gas_mix
	planetary_atmos = TRUE

/** Rain storm that never winds down, raised by the endless storm planet modifier. */
/datum/weather/particle/rain_storm/expedition_endless
	telegraph_duration = 0 SECONDS
	// Never scheduled at random, so other levels with the same storm trait keep their periodic storms.
	probability = 0
	weather_flags = parent_type::weather_flags | WEATHER_ENDLESS

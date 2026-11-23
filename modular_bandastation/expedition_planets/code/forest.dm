/** A cool temperate woodland, distinct from the jungle profile. */
/datum/stationtrauma_overmap_site/space/planet/forest
	name = "Лесная экзопланета"
	generator_type = /datum/map_generator/expedition_barren/forest
	parallax_layer = /atom/movable/screen/parallax_layer/expedition_planet/lush
	biome = "Хвойные леса, тёмная почва, ручьи и лесные озёра"
	has_atmosphere = TRUE
	surface_temperature = T0C + 15
	ruin_biome = "lush"

/datum/map_generator/expedition_barren/forest
	floor_type = /turf/open/misc/grass
	wildlife = TRUE
	mountain_height = 0.84
	source_type = /obj/structure/stationtrauma_research_source/expedition_lush
	cave_biome_table = /datum/biome/expedition/lunar/rocky

/datum/map_generator/expedition_barren/forest/biome_at(x, y, mountain)
	if(mountain)
		return ..()
	if(surface_noise(2000000, x, y, 34) > 0.5)
		return local_biome(/datum/biome/expedition/woodland/dense)
	return local_biome(/datum/biome/expedition/woodland)

/datum/biome/expedition/woodland
	open_turf_type = /turf/open/misc/grass
	flora_density = 32
	flora_types = list(
		/obj/structure/flora/tree/pine/style_random = 7,
		/obj/structure/flora/grass/green/style_random = 4,
		/obj/structure/flora/rock/pile/style_random = 1,
	)
	fauna_density = 1.4
	fauna_types = list(/mob/living/basic/rabbit = 3, /mob/living/basic/bear = 1)

/datum/biome/expedition/woodland/dense
	open_turf_type = /turf/open/misc/dirt/dark
	flora_density = 52

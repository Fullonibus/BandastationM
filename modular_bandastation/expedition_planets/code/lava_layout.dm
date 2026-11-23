/datum/map_generator/expedition_barren/lava/ruin_patrol_biome(x, y)
	var/datum/biome/biome = ..()
	if(length(biome.fauna_types))
		return biome
	return local_biome(/datum/biome/expedition/volcanic_cave)

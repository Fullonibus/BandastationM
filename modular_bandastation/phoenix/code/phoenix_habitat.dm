/// Hard budget for one habitat traversal, including connected vertical turfs.
#define PHOENIX_HABITAT_MAX_TURFS 144

/** Read the surrounding turf even in generic containers; only capsule stasis stops biology. */
/datum/phoenix_strain/proc/assess_environment(atom/movable/specimen)
	var/turf/open/location = get_turf(specimen)
	var/datum/gas_mixture/air = istype(location) ? location.return_air() : null
	var/temperature_kelvin = air?.temperature || TCMB
	var/pressure_kpa = air?.return_pressure() || 0
	var/partial_pressure_factor = air?.volume ? R_IDEAL_GAS_EQUATION * temperature_kelvin / air.volume : 0
	var/oxygen_kpa = air ? air.moles[/datum/gas/oxygen] * partial_pressure_factor : 0
	var/carbon_dioxide_kpa = air ? air.moles[/datum/gas/carbon_dioxide] * partial_pressure_factor : 0
	var/illumination = istype(location) ? location.get_lumcount() : 0
	var/observed_substrate = phoenix_substrate_at(location)
	var/list/habitat = phoenix_habitat(location, substrate_id)
	var/available_space = habitat["bounded"] ? habitat["substrate_tiles"] / max(1, habitat["population"]) : 0
	var/list/result = classify(temperature_kelvin, pressure_kpa, oxygen_kpa, carbon_dioxide_kpa, illumination, available_space, observed_substrate)
	var/list/causes = result["causes"]
	if(!habitat["bounded"])
		causes += "Не найден замкнутый вольер допустимого размера"
	if(!isturf(specimen.loc))
		result["state"] = min(result["state"], PHOENIX_SURVIVAL)
		causes += "Контейнер не является вольером для размножения"
	result["temperature"] = temperature_kelvin
	result["pressure"] = pressure_kpa
	result["oxygen"] = oxygen_kpa
	result["carbon_dioxide"] = carbon_dioxide_kpa
	result["light"] = illumination
	result["space"] = available_space
	result["substrate"] = observed_substrate
	return result

/** Flood cached atmospheric connections, stopping before any room can exceed the fixed budget. */
/proc/phoenix_habitat(turf/open/origin, required_substrate)
	var/list/result = list("bounded" = FALSE, "substrate_tiles" = 0, "population" = 0)
	if(!istype(origin) || isspaceturf(origin))
		return result
	var/list/room = list(origin)
	var/list/visited = list()
	visited[origin] = TRUE
	for(var/index = 1, index <= length(room), index++)
		var/turf/open/current = room[index]
		if(isspaceturf(current) || current.blocks_air)
			return result
		if(phoenix_substrate_at(current) == required_substrate)
			result["substrate_tiles"]++
		for(var/mob/living/basic/phoenix_weaver/animal in current)
			if(animal.stat != DEAD)
				result["population"]++
		for(var/turf/open/neighbor as anything in current.atmos_adjacent_turfs)
			if(visited[neighbor])
				continue
			if(length(room) >= PHOENIX_HABITAT_MAX_TURFS)
				return result
			visited[neighbor] = TRUE
			room += neighbor
	result["bounded"] = TRUE
	return result

/** Physical bedding overrides natural ground; painted floor colors have no ecological effect. */
/proc/phoenix_substrate_at(turf/location)
	if(!location)
		return null
	var/obj/structure/phoenix_substrate/bedding = locate() in location
	if(bedding)
		return bedding.substrate_id
	if(istype(location, /turf/open/floor/grass))
		return "grass"
	if(istype(location, /turf/open/misc/snow) || istype(location, /turf/open/floor/fake_snow))
		return "snow"
	if(istype(location, /turf/open/misc/beach) || istype(location, /turf/open/misc/sandy_dirt))
		return "sand"
	return null

/** A physical layer of habitat bedding, removable with a shovel. */
/obj/structure/phoenix_substrate
	name = "weaver sand bedding"
	desc = "Слой песчаного субстрата для янтарных ткачей. Примените лопату, чтобы снять покрытие и вернуть его в упаковку."
	icon = 'icons/turf/sand.dmi'
	icon_state = "sand"
	anchored = TRUE
	density = FALSE
	layer = LOW_OBJ_LAYER
	max_integrity = 30
	/// Ecological ground type supplied by this structure.
	var/substrate_id = "sand"
	/// Material returned when this layer is collected.
	var/bedding_type = /obj/item/stack/phoenix_bedding

/obj/structure/phoenix_substrate/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour != TOOL_SHOVEL)
		return ..()
	if(!user.is_holding(tool) || !user.Adjacent(src) || user.incapacitated)
		return ITEM_INTERACT_BLOCKING
	if(!tool.use_tool(src, user, 2 SECONDS, volume = 30))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || QDELETED(user) || QDELETED(tool) || user.incapacitated || !user.is_holding(tool) || !user.Adjacent(src))
		return ITEM_INTERACT_BLOCKING
	new bedding_type(drop_location(), 1)
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/structure/phoenix_substrate/grass
	name = "weaver grass bedding"
	desc = "Слой живого дёрна для янтарных ткачей. Примените лопату, чтобы снять покрытие и вернуть его в упаковку."
	icon = 'icons/turf/floors.dmi'
	icon_state = "grass0"
	substrate_id = "grass"
	bedding_type = /obj/item/stack/phoenix_bedding/grass

/obj/structure/phoenix_substrate/snow
	name = "weaver snow bedding"
	desc = "Слой охлаждённого снежного субстрата для янтарных ткачей. Примените лопату, чтобы снять покрытие и вернуть его в упаковку."
	icon = 'icons/turf/snow.dmi'
	icon_state = "snow"
	substrate_id = "snow"
	bedding_type = /obj/item/stack/phoenix_bedding/snow

/** Consumable bedding placed by clicking an adjacent open turf while held. */
/obj/item/stack/phoenix_bedding
	name = "weaver sand bedding pack"
	singular_name = "bedding pack"
	desc = "Песчаный субстрат для вольера. Примените к соседнему полу. Уложенное покрытие можно снять лопатой и использовать повторно."
	icon = 'icons/obj/tiles.dmi'
	icon_state = "sandstone_floor"
	max_amount = 50
	merge_type = /obj/item/stack/phoenix_bedding
	/// Ecological ground type contained in this stack.
	var/substrate_id = "sand"
	/// Structure created by one unit.
	var/substrate_type = /obj/structure/phoenix_substrate

/obj/item/stack/phoenix_bedding/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isopenturf(interacting_with))
		return NONE
	if(QDELETED(user) || user.incapacitated || !user.is_holding(src) || !user.Adjacent(interacting_with) || isspaceturf(interacting_with))
		return ITEM_INTERACT_BLOCKING
	var/turf/open/location = interacting_with
	if(location.blocks_air || locate(/obj/structure/phoenix_substrate) in location)
		return ITEM_INTERACT_BLOCKING
	for(var/obj/obstacle in location)
		if(obstacle.density)
			return ITEM_INTERACT_BLOCKING
	var/placed_substrate = substrate_type
	if(!use(1))
		return ITEM_INTERACT_BLOCKING
	new placed_substrate(location)
	return ITEM_INTERACT_SUCCESS

/obj/item/stack/phoenix_bedding/grass
	name = "weaver grass bedding pack"
	desc = "Живой дёрн для вольера. Примените к соседнему полу. Уложенное покрытие можно снять лопатой и использовать повторно."
	icon_state = "tile_grass"
	merge_type = /obj/item/stack/phoenix_bedding/grass
	substrate_id = "grass"
	substrate_type = /obj/structure/phoenix_substrate/grass

/obj/item/stack/phoenix_bedding/snow
	name = "weaver snow bedding pack"
	desc = "Охлаждённый снежный субстрат для вольера. Примените к соседнему полу. Уложенное покрытие можно снять лопатой и использовать повторно."
	icon_state = "tile_snow"
	merge_type = /obj/item/stack/phoenix_bedding/snow
	substrate_id = "snow"
	substrate_type = /obj/structure/phoenix_substrate/snow

#undef PHOENIX_HABITAT_MAX_TURFS

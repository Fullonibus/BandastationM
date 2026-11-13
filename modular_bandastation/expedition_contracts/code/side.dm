// Side tasks: a small salvage job that comes with an order, in the ruins of the same planet. What already lies there
// is taken first (Syndicate papers, data disks); otherwise the customer's own item is left in the ruins.

/// Things already lying in ruins that a side task may ask for.
GLOBAL_LIST_INIT(expedition_side_found_types, list(
	/obj/item/folder/syndicate,
	/obj/item/disk/data,
))

/// The customer's own items, left in the ruins when nothing fitting lies there.
GLOBAL_LIST_INIT(expedition_side_own_types, list(
	/obj/item/expedition_flight_recorder,
	/obj/item/disk/expedition_data,
	/obj/item/expedition_cargo,
))

/// A side task: bring a thing out of the destination's ruins and have it catalogued.
/datum/expedition_contract/side
	name = "Побочное задание"
	research_reward = 100
	credit_reward = 500
	fails_on_loss = TRUE

/datum/expedition_contract/side/build_steps(datum/stationtrauma_overmap_site/space/site)
	steps += new /datum/expedition_contract_step/salvage(target_name)
	steps += new /datum/expedition_contract_step/catalogue("каталогизировать этот предмет на сканирующей площадке станции")

/// Moves the task to `site`, a space ruin, when the planet turned out to have none.
/datum/expedition_contract/side/proc/retarget(datum/stationtrauma_overmap_site/space/site)
	target_id = site.id
	target_name = site.name
	target_x = site.pos_x
	target_y = site.pos_y
	var/datum/expedition_contract_step/salvage/step = steps[1]
	step.place = site.name
	step.text = "найти и забрать предмет в руинах на [site.name]"
	GLOB.expedition_contracts.notify("[summary()]: на планете нет руин; разведка указывает на объект [site.name] ([site.pos_x], [site.pos_y]).")

/**
 * Find a thing in the destination's ruins and pick it up. The thing is chosen when the destination loads: its map does
 * not exist before the first approach.
 */
/datum/expedition_contract_step/salvage
	event_signal = COMSIG_GLOB_EXPEDITION_SITE_LOADED
	/// Destination name, for the step text.
	var/place

/datum/expedition_contract_step/salvage/New(new_place)
	place = new_place
	text = "найти и забрать предмет в руинах на [place]"

/datum/expedition_contract_step/salvage/activate()
	. = ..()
	if(length(contract.bound))
		return
	var/datum/stationtrauma_overmap_site/space/site = expedition_site_by_id(contract.target_id)
	if(site && expedition_site_loaded(site))
		place_item(site)

/datum/expedition_contract_step/salvage/deactivate()
	. = ..()
	for(var/atom/movable/thing as anything in contract?.bound)
		UnregisterSignal(thing, COMSIG_ITEM_PICKUP)

/datum/expedition_contract_step/salvage/on_event(datum/source, datum/stationtrauma_overmap_site/space/site)
	if(site.id == contract.target_id && !length(contract.bound))
		place_item(site)

/// Picks the thing in `site`'s ruins, or moves the task to the nearest space ruin if the planet has none.
/datum/expedition_contract_step/salvage/proc/place_item(datum/stationtrauma_overmap_site/space/site)
	var/list/ruin_turfs = expedition_site_ruin_turfs(site.id)
	if(!length(ruin_turfs))
		var/datum/expedition_contract/side/side_task = contract
		var/datum/stationtrauma_overmap_site/space/ruin = istype(site, /datum/stationtrauma_overmap_site/space/planet) && expedition_nearest_space_ruin(site)
		if(ruin)
			side_task.retarget(ruin)
			if(expedition_site_loaded(ruin))
				place_item(ruin)
		return
	var/obj/item/thing
	var/list/found = list()
	var/list/floors = list()
	for(var/turf/tile as anything in ruin_turfs)
		for(var/obj/item/candidate in tile)
			if(is_type_in_list(candidate, GLOB.expedition_side_found_types))
				found += candidate
		for(var/obj/structure/closet/closet in tile)
			for(var/obj/item/candidate in closet)
				if(is_type_in_list(candidate, GLOB.expedition_side_found_types))
					found += candidate
		if(isopenturf(tile) && !tile.is_blocked_turf(exclude_mobs = TRUE))
			floors += tile
	if(length(found))
		thing = pick(found)
	else if(length(floors))
		var/thing_type = pick(GLOB.expedition_side_own_types)
		thing = new thing_type(pick(floors))
	if(!thing)
		return
	contract.bind(thing, src)
	ADD_TRAIT(thing, TRAIT_EXPEDITION_ORDER_ITEM, EXPEDITION_ORDER_TRAIT)
	RegisterSignal(thing, COMSIG_ITEM_PICKUP, PROC_REF(on_pickup))
	text = "найти «[thing.name]» в руинах на [place] и забрать"
	GLOB.expedition_contracts.notify("[contract.summary()]: разведка указывает на «[thing.name]» в руинах на [place].")

/datum/expedition_contract_step/salvage/proc/on_pickup(obj/item/source, mob/user)
	SIGNAL_HANDLER
	add_progress(user)

/// The charted destination with `id`, or null.
/proc/expedition_site_by_id(id)
	for(var/datum/stationtrauma_overmap_site/space/site as anything in GLOB.expedition_contracts.destinations())
		if(site.id == id)
			return site
	return null

/// Whether `site`'s map exists: a planet builds its surface and a space ruin loads on the first approach.
/proc/expedition_site_loaded(datum/stationtrauma_overmap_site/space/site)
	var/datum/stationtrauma_overmap_site/space/planet/planet = site
	if(istype(planet) && planet.generator)
		return FALSE
	return !site.map_loader && !site.failed && !isnull(site.berth)

/// Turfs of the ruins standing on the destination with `site_id`, found through their ruin landmarks.
/proc/expedition_site_ruin_turfs(site_id)
	. = list()
	var/list/levels = list()
	for(var/obj/effect/landmark/stationtrauma_research_site/marker in GLOB.landmarks_list)
		if(marker.site_id == site_id)
			levels |= marker.z
	for(var/obj/effect/landmark/ruin/landmark as anything in GLOB.ruin_landmarks)
		var/datum/map_template/ruin/template = landmark.ruin_template
		if(!template || !(landmark.z in levels))
			continue
		// Ruins are placed centred on their landmark.
		var/turf/low = locate(max(1, landmark.x - round(template.width / 2)), max(1, landmark.y - round(template.height / 2)), landmark.z)
		var/turf/high = locate(min(world.maxx, low.x + template.width - 1), min(world.maxy, low.y + template.height - 1), landmark.z)
		for(var/turf/tile as anything in block(low, high))
			if(istype(get_area(tile), /area/ruin))
				. |= tile

/// The space ruin of `planet`'s sector nearest to it on the chart, or null.
/proc/expedition_nearest_space_ruin(datum/stationtrauma_overmap_site/space/planet/planet)
	var/datum/stationtrauma_overmap_site/space/best
	var/best_distance = INFINITY
	for(var/datum/stationtrauma_overmap_site/space/site as anything in GLOB.expedition_contracts.destinations())
		if(istype(site, /datum/stationtrauma_overmap_site/space/planet) || site.approach_scene != "ruin" || site.failed)
			continue
		var/distance = sqrt((site.pos_x - planet.pos_x) ** 2 + (site.pos_y - planet.pos_y) ** 2)
		if(distance < best_distance)
			best_distance = distance
			best = site
	return best

// ===== The customer's own items =====

/// A flight recorder off a wreck.
/obj/item/expedition_flight_recorder
	name = "бортовой самописец"
	desc = "Защищённый бортовой самописец потерянного судна. Его данные нужны заказчику."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "blackcube"
	inhand_icon_state = "blackcube"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL

/// A data store with the records of an abandoned expedition.
/obj/item/disk/expedition_data
	name = "накопитель данных экспедиции"
	desc = "Накопитель с записями заброшенной экспедиции. Заказчику нужны сами записи."

/// A sealed consignment bolted to the floor; it has to be unbolted before it can be carried off.
/obj/item/expedition_cargo
	name = "закреплённый груз"
	desc = "Опечатанный контейнер, привинченный к полу. Открутите крепления гаечным ключом, чтобы забрать его."
	icon = 'modular_bandastation/expedition_contracts/icons/recovery.dmi'
	icon_state = "recovery_anchored"
	inhand_icon_state = "recovery"
	lefthand_file = 'modular_bandastation/expedition_contracts/icons/recovery_lefthand.dmi'
	righthand_file = 'modular_bandastation/expedition_contracts/icons/recovery_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	anchored = TRUE

/obj/item/expedition_cargo/wrench_act(mob/living/user, obj/item/tool)
	if(!anchored)
		return NONE
	balloon_alert(user, "откручиваем...")
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50) || !anchored)
		return ITEM_INTERACT_BLOCKING
	set_anchored(FALSE)
	name = "груз заказчика"
	icon_state = "recovery"
	balloon_alert(user, "откручено")
	return ITEM_INTERACT_SUCCESS

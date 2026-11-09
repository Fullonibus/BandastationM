/** Circuitboard for a station controller that publishes a completed S dock. */
/obj/item/circuitboard/computer/stationtrauma_dock_controller
	name = "контроллер причала S"
	build_path = /obj/machinery/computer/stationtrauma_dock_controller

/datum/design/board/shuttle/stationtrauma_dock_controller
	name = "Плата контроллера причала S"
	desc = "Сканирует и регистрирует построенный стыковочный слот S."
	build_path = /obj/item/circuitboard/computer/stationtrauma_dock_controller

/obj/item/circuitboard/computer/stationtrauma_dock_controller/medium
	name = "контроллер причала M"
	build_path = /obj/machinery/computer/stationtrauma_dock_controller/medium

/datum/design/board/shuttle/stationtrauma_dock_controller/medium
	name = "Плата контроллера причала M"
	desc = "Сканирует и регистрирует построенный стыковочный слот M."
	build_path = /obj/item/circuitboard/computer/stationtrauma_dock_controller/medium

/** A prefabricated endpoint installs facing away from the builder. */
/obj/item/stationtrauma_docking_kit
	name = "монтажный комплект стыковочного шлюза"
	desc = "Установите на соседний пол, стоя со стороны герметичного помещения. Стрелка установленного шлюза будет смотреть от вас, наружу к месту стыковки."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "flatpack"
	/// The finished docking endpoint this kit installs.
	var/obj/machinery/door/airlock/stationtrauma_docking/endpoint_type

/obj/item/stationtrauma_docking_kit/wall
	name = "монтажный комплект секции стыковочной стены"
	endpoint_type = /obj/machinery/door/airlock/stationtrauma_docking/wall

/obj/item/stationtrauma_docking_kit/ship
	name = "монтажный комплект корабельного стыковочного шлюза"
	endpoint_type = /obj/machinery/door/airlock/stationtrauma_docking/ship

/obj/item/stationtrauma_docking_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isturf(interacting_with) || user.combat_mode)
		return NONE
	var/turf/tile = interacting_with
	var/facing = get_dir(user, tile)
	if(!can_install(tile, user) || !(facing in GLOB.cardinals))
		balloon_alert(user, "нужен свободный пол перед вами")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "устанавливаю шлюз…")
	if(!do_after(user, 2 SECONDS, target = tile) || !can_install(tile, user) || facing != get_dir(user, tile))
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/door/airlock/stationtrauma_docking/endpoint = new endpoint_type(tile)
	endpoint.setDir(facing)
	playsound(endpoint, 'sound/machines/click.ogg', 50, TRUE)
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/item/stationtrauma_docking_kit/proc/can_install(turf/tile, mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && loc == user && user.Adjacent(tile) && isfloorturf(tile) \
		&& !tile.is_blocked_turf() && !(locate(/obj/machinery/door) in tile)

/obj/item/stationtrauma_docking_kit/wall/can_install(turf/tile, mob/living/user)
	return (is_station_level(tile.z) || stationtrauma_carrier_at(tile)) && ..()

/datum/design/stationtrauma_docking_kit
	abstract_type = /datum/design/stationtrauma_docking_kit
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT)
	category = list(RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_ENGINEERING)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/stationtrauma_docking_kit/wall
	name = "Монтажный комплект секции стыковочной стены"
	desc = "Устанавливает ответный шлюз в стене причала."
	build_path = /obj/item/stationtrauma_docking_kit/wall

/datum/design/stationtrauma_docking_kit/ship
	name = "Монтажный комплект корабельного стыковочного шлюза"
	desc = "Устанавливает наружный шлюз корабля для герметичного стыковочного трапа."
	build_path = /obj/item/stationtrauma_docking_kit/ship

/** Station console for inspecting a mapped standard dock or commissioning a new one. */
/obj/machinery/computer/stationtrauma_dock_controller
	name = "контроллер причала S"
	desc = "Проверяет и регистрирует стыковочную площадку. При строительстве ставьте контроллер в двух клетках за крайней секцией стены."
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_dock_controller
	/// Class and dimensions used when this controller creates a dock.
	var/dock_class = "S"
	/// Hull classification accepted by the controller's dock.
	var/accepted_ship_class = ST_SHIP_SMALL
	/// Width of the hull area, perpendicular to the wall.
	var/slot_width = ST_STANDARD_S_WIDTH
	/// Length of the hull area, parallel to the wall.
	var/slot_height = ST_STANDARD_S_HEIGHT
	/// Optional existing mapped destination. The controller never owns this berth.
	var/site_id
	/// Runtime berth commissioned by this controller.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/owned_slot
	/// Optional display name chosen before publishing a runtime berth.
	var/dock_name
	/// Debounces the client-only floor overlays.
	COOLDOWN_DECLARE(preview_cooldown)

/obj/machinery/computer/stationtrauma_dock_controller/medium
	name = "контроллер причала M"
	circuit = /obj/item/circuitboard/computer/stationtrauma_dock_controller/medium
	dock_class = "M"
	accepted_ship_class = ST_SHIP_MEDIUM
	slot_width = ST_STANDARD_M_WIDTH
	slot_height = ST_STANDARD_M_HEIGHT

/obj/machinery/computer/stationtrauma_dock_controller/Destroy()
	if(!QDELETED(owned_slot))
		owned_slot.retire()
	owned_slot = null
	return ..()

/obj/machinery/computer/stationtrauma_dock_controller/examine(mob/user)
	. = ..()
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = find_slot()
	. += span_notice(dock_status(slot))
	if(!slot && !site_id)
		. += span_notice("Направление контроллера задаёт линию из [slot_height] секций. Стена находится в двух клетках слева от этого направления.")

/obj/machinery/computer/stationtrauma_dock_controller/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!can_interact(user) || panel_open)
		return
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = find_slot()
	var/turf/controller_turf = get_turf(src)
	var/controller_direction = dir
	var/configured_site_id = site_id
	var/list/actions = list("Показать площадку", "Проверить площадку")
	if(!site_id && !slot)
		actions += list("Повернуть контроллер", "Зарегистрировать причал")
	else if(slot && slot == owned_slot && !owned_slot.retiring)
		actions += "Снять причал с регистрации"
	if(can_name_dock(user, slot))
		actions += "Название причала"
	var/action = tgui_input_list(user, dock_status(slot), name, actions)
	if(!action || QDELETED(src) || !can_interact(user) || panel_open)
		return
	if(action == "Название причала")
		if(get_turf(src) == controller_turf && dir == controller_direction && site_id == configured_site_id)
			name_dock(user, slot)
		return
	slot = find_slot()
	var/turf/anchor = slot ? get_turf(slot) : proposed_anchor()
	var/facing = slot ? slot.dir : dir
	var/dock_width = slot ? slot.width : slot_width
	var/dock_height = slot ? slot.height : slot_height
	switch(action)
		if("Показать площадку")
			show_layout(user, anchor, facing, dock_width, dock_height)
		if("Проверить площадку")
			var/datum/stationtrauma_overmap_site/space/site = slot_site(slot)
			if(slot && (slot.active_berth || site?.docking_owner))
				to_chat(user, span_notice(dock_status(slot)))
				return
			var/problem = stationtrauma_standard_dock_problem(anchor, facing, dock_width, dock_height, slot)
			to_chat(user, problem ? span_warning(problem) : span_notice("Площадка и коридор свободны, все секции стены на месте."))
		if("Повернуть контроллер")
			if(!site_id && !slot)
				setDir(turn(dir, -90))
				show_layout(user, proposed_anchor(), dir, slot_width, slot_height)
		if("Зарегистрировать причал")
			var/problem = publish_slot()
			to_chat(user, problem ? span_warning(problem) : span_notice("Причал зарегистрирован и виден на навигационных консолях сектора."))
		if("Снять причал с регистрации")
			if(slot && slot == owned_slot && !owned_slot.retiring)
				owned_slot.retire()
				to_chat(user, span_notice("Новые заходы закрыты. Причал будет снят с регистрации, когда освободится."))

/** Resolve the machine-owned berth or the mapped destination named by this controller. */
/obj/machinery/computer/stationtrauma_dock_controller/proc/find_slot()
	if(!QDELETED(owned_slot))
		return owned_slot
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	var/datum/stationtrauma_overmap_sector/space/sector = host ? host.sector : SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	var/datum/stationtrauma_overmap_site/space/site = sector?.sites[site_id]
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site?.berth
	return istype(slot) && site.host == host ? slot : null

/obj/machinery/computer/stationtrauma_dock_controller/proc/slot_site(obj/docking_port/stationary/stationtrauma_space_station/standard/slot)
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	var/datum/stationtrauma_overmap_sector/space/sector = host ? host.sector : SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	var/datum/stationtrauma_overmap_site/space/site = sector?.sites[slot?.site_id]
	return !QDELETED(site) && site.berth == slot && site.host == host ? site : null

/// Naming is available on this controller's draft, active runtime berth or explicitly linked mapped berth.
/obj/machinery/computer/stationtrauma_dock_controller/proc/can_name_dock(mob/user, obj/docking_port/stationary/stationtrauma_space_station/standard/slot)
	if(QDELETED(src) || QDELETED(user) || !can_interact(user) || panel_open || !anchored || !is_operational || find_slot() != slot)
		return FALSE
	if(!slot)
		return !site_id
	if(QDELETED(slot) || slot.z != z || (slot == owned_slot && owned_slot.retiring))
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = slot_site(slot)
	return !QDELETED(site) && site.berth == slot

/// Keep the navigation ID and reservations intact while changing the visible name.
/obj/machinery/computer/stationtrauma_dock_controller/proc/name_dock(mob/user, obj/docking_port/stationary/stationtrauma_space_station/standard/slot)
	if(!can_name_dock(user, slot))
		return
	var/turf/controller_turf = get_turf(src)
	var/controller_direction = dir
	var/configured_site_id = site_id
	var/datum/stationtrauma_overmap_site/space/site = slot ? slot_site(slot) : null
	var/old_name = slot ? slot.station_name : dock_name
	var/input_name = tgui_input_text(user, "Введите название причала.", "Название причала", old_name, max_length = MAX_NAME_LEN, encode = FALSE)
	if(!istext(input_name) || !input_name || !can_name_dock(user, slot) || get_turf(src) != controller_turf || dir != controller_direction || site_id != configured_site_id)
		return
	if(slot ? (slot_site(slot) != site || slot.station_name != old_name) : dock_name != old_name)
		return
	var/new_name = trim(input_name)
	var/static/regex/invalid_name_characters = regex(@"[<>&\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]")
	if(!length_char(new_name) || length_char(new_name) > MAX_NAME_LEN || invalid_name_characters.Find(new_name) || !filter_name_ic(new_name))
		to_chat(user, span_warning("Введите короткое название без разметки и управляющих символов."))
		return
	if(slot)
		slot.station_name = slot.name = site.name = new_name
	if(!site_id)
		dock_name = new_name
	to_chat(user, span_notice("Название причала: «[new_name]»."))

/obj/machinery/computer/stationtrauma_dock_controller/proc/dock_status(obj/docking_port/stationary/stationtrauma_space_station/standard/slot)
	if(!slot)
		if(site_id)
			return "Связанный причал не найден."
		return dock_name ? "Причал «[dock_name]» ещё не зарегистрирован." : "Площадка ещё не зарегистрирована."
	var/datum/stationtrauma_overmap_site/space/site = slot_site(slot)
	var/retirement = slot == owned_slot && owned_slot.retiring ? " Приём новых кораблей закрыт." : ""
	var/obj/docking_port/mobile/moored = slot.active_berth?.get_docked()
	if(moored)
		return "[slot.station_name] занят кораблём «[moored.name]».[retirement]"
	if(site?.docking_owner || slot.active_berth)
		return "[slot.station_name] зарезервирован.[retirement]"
	return "[slot.station_name] свободен.[retirement]"

/obj/machinery/computer/stationtrauma_dock_controller/proc/proposed_anchor()
	var/list/rotation = stationtrauma_port_rotation(dir)
	var/distance = slot_width + 3
	return locate(x - distance * rotation[1], y - distance * rotation[2], z)

/** Validate and publish a new physical destination. Returns a visible reason on failure. */
/obj/machinery/computer/stationtrauma_dock_controller/proc/publish_slot()
	if(site_id || !QDELETED(owned_slot) || !anchored || !is_operational || panel_open || !(dir in GLOB.cardinals))
		return "Контроллер уже связан с причалом или не готов к регистрации."
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	if(host && (host.preparing || host.relocating || host.approach_started || host.jump_target || host.ship_docking || host.carrier_busy()))
		return "Дождитесь завершения манёвра носителя."
	var/datum/stationtrauma_overmap_sector/space/sector = host ? host.sector : SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(!sector?.ready)
		return "Сектор ещё не готов к регистрации причалов."
	var/turf/anchor = proposed_anchor()
	var/problem = stationtrauma_standard_dock_problem(anchor, dir, slot_width, slot_height, host = host)
	if(problem)
		return problem
	var/id = "runtime_[lowertext(dock_class)]_[anchor.x]_[anchor.y]_[anchor.z]"
	if(sector.sites[id])
		return "На этой площадке уже зарегистрирован причал."
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = new(anchor)
	slot.width = slot_width
	slot.height = slot_height
	slot.dock_class = dock_class
	slot.accepted_ship_class = accepted_ship_class
	slot.setDir(dir)
	slot.site_id = id
	slot.station_name = slot.name = dock_name || "Причал [dock_class] ([anchor.x], [anchor.y], [anchor.z])"
	slot.controller_ref = WEAKREF(src)
	slot.controller_origin = get_turf(src)
	if(host)
		slot.host_ship_id = host.vessel.shuttle_id
		if(!host.register_carrier_dock(slot))
			qdel(slot, force = TRUE)
			return "Не удалось привязать причал к носителю."
		slot.published_site = sector.sites[id]
	else
		var/datum/stationtrauma_overmap_site/space/site = new
		slot.published_sector = sector
		slot.published_site = site
		site.id = id
		site.name = slot.station_name
		site.physical_docking = TRUE
		site.pos_x = 1000
		site.pos_y = 0
		site.berth = slot
		sector.sites[id] = site
	owned_slot = slot
	return null

/obj/machinery/computer/stationtrauma_dock_controller/proc/show_layout(mob/user, turf/anchor, facing, dock_width, dock_height)
	if(!user.client || !COOLDOWN_FINISHED(src, preview_cooldown))
		return
	var/list/tiles = stationtrauma_standard_dock_tiles(anchor, facing, dock_width, dock_height)
	if(!length(tiles))
		to_chat(user, span_warning("Разметка выходит за границы палубы."))
		return
	COOLDOWN_START(src, preview_cooldown, 2 SECONDS)
	var/list/images = list()
	for(var/turf/tile as anything in tiles)
		var/column = tiles[tile]
		var/color_state = column < dock_width ? "green" : column == dock_width ? "blue" : column == dock_width + 1 ? "red" : null
		if(!color_state)
			continue
		var/image/marker = image('icons/effects/alphacolors.dmi', tile, color_state, ABOVE_NORMAL_TURF_LAYER)
		SET_PLANE(marker, ABOVE_GAME_PLANE, tile)
		marker.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		images += marker
	user.client.images += images
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(stationtrauma_hide_dock_layout), WEAKREF(user.client), images), 12 SECONDS, TIMER_CLIENT_TIME)
	to_chat(user, span_notice("Зелёным показана площадка [dock_width]×[dock_height], синим — полоса трапа, красным — линия секций. Разметка видна при осмотре площадки."))

/proc/stationtrauma_hide_dock_layout(datum/weakref/viewer_ref, list/images)
	var/client/viewer = viewer_ref.resolve()
	viewer?.images -= images

/** Map each turf in the slot, clearance strip, wall and walkway to its column from the vacuum corner. */
/proc/stationtrauma_standard_dock_tiles(turf/anchor, facing, dock_width, dock_height)
	if(!anchor || !(facing in GLOB.cardinals))
		return null
	var/list/rotation = stationtrauma_port_rotation(facing)
	var/list/tiles = list()
	for(var/row in 0 to dock_height - 1)
		for(var/column in 0 to dock_width + 2)
			var/turf/tile = locate(anchor.x + column * rotation[1] - row * rotation[2], anchor.y + column * rotation[2] + row * rotation[1], anchor.z)
			if(!tile || tile.x <= TRANSITIONEDGE || tile.y <= TRANSITIONEDGE || tile.x >= world.maxx - TRANSITIONEDGE || tile.y >= world.maxy - TRANSITIONEDGE)
				return null
			tiles[tile] = column
	return tiles

/** Verify the complete installation at commissioning and before a runtime berth is reserved. */
/proc/stationtrauma_standard_dock_problem(turf/anchor, facing, dock_width, dock_height, obj/docking_port/stationary/stationtrauma_space_station/standard/current_slot, datum/stationtrauma_overmap/space/host)
	host ||= current_slot?.host
	var/list/tiles = stationtrauma_standard_dock_tiles(anchor, facing, dock_width, dock_height)
	if(!length(tiles) || (host ? QDELETED(host.vessel) || !host.vessel.contains_deck(anchor.z) : !is_station_level(anchor.z)))
		return "Причал должен целиком помещаться у станции или носителя вдали от края карты."
	var/turf/last = tiles[length(tiles)]
	for(var/obj/docking_port/stationary/other in SSshuttle.stationary_docking_ports)
		if(other == current_slot || other == current_slot?.active_berth || other.z != anchor.z || QDELETED(other) || (host && (other == host.flight_berth || other == host.vessel.get_docked())))
			continue
		var/list/bounds = other.return_coords()
		if(istype(other, /obj/docking_port/stationary/stationtrauma_space_station/standard))
			var/list/rotation = stationtrauma_port_rotation(other.dir)
			bounds[3] += 3 * rotation[1]
			bounds[4] += 3 * rotation[2]
		if(max(min(anchor.x, last.x), min(bounds[1], bounds[3])) <= min(max(anchor.x, last.x), max(bounds[1], bounds[3])) \
			&& max(min(anchor.y, last.y), min(bounds[2], bounds[4])) <= min(max(anchor.y, last.y), max(bounds[2], bounds[4])))
			return "Разметка пересекает другой причал."
	var/wall_direction = turn(facing, 90)
	for(var/turf/tile as anything in tiles)
		var/column = tiles[tile]
		if(host && column > dock_width && stationtrauma_carrier_at(tile) != host)
			return "Стена и коридор причала должны находиться на одном носителе."
		if(column <= dock_width)
			if(!stationtrauma_standard_dock_clear_space(tile, host))
				return "Площадка или полоса трапа перекрыта на ([tile.x], [tile.y])."
		else if(column == dock_width + 1)
			var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = locate() in tile
			if(!isfloorturf(tile) || QDELETED(wall) || !wall.anchored || wall.dir != wall_direction || !wall.density || wall.operating || wall.gangway)
				return "На ([tile.x], [tile.y]) нужна закрытая секция стены, направленная к площадке."
			if(!wall.hasPower() || tile.is_blocked_turf(exclude_mobs = TRUE, ignore_atoms = list(wall)))
				return "Секция стены на ([tile.x], [tile.y]) обесточена или перекрыта."
		else if(!isfloorturf(tile) || tile.is_blocked_turf(exclude_mobs = TRUE))
			return "Коридор за стыковочной стеной перекрыт на ([tile.x], [tile.y])."
	return null

/** A constructed berth owns its registry entry until the controller retires it and it becomes idle. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime
	/// Controller that commissioned this slot.
	var/datum/weakref/controller_ref
	/// A displaced controller must be returned to its original position before accepting ships.
	var/turf/controller_origin
	/// Sector that publishes the site.
	var/datum/stationtrauma_overmap_sector/space/published_sector
	/// Virtual site owned by this marker and shared by the sector registry.
	var/datum/stationtrauma_overmap_site/space/published_site
	/// Refuses new arrivals while the last reservation or occupant winds down.
	var/retiring = FALSE
	/// Deferred check only while a cleared marker still has a reservation in navigation.
	var/retire_timer

/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/Destroy(force)
	if(force)
		deltimer(retire_timer)
		var/datum/stationtrauma_overmap_sector/space/sector = host?.sector || published_sector
		unregister_carrier_dock()
		sector?.clear_station_docking_site(published_site)
		if(sector && sector.sites[site_id] == published_site)
			sector.sites -= site_id
		QDEL_NULL(published_site)
		published_sector = null
		var/obj/machinery/computer/stationtrauma_dock_controller/controller = controller_ref?.resolve()
		if(controller?.owned_slot == src)
			controller.owned_slot = null
		controller_ref = null
		controller_origin = null
	return ..()

/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/accepts(obj/docking_port/mobile/stationtrauma_space/ship)
	return !retiring && !QDELETED(published_site) && controller_valid() && ..()

/** Keep a controller attached to the same slot while the entire carrier translates or turns. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/proc/controller_valid()
	var/obj/machinery/computer/stationtrauma_dock_controller/controller = controller_ref?.resolve()
	if(QDELETED(controller) || !controller.anchored || !controller.is_operational || controller.panel_open || controller.dir != dir)
		return FALSE
	if(!host_ship_id)
		return get_turf(controller) == controller_origin && !stationtrauma_carrier_at(controller)
	if(QDELETED(host) || stationtrauma_carrier_at(controller) != host || controller.z != z)
		return FALSE
	var/list/rotation = stationtrauma_port_rotation(dir)
	return controller.x == x + (width + 3) * rotation[1] && controller.y == y + (width + 3) * rotation[2]

/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/prepare_berth(obj/docking_port/mobile/stationtrauma_space/ship)
	if(!accepts(ship) || active_berth || stationtrauma_standard_dock_problem(get_turf(src), dir, width, height, src))
		return null
	return ..()

/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/clear_berth()
	. = ..()
	if(retiring && !QDELETED(src))
		check_retired()

/** Stop accepting arrivals while retaining the marker and site for any present ship. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/proc/retire()
	retiring = TRUE
	var/datum/stationtrauma_overmap_sector/space/sector = host?.sector || published_sector
	sector?.clear_station_docking_site(published_site)
	check_retired()

/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/proc/check_retired()
	deltimer(retire_timer)
	retire_timer = null
	if(active_berth)
		return
	if(published_site?.docking_owner)
		retire_timer = addtimer(CALLBACK(src, PROC_REF(check_retired)), 5 SECONDS, TIMER_STOPPABLE)
		return
	qdel(src, force = TRUE)

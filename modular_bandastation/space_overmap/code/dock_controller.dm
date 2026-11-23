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

/** Circuitboard for a roof-level landing pad controller. */
/obj/item/circuitboard/computer/stationtrauma_dock_controller/hangar
	name = "контроллер ангара"
	build_path = /obj/machinery/computer/stationtrauma_dock_controller/hangar

/datum/design/board/shuttle/stationtrauma_dock_controller/hangar
	name = "Плата контроллера ангара"
	desc = "Регистрирует посадочную площадку для кораблей S и M на верхней палубе."
	build_path = /obj/item/circuitboard/computer/stationtrauma_dock_controller/hangar

/** A prefabricated endpoint installed on a free floor tile. */
/obj/item/stationtrauma_docking_kit
	name = "монтажный комплект стыковочного шлюза"
	desc = "Установите на соседний пол, стоя со стороны герметичного помещения. Шлюз будет направлен от вас наружу, к месту стыковки."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "flatpack"
	/// The finished docking endpoint this kit installs.
	var/obj/machinery/door/airlock/stationtrauma_docking/endpoint_type

/obj/item/stationtrauma_docking_kit/wall
	name = "монтажный комплект секции стыковочной стены"
	desc = "Если пол повреждён, сначала восстановите его. Примените комплект к свободной клетке стены. Разметка причала задаст направление секции. При монтаже без разметки встаньте со стороны герметичного коридора."
	endpoint_type = /obj/machinery/door/airlock/stationtrauma_docking/wall

/obj/item/stationtrauma_docking_kit/ship
	name = "монтажный комплект корабельного стыковочного шлюза"
	endpoint_type = /obj/machinery/door/airlock/stationtrauma_docking/ship

/obj/item/stationtrauma_docking_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isturf(interacting_with) || user.combat_mode)
		return NONE
	var/turf/tile = interacting_with
	if(!can_install(tile, user))
		balloon_alert(user, "нужна свободная клетка пола рядом")
		return ITEM_INTERACT_BLOCKING
	var/facing = installation_direction(tile, user)
	if(!(facing in GLOB.cardinals))
		balloon_alert(user, "здесь не установить шлюз")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, "устанавливаю шлюз…")
	if(!do_after(user, 2 SECONDS, target = tile) || !can_install(tile, user) || facing != installation_direction(tile, user))
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/door/airlock/stationtrauma_docking/endpoint = new endpoint_type(tile)
	endpoint.setDir(facing)
	playsound(endpoint, 'sound/machines/click.ogg', 50, TRUE)
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/obj/item/stationtrauma_docking_kit/proc/can_install(turf/tile, mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && loc == user && get_turf(user) != tile && user.Adjacent(tile) && isfloorturf(tile) \
		&& !tile.is_blocked_turf() && !(locate(/obj/machinery/door) in tile)

/** Endpoints built without a dock layout face away from the builder. */
/obj/item/stationtrauma_docking_kit/proc/installation_direction(turf/tile, mob/living/user)
	return get_dir(user, tile)

/obj/item/stationtrauma_docking_kit/wall/installation_direction(turf/tile, mob/living/user)
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(tile)
	for(var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot in SSshuttle.stationary_docking_ports)
		if(QDELETED(slot) || slot.hangar || slot.z != tile.z || slot.host != host || (slot.host_ship_id && !host))
			continue
		var/facing = stationtrauma_standard_dock_wall_direction(tile, get_turf(slot), slot.dir, slot.width, slot.height)
		if(facing)
			return facing

	if(!host && !is_station_level(tile.z))
		return NONE

	// An unregistered layout can still guide placement of the wall sections.
	var/draft_facing
	for(var/obj/machinery/computer/stationtrauma_dock_controller/controller as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/stationtrauma_dock_controller))
		if(QDELETED(controller) || controller.hangar || !controller.anchored || controller.z != tile.z || controller.owned_slot)
			continue
		var/facing = stationtrauma_standard_dock_wall_direction(tile, controller.proposed_anchor(), controller.dir, controller.slot_width, controller.slot_height)
		if(!facing || stationtrauma_carrier_at(controller) != host)
			continue
		if(draft_facing && draft_facing != facing)
			return ..()
		draft_facing = facing
	return draft_facing || ..()

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
	desc = "Проверяет и регистрирует стыковочную площадку. Ставьте контроллер в двух клетках за стыковочной стеной. Офсет задаёт положение вдоль стены."
	icon_state = MAP_SWITCH("computer", "/obj/machinery/computer/shuttle")
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/stationtrauma_dock_controller
	/// Class and dimensions used when this controller creates a dock.
	var/dock_class = "S"
	/// Commission a floor-only hangar instead of a berth with a docking wall.
	var/hangar = FALSE
	/// Hull classification accepted by the controller's dock.
	var/accepted_ship_class = ST_SHIP_SMALL
	/// Width of the hull area, perpendicular to the wall.
	var/slot_width = ST_STANDARD_S_WIDTH
	/// Length of the hull area, parallel to the wall.
	var/slot_height = ST_STANDARD_S_HEIGHT
	/// Stable ID for a dock commissioned when its map or carrier loads.
	var/site_id
	/// Number of tiles along the dock from its first row to the controller.
	var/row_offset = 0
	/// Distinguishes a changed or republished layout even when its geometry returns to the same values.
	var/layout_revision = 0
	/// Position of a stationary dock on the sector chart.
	var/overmap_x = 1000
	/// Position of a stationary dock on the north-south axis of the sector chart.
	var/overmap_y = 0
	/// Runtime berth commissioned by this controller.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/owned_slot
	/// Optional display name chosen before publishing a runtime berth.
	var/dock_name
	/// Active floor overlays keyed by weak references to the clients who requested them.
	var/list/preview_viewers
	/// Debounces the client-only floor overlays.
	COOLDOWN_DECLARE(preview_cooldown)

/obj/machinery/computer/stationtrauma_dock_controller/medium
	name = "контроллер причала M"
	circuit = /obj/item/circuitboard/computer/stationtrauma_dock_controller/medium
	dock_class = "M"
	accepted_ship_class = ST_SHIP_MEDIUM
	slot_width = ST_STANDARD_M_WIDTH
	slot_height = ST_STANDARD_M_HEIGHT

/** Commissions an S/M landing pad directly beside the controller. */
/obj/machinery/computer/stationtrauma_dock_controller/hangar
	parent_type = /obj/machinery/computer/stationtrauma_dock_controller/medium
	name = "контроллер ангара"
	desc = "Проверяет и регистрирует посадочную площадку. Установите контроллер у её края на верхней палубе и проверьте разметку."
	circuit = /obj/item/circuitboard/computer/stationtrauma_dock_controller/hangar
	dock_class = "Ангар"
	hangar = TRUE

/// The home sector uses this controller's mapping settings for its fixed native berth.
/obj/machinery/computer/stationtrauma_dock_controller/station
	name = "контроллер общего станционного причала"
	desc = "Задаёт положение и габариты общего причала для навигации и служебных рейсов."
	/// Eastward offset to the fixed berth's anchor, in map tiles.
	var/berth_offset_x = 0
	/// Northward offset to the fixed berth's anchor, in map tiles.
	var/berth_offset_y = 0
	/// Number of rows behind the anchor in the fixed berth's native bounds.
	var/berth_dheight = 0

/obj/machinery/computer/stationtrauma_dock_controller/station/dock_status(obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot)
	var/datum/stationtrauma_overmap_sector/space/home = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	var/datum/stationtrauma_overmap_site/space/site = home?.sites?[site_id]
	return QDELETED(site?.berth) ? "Общий станционный причал ещё не зарегистрирован." : "Общий станционный причал «[site.name]» зарегистрирован."

/// Create the fixed berth before the sector gathers its station destinations.
/obj/machinery/computer/stationtrauma_dock_controller/station/proc/create_station_berth()
	var/turf/anchor = locate(x + berth_offset_x, y + berth_offset_y, z)
	if(!anchor || !(dir in GLOB.cardinals) || slot_width < 1 || slot_height < 1 || berth_dheight < 0 || berth_dheight >= slot_height)
		return null
	var/obj/docking_port/stationary/stationtrauma_space_station/berth = new(anchor)
	berth.setDir(dir)
	berth.width = slot_width
	berth.height = slot_height
	berth.dheight = berth_dheight
	berth.site_id = site_id
	berth.station_name = berth.name = dock_name || name
	berth.overmap_x = overmap_x
	berth.overmap_y = overmap_y
	// Runtime ports do not apply the mapload protection in stationary Initialize().
	for(var/turf/tile in berth.return_turfs())
		tile.turf_flags |= NO_RUINS
	return berth

/obj/machinery/computer/stationtrauma_dock_controller/Destroy()
	clear_layout_previews()
	if(!QDELETED(owned_slot))
		owned_slot.retire()
	owned_slot = null
	return ..()

/obj/machinery/computer/stationtrauma_dock_controller/examine(mob/user)
	. = ..()
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = owned_slot
	. += span_notice(dock_status(slot))
	if(!slot && !istype(src, /obj/machinery/computer/stationtrauma_dock_controller/station))
		if(hangar)
			. += span_notice("Для ангара нужен свободный пол [slot_width]×[slot_height] на верхней палубе. Положение площадки показывает разметка.")
		else
			. += span_notice("Направление контроллера задаёт линию из [slot_height] секций. Стена находится в двух клетках слева от этого направления.")

/obj/machinery/computer/stationtrauma_dock_controller/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(istype(src, /obj/machinery/computer/stationtrauma_dock_controller/station))
		if(ui_status(user, ui_state(user)) >= UI_UPDATE)
			to_chat(user, span_notice(dock_status(owned_slot)))
		return
	open_overmap_console(user, ui, "DockController")

/obj/machinery/computer/stationtrauma_dock_controller/ui_status(mob/user, datum/ui_state/state)
	if(panel_open || (!isobserver(user) && !can_interact(user)))
		return UI_CLOSE
	return overmap_console_status(user, ..())

/obj/machinery/computer/stationtrauma_dock_controller/ui_data(mob/user)
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = owned_slot
	var/turf/anchor = slot ? get_turf(slot) : proposed_anchor()
	return list(
		"layout_key" = layout_key(),
		"dock_name" = slot?.station_name || dock_name || name,
		"dock_class" = slot?.dock_class || dock_class,
		"status" = dock_status(slot),
		"registered" = !!slot,
		"retiring" = !!slot?.retiring,
		"configured" = !!site_id,
		"can_configure" = can_configure_layout(),
		"can_register" = !slot && anchored && !!anchor && row_offset >= 0 && row_offset < slot_height,
		"can_rename" = can_name_dock(user, slot),
		"anchor" = anchor ? list(anchor.x, anchor.y, anchor.z) : null,
		"facing" = slot?.dir || dir,
		"width" = slot?.width || slot_width,
		"height" = slot?.height || slot_height,
		"hangar" = !!hangar,
		"offset" = row_offset,
	)

/obj/machinery/computer/stationtrauma_dock_controller/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!islist(params) || !istext(params["layout_key"]) || !can_interact(user) || panel_open || istype(src, /obj/machinery/computer/stationtrauma_dock_controller/station))
		return FALSE
	if(params["layout_key"] != layout_key())
		send_layout_report(ui, "Настройки изменились. Проверьте схему и повторите действие.", TRUE)
		return TRUE
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = owned_slot
	switch(action)
		if("set_offset")
			return configure_offset(params["value"])
		if("rotate")
			if(!can_configure_layout())
				return FALSE
			setDir(turn(dir, -90))
			layout_revision++
			clear_layout_previews()
			show_layout(user, proposed_anchor(), dir, slot_width, slot_height, hangar)
			return TRUE
		if("rename")
			name_dock(user, slot)
			return TRUE
		if("preview")
			show_layout(user, slot ? get_turf(slot) : proposed_anchor(), slot?.dir || dir, slot?.width || slot_width, slot?.height || slot_height, hangar)
			return TRUE
		if("check")
			check_layout(ui, slot)
			return TRUE
		if("register")
			var/problem = publish_slot()
			if(problem)
				send_layout_report(ui, problem, TRUE)
			return TRUE
		if("retire")
			if(QDELETED(slot) || slot.retiring)
				return FALSE
			slot.retire()
			return TRUE
	return FALSE

/// Identify the layout the operator saw so an older window cannot change another layout or slot.
/obj/machinery/computer/stationtrauma_dock_controller/proc/layout_key()
	var/slot_ref = owned_slot ? REF(owned_slot) : ""
	return "[layout_revision]:[REF(get_turf(src))]:[dir]:[row_offset]:[site_id]:[slot_ref]:[!!owned_slot?.retiring]"

/obj/machinery/computer/stationtrauma_dock_controller/proc/can_configure_layout()
	return !site_id && QDELETED(owned_slot) && anchored && is_operational && !panel_open

/// A draft may shift along its edge by whole tiles. Published and mapped layouts keep their anchor.
/obj/machinery/computer/stationtrauma_dock_controller/proc/configure_offset(value)
	if(!can_configure_layout() || !IS_FINITE(value) || value != round(value) || value < 0 || value >= slot_height)
		return FALSE
	if(row_offset != value)
		row_offset = value
		layout_revision++
		clear_layout_previews()
	return TRUE

/// Report to the operator who asked for a check, tied to the layout that was inspected.
/obj/machinery/computer/stationtrauma_dock_controller/proc/send_layout_report(datum/tgui/ui, message, failed = FALSE)
	ui.send_update(list("report" = list("layout_key" = layout_key(), "message" = message, "failed" = failed)))

/obj/machinery/computer/stationtrauma_dock_controller/proc/check_layout(datum/tgui/ui, obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot)
	var/datum/stationtrauma_overmap_site/space/site = slot?.published_site
	if(slot && (slot.active_berth || site?.docking_owner || site?.shuttle_order))
		send_layout_report(ui, dock_status(slot))
		return
	var/turf/anchor = slot ? get_turf(slot) : proposed_anchor()
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	var/datum/stationtrauma_overmap_sector/space/sector = host?.sector || SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	var/mapped_outpost = site_id && !host && sector?.trade_outpost_names?["[z]"]
	var/problem = stationtrauma_standard_dock_problem(anchor, slot?.dir || dir, slot?.width || slot_width, slot?.height || slot_height, slot, host, hangar = hangar, outpost = mapped_outpost)
	var/ready_message = hangar ? "Посадочная площадка свободна." : "Площадка и коридор свободны, все секции стены на месте."
	send_layout_report(ui, problem || ready_message, !!problem)

/// Name the prepared layout or the active dock owned by this controller.
/obj/machinery/computer/stationtrauma_dock_controller/proc/can_name_dock(mob/user, obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot)
	if(QDELETED(src) || QDELETED(user) || !can_interact(user) || panel_open || !anchored || !is_operational || owned_slot != slot)
		return FALSE
	if(!slot)
		return TRUE
	if(QDELETED(slot) || slot.z != z || slot.retiring)
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = slot?.published_site
	return !QDELETED(site) && site.berth == slot

/// Keep the navigation ID and reservations intact while changing the visible name.
/obj/machinery/computer/stationtrauma_dock_controller/proc/name_dock(mob/user, obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot)
	if(!can_name_dock(user, slot))
		return
	var/previous_layout = layout_key()
	var/datum/stationtrauma_overmap_site/space/site = slot ? slot.published_site : null
	var/old_name = slot ? slot.station_name : dock_name
	var/datum/ui_state/overmap_console_prompt/prompt_state = new(src)
	var/input_name = tgui_input_text(user, "Введите название причала.", "Название причала", old_name, max_length = MAX_NAME_LEN, encode = FALSE, ui_state = prompt_state)
	qdel(prompt_state)
	if(!istext(input_name) || !input_name || !can_name_dock(user, slot) || layout_key() != previous_layout)
		return
	if(slot ? (slot.published_site != site || slot.station_name != old_name) : dock_name != old_name)
		return
	var/new_name = trim(input_name)
	var/static/regex/invalid_name_characters = regex(@"[<>&\x00-\x1f\x7f-\x9f\u200b-\u200f\u2028-\u202e\u2060-\u206f\ufeff]")
	if(!length_char(new_name) || length_char(new_name) > MAX_NAME_LEN || invalid_name_characters.Find(new_name) || !filter_name_ic(new_name))
		to_chat(user, span_warning("Введите короткое название без разметки и управляющих символов."))
		return
	if(slot)
		slot.station_name = slot.name = site.name = new_name
	dock_name = new_name
	to_chat(user, span_notice("Название причала: «[new_name]»."))

/obj/machinery/computer/stationtrauma_dock_controller/proc/dock_status(obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot)
	if(!slot)
		return dock_name ? "Причал «[dock_name]» ещё не зарегистрирован." : "Площадка ещё не зарегистрирована."
	var/datum/stationtrauma_overmap_site/space/site = slot?.published_site
	var/retirement = slot.retiring ? " Приём новых кораблей закрыт." : ""
	var/obj/docking_port/mobile/moored = slot.active_berth?.get_docked()
	if(moored)
		return "[slot.station_name] занят кораблём «[moored.name]».[retirement]"
	if(site?.docking_owner || site?.shuttle_order || slot.active_berth)
		return "[slot.station_name] зарезервирован.[retirement]"
	return "[slot.station_name] свободен.[retirement]"

/** A hangar controller sits just beyond its footprint. Walled berths leave room for the gangway and wall. */
/obj/machinery/computer/stationtrauma_dock_controller/proc/anchor_distance()
	return slot_width + (hangar ? 0 : 3)

/obj/machinery/computer/stationtrauma_dock_controller/proc/proposed_anchor()
	var/list/rotation = stationtrauma_port_rotation(dir)
	var/distance = anchor_distance()
	return locate(x - distance * rotation[1] + row_offset * rotation[2], y - distance * rotation[2] - row_offset * rotation[1], z)

/** Validate and publish a new physical destination. Returns a visible reason on failure. */
/obj/machinery/computer/stationtrauma_dock_controller/proc/publish_slot(initializing = FALSE)
	if(!QDELETED(owned_slot) || !anchored || (!initializing && !is_operational) || panel_open || !(dir in GLOB.cardinals))
		return "Контроллер уже связан с причалом или не готов к регистрации."
	var/datum/stationtrauma_overmap/space/host = stationtrauma_carrier_at(src)
	if(host && (host.preparing || host.relocating || host.approach_started || host.jump_target || host.ship_docking || host.carrier_busy()))
		return "Дождитесь завершения манёвра носителя."
	var/datum/stationtrauma_overmap_sector/space/sector = host ? host.sector : SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(QDELETED(sector) || (!initializing && !sector.ready))
		return "Сектор ещё не готов к регистрации причалов."
	var/outpost_name = host || !site_id ? null : sector.trade_outpost_names?["[z]"]
	var/turf/anchor = proposed_anchor()
	if(!anchor || row_offset < 0 || row_offset >= slot_height)
		return "Неверное положение контроллера причала."
	if(site_id)
		// Established mapped docks remain visible during repairs. Approach checks the actual route.
		if((host ? !host.vessel.contains_deck(z) : !(is_station_level(z) || outpost_name)) || !length(stationtrauma_standard_dock_tiles(anchor, dir, slot_width, slot_height, hangar)) || (hangar && !stationtrauma_hangar_top_level(anchor, host)))
			return "Разметка причала выходит за границы палубы."
	else
		var/problem = stationtrauma_standard_dock_problem(anchor, dir, slot_width, slot_height, host = host, hangar = hangar)
		if(problem)
			return problem
	var/slot_kind = hangar ? "hangar" : lowertext(dock_class)
	var/id = site_id || "runtime_[slot_kind]_[anchor.x]_[anchor.y]_[anchor.z]"
	if(sector.sites[id])
		return "На этой площадке уже зарегистрирован причал."
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = new(anchor)
	slot.width = slot_width
	slot.height = slot_height
	slot.dock_class = dock_class
	slot.hangar = hangar
	slot.accepted_ship_class = accepted_ship_class
	slot.setDir(dir)
	slot.site_id = id
	slot.configured = !!site_id
	slot.auto_approve_docking = !!outpost_name
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
		site.pos_x = overmap_x
		site.pos_y = overmap_y
		site.berth = slot
		sector.sites[id] = site
		if(outpost_name)
			sector.register_docking_berth(site, "traffic:outpost:[z]", outpost_name)
		else
			var/datum/stationtrauma_overmap_site/space/docking_target/station = sector.sites["traffic:station"]
			sector.register_docking_berth(site, "traffic:station", station?.name || "Станция")
	owned_slot = slot
	layout_revision++
	return null

/obj/machinery/computer/stationtrauma_dock_controller/proc/show_layout(mob/user, turf/anchor, facing, dock_width, dock_height, hangar)
	if(!user.client || !COOLDOWN_FINISHED(src, preview_cooldown))
		return
	var/list/tiles = stationtrauma_standard_dock_tiles(anchor, facing, dock_width, dock_height, hangar)
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
	var/client/viewer = user.client
	var/datum/weakref/viewer_ref = WEAKREF(viewer)
	viewer.images -= preview_viewers?[viewer_ref]
	LAZYSET(preview_viewers, viewer_ref, images)
	viewer.images += images
	addtimer(CALLBACK(src, PROC_REF(hide_layout_preview), viewer_ref, images), 12 SECONDS, TIMER_CLIENT_TIME)
	if(hangar)
		to_chat(user, span_notice("Зелёным показана посадочная площадка [dock_width]×[dock_height]."))
	else
		to_chat(user, span_notice("Зелёным показана площадка [dock_width]×[dock_height], синим — полоса трапа, красным — клетки секций стены. Монтажный комплект сам выставит направление на этих клетках."))

/obj/machinery/computer/stationtrauma_dock_controller/proc/hide_layout_preview(datum/weakref/viewer_ref, list/images)
	if(preview_viewers?[viewer_ref] != images)
		return
	var/client/viewer = viewer_ref.resolve()
	viewer?.images -= images
	LAZYREMOVE(preview_viewers, viewer_ref)

/obj/machinery/computer/stationtrauma_dock_controller/proc/clear_layout_previews()
	for(var/datum/weakref/viewer_ref as anything in preview_viewers)
		var/client/viewer = viewer_ref.resolve()
		viewer?.images -= preview_viewers[viewer_ref]
	preview_viewers = null
	COOLDOWN_RESET(src, preview_cooldown)

/** Map each turf to its column, including the gangway strip, wall and walkway of a walled berth. */
/proc/stationtrauma_standard_dock_tiles(turf/anchor, facing, dock_width, dock_height, hangar = FALSE)
	if(!anchor || !(facing in GLOB.cardinals))
		return null
	var/list/rotation = stationtrauma_port_rotation(facing)
	var/list/tiles = list()
	var/last_column = hangar ? dock_width - 1 : dock_width + 2
	for(var/row in 0 to dock_height - 1)
		for(var/column in 0 to last_column)
			var/turf/tile = locate(anchor.x + column * rotation[1] - row * rotation[2], anchor.y + column * rotation[2] + row * rotation[1], anchor.z)
			if(!tile || tile.x <= TRANSITIONEDGE || tile.y <= TRANSITIONEDGE || tile.x >= world.maxx - TRANSITIONEDGE || tile.y >= world.maxy - TRANSITIONEDGE)
				return null
			tiles[tile] = column
	return tiles

/** Recover the outward direction of a single wall cell without building the full dock preview. */
/proc/stationtrauma_standard_dock_wall_direction(turf/tile, turf/anchor, facing, dock_width, dock_height)
	if(!anchor || tile.z != anchor.z || !(facing in GLOB.cardinals))
		return NONE
	var/list/rotation = stationtrauma_port_rotation(facing)
	var/offset_x = tile.x - anchor.x
	var/offset_y = tile.y - anchor.y
	var/column = offset_x * rotation[1] + offset_y * rotation[2]
	var/row = offset_y * rotation[1] - offset_x * rotation[2]
	if(column != dock_width + 1 || row < 0 || row >= dock_height)
		return NONE
	return turn(facing, 90)

/** Verify the complete installation at commissioning and before a runtime berth is reserved. */
/proc/stationtrauma_standard_dock_problem(turf/anchor, facing, dock_width, dock_height, obj/docking_port/stationary/stationtrauma_space_station/standard/current_slot, datum/stationtrauma_overmap/space/host, hangar = FALSE, outpost = FALSE)
	host ||= current_slot?.host
	if(current_slot)
		hangar = current_slot.hangar
	var/list/tiles = stationtrauma_standard_dock_tiles(anchor, facing, dock_width, dock_height, hangar)
	if(!length(tiles) || (host ? QDELETED(host.vessel) || !host.vessel.contains_deck(anchor.z) : !(is_station_level(anchor.z) || outpost)))
		return "Причал должен целиком помещаться у станции или носителя вдали от края карты."
	if(hangar && !stationtrauma_hangar_top_level(anchor, host))
		return "Ангар можно разместить только на верхней палубе."
	var/turf/last = tiles[length(tiles)]
	for(var/obj/docking_port/stationary/other in SSshuttle.stationary_docking_ports)
		if(other == current_slot || other == current_slot?.active_berth || other.z != anchor.z || QDELETED(other) || (host && (other == host.flight_berth || other == host.vessel.get_docked())))
			continue
		var/list/bounds = other.return_coords()
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/other_slot = other
		if(istype(other_slot) && !other_slot.hangar)
			var/list/rotation = stationtrauma_port_rotation(other_slot.dir)
			bounds[3] += 3 * rotation[1]
			bounds[4] += 3 * rotation[2]
		if(max(min(anchor.x, last.x), min(bounds[1], bounds[3])) <= min(max(anchor.x, last.x), max(bounds[1], bounds[3])) \
			&& max(min(anchor.y, last.y), min(bounds[2], bounds[4])) <= min(max(anchor.y, last.y), max(bounds[2], bounds[4])))
			return "Разметка пересекает другой причал."
	var/wall_direction = turn(facing, 90)
	for(var/turf/tile as anything in tiles)
		if(hangar)
			if(!isfloorturf(tile) || !stationtrauma_standard_dock_clear_space(tile, host))
				return "Для посадочной площадки нужен свободный пол на ([tile.x], [tile.y])."
			continue
		var/column = tiles[tile]
		if(host && column > dock_width && stationtrauma_carrier_at(tile) != host)
			return "Стена и коридор причала должны находиться на одном носителе."
		if(column <= dock_width)
			if(!stationtrauma_standard_dock_clear_space(tile, host))
				return "Площадка или полоса трапа перекрыта на ([tile.x], [tile.y])."
		else if(column == dock_width + 1)
			var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = locate() in tile
			if(!isfloorturf(tile))
				return "Восстановите пол под секцией стены на ([tile.x], [tile.y])."
			if(QDELETED(wall))
				return "Восстановите секцию стены на ([tile.x], [tile.y]) монтажным комплектом."
			if(!wall.anchored || wall.dir != wall_direction || !wall.density || wall.operating || wall.gangway)
				return "На ([tile.x], [tile.y]) нужна закрытая секция стены, направленная к площадке."
			if(!wall.hasPower() || tile.is_blocked_turf(exclude_mobs = TRUE, ignore_atoms = list(wall)))
				return "Секция стены на ([tile.x], [tile.y]) обесточена или перекрыта."
		else if(!isfloorturf(tile) || tile.is_blocked_turf(exclude_mobs = TRUE))
			return "Коридор за стыковочной стеной перекрыт на ([tile.x], [tile.y])."
	return null

/** A constructed berth owns its registry entry until the controller retires it and it becomes idle. */
/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime
	/// Uses the route checks of a fixed map layout instead of requiring a fully clear envelope.
	var/configured = FALSE
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
		sector?.unregister_docking_berth(published_site)
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
	return controller.proposed_anchor() == get_turf(src)

/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/prepare_berth(obj/docking_port/mobile/stationtrauma_space/ship)
	if(!accepts(ship) || active_berth)
		return null
	if(!configured && stationtrauma_standard_dock_problem(get_turf(src), dir, width, height, src))
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

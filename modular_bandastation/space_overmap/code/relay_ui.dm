GLOBAL_DATUM_INIT(relay_ui_state, /datum/ui_state/relay_operator, new)

/datum/ui_state/relay_operator/can_use_topic(obj/machinery/overmap_droid_relay/relay, mob/user)
	return relay.can_operate(user) ? UI_INTERACTIVE : UI_CLOSE

/obj/machinery/overmap_droid_relay/ui_state(mob/user)
	return GLOB.relay_ui_state

/obj/machinery/overmap_droid_relay/ui_interact(mob/user, datum/tgui/ui)
	if(!can_operate(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DroidRelay", profile.role_name)
		ui.open()

/obj/machinery/overmap_droid_relay/ui_data(mob/user)
	if(!can_operate(user))
		return list()
	var/list/conduit_devices = refresh_device_links()
	var/list/units = list()
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		units += list(list(
			"id" = REF(unit), "name" = unit.name, "health" = round(unit.health), "maxHealth" = unit.maxHealth,
			"viewing" = viewing == unit, "reachable" = reaches(unit),
			"selected" = (unit in selected_units), "autonomous" = unit.can_receive_relay_order(),
			"status" = unit.in_transit ? "transit" : unit.detonating ? "detonating" : unit.polling ? "polling" : (unit.client || unit.key || unit.mind) ? "guest" : unit.order,
		))
	var/list/stock = list()
	for(var/obj/item/relay_chassis/chassis in contents)
		var/mob/living/basic/relay_droid/droid_type = chassis.droid_type
		stock += list(list(
			"id" = REF(chassis),
			"name" = capitalize(initial(droid_type.name)),
			"portrait" = droid_relay_portrait(droid_type),
			"guest" = !!chassis.stored_unit?.mind,
			"prepared" = (WEAKREF(chassis) in prepared_chassis),
		))
	var/list/transports = list()
	for(var/datum/weakref/ref as anything in transport_refs)
		var/obj/machinery/relay_transport/transport = ref.resolve()
		if(transport?.is_link_ready(src))
			transports += list(list("id" = REF(transport), "name" = transport.name))
	var/list/beacons = list()
	for(var/obj/item/relay_beacon/beacon as anything in GLOB.relay_beacons)
		var/turf/location = beacon.active_turf(src)
		if(location)
			beacons += list(list("id" = REF(beacon), "name" = "[beacon.name] · [get_area_name(location)]"))
	var/list/hostile_marks = list()
	for(var/datum/weakref/reference as anything in hostile_targets)
		hostile_marks += list(list("id" = REF(reference), "name" = hostile_targets[reference]))
	var/obj/machinery/computer/stationtrauma_space_navigation/relay_board/board = board_ref?.resolve()
	var/obj/machinery/relay_fabricator/fabricator = fabricator_ref?.resolve()
	var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
	var/datum/stationtrauma_overmap/space/chart = ship?.overmap
	var/datum/stationtrauma_overmap_site/space/selected_site = selected_site_ref?.resolve()
	return list(
		"units" = units, "stock" = stock, "limit" = profile.deployment_limit, "storageLimit" = profile.storage_limit,
		"transports" = transports, "beacons" = beacons, "sites" = chart?.known_sites() || list(),
		"site" = chart?.knows_site(selected_site) ? selected_site.id : null, "watching" = !!camera_eye,
		"armedClick" = click_order, "patrolFirst" = !!patrol_start,
		"hostileTargets" = hostile_marks,
		"computer" = !!(valid_link(board, conduit_devices) && board.can_interact(user) && board.vessel == ship && chart),
		"fabricator" = !!valid_link(fabricator, conduit_devices),
	)

/obj/machinery/overmap_droid_relay/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/actor = ui.user
	if(!can_operate(actor))
		return FALSE
	var/mob/living/basic/relay_droid/unit = locate(params["unit"]) in droids
	switch(action)
		if("select")
			select_unit(unit, params["additive"] == TRUE, params["additive"] == TRUE)
		if("select_visible")
			var/list/covered = camera_view()
			selected_units.Cut()
			for(var/mob/living/basic/relay_droid/visible_unit as anything in droids)
				if(covered[get_turf(visible_unit)] && camera_sees(visible_unit))
					selected_units += visible_unit
			update_order_displays()
		if("camera")
			if(reaches(unit))
				set_camera(unit)
		if("home")
			clear_camera()
		if("site")
			var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
			var/datum/stationtrauma_overmap/space/chart = ship?.overmap
			var/id = params["id"]
			if(!istext(id) || !chart?.knows_site(chart.sites[id]))
				return FALSE
			selected_site_ref = WEAKREF(chart.sites[id])
			cancel_click_order()
		if("cancel_order")
			cancel_click_order()
		if("mark_hostile")
			if(!camera_eye || actor.client.eye != camera_eye)
				return FALSE
			cancel_click_order()
			click_order = "mark_hostile"
			to_chat(actor, span_notice("Кликните ЛКМ по видимой цели, чтобы отметить её как враждебную. ПКМ отменяет выбор."))
		if("unmark_hostile")
			var/id = params["id"]
			if(!istext(id))
				return FALSE
			for(var/datum/weakref/reference as anything in hostile_targets)
				if(REF(reference) == id)
					return unmark_hostile(reference)
			return FALSE
		if("order")
			var/command = params["command"]
			if(!(command in list("move", "follow", "patrol", "attack", "hold")) || !length(selected_units))
				return FALSE
			cancel_click_order()
			if(command == "hold")
				issue_tactical_order("hold")
			else if(camera_eye)
				click_order = command
				to_chat(actor, span_notice("Отметьте цель в поле зрения камеры."))
		if("prepare")
			var/obj/item/relay_chassis/chassis = locate(params["chassis"]) in contents
			if(!istype(chassis))
				return FALSE
			var/datum/weakref/reference = WEAKREF(chassis)
			if(reference in prepared_chassis)
				prepared_chassis -= reference
			else
				prepared_chassis += reference
		if("deploy", "choose_drop")
			if(!length(prepared_chassis) || length(droids) >= profile.deployment_limit)
				return FALSE
			var/transport_id = params["transport"]
			var/obj/machinery/relay_transport/transport = resolve_transport(transport_id)
			if(transport_id && !transport)
				return FALSE
			var/datum/stationtrauma_overmap_site/space/site = selected_site_ref?.resolve()
			if(action == "choose_drop")
				if(!camera_eye || !transport || !site || transport.target_site(src, site.id) != site)
					to_chat(actor, span_warning("Откройте камеру и войдите в зону прибытия выбранного объекта."))
					return FALSE
				cancel_click_order()
				click_order = "drop"
				drop_transport_ref = WEAKREF(transport)
				drop_site_ref = WEAKREF(site)
				to_chat(actor, span_notice("Кликните по площадке в игровом окне для немедленной высадки. ПКМ отменяет выбор."))
				return TRUE
			var/obj/item/relay_beacon/beacon = locate(params["beacon"]) in GLOB.relay_beacons
			INVOKE_ASYNC(src, PROC_REF(request_batch_launch), actor, prepared_chassis.Copy(), transport, site, params["mode"], beacon)
		if("recover")
			var/transport_id = params["transport"]
			var/obj/machinery/relay_transport/transport = resolve_transport(transport_id)
			if(transport_id && !transport)
				return FALSE
			if(!recover_unit(unit, transport))
				to_chat(actor, span_warning("Отзыв недоступен. Проверьте дальность, связь и наличие свободного места."))
		if("control")
			take_control(unit)
		if("recruit")
			INVOKE_ASYNC(src, PROC_REF(offer_droid), actor, unit)
		if("detonate")
			INVOKE_ASYNC(src, PROC_REF(confirm_detonation), actor, unit)
		if("fabricator")
			var/list/conduit_devices = refresh_device_links()
			var/obj/machinery/relay_fabricator/fabricator = fabricator_ref?.resolve()
			if(!valid_link(fabricator, conduit_devices))
				return FALSE
			fabricator.ui_interact(actor)
		if("ship")
			var/list/conduit_devices = refresh_device_links()
			var/obj/machinery/computer/stationtrauma_space_navigation/relay_board/board = board_ref?.resolve()
			if(valid_link(board, conduit_devices))
				board.ui_interact(actor)
		if("message")
			INVOKE_ASYNC(src, PROC_REF(hivemind), actor)
		else
			return FALSE
	return TRUE

/// Resolve a requested transport within the connected set.
/obj/machinery/overmap_droid_relay/proc/resolve_transport(transport_id)
	if(!istext(transport_id))
		return null
	refresh_device_links()
	for(var/datum/weakref/ref as anything in transport_refs)
		var/obj/machinery/relay_transport/transport = ref.resolve()
		if(transport?.is_link_ready(src) && REF(transport) == transport_id)
			return transport
	return null

/// Launch a prepared group, preserving any chassis for which no slot or safe tile remains.
/obj/machinery/overmap_droid_relay/proc/request_batch_launch(mob/actor, list/batch, obj/machinery/relay_transport/transport, datum/stationtrauma_overmap_site/space/site, mode, obj/item/relay_beacon/beacon, turf/aim)
	if(!can_operate(actor) || !length(batch) || length(droids) >= profile.deployment_limit)
		return
	var/list/turf/candidates = list()
	if(transport)
		if(!site || transport.target_site(src, site.id) != site)
			to_chat(actor, span_warning("Войдите в зону прибытия выбранного объекта."))
			return
		var/turf/centre = aim
		if(mode == "aimed")
			if(!site_camera_sees(centre, site, transport) || !transport.target_valid(src, site.id, centre))
				return
		else
			centre = transport.resolve_target(src, site.id, mode, null, beacon)
		if(!can_operate(actor) || QDELETED(transport) || QDELETED(site) || selected_site_ref?.resolve() != site || transport.target_site(src, site.id) != site)
			return
		if(!centre || (mode == "beacon" && (QDELETED(beacon) || beacon.active_turf(src) != centre)))
			to_chat(actor, span_warning("Нет доступной площадки для высадки."))
			return
		candidates = spiral_range_turfs(2, centre)
	else
		for(var/heading in GLOB.cardinals)
			candidates |= get_step(src, heading)

	var/deployed = 0
	for(var/datum/weakref/reference as anything in batch)
		if(!can_operate(actor) || length(droids) >= profile.deployment_limit)
			break
		var/obj/item/relay_chassis/chassis = reference.resolve()
		if(QDELETED(chassis) || chassis.loc != src)
			prepared_chassis -= reference
			continue
		if(!(reference in prepared_chassis))
			continue
		var/turf/destination
		for(var/turf/tile in candidates)
			if(transport)
				if(!transport.target_valid(src, site.id, tile) || (mode == "aimed" && !site_camera_sees(tile, site, transport)))
					continue
			else if(!local_deployment_turf(tile))
				continue
			destination = tile
			break
		if(!destination)
			break
		candidates -= destination
		if(launch(chassis, destination, transport, transport ? site : null))
			deployed += 1
	if(deployed < length(batch))
		to_chat(actor, span_warning("Развёрнуто [deployed] из [length(batch)]. Проверьте свободные слоты и площадки."))

/// Force-moved bodies need an actual clear tile, including when the floor itself is breathable beneath a window.
/obj/machinery/overmap_droid_relay/proc/local_deployment_turf(turf/tile)
	return tile && !tile.density && is_safe_turf(tile)

/obj/machinery/overmap_droid_relay/proc/confirm_detonation(mob/actor, mob/living/basic/relay_droid/unit)
	if(!can_operate(actor) || !reaches(unit))
		return
	if(tgui_alert(actor, "Самоуничтожение корпуса [unit.name]?", "Подрыв дроида", list("Подорвать", "Отмена")) != "Подорвать")
		return
	if(can_operate(actor) && reaches(unit))
		unit.arm_self_destruct(actor)

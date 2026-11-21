/// Keep the unit selected across the map and the squad panel.
/obj/machinery/overmap_droid_relay/proc/select_unit(mob/living/basic/relay_droid/unit, additive = FALSE, toggle = FALSE)
	if(!reaches(unit))
		return
	if(!additive)
		selected_units.Cut()
	if(toggle && (unit in selected_units))
		selected_units -= unit
	else
		selected_units |= unit
	update_order_displays()

/// Drag selection is limited to connected bodies actually visible on this deck.
/obj/machinery/overmap_droid_relay/proc/select_rectangle(turf/start, turf/end, additive = FALSE)
	if(!additive)
		selected_units.Cut()
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		if(unit.z == start.z && ISINRANGE(unit.x, min(start.x, end.x), max(start.x, end.x)) \
			&& ISINRANGE(unit.y, min(start.y, end.y), max(start.y, end.y)) && camera_sees(unit))
			selected_units |= unit
	update_order_displays()

/// End a pending world click without changing the prepared stock.
/obj/machinery/overmap_droid_relay/proc/cancel_click_order()
	click_order = null
	patrol_start = null
	drop_transport_ref = null
	drop_site_ref = null

/// Apply a command only to selected, reachable autonomous units.
/obj/machinery/overmap_droid_relay/proc/issue_tactical_order(command, atom/target, turf/start)
	var/turf/target_turf = get_turf(target)
	var/issued = 0
	for(var/mob/living/basic/relay_droid/unit as anything in selected_units)
		if(!reaches(unit) || !unit.can_receive_relay_order() || (target_turf && unit.z != target_turf.z))
			continue
		if(command == "context")
			if(unit.can_attack_relay_target(target))
				issued += !!unit.receive_order("attack", target)
			else if(istype(target, /mob/living/basic/relay_droid) && (target in droids))
				issued += !!unit.receive_order("follow", target)
			else if(!isliving(target))
				issued += !!unit.receive_order("move", target_turf)
		else if(command == "patrol")
			issued += !!unit.receive_order(command, target_turf, start || get_turf(unit))
		else
			issued += !!unit.receive_order(command, target)
	if(issued)
		update_order_displays()
	return issued

/// LMB selects, RMB moves or attacks, and MMB follows or patrols to the click.
/obj/machinery/overmap_droid_relay/proc/handle_tactical_click(atom/target, list/modifiers)
	if(!camera_eye || !can_operate(operator))
		return
	if(LAZYACCESS(modifiers, BUTTON4) || LAZYACCESS(modifiers, BUTTON5))
		return
	var/button = LAZYACCESS(modifiers, BUTTON)
	var/left_click = button ? button == LEFT_CLICK : LAZYACCESS(modifiers, LEFT_CLICK)
	var/right_click = button ? button == RIGHT_CLICK : LAZYACCESS(modifiers, RIGHT_CLICK)
	var/middle_click = button ? button == MIDDLE_CLICK : LAZYACCESS(modifiers, MIDDLE_CLICK)
	if(!left_click && !right_click && !middle_click)
		return
	if(right_click && click_order)
		cancel_click_order()
		return
	if(!camera_sees(target))
		return
	var/turf/target_turf = get_turf(target)
	if(click_order == "drop")
		if(middle_click)
			return
		var/obj/machinery/relay_transport/transport = drop_transport_ref?.resolve()
		var/datum/stationtrauma_overmap_site/space/site = drop_site_ref?.resolve()
		if(!transport || !site || !site_camera_sees(target_turf, site, transport) || !transport.target_valid(src, site.id, target_turf))
			to_chat(operator, span_warning("Выберите свободную видимую площадку на выбранном объекте."))
			return
		cancel_click_order()
		INVOKE_ASYNC(src, PROC_REF(request_batch_launch), operator, prepared_chassis.Copy(), transport, site, "aimed", null, target_turf)
		return
	if(click_order)
		if(middle_click)
			return
		if(click_order == "patrol" && (!patrol_start || patrol_start.z != target_turf.z))
			patrol_start = target_turf
			to_chat(operator, span_notice("Выберите вторую точку патруля."))
			return
		var/atom/order_target = (click_order in list("attack", "follow")) ? target : target_turf
		if(issue_tactical_order(click_order, order_target, patrol_start))
			cancel_click_order()
		return
	if(right_click)
		issue_tactical_order("context", target)
	else if(middle_click)
		issue_tactical_order(isliving(target) ? "follow" : "patrol", target)
	else if(istype(target, /mob/living/basic/relay_droid) && reaches(target))
		var/additive = LAZYACCESS(modifiers, SHIFT_CLICK)
		select_unit(target, additive, additive)
	else if(!LAZYACCESS(modifiers, SHIFT_CLICK))
		selected_units.Cut()
		update_order_displays()

/// Only allied droids physically present on this site can illuminate a landing tile.
/obj/machinery/overmap_droid_relay/proc/site_camera_sees(turf/tile, datum/stationtrauma_overmap_site/space/site, obj/machinery/relay_transport/transport)
	if(!camera_sees(tile) || !transport.turf_at_site(site, tile))
		return FALSE
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		if(droid_sees(unit, tile, tile) && transport.turf_at_site(site, get_turf(unit)))
			return TRUE
	return FALSE

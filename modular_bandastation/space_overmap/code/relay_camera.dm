/mob/eye/camera/remote/relay
	name = "тактическая камера реле"
	use_visibility = FALSE
	/// The client holding the private fog images and drag signal registrations.
	var/client/observer_client
	/// Opaque camera images indexed by the turf they cover.
	var/list/image/fog = list()
	/// Visible turfs in the viewport, updated on both movement and the camera tick.
	var/list/turf/visible_tiles = list()
	/// World tile under the pressed button before any dragging.
	var/turf/drag_start_turf
	/// Which button initiated the current gesture.
	var/drag_button
	/// True once the client actually drags, independent of targets moving under the cursor.
	var/selection_dragged = FALSE
	COOLDOWN_DECLARE(pan_cooldown)

/mob/eye/camera/remote/relay/assign_user(mob/living/new_user)
	if(observer_client)
		UnregisterSignal(observer_client, list(COMSIG_CLIENT_MOUSEDOWN, COMSIG_CLIENT_MOUSEDRAG, COMSIG_CLIENT_MOUSEUP))
		observer_client.images -= assoc_to_values(fog)
		observer_client = null
	QDEL_LIST_ASSOC_VAL(fog)
	visible_tiles.Cut()
	drag_start_turf = null
	drag_button = null
	selection_dragged = FALSE
	. = ..()
	if(new_user?.client)
		observer_client = new_user.client
		RegisterSignal(observer_client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(selection_started))
		RegisterSignal(observer_client, COMSIG_CLIENT_MOUSEDRAG, PROC_REF(selection_moved))
		RegisterSignal(observer_client, COMSIG_CLIENT_MOUSEUP, PROC_REF(selection_finished))
		START_PROCESSING(SSfastprocess, src)
	else
		STOP_PROCESSING(SSfastprocess, src)

/mob/eye/camera/remote/relay/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	return ..()

/mob/eye/camera/remote/relay/update_remote_sight(mob/living/user)
	. = ..()
	// The private fog masks geometry outside the droids' line of sight.
	user.set_sight(SEE_TURFS | SEE_OBJS | SEE_MOBS)

/mob/eye/camera/remote/relay/relaymove(mob/living/user, direction)
	var/obj/machinery/overmap_droid_relay/relay = origin_ref?.resolve()
	if(!relay?.can_operate(user) || relay.camera_eye != src || user.client?.eye != src || !COOLDOWN_FINISHED(src, pan_cooldown))
		return FALSE
	var/turf/destination = get_step(src, direction)
	if(!relay.camera_sees(destination))
		return FALSE
	COOLDOWN_START(src, pan_cooldown, 0.1 SECONDS)
	setLoc(destination)
	refresh_fog()
	return TRUE

/mob/eye/camera/remote/relay/process(seconds_per_tick)
	var/obj/machinery/overmap_droid_relay/relay = origin_ref?.resolve()
	var/mob/living/user = user_ref?.resolve()
	if(!relay?.can_operate(user) || relay.camera_eye != src || user.client?.eye != src)
		relay?.clear_camera()
		return PROCESS_KILL
	if(!relay.camera_sees(get_turf(src)))
		for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
			if(relay.reaches(unit) && !unit.is_blind())
				relay.viewing = unit
				if(unit.z != z)
					relay.cancel_click_order()
				setLoc(get_turf(unit))
				break
		if(!relay.camera_sees(get_turf(src)))
			relay.clear_camera()
			return PROCESS_KILL
	refresh_fog()

/// Camera bounds on one deck, including any tiles obscured by the fog.
/mob/eye/camera/remote/relay/proc/viewport_bounds()
	var/turf/centre = get_turf(src)
	if(!centre || !observer_client)
		return null
	var/list/size = getviewsize(observer_client.view)
	var/left = FLOOR((size[1] - 1) / 2, 1)
	var/below = FLOOR((size[2] - 1) / 2, 1)
	return list(max(1, centre.x - left), max(1, centre.y - below), min(world.maxx, centre.x - left + size[1] - 1), min(world.maxy, centre.y - below + size[2] - 1))

/// Recompute the bounded viewport and reuse fog images for tiles that remain covered.
/mob/eye/camera/remote/relay/proc/refresh_fog()
	var/obj/machinery/overmap_droid_relay/relay = origin_ref?.resolve()
	var/turf/centre = get_turf(src)
	var/list/bounds = viewport_bounds()
	if(!relay || !bounds || observer_client.eye != src)
		return
	var/list/turf/revealed = list()
	var/viewport_radius = max(bounds[3] - bounds[1], bounds[4] - bounds[2])
	for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
		if(unit.z != centre.z || get_dist(unit, centre) > viewport_radius + MAX_CAMERA_RANGE || !relay.reaches(unit) || unit.is_blind())
			continue
		for(var/turf/tile in view(MAX_CAMERA_RANGE, unit))
			if(tile.z == centre.z && ISINRANGE(tile.x, bounds[1], bounds[3]) && ISINRANGE(tile.y, bounds[2], bounds[4]) && unit.in_fov(tile))
				revealed[tile] = TRUE
	var/coverage_changed = length(revealed - visible_tiles) || length(visible_tiles - revealed)
	visible_tiles = revealed

	var/list/image/next_fog = list()
	var/list/levels = SSmapping.get_connected_levels(centre) || list(centre.z)
	for(var/deck in levels)
		for(var/turf/tile as anything in block(bounds[1], bounds[2], deck, bounds[3], bounds[4], deck))
			if(revealed[tile])
				continue
			var/image/cover = fog[tile]
			if(!cover)
				var/image/template = SScameras.obscured_images[GET_TURF_PLANE_OFFSET(tile) + 1]
				cover = new /image(template)
				cover.loc = tile
				observer_client.images += cover
			else
				fog -= tile
			next_fog[tile] = cover
	for(var/turf/revealed_tile as anything in fog)
		var/image/obsolete = fog[revealed_tile]
		observer_client.images -= obsolete
		qdel(obsolete)
	fog = next_fog
	if(coverage_changed)
		relay.update_order_displays()

/// Resolve even a ground click caught by the viewport overlay, using the actual eye and view dimensions.
/mob/eye/camera/remote/relay/proc/click_turf(atom/target, list/modifiers)
	if(istype(target, /atom/movable/screen/click_catcher) || !target)
		return parse_caught_click_modifiers(modifiers, get_turf(src), observer_client)
	return get_turf(target)

/mob/eye/camera/remote/relay/proc/selection_started(client/source, atom/target, location, control, params)
	SIGNAL_HANDLER
	drag_start_turf = null
	drag_button = null
	selection_dragged = FALSE
	if(control != "mapwindow.map" || source.eye != src)
		return
	var/list/modifiers = params2list(params)
	var/button = LAZYACCESS(modifiers, BUTTON)
	if(!button)
		if(LAZYACCESS(modifiers, LEFT_CLICK))
			button = LEFT_CLICK
		else if(LAZYACCESS(modifiers, MIDDLE_CLICK))
			button = MIDDLE_CLICK
	if(button in list(LEFT_CLICK, MIDDLE_CLICK))
		drag_button = button
		drag_start_turf = isturf(location) ? location : click_turf(target, modifiers)

/mob/eye/camera/remote/relay/proc/selection_moved(client/source, atom/dragged, atom/hovered, src_location, over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(drag_start_turf && src_control == "mapwindow.map" && over_control == "mapwindow.map" && source.eye == src)
		selection_dragged = TRUE

/mob/eye/camera/remote/relay/proc/selection_finished(client/source, atom/target, location, control, params)
	SIGNAL_HANDLER
	var/turf/start = drag_start_turf
	var/started_button = drag_button
	var/did_drag = selection_dragged
	drag_start_turf = null
	drag_button = null
	selection_dragged = FALSE
	if(control != "mapwindow.map" || source.eye != src)
		return
	var/list/modifiers = params2list(params)
	var/button = LAZYACCESS(modifiers, BUTTON)
	var/obj/machinery/overmap_droid_relay/relay = origin_ref?.resolve()
	if(!start || button != started_button || !relay?.can_operate(source.mob))
		return
	var/turf/end = isturf(location) ? location : click_turf(target, modifiers)
	if(button == MIDDLE_CLICK)
		if(!did_drag && end == start)
			if(!istype(target) || istype(target, /atom/movable/screen/click_catcher))
				target = end
			relay.handle_tactical_click(target, modifiers)
		return COMPONENT_CLIENT_MOUSEUP_INTERCEPT
	if(button != LEFT_CLICK || !did_drag || !end || end == start || relay.click_order || start.z != z || end.z != z)
		return
	relay.select_rectangle(start, end, LAZYACCESS(modifiers, SHIFT_CLICK))
	return COMPONENT_CLIENT_MOUSEUP_INTERCEPT

/obj/machinery/overmap_droid_relay/remove_eye_control(mob/living/user, mob/eye/camera/remote/removed_eye)
	if(removed_eye == camera_eye)
		clear_camera()

/// Focus the tactical eye on a connected droid; WASD can then pan within the network's coverage.
/obj/machinery/overmap_droid_relay/proc/set_camera(mob/living/basic/relay_droid/unit)
	if(!can_operate(operator) || !reaches(unit) || unit.is_blind())
		return
	if(!camera_eye)
		camera_eye = new(get_turf(unit), src)
		camera_eye.assign_user(operator)
	else
		camera_eye.setLoc(get_turf(unit))
	cancel_click_order()
	viewing = unit
	if(!length(selected_units))
		select_unit(unit)
	camera_eye.refresh_fog()
	update_order_displays()

/// Return the operator to their stationary body and clear any in-world click mode.
/obj/machinery/overmap_droid_relay/proc/clear_camera()
	viewing = null
	cancel_click_order()
	if(camera_eye)
		var/mob/eye/camera/remote/relay/old_eye = camera_eye
		camera_eye = null
		old_eye.assign_user(null)
		qdel(old_eye)
	update_order_displays()

/// A cached, read-only view of the turf coverage, for private order rendering.
/obj/machinery/overmap_droid_relay/proc/camera_view()
	if(camera_eye && can_operate(operator) && operator.client.eye == camera_eye)
		return camera_eye.visible_tiles
	return list()

/// Validate a target against live line of sight from an in-range droid on this deck.
/obj/machinery/overmap_droid_relay/proc/camera_sees(atom/target)
	var/turf/tile = get_turf(target)
	if(!tile || !camera_eye || tile.z != camera_eye.z || !can_operate(operator) || operator.client.eye != camera_eye)
		return FALSE
	var/list/bounds = camera_eye.viewport_bounds()
	if(!bounds || !ISINRANGE(tile.x, bounds[1], bounds[3]) || !ISINRANGE(tile.y, bounds[2], bounds[4]))
		return FALSE
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		if(droid_sees(unit, target, tile))
			return TRUE
	return FALSE

/// Only a live, connected unit can supply line of sight to a target.
/obj/machinery/overmap_droid_relay/proc/droid_sees(mob/living/basic/relay_droid/unit, atom/target, turf/tile)
	return unit.z == tile.z && get_dist(unit, tile) <= MAX_CAMERA_RANGE && reaches(unit) && unit.in_fov(tile) \
		&& target.invisibility <= unit.see_invisible && (target in view(MAX_CAMERA_RANGE, unit))

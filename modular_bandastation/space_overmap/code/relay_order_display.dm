/// Start observing a deployed droid's orders and perspective.
/obj/machinery/overmap_droid_relay/proc/track_order_display_unit(mob/living/basic/relay_droid/unit)
	var/datum/component/relay_order_displays/displays = LoadComponent(/datum/component/relay_order_displays)
	displays.track_unit(unit)

/// Stop observing a removed droid and remove its markers from current views.
/obj/machinery/overmap_droid_relay/proc/untrack_order_display_unit(mob/living/basic/relay_droid/unit)
	var/datum/component/relay_order_displays/displays = GetComponent(/datum/component/relay_order_displays)
	displays?.untrack_unit(unit)

/// Revalidate the camera and guest views after selection, perspective or visibility changes.
/obj/machinery/overmap_droid_relay/proc/update_order_displays()
	var/datum/component/relay_order_displays/displays = GetComponent(/datum/component/relay_order_displays)
	displays?.refresh()

/// Observes the relay's deployed units, their targets and their existing JPS loops.
/datum/component/relay_order_displays
	/// Relay owning the deployment roster.
	var/obj/machinery/overmap_droid_relay/relay
	/// One private set of images for each eligible viewer.
	var/list/mob/viewers = list()
	/// External mobile order targets and marked hostiles that can change the display.
	var/list/atom/movable/watched_targets = list()
	/// Active JPS loops whose path calculation can finish without any unit movement.
	var/list/datum/move_loop/has_target/jps/watched_loops = list()
	/// Single deferred refresh for related signals emitted by the same operation.
	var/refresh_timer
	/// Changes to deployed bodies that can affect a private view.
	var/static/list/unit_signals = list(
		COMSIG_MOVABLE_MOVED,
		COMSIG_ATOM_DIR_CHANGE,
		COMSIG_MOB_CLIENT_LOGIN,
		COMSIG_MOB_RESET_PERSPECTIVE,
		COMSIG_MOB_STATCHANGE,
		COMSIG_MOB_SEE_INVIS_CHANGE,
		COMSIG_MOB_CLIENT_CHANGE_VIEW,
		COMSIG_VIEWDATA_UPDATE,
		COMSIG_MOB_AI_MOVEMENT_STARTED,
		COMSIG_AI_BLACKBOARD_KEY_SET(BB_CURRENT_PET_TARGET),
		COMSIG_AI_BLACKBOARD_KEY_CLEARED(BB_CURRENT_PET_TARGET),
	)
	/// Changes to targets outside the deployment roster.
	var/static/list/target_signals = list(
		COMSIG_MOVABLE_MOVED,
		COMSIG_QDELETING,
		COMSIG_LIVING_DEATH,
		COMSIG_ATOM_POST_DIR_CHANGE,
		COMSIG_ATOM_UPDATED_ICON,
		COMSIG_LIVING_POST_UPDATE_TRANSFORM,
		COMSIG_LIVING_UPDATE_OFFSETS,
	)

/datum/component/relay_order_displays/Initialize()
	if(!istype(parent, /obj/machinery/overmap_droid_relay))
		return COMPONENT_INCOMPATIBLE
	relay = parent

/datum/component/relay_order_displays/RegisterWithParent()
	RegisterSignal(relay, COMSIG_MOVABLE_MOVED, PROC_REF(queue_refresh))
	RegisterSignal(relay.operator, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))

/datum/component/relay_order_displays/Destroy(force)
	if(refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null
	QDEL_LIST_ASSOC_VAL(viewers)
	viewers = null
	watched_targets = null
	watched_loops = null
	relay = null
	return ..()

/// Watch changes made by a newly deployed body.
/datum/component/relay_order_displays/proc/track_unit(mob/living/basic/relay_droid/unit)
	if(unit in watched_targets)
		UnregisterSignal(unit, target_signals)
		watched_targets -= unit
	RegisterSignals(unit, unit_signals, PROC_REF(queue_refresh))
	RegisterSignal(unit, COMSIG_MOB_LOGOUT, PROC_REF(on_logout))
	schedule_refresh()

/// Release subscriptions for a body leaving the roster.
/datum/component/relay_order_displays/proc/untrack_unit(mob/living/basic/relay_droid/unit)
	// A failed deployment may remove a body before it was tracked as a relay unit.
	if(!(unit in watched_targets))
		UnregisterSignal(unit, unit_signals)
		UnregisterSignal(unit, COMSIG_MOB_LOGOUT)
	remove_viewer(unit)
	refresh()

/// Remove the old client's images before it leaves or takes over another body.
/datum/component/relay_order_displays/proc/on_logout(mob/source)
	SIGNAL_HANDLER
	remove_viewer(source)
	schedule_refresh()

/// Movement and blackboard signals can arrive before a new loop is fully installed.
/datum/component/relay_order_displays/proc/queue_refresh(datum/source)
	SIGNAL_HANDLER
	schedule_refresh()

/// Retire invalid outlines before a moved target can be drawn against stale fog.
/datum/component/relay_order_displays/proc/on_target_change(atom/movable/target)
	SIGNAL_HANDLER
	if(QDELETED(target) || !isturf(target.loc) || !target.alpha)
		for(var/mob/viewer as anything in viewers)
			var/datum/relay_order_view/order_view = viewers[viewer]
			order_view.remove_hostile_outline(target)
	else
		var/datum/relay_order_view/camera_display = viewers[relay.operator]
		if(camera_display?.outline_appearances[REF(target)])
			var/list/camera_turfs = relay.camera_view()
			if(!camera_turfs[target.loc] || !relay.camera_sees(target))
				camera_display.remove_hostile_outline(target)
	schedule_refresh()

/// Coalesce changes until the current operation has finished.
/datum/component/relay_order_displays/proc/schedule_refresh()
	if(refresh_timer || QDELETED(relay))
		return
	if(relay.camera_eye || length(viewers))
		refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh)), world.tick_lag, TIMER_STOPPABLE)
		return
	for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
		if(unit.client)
			refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh)), world.tick_lag, TIMER_STOPPABLE)
			return

/// Remove the current images and perspective subscription for one viewer.
/datum/component/relay_order_displays/proc/remove_viewer(mob/viewer)
	var/datum/relay_order_view/order_view = viewers[viewer]
	viewers -= viewer
	qdel(order_view)

/// Reconcile the roster, visible viewers and the active movement subscriptions.
/datum/component/relay_order_displays/proc/refresh()
	if(refresh_timer)
		deltimer(refresh_timer)
		refresh_timer = null
	var/list/active_viewers = list()
	if(!QDELETED(relay))
		var/list/camera_turfs = relay.camera_view()
		if(length(camera_turfs))
			active_viewers += relay.operator
			render_view(relay.operator, relay.operator.client, camera_turfs, relay.selected_units)
		var/has_hostiles = length(relay.hostile_targets)
		var/has_orders = FALSE
		for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
			if(unit.order != "hold" && unit.can_receive_relay_order())
				has_orders = TRUE
				break
		for(var/mob/living/basic/relay_droid/guest as anything in relay.droids)
			var/client/guest_client = guest.client
			if(guest_client?.mob != guest || !relay.reaches(guest) || guest.stat != STABLE || guest.is_blind())
				continue
			var/draw_orders = has_orders && guest != relay.controlled
			if(guest == relay.controlled && !has_hostiles)
				continue
			active_viewers += guest
			// Keep listening to eye changes even while the guest is looking elsewhere.
			var/list/guest_view
			var/list/guest_turfs
			if(guest_client.eye == guest && (draw_orders || has_hostiles))
				guest_view = view(guest_client.view, guest)
			if(draw_orders && length(guest_view))
				guest_turfs = list()
				for(var/turf/tile in guest_view)
					if(tile.z == guest.z && guest.in_fov(tile))
						guest_turfs[tile] = TRUE
			render_view(guest, guest_client, guest_turfs, droid_view = guest_view)
	for(var/mob/old_viewer as anything in viewers - active_viewers)
		remove_viewer(old_viewer)
	sync_order_sources(length(active_viewers))

/// Keep subscriptions limited to targets and paths that can change an active display.
/datum/component/relay_order_displays/proc/sync_order_sources(has_viewers)
	var/list/current_targets = list()
	var/list/current_loops = list()
	if(has_viewers)
		for(var/datum/weakref/hostile_ref as anything in relay.hostile_targets)
			var/mob/living/hostile = hostile_ref.resolve()
			if(hostile && hostile.stat != DEAD && !(hostile in relay.droids))
				current_targets |= hostile
		for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
			if(!unit.can_receive_relay_order() || !relay.reaches(unit) || unit.order == "hold")
				continue
			var/atom/movable/target = unit.ai_controller?.blackboard[BB_CURRENT_PET_TARGET]
			if(ismovable(target) && !QDELETED(target) && !(target in relay.droids))
				current_targets |= target
			var/datum/move_loop/has_target/jps/loop = active_jps_loop(unit)
			if(loop)
				current_loops += loop
	for(var/atom/movable/target as anything in watched_targets - current_targets)
		UnregisterSignal(target, target_signals)
	for(var/atom/movable/target as anything in current_targets - watched_targets)
		RegisterSignals(target, target_signals, PROC_REF(on_target_change))
	watched_targets = current_targets
	for(var/datum/move_loop/has_target/jps/loop as anything in watched_loops - current_loops)
		UnregisterSignal(loop, list(COMSIG_MOVELOOP_STOP, COMSIG_MOVELOOP_JPS_FINISHED_PATHING, COMSIG_QDELETING))
	for(var/datum/move_loop/has_target/jps/loop as anything in current_loops - watched_loops)
		RegisterSignals(loop, list(COMSIG_MOVELOOP_STOP, COMSIG_MOVELOOP_JPS_FINISHED_PATHING, COMSIG_QDELETING), PROC_REF(queue_refresh))
	watched_loops = current_loops

/// Resolve the current AI loop without creating a new path request.
/datum/component/relay_order_displays/proc/active_jps_loop(mob/living/basic/relay_droid/unit)
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(unit, SSai_movement)
	if(istype(loop) && !QDELETED(loop) && loop.extra_info == unit.ai_controller)
		return loop
	return null

/// Render orders and marked hostiles the viewer can currently see.
/datum/component/relay_order_displays/proc/render_view(mob/living/viewer, client/recipient, list/visible, list/selected, list/droid_view)
	var/datum/relay_order_view/order_view = viewers[viewer]
	if(order_view?.recipient != recipient)
		remove_viewer(viewer)
		order_view = new(recipient, src)
		viewers[viewer] = order_view
	var/is_operator = viewer == relay.operator
	if(length(visible))
		for(var/mob/living/basic/relay_droid/unit as anything in relay.droids)
			if(!relay.reaches(unit) || unit.invisibility > viewer.see_invisible)
				continue
			var/turf/unit_turf = unit.loc
			if(!visible[unit_turf] || (is_operator && unit.invisibility && !relay.camera_sees(unit)))
				continue
			if(selected && (unit in selected))
				order_view.add_marker(unit, unit_turf, "circle", COLOR_CYAN)
			if(!unit.can_receive_relay_order() || unit.order == "hold")
				continue
			render_unit_order(order_view, unit, unit_turf, viewer.see_invisible, visible, is_operator)
	if(is_operator || length(droid_view))
		render_hostile_outlines(order_view, viewer, is_operator, visible, droid_view)
	order_view.finish_frame()

/// Draw tags only on living bodies visible through the current perspective.
/datum/component/relay_order_displays/proc/render_hostile_outlines(datum/relay_order_view/order_view, mob/living/viewer, is_operator, list/camera_turfs, list/droid_view)
	for(var/datum/weakref/hostile_ref as anything in relay.hostile_targets)
		var/mob/living/hostile = hostile_ref.resolve()
		if(!hostile || hostile == viewer || hostile.stat == DEAD || !isturf(hostile.loc) || !hostile.alpha || hostile.invisibility > viewer.see_invisible)
			continue
		var/turf/hostile_turf = hostile.loc
		if(is_operator)
			if(!camera_turfs[hostile_turf] || !relay.camera_sees(hostile))
				continue
		else if(hostile_turf.z != viewer.z || !(hostile in droid_view) || !viewer.in_fov(hostile_turf))
			continue
		order_view.add_hostile_outline(hostile)

/// Draw the directive, visible endpoints, and only visible segments of its existing route.
/datum/component/relay_order_displays/proc/render_unit_order(datum/relay_order_view/order_view, mob/living/basic/relay_droid/unit, turf/unit_turf, see_invisible, list/visible, is_operator)
	var/static/list/order_icons = list("move" = "hudmove", "follow" = "hudcalled", "patrol" = "hudpatrol", "attack" = "hudalert")
	var/static/list/order_colors = list("move" = COLOR_PALE_GREEN, "follow" = COLOR_BLUE_LIGHT, "patrol" = COLOR_YELLOW, "attack" = COLOR_RED_LIGHT)
	var/order_icon = order_icons[unit.order]
	var/atom/target = unit.ai_controller?.blackboard[BB_CURRENT_PET_TARGET]
	if(!order_icon || QDELETED(target))
		return
	var/marker_color = order_colors[unit.order]
	order_view.add_marker(unit, unit_turf, order_icon, marker_color)
	var/turf/destination = get_turf(target)
	if(!destination)
		return
	// A live target can leave sight after an order was issued; its route would still reveal where it went.
	if(ismovable(target) && (!visible[destination] || target.invisibility > see_invisible || target.loc != destination || (is_operator && target.invisibility && !relay.camera_sees(target))))
		return
	if(unit.order == "patrol")
		var/turf/other_point = destination == unit.patrol_first ? unit.patrol_second : unit.patrol_first
		if(visible[other_point])
			order_view.add_marker(unit, other_point, "start", marker_color)
	if(visible[destination])
		order_view.add_marker(unit, destination, "end", marker_color)

	var/datum/move_loop/has_target/jps/loop = active_jps_loop(unit)
	if(!loop || !length(loop.movement_path))
		return
	// A melee route leads to a reserved flank while the order remains aimed at the visible enemy.
	var/turf/route_destination = get_turf(loop.target)
	if(!route_destination || (loop.target != target && (unit.order != "attack" || route_destination.z != destination.z)))
		return
	var/turf/path_end = loop.movement_path[length(loop.movement_path)]
	if(path_end.z != route_destination.z || get_dist(path_end, route_destination) > loop.minimum_distance)
		return
	var/turf/previous = unit_turf
	for(var/index in 1 to length(loop.movement_path))
		var/turf/current = loop.movement_path[index]
		if(current == previous)
			continue
		if(previous == unit_turf && visible[current] && get_dist(previous, current) == 1)
			order_view.add_marker(unit, unit_turf, "arrow", marker_color, get_dir(unit_turf, current))
		if(index < length(loop.movement_path) && visible[previous] && visible[current] && get_dist(previous, current) == 1)
			var/turf/next = loop.movement_path[index + 1]
			if(visible[next] && get_dist(current, next) == 1)
				order_view.add_marker(unit, current, "path_indicator", marker_color, get_dir(previous, next), get_dir(current, previous))
		previous = current

/// Owns one client's images and reuses unchanged markers from the previous frame.
/datum/relay_order_view
	/// The only client to which these images are sent.
	var/client/recipient
	/// Images sent in the previous frame, keyed by their visual parameters.
	var/list/current_images = list()
	/// Images selected for the next frame, including reused images.
	var/list/next_images = list()
	/// Original appearances used to build each private outline, keyed like the images.
	var/list/outline_appearances = list()
	/// Parent renderer, which rechecks permission after an eye change.
	var/datum/component/relay_order_displays/displays

/datum/relay_order_view/New(client/recipient, datum/component/relay_order_displays/displays)
	src.recipient = recipient
	src.displays = displays
	RegisterSignal(recipient, COMSIG_CLIENT_SET_EYE, PROC_REF(on_eye_change))

/datum/relay_order_view/Destroy()
	clear_images()
	recipient = null
	displays = null
	return ..()

/// Drop images immediately when the client switches perspective.
/datum/relay_order_view/proc/on_eye_change(client/source)
	SIGNAL_HANDLER
	clear_images()
	displays.schedule_refresh()

/// Drop only the images owned by this display.
/datum/relay_order_view/proc/clear_images()
	for(var/key in current_images)
		recipient?.images -= current_images[key]
	current_images.Cut()
	next_images.Cut()
	outline_appearances.Cut()

/// Attach the outline to the target so engine visibility and fog still apply to it.
/datum/relay_order_view/proc/add_hostile_outline(mob/living/hostile)
	var/key = REF(hostile)
	var/image/outline = current_images[key]
	var/original_appearance = hostile.appearance
	if(!outline || outline_appearances[key] != original_appearance)
		var/mutable_appearance/outlined_appearance = new(original_appearance)
		outlined_appearance.appearance_flags |= KEEP_APART | KEEP_TOGETHER
		outlined_appearance.override = TRUE
		outlined_appearance.add_filter("hostile_outline", 2, outline_filter(1, "#FF0022CC"))
		// The image inherits movement and transforms from its host.
		outlined_appearance.transform = null
		outlined_appearance.pixel_x = 0
		outlined_appearance.pixel_y = 0
		if(outline)
			outline.appearance = outlined_appearance
		else
			outline = image(outlined_appearance, hostile)
			outline.override = TRUE
			recipient.images += outline
		outline_appearances[key] = original_appearance
	current_images -= key
	next_images[key] = outline

/// Drop a target's outline before the next display refresh.
/datum/relay_order_view/proc/remove_hostile_outline(atom/movable/target)
	var/key = REF(target)
	var/image/outline = current_images[key]
	if(!outline)
		return
	recipient.images -= outline
	current_images -= key
	outline_appearances -= key

/// Reuse the previous marker when its location, style and direction are unchanged.
/datum/relay_order_view/proc/add_marker(mob/living/basic/relay_droid/unit, turf/location, icon_state, color, direction = SOUTH, previous_direction = NONE)
	var/key = "[REF(unit)]/[REF(location)]/[icon_state]/[color]/[direction]/[previous_direction]"
	if(next_images[key])
		return
	var/image/marker = current_images[key]
	if(marker)
		current_images -= key
	else
		if(icon_state == "path_indicator")
			marker = image('icons/mob/silicon/aibots.dmi', location, icon_state, BOT_PATH_LAYER, direction)
			if(ISDIAGONALDIR(direction) && (previous_direction & (NORTH|SOUTH)))
				var/turn_value = (direction == SOUTHWEST || direction == NORTHEAST) ? 90 : -90
				marker.transform = marker.transform.Turn(turn_value)
				marker.transform = marker.transform.Scale(1, -1)
		else if(copytext(icon_state, 1, 4) == "hud")
			marker = image('icons/mob/huds/hud.dmi', location, icon_state, ABOVE_MOB_LAYER)
			marker.pixel_y = 12
		else
			marker = image('icons/turf/debug.dmi', location, icon_state, BOT_PATH_LAYER, direction)
		SET_PLANE(marker, GAME_PLANE, location)
		marker.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		marker.color = color
		recipient.images += marker
	next_images[key] = marker

/// Retire markers that are no longer authorized or present in the current frame.
/datum/relay_order_view/proc/finish_frame()
	for(var/key in current_images)
		recipient.images -= current_images[key]
		outline_appearances -= key
	current_images.Cut()
	var/list/retired_images = current_images
	current_images = next_images
	next_images = retired_images

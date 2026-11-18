/// Configuration shared by all installations running this relay role.
/datum/droid_relay_profile
	/// Role name shown to the operator and potential guest pilots.
	var/role_name = "Оператор дроидов"
	/// Printed bodies this relay can manufacture and deploy.
	var/mob/living/basic/relay_droid/droid_type = /mob/living/basic/relay_droid
	/// Simultaneously active bodies, including bodies in transit.
	var/deployment_limit = 4
	/// Number of stored bodies the relay can physically hold.
	var/storage_limit = 8
	/// Fabricator cost in sheets of iron.
	var/iron_sheets = 3

/obj/machinery/overmap_droid_relay
	name = "реле управления дроидами"
	desc = "Терминал оператора боевого отряда. Принимает напечатанные корпуса и связывается с периферией через мультитул."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "relay"
	density = TRUE
	anchored = TRUE
	idle_power_usage = 100
	processing_flags = START_PROCESSING_MANUALLY
	/// Profile used by this installation.
	var/datum/droid_relay_profile/profile_type = /datum/droid_relay_profile
	/// Instance owned by this machine.
	var/datum/droid_relay_profile/profile
	/// Stationary body representing the operator.
	var/mob/living/basic/relay_operator/operator
	/// Active bodies and pending transports. Stored bodies are inside chassis items.
	var/list/mob/living/basic/relay_droid/droids = list()
	/// Optional peripherals, resolved again before use.
	var/datum/weakref/board_ref
	/// Optional fabricator.
	var/datum/weakref/fabricator_ref
	/// Each transport can be chosen independently.
	var/list/datum/weakref/transport_refs = list()
	/// Controlled body while the operator's mind is away from the relay.
	var/mob/living/basic/relay_droid/controlled
	/// Body supplying the active camera.
	var/mob/living/basic/relay_droid/viewing
	/// Movable eye whose view is limited to the squad's combined coverage.
	var/mob/eye/camera/remote/relay/camera_eye
	/// Bodies selected by the operator through the map or the squad panel.
	var/list/mob/living/basic/relay_droid/selected_units = list()
	/// Current click operation, chosen through TGUI.
	var/click_order
	/// Starting point while selecting a patrol.
	var/turf/patrol_start
	/// Ordered list of prepared chassis in the relay's stock.
	var/list/datum/weakref/prepared_chassis = list()
	/// Transport and site captured when the operator arms the next click.
	var/datum/weakref/drop_transport_ref
	var/datum/weakref/drop_site_ref
	/// Selected overmap site for deployment.
	var/datum/weakref/selected_site_ref

/obj/machinery/overmap_droid_relay/Initialize(mapload)
	. = ..()
	profile = new profile_type
	operator = new(src, src)
	operator.name = profile.role_name
	operator.real_name = profile.role_name

/obj/machinery/overmap_droid_relay/Destroy()
	clear_camera()
	for(var/mob/living/basic/relay_droid/unit as anything in droids.Copy())
		unit.clear_order()
		remove_unit(unit)
	for(var/obj/item/relay_chassis/chassis in contents)
		if(chassis.stored_unit)
			chassis.stored_unit.relay_ref = null
		chassis.forceMove(drop_location())
	board_ref = null
	fabricator_ref = null
	selected_site_ref = null
	selected_units.Cut()
	prepared_chassis.Cut()
	transport_refs.Cut()
	operator?.ghostize(can_reenter_corpse = FALSE, forced = TRUE)
	QDEL_NULL(operator)
	QDEL_NULL(profile)
	return ..()

/// Whether this actor is the operator and currently allowed to issue commands.
/obj/machinery/overmap_droid_relay/proc/can_operate(mob/actor)
	return !QDELETED(src) && !QDELETED(operator) && actor == operator && !controlled \
		&& actor.loc == src && actor.stat == STABLE && check_rights_for(actor.client, R_ADMIN) \
		&& anchored && !(machine_stat & (NOPOWER | BROKEN | MAINT))

/obj/machinery/overmap_droid_relay/can_interact(mob/user)
	if(istype(user, /mob/living/basic/relay_operator))
		return can_operate(user)
	return ..()

/// Take an available relay from an administrator's observer.
/obj/machinery/overmap_droid_relay/proc/claim(client/administrator)
	if(!check_rights_for(administrator, R_ADMIN) || !isobserver(administrator.mob) || QDELETED(operator) \
		|| operator.key || operator.stat == DEAD || controlled)
		return FALSE
	var/mob/dead/observer/previous = administrator.mob
	operator.PossessByPlayer(administrator.ckey)
	if(administrator.mob != operator)
		return FALSE
	qdel(previous)
	operator.reset_perspective()
	log_admin("[key_name(administrator)] took control of droid relay [src] at [AREACOORD(src)].")
	return TRUE

/// Returns the physical ship containing this relay, even without the computer.
/obj/machinery/overmap_droid_relay/proc/linked_ship()
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(src)
	return istype(ship) && ship.is_in_shuttle_bounds(src) && ship.shuttle_areas[get_area(src)] ? ship : null

/// Devices have a physical connection only on the same hull or beside a grounded relay.
/obj/machinery/overmap_droid_relay/proc/valid_link(obj/machinery/device)
	if(QDELETED(device) || !isturf(device.loc) || !isturf(loc) || !device.anchored)
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
	if(ship)
		return aboard_ship(device, ship)
	return !SSshuttle.get_containing_shuttle(device) && in_range(src, device)

/// Attaches a supported device to this relay.
/obj/machinery/overmap_droid_relay/proc/link_device(obj/machinery/device)
	if(!valid_link(device))
		return FALSE
	if(istype(device, /obj/machinery/computer/stationtrauma_space_navigation/relay_board))
		var/obj/machinery/computer/stationtrauma_space_navigation/relay_board/board = device
		var/obj/machinery/overmap_droid_relay/previous = board.relay_ref?.resolve()
		if(previous && previous != src && previous.valid_link(board))
			return FALSE
		board.relay_ref = WEAKREF(src)
		board_ref = WEAKREF(board)
	else if(istype(device, /obj/machinery/relay_fabricator))
		fabricator_ref = WEAKREF(device)
	else if(istype(device, /obj/machinery/relay_transport))
		transport_refs |= WEAKREF(device)
	else
		return FALSE
	return TRUE

/// Initial wiring for the scenario shuttle's known hardware.
/obj/machinery/overmap_droid_relay/proc/connect_peripherals()
	var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
	for(var/area/ship_area as anything in ship?.shuttle_areas)
		for(var/obj/machinery/computer/stationtrauma_space_navigation/relay_board/board in ship_area)
			link_device(board)
		for(var/obj/machinery/relay_fabricator/fabricator in ship_area)
			link_device(fabricator)
		for(var/obj/machinery/relay_transport/transport in ship_area)
			link_device(transport)
		for(var/obj/item/relay_beacon/beacon in ship_area)
			if(ship.is_in_shuttle_bounds(beacon) && !beacon.relay_ref?.resolve())
				beacon.bind(src)

/obj/machinery/overmap_droid_relay/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!check_rights_for(user.client, R_ADMIN))
		return ITEM_INTERACT_BLOCKING
	if(ismachinery(tool.buffer) && link_device(tool.buffer))
		balloon_alert(user, "периферия подключена")
	else
		tool.set_buffer(src)
		balloon_alert(user, "реле сохранено в буфер")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/overmap_droid_relay/item_interaction(mob/living/user, obj/item/item, list/modifiers)
	if(istype(item, /obj/item/relay_chassis))
		var/obj/item/relay_chassis/chassis = item
		if(chassis.droid_type != profile.droid_type || chassis.stored_unit || !has_storage_space())
			balloon_alert(user, "нет места или корпус несовместим")
			return ITEM_INTERACT_BLOCKING
		if(user.transferItemToLoc(chassis, src))
			balloon_alert(user, "корпус загружен")
		return ITEM_INTERACT_SUCCESS
	if(istype(item, /obj/item/relay_beacon) && check_rights_for(user.client, R_ADMIN))
		var/obj/item/relay_beacon/beacon = item
		beacon.bind(src)
		balloon_alert(user, "маяк привязан")
		return ITEM_INTERACT_SUCCESS
	return ..()

/// True for active units receiving the signal of this installation.
/obj/machinery/overmap_droid_relay/proc/reaches(mob/living/basic/relay_droid/unit)
	if(QDELETED(unit) || !(unit in droids) || unit.stat == DEAD || unit.in_transit || !isturf(unit.loc))
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
	if(aboard_ship(unit, ship))
		return TRUE
	var/datum/stationtrauma_overmap_sector/space/sector = unit.sector_ref?.resolve()
	if(sector)
		return ship?.overmap?.sector == sector && !ship.overmap.jump_target
	return z == unit.z

/// A body on this hull stays in local contact as the hull changes sectors.
/obj/machinery/overmap_droid_relay/proc/aboard_ship(atom/movable/body, obj/docking_port/mobile/stationtrauma_space/ship)
	return ship && ship.shuttle_areas[get_area(body)] && ship.is_in_shuttle_bounds(body) && SSshuttle.get_containing_shuttle(body) == ship

/obj/machinery/overmap_droid_relay/process(seconds_per_tick)
	if(!length(droids))
		return PROCESS_KILL
	update_order_displays()


/// Consume a compatible printed chassis and track its living independent body.
/obj/machinery/overmap_droid_relay/proc/launch(obj/item/relay_chassis/chassis, turf/destination, obj/machinery/relay_transport/transport, datum/stationtrauma_overmap_site/space/site)
	if(QDELETED(chassis) || chassis.loc != src || chassis.droid_type != profile.droid_type || length(droids) >= profile.deployment_limit || !destination)
		return FALSE
	var/mob/living/basic/relay_droid/unit = chassis.stored_unit
	if(unit && (QDELETED(unit) || unit.stat == DEAD || unit.loc != chassis))
		return FALSE
	var/new_unit = !unit
	if(new_unit)
		unit = new chassis.droid_type(chassis)
	var/obj/docking_port/mobile/stationtrauma_space/ship = linked_ship()
	unit.relay_ref = WEAKREF(src)
	unit.sector_ref = ship?.overmap?.sector ? WEAKREF(ship.overmap.sector) : null
	unit.site_ref = site ? WEAKREF(site) : null
	droids += unit
	RegisterSignals(unit, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(unit_lost))
	var/deployed = transport ? transport.deploy(unit, destination) : unit.forceMove(destination)
	if(!deployed)
		remove_unit(unit)
		if(new_unit)
			qdel(unit)
		return FALSE
	chassis.clear_stored_unit()
	prepared_chassis -= WEAKREF(chassis)
	qdel(chassis)
	track_order_display_unit(unit)
	START_PROCESSING(SSmachines, src)
	if(!unit.in_transit)
		unit.reset_perspective()
	return TRUE

/// Stop counting a unit as active.
/obj/machinery/overmap_droid_relay/proc/remove_unit(mob/living/basic/relay_droid/unit)
	if(viewing == unit)
		viewing = null
	selected_units -= unit
	if(controlled == unit)
		release_control(unit)
	droids -= unit
	untrack_order_display_unit(unit)
	UnregisterSignal(unit, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	unit.site_ref = null
	unit.sector_ref = null

/obj/machinery/overmap_droid_relay/proc/unit_lost(mob/living/basic/relay_droid/unit)
	SIGNAL_HANDLER
	remove_unit(unit)
	unit.relay_ref = null

/// Assign the operator's own mind to a free body; guests keep possession of theirs.
/obj/machinery/overmap_droid_relay/proc/take_control(mob/living/basic/relay_droid/unit)
	if(!can_operate(operator) || !reaches(unit) || unit.client || unit.key || unit.mind || unit.polling || !operator.mind)
		return
	clear_camera()
	unit.clear_order()
	controlled = unit
	operator.mind.transfer_to(unit)
	if(unit.mind)
		unit.reset_perspective()
		// A deliberate transfer out of the relay console also runs Logout.
		if(!operator.player_logged && !operator.mind && !operator.client)
			var/datum/element/ssd/ssd = SSdcs.GetElement(list(/datum/element/ssd), init_element = FALSE)
			ssd?.handle_detach(operator)

/// Return from manual control. Called before a controlled body is destroyed.
/obj/machinery/overmap_droid_relay/proc/release_control(mob/living/basic/relay_droid/unit)
	if(controlled != unit)
		return
	controlled = null
	if(QDELETED(src) || QDELETED(operator) || operator.stat == DEAD || !unit.mind)
		return
	unit.mind.transfer_to(operator)
	operator.reset_perspective()
	if(QDELETED(unit) || unit.client || unit.mind)
		return
	if(unit.key)
		unit.key = null
	// Logout marks the old body SSD even when its pilot intentionally transferred away.
	if(!unit.player_logged)
		var/datum/element/ssd/ssd = SSdcs.GetElement(list(/datum/element/ssd), init_element = FALSE)
		ssd?.handle_detach(unit)
	unit.ai_controller?.reset_ai_status()

/// Recruit a guest without authorizing them to operate the relay.
/obj/machinery/overmap_droid_relay/proc/offer_droid(mob/actor, mob/living/basic/relay_droid/unit)
	if(!can_operate(actor) || !reaches(unit) || unit.client || unit.key || unit.mind || unit.polling || !(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER))
		return
	unit.polling = TRUE
	var/mob/dead/observer/chosen = SSpolling.poll_ghosts_for_target(
		question = "Управлять боевым дроном? Оператор может отозвать или подорвать ваш корпус.",
		check_jobban = ROLE_SENTIENCE,
		poll_time = 15 SECONDS,
		checked_target = unit,
		alert_pic = unit,
		role_name_text = "Боевой дроид",
	)
	if(QDELETED(unit))
		return
	unit.polling = FALSE
	if(!can_operate(actor) || !reaches(unit) || unit.client || unit.key || unit.mind || !chosen?.client || !(GLOB.ghost_role_flags & GHOSTROLE_SPAWNER))
		return
	unit.clear_order()
	unit.PossessByPlayer(chosen.ckey)

/// Recall an active unit into a physical storage chassis.
/obj/machinery/overmap_droid_relay/proc/recover_unit(mob/living/basic/relay_droid/unit, obj/machinery/relay_transport/transport)
	if(!reaches(unit) || unit.polling || unit.detonating || !has_storage_space())
		return FALSE
	var/turf/pad = get_turf(src)
	if(transport)
		if(!transport.is_link_ready(src))
			return FALSE
		if(!aboard_ship(unit, linked_ship()))
			var/datum/stationtrauma_overmap_site/space/site = unit.site_ref?.resolve()
			if(!transport.turf_at_site(site, get_turf(unit)))
				site = selected_site_ref?.resolve()
			if(!site || transport.target_site(src, site.id) != site || !transport.turf_at_site(site, get_turf(unit)))
				return FALSE
		if(!transport.recall(unit, pad))
			return FALSE
	else if(!Adjacent(unit))
		return FALSE
	return stow_unit(unit)

/// Complete a return, including rollback of a launch that lost its landing zone.
/obj/machinery/overmap_droid_relay/proc/stow_unit(mob/living/basic/relay_droid/unit)
	if(QDELETED(src) || QDELETED(unit) || unit.stat == DEAD || !(unit in droids))
		return FALSE
	var/obj/item/relay_chassis/chassis = new(src, unit.type)
	unit.clear_order()
	remove_unit(unit)
	chassis.stow(unit)
	unit.forceMove(chassis)
	unit.reset_perspective(src)
	return TRUE

/// Announce a message to the connected participants of this relay.
/obj/machinery/overmap_droid_relay/proc/hivemind(mob/living/speaker)
	if(!can_operate(speaker) && !reaches(speaker))
		return
	var/message = tgui_input_text(speaker, "Сообщение отряду", "Канал реле", max_length = MAX_MESSAGE_LEN)
	if(!message || QDELETED(src) || QDELETED(speaker) || !speaker.client || speaker.stat == DEAD \
		|| (!can_operate(speaker) && !reaches(speaker)))
		return
	var/text = span_robot("<b>Канал реле · [speaker.name]</b>: [html_encode(message)]")
	if(operator?.client)
		to_chat(operator, text)
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		if(unit.client && reaches(unit))
			to_chat(unit, text)
	speaker.log_talk(message, LOG_SAY, tag = "droid relay")

/// In-flight capsules keep room available in case the delivery must be rolled back.
/obj/machinery/overmap_droid_relay/proc/has_storage_space()
	var/count = 0
	for(var/obj/item/relay_chassis/chassis in contents)
		count += 1
	for(var/mob/living/basic/relay_droid/unit as anything in droids)
		if(unit.in_transit)
			count += 1
	return count < profile.storage_limit

/obj/item/circuitboard/computer/relay_board
	name = "бортовой компьютер"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/stationtrauma_space_navigation/relay_board

/obj/machinery/computer/stationtrauma_space_navigation/relay_board
	name = "бортовой компьютер"
	desc = "Единый пост навигации, блюспейс-переходов и управления транспондером."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "computer"
	icon_keyboard = null
	icon_screen = null
	circuit = /obj/item/circuitboard/computer/relay_board
	/// Operator on this same hull may use the normal helm commands remotely.
	var/datum/weakref/relay_ref

GLOBAL_DATUM_INIT(relay_board_state, /datum/ui_state/default/relay_board, new)

/datum/ui_state/default/relay_board/can_use_topic(obj/machinery/computer/stationtrauma_space_navigation/relay_board/board, mob/user)
	if(istype(user, /mob/living/basic/relay_operator))
		return board.can_interact(user) ? UI_INTERACTIVE : UI_CLOSE
	return ..()

/obj/machinery/computer/stationtrauma_space_navigation/relay_board/ui_state(mob/user)
	return GLOB.relay_board_state

/obj/machinery/computer/stationtrauma_space_navigation/relay_board/can_interact(mob/user)
	if(!istype(user, /mob/living/basic/relay_operator))
		return ..()
	var/obj/machinery/overmap_droid_relay/relay = relay_ref?.resolve()
	return relay?.can_operate(user) && relay.board_ref?.resolve() == src && relay.valid_link(src) \
		&& relay.linked_ship() == vessel && !QDELETED(vessel?.overmap) && !panel_open \
		&& !(machine_stat & (NOPOWER | BROKEN | MAINT))

/obj/machinery/computer/stationtrauma_space_navigation/relay_board/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!check_rights_for(user.client, R_ADMIN))
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/overmap_droid_relay/relay = tool.buffer
	if(istype(relay) && relay.link_device(src))
		balloon_alert(user, "компьютер подключён")
	else
		tool.set_buffer(src)
		balloon_alert(user, "компьютер сохранён в буфер")
	return ITEM_INTERACT_SUCCESS

/// A single working transponder may be switched by the board.
/obj/machinery/computer/stationtrauma_space_navigation/relay_board/proc/transponder()
	for(var/obj/machinery/computer/stationtrauma_transponder/device as anything in vessel?.transponders)
		if(!QDELETED(device) && device.anchored && !(device.machine_stat & (NOPOWER | BROKEN | MAINT)) \
			&& vessel.is_in_shuttle_bounds(device))
			return device
	return null

/obj/machinery/computer/stationtrauma_space_navigation/relay_board/ui_data(mob/user)
	. = ..()
	if(!vessel?.overmap)
		return
	var/datum/stationtrauma_overmap/space/navigation = vessel.overmap
	var/obj/machinery/computer/stationtrauma_transponder/device = transponder()
	.["board"] = list("jumps" = navigation.jump_data(), "transponder" = device ? device.ui_data(user) : null)

/obj/machinery/computer/stationtrauma_space_navigation/relay_board/navigation_command(action, value)
	if(!(action in list("jump", "transponder")))
		return ..()
	var/datum/stationtrauma_overmap/space/navigation = vessel?.overmap
	if(QDELETED(navigation) || panel_open || (machine_stat & (NOPOWER | BROKEN | MAINT)))
		return FALSE
	if(action == "jump")
		return istext(value) && navigation.request_jump(value)
	var/obj/machinery/computer/stationtrauma_transponder/device = transponder()
	if(!device)
		return FALSE
	device.enabled = !device.enabled
	return TRUE

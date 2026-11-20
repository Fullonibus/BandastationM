#define SPACEPOD_CAMERA_VIEW_BONUS 10
#define SPACEPOD_ACTION_KEYS "spacepod_action_keys"

/obj/vehicle/sealed/spacepod/generate_actions()
	initialize_passenger_action_type(/datum/action/vehicle/sealed/spacepod/status)
	initialize_passenger_action_type(/datum/action/vehicle/sealed/spacepod/eject)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/internals, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/lights, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/brakes, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/camera_zoom, VEHICLE_CONTROL_DRIVE)

/datum/action/vehicle/sealed/spacepod
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	/// The native vehicle owns the action and clears it on the occupant's exit.
	var/obj/vehicle/sealed/spacepod/pod

/obj/vehicle/sealed/spacepod/generate_action_type(actiontype)
	. = ..()
	if(istype(., /datum/action/vehicle/sealed/spacepod))
		var/datum/action/vehicle/sealed/spacepod/pod_action = .
		pod_action.pod = src

/datum/action/vehicle/sealed/spacepod/Destroy()
	pod = null
	return ..()

/datum/action/vehicle/sealed/spacepod/IsAvailable(feedback = FALSE)
	return ..() && !QDELETED(pod) && pod.is_occupant(owner) && owner.loc == pod

/datum/action/vehicle/sealed/spacepod/Grant(mob/grant_to)
	if(!grant_to || grant_to == owner)
		return ..()
	var/client/viewer = GET_CLIENT(grant_to)
	var/list/bindings = SANITIZE_LIST(viewer?.prefs?.savefile?.get_entry(SPACEPOD_ACTION_KEYS))
	full_key = validated_key(bindings["[type]"])
	return ..()

/datum/action/vehicle/sealed/spacepod/begin_creating_bind(atom/movable/screen/movable/action_button/current_button, mob/user)
	if(user != owner || !current_button || !IsAvailable())
		return
	var/datum/preferences/preferences = user.client?.prefs
	if(!preferences?.savefile)
		return
	if(full_key)
		set_key(null)
		return
	var/new_key = tgui_input_keycombo(user, "Пожалуйста, привяжите клавишу для этого действия.")
	if(QDELETED(src) || QDELETED(user) || user != owner || user.client?.prefs != preferences || full_key || !IsAvailable())
		return
	if(validated_key(new_key))
		set_key(new_key)

/datum/action/vehicle/sealed/spacepod/set_key(new_full_key)
	new_full_key = validated_key(new_full_key)
	. = ..()
	var/client/viewer = owner ? GET_CLIENT(owner) : null
	var/datum/preferences/preferences = viewer?.prefs
	if(!preferences?.savefile)
		return
	var/list/bindings = SANITIZE_LIST(preferences.savefile.get_entry(SPACEPOD_ACTION_KEYS))
	if(new_full_key)
		bindings["[type]"] = new_full_key
	else
		bindings -= "[type]"
	preferences.savefile.set_entry(SPACEPOD_ACTION_KEYS, bindings)
	preferences.save_preferences()

/// Action buttons render the key in maptext, so saved values cannot contain markup.
/datum/action/vehicle/sealed/spacepod/proc/validated_key(key)
	var/static/regex/valid_key = regex(@"^[^<>&\r\n\t]{1,32}$")
	return istext(key) && valid_key.Find(key) ? key : null

/datum/action/vehicle/sealed/spacepod/status
	name = "Состояние челнока"
	desc = "Открывает бортовой монитор с телеметрией и управлением системами челнока."
	button_icon_state = "mech_view_stats"
	check_flags = AB_CHECK_CONSCIOUS

/datum/action/vehicle/sealed/spacepod/status/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(.)
		pod.ui_interact(owner)

/datum/action/vehicle/sealed/spacepod/eject
	name = "Выйти из челнока"
	button_icon_state = "mech_eject"
	check_flags = AB_CHECK_CONSCIOUS

/datum/action/vehicle/sealed/spacepod/eject/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(.)
		pod.exit_pod(owner)

/datum/action/vehicle/sealed/spacepod/internals
	name = "Переключить баллон"
	desc = "Переключает дыхание между внутренней кабиной и внешней атмосферой."
	button_icon_state = "mech_cabin_closed"

/datum/action/vehicle/sealed/spacepod/internals/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(. && pod.toggle_internal_tank(owner))
		button_icon_state = pod.use_internal_tank ? "mech_cabin_closed" : "mech_cabin_open"
		build_all_button_icons()

/datum/action/vehicle/sealed/spacepod/lights
	name = "Переключить прожектор"
	button_icon_state = "mech_lights_off"

/datum/action/vehicle/sealed/spacepod/lights/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(. && pod.toggleLights(owner))
		button_icon_state = "mech_lights_[pod.lights ? "on" : "off"]"
		build_all_button_icons()

/datum/action/vehicle/sealed/spacepod/brakes
	name = "Тормоз челнока"
	desc = "Усиливает автоматическое торможение, когда отпущены клавиши движения."
	button_icon_state = "mech_safeties_off"

/datum/action/vehicle/sealed/spacepod/brakes/Grant(mob/grant_to)
	button_icon_state = pod?.flight?.brakes ? "mech_safeties_on" : "mech_safeties_off"
	return ..()

/datum/action/vehicle/sealed/spacepod/brakes/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(. && pod.can_control(owner) && pod.flight.toggle_brakes())
		button_icon_state = pod.flight.brakes ? "mech_safeties_on" : "mech_safeties_off"
		build_all_button_icons()
		pod.balloon_alert(owner, pod.flight.brakes ? "усиленное торможение включено" : "усиленное торможение выключено")

/datum/action/vehicle/sealed/spacepod/camera_zoom
	name = "Отдалить камеру"
	desc = "Расширяет обзор вокруг челнока. Повторное нажатие возвращает прежний масштаб."
	button_icon_state = "mech_zoom_off"
	check_flags = AB_CHECK_CONSCIOUS
	/// The viewport this action changed, even if the pilot has since lost their client.
	var/datum/view_data/zoomed_view
	/// View offsets after applying the zoom, used to detect an override by another effect.
	var/zoomed_width
	/// See zoomed_width.
	var/zoomed_height

/datum/action/vehicle/sealed/spacepod/camera_zoom/Trigger(mob/clicker, trigger_flags)
	. = ..()
	var/client/viewer = owner?.client
	if(!. || !viewer?.view_size || viewer.eye != pod || !pod?.can_control(owner))
		return FALSE
	if(zoomed_view)
		restore_view(owner)
		return TRUE

	zoomed_view = viewer.view_size
	zoomed_width = zoomed_view.width + SPACEPOD_CAMERA_VIEW_BONUS
	zoomed_height = zoomed_view.height + SPACEPOD_CAMERA_VIEW_BONUS
	RegisterSignal(owner, COMSIG_MOB_LOGOUT, PROC_REF(on_view_lost))
	RegisterSignal(owner, COMSIG_VIEWDATA_UPDATE, PROC_REF(on_view_size_changed))
	RegisterSignal(viewer, COMSIG_CLIENT_SET_EYE, PROC_REF(on_view_lost))
	button_icon_state = "mech_zoom_on"
	zoomed_view.add(SPACEPOD_CAMERA_VIEW_BONUS)
	build_all_button_icons()

/datum/action/vehicle/sealed/spacepod/camera_zoom/Remove(mob/remove_from)
	restore_view(remove_from)
	return ..()

/datum/action/vehicle/sealed/spacepod/camera_zoom/proc/on_view_lost()
	SIGNAL_HANDLER
	restore_view(owner)

/datum/action/vehicle/sealed/spacepod/camera_zoom/proc/on_view_size_changed()
	SIGNAL_HANDLER
	if(zoomed_view && (zoomed_view.width != zoomed_width || zoomed_view.height != zoomed_height))
		restore_view(owner)

/datum/action/vehicle/sealed/spacepod/camera_zoom/proc/restore_view(mob/pilot)
	if(!zoomed_view)
		return
	var/datum/view_data/previous_view = zoomed_view
	zoomed_view = null
	var/client/viewer = previous_view.chief
	UnregisterSignal(pilot, list(COMSIG_MOB_LOGOUT, COMSIG_VIEWDATA_UPDATE))
	if(!QDELETED(viewer))
		UnregisterSignal(viewer, COMSIG_CLIENT_SET_EYE)
		if(viewer.mob && previous_view.width == zoomed_width && previous_view.height == zoomed_height)
			previous_view.add(-SPACEPOD_CAMERA_VIEW_BONUS)
	button_icon_state = "mech_zoom_off"
	build_all_button_icons()

/// Mouse steering is scoped to a conscious pilot inside their own pod.
/client/MouseMove(object, location, control, params)
	. = ..()
	if((control != "mapwindow.map" && control != "map") || !istype(mob?.loc, /obj/vehicle/sealed/spacepod))
		return
	if(istype(object, /atom/movable/screen) && !istype(object, /atom/movable/screen/click_catcher))
		return
	var/obj/vehicle/sealed/spacepod/pod = mob.loc
	pod.aim_from_mouse(mob, params)

/obj/vehicle/sealed/spacepod/proc/aim_from_mouse(mob/living/user, params)
	if(!can_control(user) || !user.client || user.client.eye != src || !istext(params))
		return FALSE
	var/list/modifiers = params2list(params)
	var/screen_position = modifiers[SCREEN_LOC]
	if(!istext(screen_position) || length(screen_position) > 32)
		return FALSE
	var/list/axes = splittext(screen_position, ",")
	if(length(axes) != 2)
		return FALSE
	var/list/view_size = getviewsize(user.client.view)
	var/list/screen_pixels = list()
	for(var/index in 1 to 2)
		var/list/axis = splittext(axes[index], ":")
		if(length(axis) != 2)
			return FALSE
		var/tile = text2num(axis[1])
		var/pixel = text2num(axis[2])
		if(!isnum(tile) || !isnum(pixel) || tile < 1 || tile > view_size[index] || pixel < 0 || pixel > ICON_SIZE_ALL)
			return FALSE
		screen_pixels += (tile - 1) * ICON_SIZE_ALL + pixel
	// The flight camera follows the hull; its own offset must not steer the nose each tile.
	var/list/flight_camera = flight.camera_offsets[user]
	var/dx = screen_pixels[1] - view_size[1] * ICON_SIZE_X / 2 + user.client.pixel_x - (flight_camera ? flight_camera[1] : 0)
	var/dy = screen_pixels[2] - view_size[2] * ICON_SIZE_Y / 2 + user.client.pixel_y - (flight_camera ? flight_camera[2] : 0)
	if(dx ** 2 + dy ** 2 < ICON_SIZE_ALL ** 2)
		return flight.aim(null)
	return flight.aim(delta_to_angle(dx, dy))

/// Only an unmodified left click on the map fires along the current heading.
/obj/vehicle/sealed/spacepod/proc/on_pilot_click(mob/living/user, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(!LAZYACCESS(modifiers, LEFT_CLICK) || modifiers[RIGHT_CLICK] || modifiers[MIDDLE_CLICK] || modifiers[SHIFT_CLICK] || modifiers[CTRL_CLICK] || modifiers[ALT_CLICK])
		return NONE
	if(!target || target == src || (!isturf(target) && !isturf(target.loc)) || target.z != z)
		return NONE
	if(flight.parking || !weapon_system || !can_control(user) || (user.client && user.client.eye != src))
		return NONE
	INVOKE_ASYNC(src, PROC_REF(fireWeapon), user)
	return COMSIG_MOB_CANCEL_CLICKON

#undef SPACEPOD_ACTION_KEYS
#undef SPACEPOD_CAMERA_VIEW_BONUS

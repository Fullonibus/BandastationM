#define SPACEPOD_CAMERA_VIEW_BONUS 10

/obj/vehicle/sealed/spacepod/generate_actions()
	initialize_passenger_action_type(/datum/action/vehicle/sealed/spacepod/status)
	initialize_passenger_action_type(/datum/action/vehicle/sealed/spacepod/eject)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/internals, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/lights, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/fire, VEHICLE_CONTROL_EQUIPMENT)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/systems, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/brakes, VEHICLE_CONTROL_SETTINGS)
	initialize_controller_action_type(/datum/action/vehicle/sealed/spacepod/turbo, VEHICLE_CONTROL_SETTINGS)
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

/datum/action/vehicle/sealed/spacepod/status
	name = "Состояние челнока"
	desc = "Открывает бортовой монитор: батарея, прочность корпуса и атмосфера салона."
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

/datum/action/vehicle/sealed/spacepod/fire
	name = "Стрелять"
	desc = "Стреляет установленным оружием вперёд по курсу челнока."
	button_icon_state = "mech_thrusters_off"

/datum/action/vehicle/sealed/spacepod/fire/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(.)
		pod.fireWeapon(owner)

/datum/action/vehicle/sealed/spacepod/brakes
	name = "Тормоз челнока"
	desc = "Гасит инерцию, когда отпущены клавиши движения. Встречная тяга расходует вдвое больше заряда при той же силе."
	button_icon_state = "mech_safeties_off"

/datum/action/vehicle/sealed/spacepod/brakes/Grant(mob/grant_to)
	button_icon_state = pod?.flight?.brakes ? "mech_safeties_on" : "mech_safeties_off"
	return ..()

/datum/action/vehicle/sealed/spacepod/brakes/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(. && pod.can_control(owner) && pod.flight.toggle_brakes())
		button_icon_state = pod.flight.brakes ? "mech_safeties_on" : "mech_safeties_off"
		build_all_button_icons()
		pod.balloon_alert(owner, pod.flight.brakes ? "автотормоз включён" : "автотормоз выключен")

/datum/action/vehicle/sealed/spacepod/turbo
	name = "ТУРБО"
	desc = "Удваивает скорость и ускорение челнока. Расход батареи на тягу увеличивается в два раза."
	button_icon_state = "mech_overload_off"

/datum/action/vehicle/sealed/spacepod/turbo/Grant(mob/grant_to)
	button_icon_state = pod?.flight?.turbo ? "mech_overload_on" : "mech_overload_off"
	return ..()

/datum/action/vehicle/sealed/spacepod/turbo/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(. && pod.can_control(owner) && pod.flight.toggle_turbo())
		button_icon_state = pod.flight.turbo ? "mech_overload_on" : "mech_overload_off"
		build_all_button_icons()
		pod.balloon_alert(owner, pod.flight.turbo ? "турбо включено" : "турбо выключено")

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

/datum/action/vehicle/sealed/spacepod/systems
	name = "Дополнительные системы"
	button_icon_state = "mech_cycle_equip_off"

/datum/action/vehicle/sealed/spacepod/systems/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!. || !pod.can_control(owner))
		return
	var/selection = tgui_input_list(owner, "Выберите систему", "Управление челноком", list("Блокировка дверей", "Шлюз отсека", "Сбросить груз", "Проверить под сиденьем", "Сканировать сектор"))
	if(!selection || QDELETED(src) || QDELETED(pod) || !pod.can_control(owner))
		return
	switch(selection)
		if("Блокировка дверей")
			pod.lock_pod(owner)
		if("Шлюз отсека")
			pod.toggleDoors(owner)
		if("Сбросить груз")
			pod.unload(owner)
		if("Проверить под сиденьем")
			pod.checkSeat(owner)
		if("Сканировать сектор")
			pod.startScan(owner)

#undef SPACEPOD_CAMERA_VIEW_BONUS

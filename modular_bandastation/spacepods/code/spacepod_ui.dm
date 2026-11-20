/// Cabin telemetry belongs only to a current occupant, independently of pilot controls.
/obj/vehicle/sealed/spacepod/proc/can_view_status(mob/user)
	return !QDELETED(src) && !QDELETED(user) && isliving(user) && is_occupant(user) && user.loc == src

/obj/vehicle/sealed/spacepod/ui_status(mob/user, datum/ui_state/state)
	return can_view_status(user) ? UI_INTERACTIVE : UI_CLOSE

/obj/vehicle/sealed/spacepod/ui_interact(mob/user, datum/tgui/ui)
	if(!can_view_status(user))
		SStgui.close_user_uis(user, src)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SpacepodStatus", "Состояние челнока")
		if(!ui.open())
			qdel(ui)

/obj/vehicle/sealed/spacepod/ui_data(mob/user)
	if(!can_view_status(user))
		return list()
	var/list/data = get_status_data()
	data["name"] = declent_ru(NOMINATIVE)
	data["cabin_temperature_k"] = cabin_air?.temperature
	data["lights_on"] = !!lights
	data["locked"] = !unlocked
	data["occupant_count"] = occupant_amount()
	data["occupant_capacity"] = max_occupants
	data["pilot_controls"] = can_control(user)
	data["turbo"] = !!flight.turbo
	data["parking"] = !!flight.parking
	data["parked"] = !!flight.parked
	var/list/passenger_rows = list()
	for(var/mob/living/passenger as anything in passengers)
		if(!QDELETED(passenger) && passenger.loc == src)
			passenger_rows += list(list("name" = passenger.name, "ref" = REF(passenger)))
	data["passengers"] = passenger_rows
	return data

/obj/vehicle/sealed/spacepod/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	if(!can_control(user))
		return FALSE
	switch(action)
		if("turbo")
			return !flight.parking && flight.toggle_turbo()
		if("parking")
			return flight.toggle_parking()
		if("lock")
			return lock_pod(user)
		if("doors")
			return toggleDoors(user)
		if("unload")
			return unload(user)
		if("check_seat")
			INVOKE_ASYNC(src, PROC_REF(checkSeat), user)
			return TRUE
		if("scan")
			INVOKE_ASYNC(src, PROC_REF(startScan), user)
			return TRUE
		if("eject_passenger")
			if(!istext(params["passenger"]))
				return FALSE
			var/mob/living/passenger = locate(params["passenger"]) in passengers
			if(QDELETED(passenger) || passenger.loc != src)
				return FALSE
			eject_passenger(passenger)
			return TRUE

/obj/vehicle/sealed/spacepod/mouse_drop_dragged(atom/over, mob/living/user, src_location, over_location, params)
	if(over != user || !length(passengers))
		return ..()
	var/mob/living/passenger = passengers[1]
	if(!can_unload_passenger(user, passenger))
		return
	if(!do_after(user, 5 SECONDS, src, extra_checks = CALLBACK(src, PROC_REF(can_unload_passenger), user, passenger)))
		return
	if(can_unload_passenger(user, passenger))
		eject_passenger(passenger)

/// Outside rescue requires access to the hull and the same passenger through the entire action.
/obj/vehicle/sealed/spacepod/proc/can_unload_passenger(mob/living/user, mob/living/passenger)
	return !QDELETED(src) && isliving(user) && !QDELETED(user) && isturf(user.loc) && !user.incapacitated && !HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) && unlocked && Adjacent(user) && !QDELETED(passenger) && passenger.loc == src && (passenger in passengers)

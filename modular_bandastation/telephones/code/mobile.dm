#define MOBILE_PHONE_STANDBY_DRAIN (1.4 WATTS)
#define MOBILE_PHONE_CALL_DRAIN (34 WATTS)

/// A pocket telephone with a rechargeable cell and its own station directory entry.
/obj/item/telephone/mobile
	name = "mobile telephone"
	desc = "Переносной телефон с выдвижной антенной. Используйте его в руке, чтобы открыть телефонную книгу или принять входящий вызов. Во время разговора это поднимает или опускает телефон. Alt+ЛКМ открывает телефонную книгу даже во время звонка. Телефон можно зарядить в станционной зарядной станции."
	icon = 'modular_bandastation/telephones/icons/mobile_phone.dmi'
	icon_state = "lawyer_mobile"
	inhand_icon_state = "lawyer_mobile"
	raised_inhand_icon_state = "lawyer_mobile_ear"
	lefthand_file = 'modular_bandastation/telephones/icons/mobile_phone_lefthand.dmi'
	righthand_file = 'modular_bandastation/telephones/icons/mobile_phone_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	has_cord = FALSE
	/// Name published alongside the assigned number.
	var/directory_name = "Мобильный телефон"
	/// Sealed cell exposed to ordinary device chargers.
	var/obj/item/stock_parts/power_store/cell/battery

/obj/item/telephone/mobile/Initialize(mapload)
	. = ..()
	battery = new(src)
	RegisterSignal(battery, COMSIG_POWER_STORE_GIVE, PROC_REF(on_battery_recharged))
	attached_to = new /obj/structure/transmitter/command/mobile(src, src)
	START_PROCESSING(SSobj, src)

/obj/item/telephone/mobile/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(attached_to)
		attached_to.handset = null
		QDEL_NULL(attached_to)
	QDEL_NULL(battery)
	return ..()

/obj/item/telephone/mobile/get_cell()
	return battery

/obj/item/telephone/mobile/examine(mob/user)
	. = ..()
	. += span_notice("Заряд батареи: [battery?.charge > 0 ? CEILING(battery.percent(), 1) : 0]%.")
	if(attached_to)
		. += span_notice("Номер телефона: [attached_to.phone_id].")

/obj/item/telephone/mobile/update_icon_state()
	. = ..()
	icon_state = battery?.charge > 0 ? initial(icon_state) : "[initial(icon_state)]_off"

/obj/item/telephone/mobile/process(seconds_per_tick)
	if(istype(loc, /obj/machinery/recharger))
		return
	var/drain = attached_to?.status == PHONE_CONNECTED ? MOBILE_PHONE_CALL_DRAIN : MOBILE_PHONE_STANDBY_DRAIN
	battery?.change(-drain * seconds_per_tick)
	if(battery?.charge > 0)
		return
	attached_to?.end_call()
	if(holder)
		balloon_alert(holder, "батарея разряжена")
	update_appearance(UPDATE_ICON_STATE)
	SStgui.close_uis(attached_to)
	return PROCESS_KILL

/// A flat battery stops processing until the first charge arrives.
/obj/item/telephone/mobile/proc/on_battery_recharged(obj/item/stock_parts/power_store/source, amount)
	SIGNAL_HANDLER
	if(amount <= 0 || source.charge > amount)
		return
	START_PROCESSING(SSobj, src)
	update_appearance(UPDATE_ICON_STATE)

/obj/item/telephone/mobile/attack_self(mob/user)
	if(battery?.charge <= 0)
		balloon_alert(user, "батарея разряжена")
		return
	if(!attached_to?.can_use_handset(user))
		return
	switch(attached_to.status)
		if(PHONE_INCOMING)
			attached_to.answer_call()
		if(PHONE_CONNECTED)
			return ..()
		else
			attached_to.ui_interact(user)

/obj/item/telephone/mobile/clear_holder()
	var/was_held = !!holder
	. = ..()
	if(was_held && (attached_to?.status == PHONE_CONNECTED || attached_to?.status == PHONE_OUTGOING))
		attached_to.end_call()

/obj/item/telephone/mobile/magistrate
	name = "magistrate's mobile telephone"
	icon_state = "magistrate_mobile"
	inhand_icon_state = "magistrate_mobile"
	raised_inhand_icon_state = "magistrate_mobile_ear"
	directory_name = "Магистрат (мобильный)"

/obj/item/telephone/mobile/lawyer
	name = "internal affairs agent's mobile telephone"
	directory_name = "АВД (мобильный)"

/// The pocket phone owns this invisible exchange endpoint.
/obj/structure/transmitter/command/mobile
	icon = null
	icon_state = null
	post_init_icon_state = null
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	greyscale_config = null
	greyscale_colors = null
	phone_icon = "mobile-screen-button"

/obj/structure/transmitter/command/mobile/Initialize(mapload, obj/item/telephone/mobile/phone)
	display_name = phone?.directory_name
	. = ..()
	if(QDELETED(phone) || loc != phone)
		return INITIALIZE_HINT_QDEL

/obj/structure/transmitter/command/mobile/has_working_handset()
	if(!..())
		return FALSE
	var/obj/item/stock_parts/power_store/battery = handset.get_cell()
	return battery?.charge > 0

/obj/structure/transmitter/command/mobile/connect_call()
	. = ..()
	handset.set_raised(TRUE)

/obj/structure/transmitter/command/mobile/end_call()
	handset?.set_raised(FALSE)
	return ..()

#undef MOBILE_PHONE_STANDBY_DRAIN
#undef MOBILE_PHONE_CALL_DRAIN

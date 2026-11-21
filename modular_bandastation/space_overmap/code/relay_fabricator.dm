/obj/item/relay_chassis
	name = "напечатанный корпус дроида"
	desc = "Собранный дроид в транспортном положении. Его можно загрузить в командное реле."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "chassis"
	w_class = WEIGHT_CLASS_BULKY
	/// Type selected by the factory at the time of printing.
	var/mob/living/basic/relay_droid/droid_type = /mob/living/basic/relay_droid
	/// Returned body, if this chassis already contains a unit.
	var/mob/living/basic/relay_droid/stored_unit

/obj/item/relay_chassis/Initialize(mapload, mob/living/basic/relay_droid/printed_type)
	. = ..()
	if(printed_type)
		droid_type = printed_type

/obj/item/relay_chassis/Destroy()
	var/mob/living/basic/relay_droid/unit = stored_unit
	clear_stored_unit()
	if(!QDELETED(unit))
		var/turf/destination = get_turf(src)
		if(destination)
			unit.forceMove(destination)
			unit.reset_perspective()
		else
			qdel(unit)
	return ..()

/// Keep the same body and invalidate this chassis when its occupant dies.
/obj/item/relay_chassis/proc/stow(mob/living/basic/relay_droid/unit)
	stored_unit = unit
	RegisterSignals(unit, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(body_lost))

/// Drop the stored-body relationship before redeployment or destruction.
/obj/item/relay_chassis/proc/clear_stored_unit()
	if(stored_unit)
		UnregisterSignal(stored_unit, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		stored_unit = null

/obj/item/relay_chassis/proc/body_lost(mob/living/basic/relay_droid/unit)
	SIGNAL_HANDLER
	clear_stored_unit()
	var/turf/destination = get_turf(src)
	if(!QDELETED(unit) && destination && unit.loc == src)
		unit.forceMove(destination)
		unit.reset_perspective()
	qdel(src)

/obj/machinery/relay_fabricator
	name = "фабрикатор дроидов"
	desc = "Печатает законченные корпуса из железа. Принимает листы вручную."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "fabricator"
	density = TRUE
	anchored = TRUE
	idle_power_usage = 100
	processing_flags = NONE
	/// Integer sheets available for printing.
	var/iron_sheets = 0
	/// Maximum input capacity.
	var/max_iron_sheets = 60
	/// Default role profile used when manufacturing independently.
	var/datum/droid_relay_profile/profile_type = /datum/droid_relay_profile
	COOLDOWN_DECLARE(print_cooldown)

/obj/machinery/relay_fabricator/item_interaction(mob/living/user, obj/item/item, list/modifiers)
	if(!istype(item, /obj/item/stack/sheet/iron))
		return ..()
	var/obj/item/stack/sheet/iron/stack = item
	var/amount = min(stack.get_amount(), max_iron_sheets - iron_sheets)
	if(amount <= 0 || !stack.use(amount))
		balloon_alert(user, "отсек заполнен")
		return ITEM_INTERACT_BLOCKING
	iron_sheets += amount
	balloon_alert(user, "железо загружено")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/relay_fabricator/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!check_rights_for(user.client, R_ADMIN))
		return ITEM_INTERACT_BLOCKING
	var/obj/machinery/overmap_droid_relay/relay = tool.buffer
	if(istype(relay) && relay.link_device(src))
		balloon_alert(user, "фабрикатор подключён")
	else
		tool.set_buffer(src)
		balloon_alert(user, "фабрикатор сохранён в буфер")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/relay_fabricator/examine(mob/user)
	. = ..()
	. += span_notice("Листов железа: [iron_sheets]/[max_iron_sheets]. Нажмите пустой рукой, чтобы напечатать корпус.")

/obj/machinery/relay_fabricator/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !Adjacent(user) || !can_interact(user))
		return
	var/datum/droid_relay_profile/profile = new profile_type
	if(!print_chassis(profile, drop_location()))
		balloon_alert(user, "фабрикатор недоступен")
	qdel(profile)

/// Make one physical chassis. Cost and cooldown are charged before the item is created.
/obj/machinery/relay_fabricator/proc/print_chassis(datum/droid_relay_profile/profile, atom/destination)
	if(!destination || !anchored || (machine_stat & (NOPOWER | BROKEN | MAINT)) \
		|| !COOLDOWN_FINISHED(src, print_cooldown) || iron_sheets < profile.iron_sheets \
		|| !use_energy(5 KILO JOULES, force = FALSE))
		return FALSE
	iron_sheets -= profile.iron_sheets
	COOLDOWN_START(src, print_cooldown, 3 SECONDS)
	new /obj/item/relay_chassis(destination, profile.droid_type)
	playsound(src, 'sound/machines/click.ogg', 35, TRUE)
	return TRUE

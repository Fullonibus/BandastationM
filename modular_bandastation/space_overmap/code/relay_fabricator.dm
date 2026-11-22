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

/// A fabrication recipe for one transportable droid chassis.
/datum/droid_fabrication_design
	/// Name shown in the fabricator's catalog.
	var/name
	/// Function and intended use of the deployed body.
	var/desc
	/// Droid body instantiated when the finished chassis is deployed.
	var/mob/living/basic/relay_droid/droid_type
	/// Solid materials required for one chassis, in material units.
	var/list/materials
	/// Time at the factory's nominal speed.
	var/build_time
	/// Energy drawn when finishing one chassis.
	var/energy_cost = 5 KILO JOULES

/// Use the same cached appearance for printed bodies in both operator windows.
/proc/droid_relay_portrait(mob/living/basic/relay_droid/body_type)
	var/static/list/portraits = list()
	if(!(body_type in portraits))
		portraits[body_type] = icon2base64(icon(initial(body_type.icon), initial(body_type.icon_state), SOUTH, 1))
	return portraits[body_type]

/// Check the recipe's material requirements without consuming anything.
/datum/droid_fabrication_design/proc/can_fabricate(obj/machinery/relay_fabricator/fabricator, obj/machinery/relay_resource_storage/storage)
	return storage && (!length(materials) || storage.materials.has_materials(materials))

/// Check and pay for the finished job in one non-sleeping operation. Failure leaves inputs intact.
/datum/droid_fabrication_design/proc/pay_requirements(obj/machinery/relay_fabricator/fabricator, obj/machinery/relay_resource_storage/storage)
	if(!can_fabricate(fabricator, storage) || (energy_cost && !fabricator.use_energy(energy_cost, force = FALSE)))
		return FALSE
	storage.materials.use_materials(materials)
	return TRUE

/datum/droid_fabrication_design/basic
	name = "Боевой дроид"
	desc = "Дроид ближнего боя. Выполняет приказы реле, патрулирует и передаёт изображение с камеры."
	droid_type = /mob/living/basic/relay_droid
	materials = list(/datum/material/iron = 3 * SHEET_MATERIAL_AMOUNT)
	build_time = 45 SECONDS

/obj/machinery/relay_fabricator
	name = "фабрикатор дроидов"
	desc = "Собирает корпуса дроидов по установленным чертежам. Получает материалы из силоса по грузовой трубе."
	icon = 'modular_bandastation/space_overmap/icons/droid_relay.dmi'
	icon_state = "fabricator"
	density = TRUE
	anchored = TRUE
	idle_power_usage = 100
	processing_flags = NONE
	/// Catalog configured for this model of fabricator.
	var/list/design_types = list(/datum/droid_fabrication_design/basic)
	/// Recipes owned by this machine.
	var/list/datum/droid_fabrication_design/designs = list()
	/// Production speed multiplier. A value of 2 halves the build time.
	var/productivity = 1
	/// Recipe currently in production.
	var/datum/droid_fabrication_design/printing_design
	/// Optional destination. If unavailable at completion, the chassis is ejected locally.
	var/datum/weakref/print_relay_ref
	/// The silo selected at the start of the job. A different silo cannot be charged on completion.
	var/datum/weakref/print_storage_ref
	/// Stoppable timer for the current job.
	var/print_timer
	/// Duration captured at the start, so changing productivity cannot move the current progress.
	var/active_print_duration = 0

/obj/machinery/relay_fabricator/Initialize(mapload)
	. = ..()
	for(var/design_type in design_types)
		var/datum/droid_fabrication_design/design = new design_type
		designs += design

/obj/machinery/relay_fabricator/Destroy()
	if(print_timer)
		deltimer(print_timer)
	printing_design = null
	print_relay_ref = null
	print_storage_ref = null
	QDEL_LIST(designs)
	return ..()

/obj/machinery/relay_fabricator/on_set_machine_stat(old_value)
	. = ..()
	if(print_timer && (machine_stat & (NOPOWER | BROKEN | MAINT)))
		deltimer(print_timer)
		print_timer = null
		printing_design = null
		active_print_duration = 0
		report_print_failure()

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
	if(printing_design)
		. += span_notice("Идёт сборка: [printing_design.name]. Осталось [CEILING(timeleft(print_timer) / (1 SECONDS), 1)] сек.")
	else
		. += span_notice("Нажмите пустой рукой, чтобы открыть каталог чертежей.")
	if(!connected_storage())
		. += span_warning("Хранилище ресурсов не подключено.")

/obj/machinery/relay_fabricator/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!. && Adjacent(user) && can_interact(user))
		ui_interact(user)

/// Whether the factory is operational and has no outstanding print.
/obj/machinery/relay_fabricator/proc/can_start_print()
	return !printing_design && anchored && isturf(loc) && !(machine_stat & (NOPOWER | BROKEN | MAINT))

/// Duration for a new job. The current job keeps its original timer.
/obj/machinery/relay_fabricator/proc/print_duration(datum/droid_fabrication_design/design)
	if(!isnum(productivity) || !IS_FINITE(productivity) || productivity <= 0)
		return 0
	return max(world.tick_lag, design.build_time / productivity)

/// Check the live connection and all conditions for placing this chassis inside the relay.
/obj/machinery/relay_fabricator/proc/can_deliver_to(obj/machinery/overmap_droid_relay/relay, datum/droid_fabrication_design/design)
	return !QDELETED(relay) && relay.fabricator_ref?.resolve() == src && relay.valid_link(src) \
		&& (design.droid_type in relay.profile.droid_types) && relay.has_storage_space()

/// Start one timed chassis. The factory owns the job and charges the recipe at completion.
/obj/machinery/relay_fabricator/proc/print_chassis(datum/droid_fabrication_design/design, obj/machinery/overmap_droid_relay/relay)
	if(!can_start_print() || QDELETED(design) || !(design in designs) || (relay && !can_deliver_to(relay, design)))
		return FALSE
	var/obj/machinery/relay_resource_storage/storage = connected_storage()
	if(!storage || !design.can_fabricate(src, storage))
		return FALSE
	var/duration = print_duration(design)
	if(!duration)
		return FALSE
	printing_design = design
	print_relay_ref = relay ? WEAKREF(relay) : null
	print_storage_ref = WEAKREF(storage)
	active_print_duration = duration
	print_timer = addtimer(CALLBACK(src, PROC_REF(finish_print)), duration, TIMER_STOPPABLE)
	return TRUE

/obj/machinery/relay_fabricator/proc/finish_print()
	var/datum/droid_fabrication_design/design = printing_design
	print_timer = null
	printing_design = null
	active_print_duration = 0
	var/atom/destination = drop_location()
	var/obj/machinery/relay_resource_storage/storage = connected_storage()
	if(QDELETED(design) || !destination || !storage || storage != print_storage_ref?.resolve() || (machine_stat & (NOPOWER | BROKEN | MAINT)) || !design.pay_requirements(src, storage))
		report_print_failure()
		return
	var/obj/machinery/overmap_droid_relay/relay = print_relay_ref?.resolve()
	print_relay_ref = null
	print_storage_ref = null
	if(can_deliver_to(relay, design))
		destination = relay
	else if(relay)
		to_chat(relay.operator, span_notice("Готовый корпус выгружен у фабрикатора."))
	new /obj/item/relay_chassis(destination, design.droid_type)
	playsound(src, 'sound/machines/click.ogg', 35, TRUE)

/obj/machinery/relay_fabricator/proc/report_print_failure()
	var/obj/machinery/overmap_droid_relay/relay = print_relay_ref?.resolve()
	print_relay_ref = null
	print_storage_ref = null
	balloon_alert_to_viewers("сборка прервана")
	if(relay?.valid_link(src))
		to_chat(relay.operator, span_warning("Сборка корпуса прервана. Проверьте питание, грузовую трубу и материалы."))

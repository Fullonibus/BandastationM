// Field kit of the Sierra anomaly mod: detector, bolts and an artefact collector.

// ===== Detector =====

/**
 * The field anomaly detector. Switched on, it beeps while any field is within three tiles, faster the closer
 * it is; used while on, it listens for a few seconds and says whether anything anomalous is near, never
 * where. Pointed at an anomaly, artefact or core it reads its energy kind, and a living anomaly's
 * frequency and code for a signaller.
 */
/obj/item/field_detector
	name = "полевой детектор аномалий"
	desc = "Наручный прибор с тремя лампами. Включённый, пищит рядом с аномальным полем, тем чаще, чем ближе; по нажатию сообщает, есть ли рядом аномалии. Приложенный к аномалии, артефакту или ядру, определяет вид энергии, а у живой аномалии — частоту и код для нейтрализации. Alt-клик включает и выключает его."
	icon = 'modular_bandastation/anomaly_fields/icons/equipment.dmi'
	icon_state = "detector_turned_off"
	worn_icon_state = "analyzer"
	inhand_icon_state = "analyzer"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/silver = SMALL_MATERIAL_AMOUNT * 2)
	/// Switched on.
	var/on = FALSE
	/// A scan is running.
	var/scanning = FALSE
	/// A field is within beeping range.
	var/peak = FALSE
	/// Next beep while peaking.
	var/next_beep = 0
	/// Reach of the beeping, in tiles.
	var/beep_range = 3
	/// Reach of a scan, in tiles.
	var/scan_range = 7

/obj/item/field_detector/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	return ..()

/obj/item/field_detector/update_icon_state()
	if(!on)
		icon_state = "detector_turned_off"
	else if(scanning)
		icon_state = peak ? "detector_scanning_and_peak" : "detector_scanning"
	else
		icon_state = peak ? "detector_idle_and_peak" : "detector_idle"
	return ..()

/obj/item/field_detector/click_alt(mob/user)
	toggle(user)
	return CLICK_ACTION_SUCCESS

/obj/item/field_detector/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!on)
		toggle(user)
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(scan), user)
	return TRUE

/obj/item/field_detector/proc/toggle(mob/user)
	on = !on
	peak = FALSE
	flick(on ? "detector_turning_on" : "detector_turning_off", src)
	balloon_alert(user, on ? "включён" : "выключен")
	if(on)
		START_PROCESSING(SSfastprocess, src)
	else
		STOP_PROCESSING(SSfastprocess, src)
	update_appearance()

/obj/item/field_detector/process(seconds_per_tick)
	if(!on)
		return PROCESS_KILL
	var/turf/here = get_turf(src)
	var/nearest = INFINITY
	for(var/obj/effect/anomaly_field/field in range(beep_range, here))
		nearest = min(nearest, get_dist(field, here))
	var/now_peak = nearest <= beep_range
	if(now_peak != peak)
		peak = now_peak
		update_appearance()
	if(peak && world.time >= next_beep)
		next_beep = world.time + (0.25 SECONDS) * (nearest + 1)
		playsound(src, 'modular_bandastation/anomaly_fields/sound/detector_peek.ogg', 40, FALSE)

/obj/item/field_detector/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/kind_key = anomalous_energy_kind(interacting_with)
	var/obj/effect/anomaly/anomaly = interacting_with
	if(!kind_key && !istype(anomaly))
		return NONE
	var/list/lines = list("<b>[capitalize(interacting_with.name)]</b>")
	if(kind_key)
		var/datum/artifact_energy_kind/kind = artifact_energy_kind(kind_key)
		lines += "Вид энергии: [kind.report_name]."
	else
		lines += "Вид энергии не определяется."
	if(istype(anomaly))
		if(anomaly.anomaly_core)
			lines += "Поле колеблется на частоте [format_frequency(anomaly.anomaly_core.frequency)], код [anomaly.anomaly_core.code]."
		else
			lines += "Поле не колеблется на устойчивой частоте."
		var/obj/effect/anomaly/pulsing/living = anomaly
		if(istype(living) && !living.journal_record)
			living.journal_note(user, "Обнаружена аномалия «[living.name]»: [jointext(lines.Copy(2), " ")]")
	playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
	to_chat(user, span_notice(jointext(lines, "<br>")))
	return ITEM_INTERACT_SUCCESS

/obj/item/field_detector/proc/scan(mob/user)
	if(scanning)
		return
	scanning = TRUE
	update_appearance()
	var/finished = do_after(user, 3 SECONDS, src)
	scanning = FALSE
	update_appearance()
	if(!finished || !on)
		return
	if(locate(/obj/effect/anomaly_field) in range(scan_range, get_turf(src)))
		flick("detector_detected_anomalies", src)
		to_chat(user, span_warning("[capitalize(name)] фиксирует аномальную активность поблизости."))
	else
		to_chat(user, span_notice("[capitalize(name)] не фиксирует аномалий поблизости."))

/// ARTIFACT_ENERGY_* of an anomaly, field, field artefact or anomaly core, or null if it carries none known.
/proc/anomalous_energy_kind(atom/thing)
	if(istype(thing, /obj/effect/anomaly_field))
		var/obj/effect/anomaly_field/field = thing
		return field.energy_kind
	if(istype(thing, /obj/item/field_artefact))
		var/obj/item/field_artefact/artefact = thing
		return artefact.energy_kind
	var/core_type
	if(istype(thing, /obj/item/assembly/signaler/anomaly))
		core_type = thing.type
	else if(istype(thing, /obj/effect/anomaly))
		var/obj/effect/anomaly/anomaly = thing
		core_type = isdatum(anomaly.anomaly_core) ? anomaly.anomaly_core.type : anomaly.anomaly_core
	if(!core_type)
		return null
	if(ispath(core_type, /obj/item/assembly/signaler/anomaly/planetary))
		var/obj/item/assembly/signaler/anomaly/planetary/planetary_core = core_type
		return initial(planetary_core.energy_kind)
	var/list/entry = GLOB.xenoarch_tg_core_battery[core_type]
	return entry?[1]

// ===== Bolts =====

/obj/item/field_bolt
	name = "болт"
	desc = "Простой стальной болт. Брошенный вперёд, будит то, чего не видно глазу."
	icon = 'modular_bandastation/anomaly_fields/icons/equipment.dmi'
	icon_state = "bolt"
	inhand_icon_state = "rods"
	w_class = WEIGHT_CLASS_TINY
	obj_flags = CONDUCTS_ELECTRICITY
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)

/**
 * Ten bolts. Used in hand it puts a bolt in the other hand ready to throw. Worn or held, it picks up
 * bolts its carrier walks over, unless that is switched off to leave bolts as path markers.
 */
/obj/item/storage/field_bolts
	name = "мешочек с болтами"
	desc = "Плотный мешочек на десять болтов. В руке достаёт болт для броска; Alt+ПКМ переключает сбор болтов под ногами."
	icon = 'modular_bandastation/anomaly_fields/icons/equipment.dmi'
	icon_state = "bolt_bag"
	inhand_icon_state = "satchel"
	lefthand_file = 'icons/mob/inhands/equipment/backpack_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/backpack_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT | ITEM_SLOT_POCKETS
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 10)
	/// Picks up bolts its carrier walks over.
	var/autocollect = TRUE
	/// Carrier whose steps it follows.
	var/mob/listening_to

/obj/item/storage/field_bolts/Initialize(mapload)
	. = ..()
	atom_storage.max_slots = 10
	atom_storage.max_total_storage = 10
	atom_storage.max_specific_storage = WEIGHT_CLASS_TINY
	atom_storage.set_holdable(/obj/item/field_bolt)

/obj/item/storage/field_bolts/Destroy(force)
	listening_to = null
	return ..()

/obj/item/storage/field_bolts/equipped(mob/user, slot, initial)
	. = ..()
	if(listening_to == user)
		return
	if(listening_to)
		UnregisterSignal(listening_to, COMSIG_MOVABLE_MOVED)
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_carrier_moved))
	listening_to = user

/obj/item/storage/field_bolts/dropped(mob/user, silent)
	. = ..()
	if(listening_to)
		UnregisterSignal(listening_to, COMSIG_MOVABLE_MOVED)
		listening_to = null

/obj/item/storage/field_bolts/proc/on_carrier_moved(mob/carrier)
	SIGNAL_HANDLER
	if(!autocollect || !isturf(carrier.loc))
		return
	for(var/obj/item/field_bolt/bolt in carrier.loc)
		if(!bolt.throwing)
			INVOKE_ASYNC(atom_storage, TYPE_PROC_REF(/datum/storage, attempt_insert), bolt, carrier, FALSE, STORAGE_NOT_LOCKED, FALSE)

/obj/item/storage/field_bolts/attack_self(mob/living/user, modifiers)
	. = ..()
	if(. || !isliving(user))
		return
	var/obj/item/field_bolt/bolt = locate() in src
	if(!bolt)
		balloon_alert(user, "пусто!")
		return TRUE
	if(user.put_in_hands(bolt))
		user.throw_mode_on(THROW_MODE_TOGGLE)
	return TRUE

/obj/item/storage/field_bolts/click_alt_secondary(mob/user)
	autocollect = !autocollect
	balloon_alert(user, autocollect ? "сбор болтов включён" : "сбор болтов выключен")
	return CLICK_ACTION_SUCCESS

/obj/item/storage/field_bolts/PopulateContents()
	for(var/i in 1 to 10)
		new /obj/item/field_bolt(src)

// ===== Collector =====

/**
 * Holds one small anomalous find (field artefact, anomaly core, strange rock or curio) and shuts it off.
 * Only a collector lifts an artefact out of its field: it takes a few seconds, and the field may go off
 * as it lets go.
 */
/obj/item/field_collector
	name = "коллектор артефактов"
	desc = "Экранированный контейнер со щупами для одной мелкой находки: артефакта, ядра аномалии, странного камня или древности. Внутри артефакт не действует."
	icon = 'modular_bandastation/anomaly_fields/icons/equipment.dmi'
	icon_state = "collector_empty"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/glass = SHEET_MATERIAL_AMOUNT, /datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT)
	/// The find inside.
	var/obj/item/stored

/obj/item/field_collector/Destroy()
	stored?.forceMove(drop_location()) // Finds must not vanish with their container; artefacts are indestructible.
	return ..()

/obj/item/field_collector/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == stored)
		stored = null
		update_appearance()

/obj/item/field_collector/update_icon_state()
	var/obj/item/field_artefact/artefact = stored
	if(istype(artefact))
		icon_state = artefact.collector_state
	else
		icon_state = stored ? "collector_closed" : "collector_empty"
	return ..()

/obj/item/field_collector/examine(mob/user)
	. = ..()
	. += stored ? span_notice("Внутри [stored.name]. Используйте в руке, чтобы достать.") : span_notice("Пуст.")
	if(istype(stored, /obj/item/field_artefact/pruzhina))
		. += span_notice("Alt-клик переключает коллектор с электретным образованием в режим батареи.")

/// A collector holding a pruzhina turns into a power cell charged from it.
/obj/item/field_collector/click_alt(mob/user)
	if(!istype(stored, /obj/item/field_artefact/pruzhina))
		balloon_alert(user, "нужно электретное образование!")
		return CLICK_ACTION_BLOCKING
	var/obj/item/stock_parts/power_store/cell/pruzhina/cell = new(drop_location())
	cell.take_collector(src)
	user.put_in_hands(cell)
	playsound(cell, 'modular_bandastation/anomaly_fields/sound/collector_closed.ogg', 25, FALSE)
	return CLICK_ACTION_SUCCESS

/obj/item/field_collector/attack_self(mob/user, modifiers)
	. = ..()
	if(. || !stored)
		return
	playsound(src, 'modular_bandastation/anomaly_fields/sound/collector_open.ogg', 25, FALSE)
	user.put_in_hands(stored)
	return TRUE

/obj/item/field_collector/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!is_type_in_typecache(interacting_with, GLOB.field_collector_holdable))
		return NONE
	var/obj/item/find = interacting_with
	var/obj/item/field_artefact/artefact = find
	if(stored)
		balloon_alert(user, "уже занят!")
		return ITEM_INTERACT_BLOCKING
	if(istype(artefact) && artefact.bound)
		balloon_alert(user, "захват...")
		if(!do_after(user, 3 SECONDS, artefact) || stored || QDELETED(artefact) || !artefact.bound)
			return ITEM_INTERACT_BLOCKING
		var/obj/effect/anomaly_field/field = locate() in artefact.loc
		artefact.collect(user)
		if(field && (user.loc == field.loc || prob(50)))
			field.provoke()
	else if(find.loc == user)
		if(!user.transferItemToLoc(find, src))
			return ITEM_INTERACT_BLOCKING
	if(find.loc != src)
		find.forceMove(src)
	stored = find
	playsound(src, 'modular_bandastation/anomaly_fields/sound/collector_closed.ogg', 25, FALSE)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/// What a collector takes in.
GLOBAL_LIST_INIT(field_collector_holdable, typecacheof(list(
	/obj/item/field_artefact,
	/obj/item/assembly/signaler/anomaly,
	/obj/item/strange_rock,
	/obj/item/xenoarch_curio,
)))

// ===== Pruzhina cell =====

/**
 * A collector with a pruzhina inside, switched over to feed a device. It holds the pruzhina's charge,
 * cannot be recharged and shrugs off EMPs. Alt-click turns it back into the collector.
 */
/obj/item/stock_parts/power_store/cell/pruzhina
	name = "электретная батарея"
	desc = "Коллектор с электретным образованием, переключённый в режим батареи. Не заряжается, но ЭМИ ему нипочём. Alt-клик переключает обратно."
	icon = 'modular_bandastation/anomaly_fields/icons/equipment.dmi'
	icon_state = "collector_closed"
	maxcharge = STANDARD_CELL_CHARGE * 10
	charge_light_type = null
	ratingdesc = FALSE
	emp_damage_modifier = 0
	custom_materials = null
	/// The collector, with its pruzhina, inside.
	var/obj/item/field_collector/collector

/obj/item/stock_parts/power_store/cell/pruzhina/Destroy()
	collector?.forceMove(drop_location()) // The pruzhina is indestructible and must not vanish with the cell.
	return ..()

/obj/item/stock_parts/power_store/cell/pruzhina/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == collector)
		collector = null

/// Takes `holder` and its pruzhina in, charged in proportion to the pruzhina's energy.
/obj/item/stock_parts/power_store/cell/pruzhina/proc/take_collector(obj/item/field_collector/holder)
	collector = holder
	holder.forceMove(src)
	var/obj/item/field_artefact/pruzhina/spring = holder.stored
	charge = maxcharge * spring.energy / spring.max_energy
	update_appearance()

/obj/item/stock_parts/power_store/cell/pruzhina/give(amount)
	return 0

/obj/item/stock_parts/power_store/cell/pruzhina/change(amount)
	return ..(min(amount, 0))

/obj/item/stock_parts/power_store/cell/pruzhina/click_alt(mob/user)
	if(!collector)
		return CLICK_ACTION_BLOCKING
	var/obj/item/field_collector/holder = collector
	var/obj/item/field_artefact/pruzhina/spring = holder.stored
	if(spring)
		spring.energy = round(spring.max_energy * charge / maxcharge)
	holder.forceMove(drop_location())
	qdel(src)
	user.put_in_hands(holder)
	playsound(holder, 'modular_bandastation/anomaly_fields/sound/collector_open.ogg', 25, FALSE)
	return CLICK_ACTION_SUCCESS

// ===== Designs =====

/datum/design/field_bolts
	name = "Мешочек с болтами"
	desc = "Десять стальных болтов, чтобы бросать их перед собой на аномальных планетах."
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 10)
	build_path = /obj/item/storage/field_bolts
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/field_detector
	name = "Полевой детектор аномалий"
	desc = "Наручный прибор: находит невидимые аномальные поля и определяет вид энергии и частоту аномалий."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/silver = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/field_detector
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/field_collector
	name = "Коллектор артефактов"
	desc = "Экранированный контейнер, извлекающий артефакт из аномального поля."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/glass = SHEET_MATERIAL_AMOUNT, /datum/material/plasma = HALF_SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/field_collector
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

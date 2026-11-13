/**
 * # Excavation tools
 *
 * The hand kit for working dig finds: a rock hammer with interchangeable heads, a brush, a depth
 * scanner, a core sampler and a bag for strange rocks, sold as a belt kit from the ship autolathe.
 * The stabiliser is in stabiliser.dm.
 *
 * Merged from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarch/.../xenoarch_tool.dm: one
 * hammer instead of seven (Nova's adjustable hammer, with a radial), one scanner that also measures
 * (Nova's scanner plus tape measure). Sprites from Nova's xenoarch_items.dmi and tools.dmi.
 */
/obj/item/excavation
	name = "инструмент для раскопок"
	icon = 'modular_bandastation/xenoarchaeology/icons/dig_tools.dmi'
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	obj_flags = CONDUCTS_ELECTRICITY

// ===== Hammer =====

/// Hammer heads, in cm taken off per strike.
#define XENOARCH_HAMMER_HEADS list(1, 2, 4, 6, 10)

/**
 * A rock hammer with a set of heads. The head fitted sets how much each strike takes off.
 */
/obj/item/excavation/hammer
	name = "геологический молоток"
	desc = "Короткий геологический молоток с набором сменных насадок, от тонкой кирки до широкого зубила."
	icon_state = "hammer_4"
	inhand_icon_state = "screwdriver_head"
	force = 6
	throwforce = 6
	attack_verb_continuous = list("hammers", "chips", "taps")
	attack_verb_simple = list("hammer", "chip", "tap")
	hitsound = 'sound/effects/rock/rocktap1.ogg'
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT)
	/// cm each strike takes off
	var/head = 4

/obj/item/excavation/hammer/examine(mob/user)
	. = ..()
	. += "Установлена насадка на [head] см."

/obj/item/excavation/hammer/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	var/list/choices = list()
	for(var/size in XENOARCH_HAMMER_HEADS)
		choices["[size] см"] = image(icon, "hammer_[size]")
	var/picked = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	if(!picked || !user.is_holding(src))
		return TRUE
	var/new_head = text2num(picked)
	if(!new_head || new_head == head)
		return TRUE
	head = new_head
	icon_state = "hammer_[head]"
	playsound(src, 'sound/items/tools/ratchet.ogg', 30, TRUE)
	balloon_alert(user, "насадка [head] см")
	update_appearance()
	return TRUE

#undef XENOARCH_HAMMER_HEADS

// ===== Brush =====

/obj/item/excavation/brush
	name = "кисть для раскопок"
	desc = "Жёсткая кисточка, чтобы сметать крошку с того, что не хочется поцарапать."
	icon_state = "brush"
	inhand_icon_state = "screwdriver_head"
	w_class = WEIGHT_CLASS_TINY
	custom_materials = list(/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2, /datum/material/iron = SMALL_MATERIAL_AMOUNT)
	/// One pass of the brush
	var/brush_time = XENOARCH_BRUSH_TIME

/obj/item/excavation/brush/quick
	name = "быстрая кисть"
	desc = "Кисть для раскопок с вибрирующей головкой. Жужжит в пальцах."
	icon_state = "brush_quick"
	custom_materials = list(/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2, /datum/material/iron = SMALL_MATERIAL_AMOUNT * 2, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2)
	brush_time = XENOARCH_BRUSH_TIME_QUICK

// ===== Depth scanner =====

/obj/item/excavation/depth_scanner
	name = "стратиграфический сканер"
	desc = "Ручной стратиграфический сканер. В руке подсвечивает места находок в породе вокруг; по месту находки ставит голобирку (видна по GPS) и сообщает, крупная там находка или малая; показывает глубину крупной находки и сколько уже снято. Alt-клик — набор бирки, клик по выкопанному артефакту — прижать бирку. Также проводит полевое обследование экспедиционных находок перед отбором проб."
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "manual_mining"
	color = "#ff9933"
	inhand_icon_state = "analyzer"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3)
	/// How long a sounding takes
	var/scan_time = 2 SECONDS
	/// Reads the true depth, not a range
	var/exact = FALSE
	/// Also reads which stabilising field holds a boulder
	var/reads_field = FALSE

/obj/item/excavation/depth_scanner/advanced
	name = "продвинутый стратиграфический сканер"
	desc = "Стратиграфический сканер, прямо на раскопе определяющий точную глубину находки и нужное поле её матрицы."
	color = "#e0661a"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2, /datum/material/uranium = SMALL_MATERIAL_AMOUNT * 2)
	scan_time = 1 SECONDS
	exact = TRUE
	reads_field = TRUE

// ===== Core sampler =====

/**
 * Draws a core out of a boulder for the spectrometer. Holds one core at a time; the spectrometer
 * empties it, or knock the core out by hand.
 */
/obj/item/excavation/core_sampler
	name = "керновый пробоотборник"
	desc = "Полая стальная трубка с закалённым наконечником для отбора керна из находки."
	icon_state = "sampler"
	inhand_icon_state = "screwdriver_head"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 4)
	/// Catalogue number of the boulder the core came from, or null when empty
	var/sample_serial
	/// The field that holds that boulder
	var/sample_field
	/// Radiometric age of the rock
	var/sample_age
	/// XENOARCH_SITE_* it came from
	var/sample_site_kind

/obj/item/excavation/core_sampler/examine(mob/user)
	. = ..()
	if(sample_serial)
		. += "Внутри керн породы с прожилками, метка <b>[sample_serial]</b>."
	else
		. += "Пусто."

/// Fills it from a boulder's record.
/obj/item/excavation/core_sampler/proc/take_core(datum/dig_boulder_record/record)
	sample_serial = record.serial
	sample_field = record.field
	sample_age = record.age
	sample_site_kind = record.site_kind
	update_appearance()

/// Empties it.
/obj/item/excavation/core_sampler/proc/clear_core()
	sample_serial = null
	sample_field = null
	sample_age = null
	sample_site_kind = null
	update_appearance()

/obj/item/excavation/core_sampler/update_icon_state()
	icon_state = sample_serial ? "sampler_full" : "sampler"
	return ..()

/obj/item/excavation/core_sampler/attack_self(mob/user, modifiers)
	. = ..()
	if(. || !sample_serial)
		return
	clear_core()
	playsound(src, 'sound/effects/rock/rocktap3.ogg', 30, TRUE)
	to_chat(user, span_notice("Вы выбиваете керн из [src]. Он рассыпается."))
	return TRUE

// ===== Bag and belt =====

/// A satchel for strange rocks and small finds.
/obj/item/storage/bag/excavation
	name = "сумка для находок"
	desc = "Мягкая сумка с отделением для каждого странного камня."
	icon = 'modular_bandastation/xenoarchaeology/icons/dig_tools.dmi'
	icon_state = "find_bag"
	inhand_icon_state = "satchel-explorer"
	lefthand_file = 'icons/mob/inhands/equipment/backpack_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/backpack_righthand.dmi'
	worn_icon_state = "satchel"
	slot_flags = ITEM_SLOT_BELT | ITEM_SLOT_POCKETS
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = FLAMMABLE
	storage_type = /datum/storage/bag/excavation
	custom_materials = list(/datum/material/plastic = SHEET_MATERIAL_AMOUNT)

/datum/storage/bag/excavation
	max_slots = 12
	max_specific_storage = WEIGHT_CLASS_NORMAL
	max_total_storage = 40

/datum/storage/bag/excavation/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(list(
		/obj/item/strange_rock,
		/obj/item/xenoarch_curio,
		/obj/item/relic,
	))

/// A webbing rig with loops for the dig kit.
/obj/item/storage/belt/excavation
	name = "разгрузка для раскопок"
	desc = "Нагрудная разгрузка с петлями для насадок, кистей и пробоотборника и карманом для полевых меток."
	icon_state = "explorer2"
	inhand_icon_state = "explorer2"
	worn_icon_state = "explorer2"
	storage_type = /datum/storage/excavation_belt

/datum/storage/excavation_belt
	max_slots = 8
	max_specific_storage = WEIGHT_CLASS_NORMAL
	max_total_storage = 21

/datum/storage/excavation_belt/New(atom/parent, max_slots, max_specific_storage, max_total_storage, rustle_sound, remove_rustle_sound)
	. = ..()
	set_holdable(list(
		/obj/item/excavation,
		/obj/item/storage/bag/excavation,
		/obj/item/mining_scanner,
		/obj/item/t_scanner/adv_mining_scanner,
		/obj/item/gps,
		/obj/item/pickaxe/mini,
		/obj/item/strange_rock,
		/obj/item/flashlight,
		/obj/item/paper,
		/obj/item/pen,
	))

/// The kit the autolathe prints: webbing with the hand tools and a satchel.
/obj/item/storage/belt/excavation/full

/obj/item/storage/belt/excavation/full/PopulateContents()
	new /obj/item/excavation/hammer(src)
	new /obj/item/excavation/brush(src)
	new /obj/item/excavation/depth_scanner(src)
	new /obj/item/excavation/core_sampler(src)
	new /obj/item/storage/bag/excavation(src)

/**
 * # Field artefact
 *
 * Grows inside an anomaly field and stays bound to it: a hand only wakes the field, a collector lifts it.
 * Carried in hands, pockets or a worn slot, it works on its carrier; a collector or a bag shuts it off.
 * Six hand probes tell its properties apart, and the scan pad catalogues it once for research.
 *
 * Adapted from the Sierra anomaly mod (SierraBay12 `mods/anomaly`), rewritten for our codebase.
 */
/obj/item/field_artefact
	name = "аномальное образование"
	icon = 'modular_bandastation/anomaly_fields/icons/artefacts.dmi'
	inhand_icon_state = "blackcube"
	abstract_type = /obj/item/field_artefact
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = INDESTRUCTIBLE
	/// Still held by the field it grew in.
	var/bound = FALSE
	/// Danger band of the planet it grew on; null if it never grew in a field.
	var/origin_band
	/// Catalogue number, given when it is collected.
	var/serial
	/// Corps journal record, made when it is collected.
	var/datum/expedition_record/xenoarch_find/journal_record
	/// Research the scan pad pays for cataloguing it.
	var/research_points = 100
	/// Paid its catalogue research already.
	var/research_paid = FALSE
	/// What the scan pad reads off it, for the catalogue report.
	var/catalogue_note = ""
	/// FIELD_ARTEFACT_* protections it gives its carrier.
	var/field_protection = NONE
	/// Collector icon state while it sits in one.
	var/collector_state = "collector_empty"
	/// Charge spent by its active properties.
	var/energy = 0
	var/max_energy = 0
	/// Whoever carries it in a slot now.
	var/mob/living/holder
	/// ARTIFACT_ENERGY_* it carries.
	var/energy_kind = ARTIFACT_ENERGY_PARTICLE
	/// Effect an exotic harvester pours from it into a battery, burning it out.
	var/battery_effect = /datum/artifact_effect/light

/obj/item/field_artefact/Initialize(mapload, band)
	. = ..()
	origin_band = band
	energy = max_energy

/obj/item/field_artefact/Destroy()
	if(holder)
		release_holder()
	journal_record = null
	return ..()

/obj/item/field_artefact/proc/set_bound(new_bound)
	bound = new_bound
	set_anchored(new_bound)

/obj/item/field_artefact/attack_hand(mob/user, list/modifiers)
	if(!bound)
		return ..()
	var/obj/effect/anomaly_field/field = locate() in loc
	if(!field)
		set_bound(FALSE)
		return ..()
	field.provoke()
	to_chat(user, span_warning("[capitalize(name)] выскальзывает из пальцев. Его держит поле, нужен коллектор."))
	return TRUE

/// Taken out of its field by `user`: it loosens, and a found one gets its serial and journal record.
/obj/item/field_artefact/proc/collect(mob/user)
	set_bound(FALSE)
	if(isnull(origin_band) || journal_record)
		return
	serial = xenoarch_new_serial()
	journal_record = new(serial, src)
	journal_record.log_observation(user, src, "[capitalize(name)] извлечён коллектором из аномального поля.")
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_RECOVERED, src, user, get_turf(src))

/obj/item/field_artefact/equipped(mob/living/user, slot, initial)
	. = ..()
	if(holder == user)
		return
	if(holder)
		release_holder()
	holder = user
	on_carried(user)
	START_PROCESSING(SSobj, src)

/obj/item/field_artefact/dropped(mob/user, silent)
	. = ..()
	if(holder)
		release_holder()

/obj/item/field_artefact/proc/release_holder()
	STOP_PROCESSING(SSobj, src)
	on_released(holder)
	holder = null

/obj/item/field_artefact/process(seconds_per_tick)
	if(!holder)
		return PROCESS_KILL
	carried_effect(holder, seconds_per_tick)

/// Its carrier picks it up or slots it.
/obj/item/field_artefact/proc/on_carried(mob/living/user)
	return

/// Its carrier lets go of it.
/obj/item/field_artefact/proc/on_released(mob/living/user)
	return

/// Works on its carrier, every few seconds.
/obj/item/field_artefact/proc/carried_effect(mob/living/user, seconds_per_tick)
	return

/obj/item/field_artefact/attack_self(mob/living/user, modifiers)
	. = ..()
	if(. || !isliving(user))
		return
	var/static/list/probes = list("Потрясти", "Постучать", "Сжать", "Потереть", "Лизнуть", "Укусить")
	var/choice = tgui_input_list(user, "Что сделать с [name]?", "Проба", probes)
	if(!choice || QDELETED(src) || !user.is_holding(src) || user.incapacitated)
		return
	if((choice == "Лизнуть" || choice == "Укусить") && user.is_mouth_covered())
		to_chat(user, span_warning("Рот закрыт."))
		return
	user.visible_message(span_notice("[user] пробует [name]: [LOWER_TEXT(choice)]."), span_notice("Вы пробуете [name]: [LOWER_TEXT(choice)]."))
	probe(user, choice)

/// Its answer to a hand probe. Prints nothing by default.
/obj/item/field_artefact/proc/probe(mob/living/user, choice)
	to_chat(user, span_notice("Ничего необычного."))

/// Poured into a battery: what is left is an empty husk, in the same hands or on the same spot.
/obj/item/field_artefact/proc/burn_out()
	var/mob/living/carrier = loc
	var/obj/item/field_artefact_husk/husk = new(drop_location(), src)
	if(istype(carrier) && carrier.is_holding(src))
		qdel(src)
		carrier.put_in_hands(husk)
		return
	qdel(src)

/// What a field artefact leaves after a harvester drains it: it looks the same, grey, and does nothing.
/obj/item/field_artefact_husk
	name = "истощённое образование"
	desc = "Бывшее аномальное образование, из которого вытянули всю энергию. Теперь это просто странный серый камень."
	icon = 'modular_bandastation/anomaly_fields/icons/artefacts.dmi'
	w_class = WEIGHT_CLASS_SMALL
	color = "#8a8a8a"

/obj/item/field_artefact_husk/Initialize(mapload, obj/item/field_artefact/source)
	. = ..()
	if(source)
		name = "истощённое образование ([source.name])"
		icon_state = source.icon_state

/// Spends charge. Returns FALSE if there is not enough.
/obj/item/field_artefact/proc/use_energy(amount)
	if(energy < amount)
		return FALSE
	energy -= amount
	update_appearance()
	return TRUE

// ===== Gravi =====

/obj/item/field_artefact/gravi
	energy_kind = ARTIFACT_ENERGY_BLUESPACE
	battery_effect = /datum/artifact_effect/gravity
	name = "гравитационный конденсат"
	desc = "Стоит взять его в руку, и он упирается, будто не хочет двигаться."
	icon_state = "gravi"
	collector_state = "collector_gravi"
	field_protection = FIELD_ARTEFACT_ANCHOR
	catalogue_note = "При разряде отскакивает от точки контакта в противоположную сторону."

/obj/item/field_artefact/gravi/carried_effect(mob/living/user, seconds_per_tick)
	user.adjust_stamina_loss(-2 * seconds_per_tick)

/obj/item/field_artefact/gravi/probe(mob/living/user, choice)
	switch(choice)
		if("Потрясти")
			to_chat(user, span_nicegreen("Резко опустить его к земле не выходит: он сопротивляется, и рука вместе с ним."))
		if("Постучать")
			to_chat(user, span_notice("Рука словно отпружинивает."))
		if("Сжать")
			to_chat(user, span_notice("Не поддаётся, как камень."))
		if("Потереть")
			to_chat(user, span_notice("На ощупь камень."))
		if("Лизнуть")
			to_chat(user, span_notice("На вкус как камень."))
		if("Укусить")
			to_chat(user, span_notice("Зубы стукаются о камень. Ничего необычного."))

// ===== Flyer =====

/obj/item/field_artefact/flyer
	energy_kind = ARTIFACT_ENERGY_PSIONIC
	battery_effect = /datum/artifact_effect/bestow/sprint
	name = "левитационное образование"
	desc = "Совершенно невесомый, словно плотный сгусток воздуха."
	icon_state = "flyer"
	collector_state = "collector_flyer"
	field_protection = FIELD_ARTEFACT_LIFT
	research_points = 120
	catalogue_note = "Ни на одно воздействие не отвечает. Весы площадки не регистрируют массы."

/obj/item/field_artefact/flyer/on_carried(mob/living/user)
	user.add_traits(list(TRAIT_MOVE_FLOATING, TRAIT_PASSTABLE), REF(src))

/obj/item/field_artefact/flyer/on_released(mob/living/user)
	user.remove_traits(list(TRAIT_MOVE_FLOATING, TRAIT_PASSTABLE), REF(src))

/obj/item/field_artefact/flyer/carried_effect(mob/living/user, seconds_per_tick)
	user.adjust_stamina_loss(-2 * seconds_per_tick)

/obj/item/field_artefact/flyer/probe(mob/living/user, choice)
	switch(choice)
		if("Потрясти")
			to_chat(user, span_nicegreen("Стоит на миг его отпустить, и он зависает в воздухе."))
		if("Постучать")
			to_chat(user, span_notice("От удара он едва не выпрыгивает из рук."))
		if("Сжать")
			to_chat(user, span_notice("Легко сжимается в шарик и тут же расправляется. Очень мягкий."))
		if("Потереть")
			to_chat(user, span_notice("Будто водите рукой по воздуху."))
		if("Лизнуть")
			to_chat(user, span_notice("На вкус как воздух."))
		if("Укусить")
			to_chat(user, span_notice("Материя расступается перед зубами."))

// ===== Svetlyak =====

/obj/item/field_artefact/svetlyak
	energy_kind = ARTIFACT_ENERGY_PARTICLE
	battery_effect = /datum/artifact_effect/light
	name = "фотолюминесцентное образование"
	desc = "Безумно яркий: смотреть на него дольше пары секунд неприятно."
	icon_state = "svetlyak"
	collector_state = "collector_svetlyak"
	field_protection = FIELD_ARTEFACT_BLINDPROOF
	light_system = OVERLAY_LIGHT
	light_range = 4
	light_power = 1.5
	light_color = "#dff4ff"
	light_on = TRUE
	max_energy = 1000
	catalogue_note = "Излучение и разряд проходят сквозь объект без потерь, луч лазера выходит из него усиленным."
	/// A flash is building up.
	var/flashing = FALSE

/obj/item/field_artefact/svetlyak/probe(mob/living/user, choice)
	switch(choice)
		if("Потрясти")
			if(flashing || !use_energy(50))
				to_chat(user, span_notice("Светится всё так же."))
				return
			flashing = TRUE
			to_chat(user, span_warning("Он то разгорается, то тускнеет..."))
			addtimer(CALLBACK(src, PROC_REF(flash_burst)), 2 SECONDS)
		if("Постучать")
			to_chat(user, span_notice("Рука проходит сквозь него."))
		if("Сжать")
			to_chat(user, span_notice("Пальцы проходят насквозь, но он остаётся в ладони."))
		if("Потереть")
			to_chat(user, span_notice("Светится всё так же."))
		if("Лизнуть")
			to_chat(user, span_notice("Язык ничего не чувствует, будто проходит насквозь."))
		if("Укусить")
			to_chat(user, span_notice("Зубы проходят сквозь него."))

/// Blinds and dazes everyone who can see it, except those a svetlyak protects.
/obj/item/field_artefact/svetlyak/proc/flash_burst()
	flashing = FALSE
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/mob/living/victim in view(7, here))
		if(field_artefact_protection(victim) & FIELD_ARTEFACT_BLINDPROOF)
			continue
		if(victim.flash_act(affect_silicon = TRUE))
			victim.adjust_confusion(5 SECONDS)

// ===== Pruzhina =====

/obj/item/field_artefact/pruzhina
	energy_kind = ARTIFACT_ENERGY_ELECTROMAGNETIC
	battery_effect = /datum/artifact_effect/cell/charge
	name = "электретное образование"
	desc = "Мышцы руки сводит, как от слабого тока, волосы встают дыбом."
	icon_state = "pruzhina"
	collector_state = "collector_pruzhina"
	research_points = 80
	max_energy = 1000
	catalogue_note = "Поглощает переданный разряд целиком. При ударе о преграду теряет устойчивость."
	/// Overloading after a throw.
	var/overloading = FALSE

/obj/item/field_artefact/pruzhina/equipped(mob/living/user, slot, initial)
	. = ..()
	if(slot & ITEM_SLOT_HANDS)
		user.electrocute_act(10, src, 1, SHOCK_NOSTUN)

/obj/item/field_artefact/pruzhina/probe(mob/living/user, choice)
	switch(choice)
		if("Потрясти")
			to_chat(user, span_nicegreen("Начинает пощёлкивать и будто оживает. Похоже на мурчание."))
		if("Постучать")
			discharge(user)
		if("Сжать")
			to_chat(user, span_notice("Поле выталкивает его из пальцев обратно."))
		if("Потереть")
			if(!use_energy(100))
				to_chat(user, span_notice("Не отвечает."))
				return
			to_chat(user, span_notice("Волосы встают дыбом."))
			charge_cells()
		if("Лизнуть", "Укусить")
			to_chat(user, span_warning("Язык пронзает острая боль, как от оголённого провода."))
			use_energy(50)
			user.electrocute_act(15, src, 1, SHOCK_NOGLOVES)

/// Shocks everyone close by.
/obj/item/field_artefact/pruzhina/proc/discharge(mob/living/user)
	to_chat(user, span_userdanger("Вспышка!"))
	use_energy(200)
	for(var/mob/living/victim in range(3, get_turf(src)))
		Beam(victim, icon_state = "electra_long", icon = 'modular_bandastation/anomaly_fields/icons/fields.dmi', time = 0.3 SECONDS)
		victim.electrocute_act(25, src, 1, SHOCK_NOGLOVES)

/// Tops up every cell nearby: loose or carried ones, and those in APCs.
/obj/item/field_artefact/pruzhina/proc/charge_cells()
	var/turf/here = get_turf(src)
	for(var/obj/machinery/power/apc/apc in range(3, here))
		apc.cell?.give(apc.cell.maxcharge * 0.1)
	for(var/obj/item/stock_parts/power_store/cell in range(3, here))
		cell.give(cell.maxcharge * 0.1)
	for(var/mob/living/carrier in range(3, here))
		for(var/obj/item/stock_parts/power_store/carried in carrier.get_all_contents())
			carried.give(carried.maxcharge * 0.1)

/obj/item/field_artefact/pruzhina/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	. = ..()
	if(overloading || bound)
		return
	overloading = TRUE
	visible_message(span_warning("[capitalize(name)] начинает пульсировать!"))
	addtimer(CALLBACK(src, PROC_REF(overload)), 2.5 SECONDS)

/// Collapses into a short-lived electra on its tile.
/obj/item/field_artefact/pruzhina/proc/overload()
	var/turf/here = get_turf(src)
	if(here && !(locate(/obj/effect/anomaly_field) in here))
		var/obj/effect/anomaly_field/electra/burst = new(here)
		QDEL_IN(burst, 2 MINUTES)
	qdel(src)

// ===== Zjar =====

/obj/item/field_artefact/zjar
	energy_kind = ARTIFACT_ENERGY_ORGANIC
	battery_effect = /datum/artifact_effect/heal
	name = "пирогенное образование"
	desc = "Тепло растекается по рукам; от одного его вида становится теплее."
	icon_state = "fire_ball"
	collector_state = "collector_zjar"
	max_energy = 1500
	catalogue_note = "Поглощает разряд. Луч лазера прожигает и повреждает объект; в огне восстанавливается."

/obj/item/field_artefact/zjar/Initialize(mapload, band)
	. = ..()
	energy = 1000

/obj/item/field_artefact/zjar/update_icon_state()
	icon_state = energy > 1000 ? "fire_ball_active" : "fire_ball"
	return ..()

/obj/item/field_artefact/zjar/fire_act(exposed_temperature, exposed_volume)
	. = ..()
	energy = min(energy + 100, max_energy)
	update_appearance()

/obj/item/field_artefact/zjar/carried_effect(mob/living/user, seconds_per_tick)
	if(user.bodytemperature < BODYTEMP_NORMAL)
		user.adjust_bodytemperature(10 * seconds_per_tick, max_temp = BODYTEMP_NORMAL)
	if(!iscarbon(user))
		return
	var/mob/living/carbon/carbon = user
	for(var/obj/item/organ/organ as anything in carbon.organs)
		if(organ.damage > 0 && use_energy(1))
			organ.apply_organ_damage(-0.5 * seconds_per_tick)

/obj/item/field_artefact/zjar/probe(mob/living/user, choice)
	switch(choice)
		if("Потрясти")
			to_chat(user, span_notice("Внутри будто что-то есть, но он монолитный."))
		if("Постучать")
			use_energy(50)
			to_chat(user, span_warning("Похоже, ему это не понравилось: руку ошпарило."))
			user.apply_damage(10, BURN, user.get_active_hand())
		if("Сжать")
			to_chat(user, span_notice("Как желе, но не желе. Очень странно."))
		if("Потереть")
			to_chat(user, span_nicegreen("Тепло и приятно, не хочется убирать руки."))
		if("Лизнуть")
			to_chat(user, span_nicegreen("...он вкусный. По телу растекается тепло."))
			user.adjust_bodytemperature(15)
		if("Укусить")
			if(!use_energy(100))
				to_chat(user, span_notice("Тёплый, и только."))
				return
			to_chat(user, span_nicegreen("Становится жарко, но думается свободнее и проще."))
			user.adjust_bodytemperature(30)
			user.adjust_organ_loss(ORGAN_SLOT_BRAIN, -20)

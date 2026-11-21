GLOBAL_DATUM_INIT(relay_fabricator_ui_state, /datum/ui_state/relay_fabricator, new)

/datum/ui_state/relay_fabricator/can_use_topic(obj/machinery/relay_fabricator/fabricator, mob/user)
	if(istype(user, /mob/living/basic/relay_operator))
		return fabricator.operator_relay(user) ? UI_INTERACTIVE : UI_CLOSE
	if(!fabricator.Adjacent(user))
		return UI_CLOSE
	return GLOB.default_state.can_use_topic(fabricator, user)

/// A remote session is valid only while this operator can use its linked relay.
/obj/machinery/relay_fabricator/proc/operator_relay(mob/living/basic/relay_operator/user)
	var/obj/machinery/overmap_droid_relay/relay = user.relay_ref?.resolve()
	if(relay?.can_operate(user) && relay.fabricator_ref?.resolve() == src && relay.valid_link(src))
		return relay
	return null

/obj/machinery/relay_fabricator/ui_state(mob/user)
	return GLOB.relay_fabricator_ui_state

/obj/machinery/relay_fabricator/ui_status(mob/user, datum/ui_state/state)
	// The atom's default status requires hand reach even when the relay authorizes remote use.
	if(state == GLOB.relay_fabricator_ui_state && istype(user, /mob/living/basic/relay_operator))
		return state.can_use_topic(src, user)
	return ..()

/obj/machinery/relay_fabricator/ui_interact(mob/user, datum/tgui/ui)
	if(GLOB.relay_fabricator_ui_state.can_use_topic(src, user) < UI_UPDATE)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DroidFabricator", "Производство дроидов")
		ui.open()

/obj/machinery/relay_fabricator/ui_data(mob/user)
	var/obj/machinery/overmap_droid_relay/relay
	if(istype(user, /mob/living/basic/relay_operator))
		relay = operator_relay(user)
		if(!relay)
			return list()
	var/obj/machinery/relay_resource_storage/storage = connected_storage()
	var/datum/material_container/stock = storage?.materials
	var/list/materials = list()
	var/list/catalog = list()
	for(var/datum/droid_fabrication_design/design as anything in designs)
		if(relay && !(design.droid_type in relay.profile.droid_types))
			continue
		var/list/costs = list()
		for(var/material_type in design.materials)
			var/datum/material/material = SSmaterials.get_material(material_type)
			var/id = REF(material)
			materials[id] ||= resource_ui_data(material, stock?.get_material_amount(material))
			costs += list(list(
				"id" = id,
				"required" = design.materials[material_type] / SHEET_MATERIAL_AMOUNT,
			))
		var/duration = print_duration(design)
		catalog += list(list(
			"id" = REF(design),
			"name" = design.name,
			"description" = design.desc,
			"portrait" = droid_relay_portrait(design.droid_type),
			"costs" = costs,
			"seconds" = CEILING(duration / (1 SECONDS), 1),
			"energy" = design.energy_cost / (1 KILO JOULES),
			"enabled" = !!(duration && design.can_fabricate(src, storage)),
		))
	for(var/datum/material/material as anything in stock?.materials)
		var/amount = stock.get_material_amount(material)
		if(amount > 0)
			materials[REF(material)] ||= resource_ui_data(material, amount)
	var/blocked
	if(!storage)
		blocked = "Подключите хранилище грузовой трубой."
	else if(!printing_design && !can_start_print())
		blocked = "Фабрикатор недоступен. Проверьте питание и состояние машины."
	else if(relay && !relay.has_storage_space())
		blocked = "В реле нет места для готового корпуса."
	var/time_remaining = print_timer ? timeleft(print_timer) : 0
	return list(
		"designs" = catalog,
		"materials" = materials,
		"storage" = storage ? list("used" = stock.total_amount() / SHEET_MATERIAL_AMOUNT, "capacity" = storage.sheet_capacity) : null,
		"blocked" = blocked,
		"printing" = printing_design?.name,
		"remaining" = CEILING(time_remaining / (1 SECONDS), 1),
		"progress" = active_print_duration ? clamp(1 - time_remaining / active_print_duration, 0, 1) : 0,
		"delivery" = relay ? "В реле" : "На площадку фабрикатора",
		"productivity" = productivity,
	)

/// Share the live quantity and item sprite between storage and recipe requirements.
/obj/machinery/relay_fabricator/proc/resource_ui_data(datum/material/material, amount)
	var/static/list/sprites = list()
	var/obj/item/sprite_type = material.sheet_type || material.ore_type
	if(sprite_type && !(sprite_type in sprites))
		sprites[sprite_type] = icon2base64(icon(initial(sprite_type.icon), initial(sprite_type.icon_state), frame = 1))
	return list(
		"name" = capitalize(material.declent_ru(NOMINATIVE)),
		"icon" = sprite_type ? sprites[sprite_type] : null,
		"available" = (amount || 0) / SHEET_MATERIAL_AMOUNT,
	)

/obj/machinery/relay_fabricator/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(. || action != "print" || !istext(params["design"]))
		return .
	var/mob/actor = ui.user
	if(GLOB.relay_fabricator_ui_state.can_use_topic(src, actor) != UI_INTERACTIVE)
		return FALSE
	var/obj/machinery/overmap_droid_relay/relay
	if(istype(actor, /mob/living/basic/relay_operator))
		relay = operator_relay(actor)
		if(!relay)
			return FALSE
	else if(!can_interact(actor))
		return FALSE
	var/datum/droid_fabrication_design/design = locate(params["design"]) in designs
	if(!print_chassis(design, relay))
		to_chat(actor, span_warning("Сборка недоступна. Проверьте состояние фабрикатора, подключение хранилища и материалы."))
	return TRUE

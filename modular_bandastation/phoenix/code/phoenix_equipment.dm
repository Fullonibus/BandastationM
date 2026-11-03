/// An archival preservation capsule and material acceptance point.
/obj/machinery/phoenix_capsule
	name = "Phoenix preservation capsule"
	desc = "Архивная капсула проекта «Феникс». Сохраняет образец и принимает биоволокно. Для лечения живой особи в стазисе залейте либитал из мензурки. Тяжёлые повреждения восстанавливаются примерно за три минуты."
	icon = 'modular_bandastation/phoenix/icons/phoenix_equipment.dmi'
	icon_state = "capsule_empty"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	/// The sole preserved animal, released on exit or teardown.
	var/mob/living/basic/phoenix_weaver/archived_specimen

/obj/machinery/phoenix_capsule/Initialize(mapload, datum/phoenix_strain/source_strain, source_project_id)
	create_reagents(PHOENIX_MEDICINE_CAPACITY, OPENCONTAINER | NO_REACT)
	. = ..()
	if(source_strain)
		load_archive(source_strain, source_project_id)

/obj/machinery/phoenix_capsule/update_icon_state()
	. = ..()
	icon_state = QDELETED(archived_specimen) ? "capsule_empty" : "capsule_occupied"

/** Load an archived founder directly into stasis, before it can encounter the delivery environment. */
/obj/machinery/phoenix_capsule/proc/load_archive(datum/phoenix_strain/source_strain, source_project_id)
	if(archived_specimen || QDELETED(source_strain))
		return FALSE
	archived_specimen = new(src, source_strain, source_project_id)
	if(QDELETED(archived_specimen))
		archived_specimen = null
		return FALSE
	ADD_TRAIT(archived_specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	update_appearance(UPDATE_ICON_STATE)
	return TRUE

/obj/machinery/phoenix_capsule/Destroy()
	release_specimen()
	return ..()

/** External treatment continues in stasis, with every restored point backed by medicine from the tank. */
/obj/machinery/phoenix_capsule/process(seconds_per_tick)
	if(!is_operational || seconds_per_tick <= 0)
		return
	var/mob/living/basic/phoenix_weaver/specimen = archived_specimen
	if(QDELETED(specimen) || specimen.loc != src || specimen.stat == DEAD || !HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE))
		return
	var/recovery = min(
		specimen.get_brute_loss(),
		specimen.maxHealth / PHOENIX_TREATMENT_SECONDS * seconds_per_tick,
		reagents.get_reagent_amount(PHOENIX_MEDICINE_TYPE) / PHOENIX_MEDICINE_PER_HEALTH,
	)
	if(recovery <= 0)
		return
	// Round the dose up to the reservoir's precision so the final fraction of damage remains treatable.
	var/medicine_dose = CEILING(recovery * PHOENIX_MEDICINE_PER_HEALTH, CHEMICAL_QUANTISATION_LEVEL)
	var/medicine_used = reagents.remove_reagent(PHOENIX_MEDICINE_TYPE, medicine_dose)
	if(medicine_used > 0)
		specimen.heal_overall_damage(min(recovery, medicine_used / PHOENIX_MEDICINE_PER_HEALTH))

/obj/machinery/phoenix_capsule/Exited(atom/movable/gone, direction)
	if(gone == archived_specimen)
		REMOVE_TRAIT(archived_specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
		archived_specimen = null
		update_appearance(UPDATE_ICON_STATE)
	return ..()

/** Preserve a nearby exposed weaver; ordinary containers cannot impersonate a capsule. */
/obj/machinery/phoenix_capsule/proc/preserve(mob/living/basic/phoenix_weaver/specimen)
	if(archived_specimen || QDELETED(specimen) || !isturf(specimen.loc) || !specimen.Adjacent(src))
		return FALSE
	archived_specimen = specimen
	ADD_TRAIT(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	specimen.forceMove(src)
	update_appearance(UPDATE_ICON_STATE)
	return TRUE

/** Return the animal to the world and release the equipment's trait and reference. */
/obj/machinery/phoenix_capsule/proc/release_specimen()
	var/mob/living/basic/phoenix_weaver/specimen = archived_specimen
	archived_specimen = null
	if(!QDELETED(src))
		update_appearance(UPDATE_ICON_STATE)
	if(QDELETED(specimen))
		return
	REMOVE_TRAIT(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
	specimen.forceMove(drop_location())

/obj/machinery/phoenix_capsule/examine(mob/user)
	. = ..()
	var/capsule_status = archived_specimen ? "Образец сохранён в стазисе. Взаимодействуйте с капсулой для пробуждения." : "Капсула пуста. В неё можно поместить находящегося рядом ткача."
	. += span_notice(capsule_status)
	. += span_notice("Либитал: [round(reagents.get_reagent_amount(PHOENIX_MEDICINE_TYPE), 0.1)] ед. Резервуар вмещает [reagents.maximum_volume] ед. раствора; заполните его из мензурки. Лечение живого ткача в стазисе начинается автоматически.")
	var/datum/station_goal/phoenix/goal = SSstation.get_station_goal(/datum/station_goal/phoenix)
	if(goal)
		. += span_notice("Принято биоволокна: [goal.fiber_delivered] / [PHOENIX_FIBER_TARGET].")

/obj/machinery/phoenix_capsule/ui_state(mob/user)
	return GLOB.notcontained_state

/obj/machinery/phoenix_capsule/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PhoenixCapsule", "Проект «Феникс»")
		ui.open()

/** Report current reservoir and specimen readings on every normal TGUI update. */
/obj/machinery/phoenix_capsule/ui_data(mob/user)
	var/list/data = list()
	var/medicine_amount = reagents.get_reagent_amount(PHOENIX_MEDICINE_TYPE)
	data["medicine_amount"] = round(medicine_amount, 0.1)
	data["total_volume"] = round(reagents.total_volume, 0.1)
	data["capacity"] = reagents.maximum_volume
	data["operational"] = is_operational
	data["specimen"] = null
	data["candidates"] = list()
	data["treatment_status"] = "empty"
	var/static/list/stage_names = list("Личинка", "Кокон", "Взрослая особь")
	var/mob/living/basic/phoenix_weaver/specimen = archived_specimen
	if(!QDELETED(specimen))
		var/in_stasis = HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE)
		data["specimen"] = list(
			"ref" = REF(specimen),
			"name" = specimen.name,
			"generation" = specimen.generation,
			"stage" = stage_names[specimen.life_stage],
			"health" = specimen.health,
			"max_health" = specimen.maxHealth,
			"nutrition" = specimen.nutrition,
			"alive" = specimen.stat != DEAD,
			"stasis" = in_stasis,
		)
		if(specimen.stat == DEAD)
			data["treatment_status"] = "dead"
		else if(!is_operational)
			data["treatment_status"] = "offline"
		else if(specimen.loc != src || !in_stasis)
			data["treatment_status"] = "inactive"
		else if(specimen.get_brute_loss() <= 0)
			data["treatment_status"] = "healthy"
		else if(medicine_amount <= 0)
			data["treatment_status"] = "no_medicine"
		else
			data["treatment_status"] = "treating"
	else if(!QDELETED(user) && user.Adjacent(src))
		var/list/candidates = data["candidates"]
		for(var/mob/living/basic/phoenix_weaver/candidate in range(1, src))
			if(!isturf(candidate.loc) || !candidate.Adjacent(src) || !candidate.Adjacent(user))
				continue
			candidates += list(list(
				"ref" = REF(candidate),
				"name" = candidate.name,
				"generation" = candidate.generation,
				"stage" = stage_names[candidate.life_stage],
				"alive" = candidate.stat != DEAD,
			))
	var/datum/station_goal/phoenix/goal = SSstation.get_station_goal(/datum/station_goal/phoenix)
	data["goal_active"] = !!goal
	data["fiber_delivered"] = goal?.fiber_delivered || 0
	data["fiber_target"] = PHOENIX_FIBER_TARGET
	return data

/obj/machinery/phoenix_capsule/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	if(!isliving(user) || QDELETED(user) || !user.Adjacent(src) || user.incapacitated || !can_interact(user))
		return FALSE
	switch(action)
		if("release")
			if(QDELETED(archived_specimen))
				balloon_alert(user, "капсула пуста!")
				return TRUE
			if(!istext(params["specimen"]) || params["specimen"] != REF(archived_specimen))
				balloon_alert(user, "образец изменился!")
				return TRUE
			var/was_alive = archived_specimen.stat != DEAD
			release_specimen()
			balloon_alert(user, was_alive ? "образец пробуждён" : "образец извлечён")
			return TRUE
		if("preserve")
			if(archived_specimen)
				balloon_alert(user, "капсула занята!")
				return TRUE
			if(!istext(params["specimen"]))
				return FALSE
			var/mob/living/basic/phoenix_weaver/selected = locate(params["specimen"]) in range(1, src)
			if(!istype(selected) || QDELETED(selected) || !selected.Adjacent(user) || !preserve(selected))
				balloon_alert(user, "особь недоступна!")
				return TRUE
			balloon_alert(user, "особь сохранена")
			return TRUE
	return FALSE

/obj/machinery/phoenix_capsule/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/phoenix_fiber))
		return ..()
	if(!user.Adjacent(src) || user.incapacitated)
		return ITEM_INTERACT_BLOCKING
	var/datum/station_goal/phoenix/goal = SSstation.get_station_goal(/datum/station_goal/phoenix)
	var/accepted = goal?.accept_fiber(tool, user)
	balloon_alert(user, accepted ? "принято: [accepted]" : "партия не принята")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/phoenix_capsule/wrench_act(mob/living/user, obj/item/tool)
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/// Limited heritable changes are applied to nearby eggs using station research points.
/obj/machinery/phoenix_research
	name = "Phoenix adaptation station"
	desc = "Станция адаптации клеточной линии янтарного ткача. Загрузите яйцо кликом из руки. Изменения сохраняются в потомстве и расходуют общие научные очки станции."
	icon = 'modular_bandastation/phoenix/icons/phoenix_equipment.dmi'
	icon_state = "adaptation_on"
	density = TRUE
	anchored = FALSE
	use_power = IDLE_POWER_USE
	req_access = list(ACCESS_RESEARCH)
	/// The physical egg held in research stasis until ejected or removed.
	var/obj/item/phoenix_egg/loaded_egg
	/// The connected techweb supplies the same shared point pool as the R&D console.
	var/datum/techweb/stored_research
	/// Player-facing descriptions, never the hidden numerical phenotype requirements.
	var/static/list/adaptation_options = list(
		"temperature" = list("name" = "Температура", "description" = "Сдвигает температурные допуски в сторону станционной температуры"),
		"pressure" = list("name" = "Давление", "description" = "Сдвигает допуски давления в сторону станционного давления"),
		"light" = list("name" = "Освещение", "description" = "Расширяет диапазон подходящей освещённости"),
		"allergy" = list("name" = "Питание", "description" = "Устраняет пищевую аллергию линии"),
		"yield" = list("name" = "Биоволокно", "description" = "Повышает выход волокна, но увеличивает расход корма"),
	)

/obj/machinery/phoenix_research/post_machine_initialize()
	. = ..()
	if(!CONFIG_GET(flag/no_default_techweb_link) && !stored_research)
		CONNECT_TO_RND_SERVER_ROUNDSTART(stored_research, src)

/obj/machinery/phoenix_research/Destroy()
	eject_egg()
	stored_research = null
	return ..()

/obj/machinery/phoenix_research/Exited(atom/movable/gone, direction)
	if(gone == loaded_egg)
		REMOVE_TRAIT(loaded_egg, TRAIT_STASIS, REF(src))
		loaded_egg = null
	return ..()

/obj/machinery/phoenix_research/update_icon_state()
	. = ..()
	icon_state = is_operational ? "adaptation_on" : "adaptation_off"

/obj/machinery/phoenix_research/on_set_is_operational(old_value)
	. = ..()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/phoenix_research/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/phoenix_egg) || user.combat_mode)
		return ..()
	if(!user.Adjacent(src) || user.incapacitated || !can_interact(user) || !allowed(user) || !user.is_holding(tool))
		balloon_alert(user, "загрузка недоступна!")
		return ITEM_INTERACT_BLOCKING
	if(loaded_egg)
		balloon_alert(user, "станция занята!")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/phoenix_egg/egg = tool
	ADD_TRAIT(egg, TRAIT_STASIS, REF(src))
	if(!user.transferItemToLoc(egg, src))
		REMOVE_TRAIT(egg, TRAIT_STASIS, REF(src))
		balloon_alert(user, "нельзя отпустить яйцо!")
		return ITEM_INTERACT_BLOCKING
	loaded_egg = egg
	balloon_alert(user, "яйцо загружено")
	return ITEM_INTERACT_SUCCESS

/** Unload onto the floor and remove only this station's suspension source. */
/obj/machinery/phoenix_research/proc/eject_egg()
	var/obj/item/phoenix_egg/egg = loaded_egg
	loaded_egg = null
	if(QDELETED(egg))
		return
	REMOVE_TRAIT(egg, TRAIT_STASIS, REF(src))
	egg.forceMove(drop_location())
	return egg

/obj/machinery/phoenix_research/ui_state(mob/user)
	return GLOB.notcontained_state

/obj/machinery/phoenix_research/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PhoenixAdaptation", "Станция адаптации «Феникс»")
		ui.open()

/obj/machinery/phoenix_research/ui_data(mob/user)
	var/access_allowed = !QDELETED(user) && allowed(user)
	var/can_operate = access_allowed && isliving(user) && user.Adjacent(src) && !user.incapacitated && can_interact(user)
	var/datum/techweb/research = QDELETED(stored_research) ? null : stored_research
	var/obj/item/phoenix_egg/egg = QDELETED(loaded_egg) ? null : loaded_egg
	var/list/data = list(
		"research_connected" = !!research,
		"points" = research ? (research.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0) : 0,
		"adaptation_cost" = PHOENIX_ADAPTATION_COST,
		"max_adaptations" = PHOENIX_MAX_ADAPTATIONS,
		"operational" = is_operational,
		"access_allowed" = access_allowed,
		"can_operate" = can_operate,
		"egg" = egg ? list("ref" = REF(egg), "name" = egg.name, "generation" = egg.generation, "adaptations" = egg.strain.adaptations) : null,
		"adaptations" = list(),
	)
	var/common_reason
	if(!access_allowed)
		common_reason = "Требуется исследовательский доступ"
	else if(!is_operational)
		common_reason = "Станция не работает"
	else if(!can_operate)
		common_reason = "Нет доступа к управлению"
	else if(!egg)
		common_reason = "Загрузите яйцо"
	else if(!research)
		common_reason = "Нет связи с научной сетью"
	else if(egg.strain.adaptations >= PHOENIX_MAX_ADAPTATIONS)
		common_reason = "Лимит линии исчерпан"
	else if(!research.can_afford(list(TECHWEB_POINT_TYPE_GENERIC = PHOENIX_ADAPTATION_COST)))
		common_reason = "Недостаточно научных очков"
	var/list/options = data["adaptations"]
	for(var/id in adaptation_options)
		var/list/details = adaptation_options[id]
		var/reason = common_reason
		if(!reason)
			switch(id)
				if("temperature")
					if((egg.strain.temperature[2] + egg.strain.temperature[3]) / 2 == T20C)
						reason = "Допуски уже настроены на станционную температуру"
				if("pressure")
					if((egg.strain.pressure[2] + egg.strain.pressure[3]) / 2 == ONE_ATMOSPHERE)
						reason = "Допуски уже настроены на станционное давление"
				if("light")
					if(egg.strain.light[1] <= 0 && egg.strain.light[2] >= 1)
						reason = "Диапазон освещения уже максимален"
				if("allergy")
					if(!egg.strain.allergen)
						reason = "У линии нет пищевой аллергии"
				if("yield")
					if(egg.strain.productivity >= 1.5)
						reason = "Выход волокна уже максимален"
		options += list(list("id" = id, "name" = details["name"], "description" = details["description"], "available" = !reason, "reason" = reason))
	return data

/obj/machinery/phoenix_research/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	if(!isliving(user) || QDELETED(user) || !user.Adjacent(src) || user.incapacitated || !can_interact(user) || !allowed(user))
		return FALSE
	if(!(action in list("eject", "adapt")))
		return FALSE
	if(QDELETED(loaded_egg) || loaded_egg.loc != src || !istext(params["egg"]) || params["egg"] != REF(loaded_egg))
		balloon_alert(user, "яйцо изменилось!")
		return TRUE
	if(action == "eject")
		var/obj/item/phoenix_egg/egg = eject_egg()
		if(!QDELETED(egg))
			user.put_in_hands(egg)
		return TRUE
	var/id = params["adaptation"]
	if(!istext(id) || !(id in adaptation_options))
		return FALSE
	if(!isnum(params["expected_adaptations"]) || params["expected_adaptations"] != loaded_egg.strain.adaptations)
		balloon_alert(user, "данные яйца изменились!")
		return TRUE
	if(QDELETED(stored_research) || !stored_research.can_afford(list(TECHWEB_POINT_TYPE_GENERIC = PHOENIX_ADAPTATION_COST)))
		balloon_alert(user, "недостаточно научных очков!")
		return TRUE
	if(!loaded_egg.strain.adapt(id))
		balloon_alert(user, "адаптация невозможна!")
		return TRUE
	stored_research.adjust_points(TECHWEB_POINT_TYPE_GENERIC, -PHOENIX_ADAPTATION_COST)
	loaded_egg.next_environment_check = 0
	balloon_alert(user, "линия адаптирована")
	return TRUE

/obj/machinery/phoenix_research/wrench_act(mob/living/user, obj/item/tool)
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

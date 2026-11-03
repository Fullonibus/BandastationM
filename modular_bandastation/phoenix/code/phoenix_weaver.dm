/// Weak references reserve the finite project population, including unhatched eggs.
GLOBAL_LIST_EMPTY(phoenix_population)

/** Count living animals and eggs belonging to one project, without scanning the world. */
/proc/phoenix_population_count(project_id)
	var/population = 0
	for(var/datum/weakref/reference as anything in GLOB.phoenix_population)
		var/atom/movable/member = reference.resolve()
		if(istype(member, /mob/living/basic/phoenix_weaver))
			var/mob/living/basic/phoenix_weaver/weaver = member
			if(weaver.project_id == project_id && weaver.stat != DEAD)
				population++
		else if(istype(member, /obj/item/phoenix_egg))
			var/obj/item/phoenix_egg/egg = member
			if(egg.project_id == project_id)
				population++
	return population

/** Flightless archive arthropod whose development and productivity depend on its inherited ecology. */
/mob/living/basic/phoenix_weaver
	name = "янтарный ткач"
	desc = "Бескрылый ткач с округлыми янтарными сегментами и короткими ножками. Между складками покрова поблёскивают шёлковые нити."
	icon = 'modular_bandastation/phoenix/icons/phoenix_weaver.dmi'
	icon_state = "weaver"
	icon_living = "weaver"
	icon_dead = "weaver_dead"
	health = 40
	maxHealth = 40
	mob_biotypes = MOB_ORGANIC|MOB_BUG
	mob_size = MOB_SIZE_SMALL
	layer = LOW_MOB_LAYER
	density = FALSE
	faction = list(FACTION_NEUTRAL)
	speed = 2
	speak_emote = list("chitters")
	ai_controller = /datum/ai_controller/basic_controller/phoenix_weaver
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	/// Owned copy of the inherited ecological profile.
	var/datum/phoenix_strain/strain
	/// Provenance used by the goal and the physical fiber stacks.
	var/project_id
	/// Zero identifies the archival founder; natural descendants increment this value.
	var/generation = 0
	/// Development keeps this mob and its owned profile throughout all three stages.
	var/life_stage = PHOENIX_ADULT
	/// Seconds of supported development within the current immature stage.
	var/growth_seconds = 0
	/// Seconds of supported adult reproduction since the previous egg.
	var/breeding_seconds = 0
	/// Seconds of supported adult fiber production since the previous batch.
	var/fiber_seconds = 0
	/// Fractional output is retained, including the founder's reduced production.
	var/fiber_remainder = 0
	/// Latest measured environmental diagnosis, refreshed on demand or every ten seconds.
	var/list/last_environment
	/// World time of the next scheduled environmental snapshot.
	var/next_environment_check = 0
	/// Remaining seconds for which the last allergic reaction can be diagnosed.
	var/allergy_seconds = 0
	/// Registry entry removed during teardown.
	var/datum/weakref/population_reference

/mob/living/basic/phoenix_weaver/Initialize(mapload, datum/phoenix_strain/source_strain, source_project_id, source_generation = 0)
	strain = source_strain ? source_strain.copy() : new
	project_id = source_project_id
	generation = source_generation
	life_stage = generation ? PHOENIX_LARVA : PHOENIX_ADULT
	. = ..()
	// Mob initialization randomizes nutrition; an archive reserve must not replace regular feeding.
	set_nutrition(30)
	AddElement(/datum/element/ai_retaliate)
	population_reference = WEAKREF(src)
	GLOB.phoenix_population += population_reference
	RegisterSignal(src, COMSIG_LIVING_HEALTHSCAN, PROC_REF(on_healthscan))
	RegisterSignals(src, list(COMSIG_ATOM_ITEM_INTERACTION, COMSIG_ATOM_ITEM_INTERACTION_SECONDARY), PROC_REF(on_medical_interaction))
	update_life_stage()
	var/datum/station_goal/phoenix/goal = SSstation.get_station_goal(/datum/station_goal/phoenix)
	goal?.register_specimen(src)

/mob/living/basic/phoenix_weaver/Destroy()
	GLOB.phoenix_population -= population_reference
	population_reference = null
	UnregisterSignal(src, COMSIG_LIVING_HEALTHSCAN)
	UnregisterSignal(src, list(COMSIG_ATOM_ITEM_INTERACTION, COMSIG_ATOM_ITEM_INTERACTION_SECONDARY))
	QDEL_NULL(strain)
	last_environment = null
	return ..()

/** Keep generic nutrition changes within the weaver's reserve capacity before parent updates and signals. */
/mob/living/basic/phoenix_weaver/adjust_nutrition(change, forced = FALSE)
	return ..(clamp(nutrition + change, 0, PHOENIX_NUTRITION_MAX) - nutrition, forced)

/** Preserve the parent's trait checks while keeping initialization and healing on the percentage scale. */
/mob/living/basic/phoenix_weaver/set_nutrition(set_to, forced = FALSE)
	return ..(clamp(set_to, 0, PHOENIX_NUTRITION_MAX), forced)

/** Ordinary dressings cannot treat the armored archive species; reject both item click paths before use. */
/mob/living/basic/phoenix_weaver/proc/on_medical_interaction(datum/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(tool, /obj/item/stack/medical))
		return NONE
	balloon_alert(user, "нужно лечение в капсуле!")
	return ITEM_INTERACT_BLOCKING

/mob/living/basic/phoenix_weaver/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(QDELETED(src))
		return
	process_biology(seconds_per_tick)

/** Explicit observations bypass the periodic cache and measure the current enclosure. */
/mob/living/basic/phoenix_weaver/proc/assess_environment()
	last_environment = strain.assess_environment(src)
	next_environment_check = world.time + PHOENIX_ENVIRONMENT_SECONDS SECONDS
	return last_environment

/** Advance metabolism and the supported life cycle using elapsed seconds, never subsystem tick counts. */
/mob/living/basic/phoenix_weaver/proc/process_biology(seconds_per_tick)
	if(stat == DEAD || HAS_TRAIT(src, TRAIT_STASIS) || seconds_per_tick <= 0)
		return
	if(!last_environment || world.time >= next_environment_check)
		assess_environment()
	allergy_seconds = max(0, allergy_seconds - seconds_per_tick)
	var/fed_seconds = min(seconds_per_tick, nutrition / strain.food_demand)
	nutrition = max(0, nutrition - strain.food_demand * seconds_per_tick)
	if(fed_seconds < seconds_per_tick)
		apply_damage((seconds_per_tick - fed_seconds) * 0.5, BRUTE)
	if(last_environment["state"] == PHOENIX_DANGER)
		apply_damage(seconds_per_tick * 0.5, BRUTE)
		return
	if(stat == DEAD || fed_seconds <= 0)
		return
	if(last_environment["state"] != PHOENIX_BREEDING)
		return
	var/adult_seconds = fed_seconds
	while(life_stage != PHOENIX_ADULT && adult_seconds > 0)
		var/required_seconds = life_stage == PHOENIX_LARVA ? PHOENIX_LARVA_SECONDS : PHOENIX_COCOON_SECONDS
		var/advance_seconds = min(adult_seconds, required_seconds - growth_seconds)
		growth_seconds += advance_seconds
		adult_seconds -= advance_seconds
		if(growth_seconds < required_seconds)
			return
		life_stage++
		growth_seconds = 0
		update_life_stage()
	if(adult_seconds <= 0)
		return
	fiber_seconds += adult_seconds
	var/batches = floor(fiber_seconds / PHOENIX_FIBER_SECONDS)
	if(batches)
		fiber_seconds -= batches * PHOENIX_FIBER_SECONDS
		fiber_remainder += batches * strain.productivity * (generation ? 1 : 0.2)
		var/amount = floor(fiber_remainder)
		if(amount)
			fiber_remainder -= amount
			new /obj/item/stack/phoenix_fiber(drop_location(), amount, project_id)
	breeding_seconds += adult_seconds
	while(breeding_seconds >= PHOENIX_BREED_SECONDS)
		if(phoenix_population_count(project_id) >= PHOENIX_MAX_POPULATION)
			breeding_seconds = PHOENIX_BREED_SECONDS
			return
		breeding_seconds -= PHOENIX_BREED_SECONDS
		new /obj/item/phoenix_egg(drop_location(), strain, project_id, generation + 1)
		visible_message(span_notice("[src] откладывает янтарное яйцо."))

/** Apply stage appearance and cocoon immobility without replacing the animal or its lineage. */
/mob/living/basic/phoenix_weaver/proc/update_life_stage()
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, type)
	switch(life_stage)
		if(PHOENIX_LARVA)
			name = "личинка янтарного ткача"
			icon_living = "weaver_larva"
			icon_dead = "weaver_larva_dead"
		if(PHOENIX_COCOON)
			name = "кокон янтарного ткача"
			icon_living = "weaver_cocoon"
			icon_dead = "weaver_cocoon_dead"
			ADD_TRAIT(src, TRAIT_IMMOBILIZED, type)
		if(PHOENIX_ADULT)
			name = initial(name)
			icon_living = "weaver"
			icon_dead = "weaver_dead"
	icon_state = stat == DEAD ? icon_dead : icon_living

/mob/living/basic/phoenix_weaver/item_interaction(mob/living/user, obj/item/used_item, list/modifiers)
	var/datum/component/edible/meal = used_item.GetComponent(/datum/component/edible)
	if(!meal || user.combat_mode)
		return ..()
	if(stat == DEAD || HAS_TRAIT(src, TRAIT_STASIS) || life_stage == PHOENIX_COCOON || user.incapacitated || !user.Adjacent(src) || !user.is_holding(used_item))
		return ITEM_INTERACT_BLOCKING
	if(nutrition >= PHOENIX_NUTRITION_MAX)
		balloon_alert(user, "сыт")
		return ITEM_INTERACT_SUCCESS
	var/food_nutrition = 0
	for(var/datum/reagent/consumable/reagent in used_item.reagents?.reagent_list)
		food_nutrition += reagent.volume * reagent.nutriment_factor
	if(food_nutrition <= 0)
		balloon_alert(user, "несъедобно")
		return ITEM_INTERACT_SUCCESS
	if(meal.foodtypes & strain.allergen)
		allergy_seconds = 60
		apply_damage(5, BRUTE)
		visible_message(span_warning("[src] вздрагивает и отрыгивает корм."))
	else
		nutrition = min(PHOENIX_NUTRITION_MAX, nutrition + food_nutrition)
		visible_message(span_notice("[src] съедает [used_item]."))
		balloon_alert(user, "накормлен")
	user.do_attack_animation(src, no_effect = TRUE)
	qdel(used_item)
	return ITEM_INTERACT_SUCCESS

/mob/living/basic/phoenix_weaver/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		return
	if(HAS_TRAIT(src, TRAIT_STASIS))
		. += span_notice("Жизненные процессы приостановлены стазисом.")
	else if(nutrition < 25)
		. += span_warning("Ткач беспокойно перебирает жвалами: похоже, он голоден.")
	if(allergy_seconds > 0)
		. += span_warning("По панцирю проходят судороги после кормления.")

/** Append biological status and qualitative stress symptoms to the ordinary medical scanner report. */
/mob/living/basic/phoenix_weaver/proc/on_healthscan(datum/source, list/render_list, advanced, mob/user, mode, tochat)
	SIGNAL_HANDLER
	var/list/environment = assess_environment()
	var/list/causes = environment["causes"]
	render_list += "<br><b>Янтарный ткач:</b> поколение [generation], запас питания [round(nutrition)]%<br>"
	if(length(causes))
		render_list += "Наблюдаемые нарушения: [jointext(causes, "; ")]<br>"
	else
		render_list += "Признаков экологического стресса нет.<br>"
	if(nutrition < 25)
		render_list += "Истощение: требуется кормление.<br>"
	if(allergy_seconds > 0)
		render_list += "Зафиксирована пищевая аллергическая реакция.<br>"

/** Existing passive wandering and skittish behavior; pulling and medical do_afters pause movement. */
/datum/ai_controller/basic_controller/phoenix_weaver
	behavior_tree_json = "code/modules/mob/living/basic/farm_animals/sheep.bt.json"
	ai_traits = PASSIVE_AI_FLAGS
	ai_movement = /datum/ai_movement/basic_avoidance
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_BASIC_MOB_SPEAK_LINES = list(
			BB_EMOTE_HEAR = list("тихо стрекочет."),
			BB_EMOTE_SEE = list("перебирает усиками.", "потирает панцирные сегменты."),
			BB_SPEAK_CHANCE = 5,
		),
	)

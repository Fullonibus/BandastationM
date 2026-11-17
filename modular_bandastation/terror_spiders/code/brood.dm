#define TERROR_PRINCESS_BROOD_CAP 20

GLOBAL_LIST_EMPTY(terror_brood_eggs)

/datum/antagonist/spider/terror
	name = "Паук террора"
	roundend_category = "Пауки террора"
	show_in_antagpanel = TRUE

/datum/antagonist/spider/terror/New(directive = TERROR_SPIDER_DEFAULT_DIRECTIVE)
	return ..(directive)

/datum/antagonist/spider/terror/can_be_owned(datum/mind/new_owner)
	var/datum/mind/target = new_owner || owner
	return !QDELETED(target) && !QDELETED(target.current) && !target.has_antag_datum(/datum/antagonist/spider)

/datum/antagonist/spider/terror/admin_add(datum/mind/new_owner, mob/admin)
	if(!admin?.client || !check_rights_for(admin.client, R_ADMIN) || !can_be_owned(new_owner))
		return

	var/mob/previous_body = new_owner.current
	var/mob/living/basic/spider/giant/terror/spider = previous_body
	if(!istype(spider))
		var/list/castes = list()
		for(var/mob/living/basic/spider/giant/terror/caste as anything in subtypesof(/mob/living/basic/spider/giant/terror))
			castes[initial(caste.name)] = caste
		var/choice = tgui_input_list(admin, "Выберите касту паука террора.", "Паук террора", castes)
		var/selected_caste = castes[choice]
		if(!selected_caste || QDELETED(src) || !admin?.client || !check_rights_for(admin.client, R_ADMIN) || !can_be_owned(new_owner) || new_owner.current != previous_body)
			return
		var/turf/spawn_turf = get_turf(previous_body)
		if(!spawn_turf)
			return
		spider = new selected_caste(spawn_turf)

	directive = spider.directive || directive
	. = ..()
	if(owner != new_owner)
		if(spider != previous_body)
			qdel(spider)
		return
	spider.directive = directive
	new_owner.set_assigned_role(SSjob.get_job_type(/datum/job/spider))
	if(spider != previous_body)
		new_owner.transfer_to(spider, force_key_move = TRUE)

/// Returns the orders the next generation should inherit.
/mob/living/basic/spider/giant/terror/proc/get_brood_directive()
	var/datum/action/cooldown/mob_cooldown/set_spider_directive/orders = locate() in actions
	return orders?.current_directive || directive || TERROR_SPIDER_DEFAULT_DIRECTIVE

/obj/structure/spider/eggcluster/terror
	name = "кладка пауков террора"
	color = "#a63b46"

/obj/effect/mob_spawn/ghost_role/spider/terror
	name = "кладка пауков террора"
	mob_type = /mob/living/basic/spider/giant/terror/red
	prompt_ghost = TRUE
	show_flavor = TRUE
	you_are_text = "Вы паук террора."
	important_text = "Следуйте директиве выводка."
	directive = TERROR_SPIDER_DEFAULT_DIRECTIVE
	faction = list(FACTION_TERROR_SPIDER)
	role_ban = list(ROLE_ALIEN, ROLE_SYNDICATE)
	cluster_type = /obj/structure/spider/eggcluster/terror
	granted_datum = /datum/antagonist/spider/terror
	flash_window = TRUE
	/// Time needed to mature from an empty growth bar.
	var/incubation_time = 8 SECONDS

/obj/effect/mob_spawn/ghost_role/spider/terror/Initialize(mapload, mob/living/basic/spider/giant/terror/caste, brood_directive)
	caste = caste || mob_type
	ASSERT(ispath(caste, /mob/living/basic/spider/giant/terror))
	mob_type = caste
	potentialspawns = list(caste)
	prompt_name = initial(caste.name)
	name = "Кладка — [prompt_name]"
	flavour_text = initial(caste.menu_description)
	if(!isnull(brood_directive))
		directive = brood_directive
	return ..()

/obj/effect/mob_spawn/ghost_role/spider/terror/growth_progress(seconds_per_tick)
	return 100 * (seconds_per_tick SECONDS) / incubation_time

/obj/effect/mob_spawn/ghost_role/spider/terror/process(seconds_per_tick)
	if(amount_grown >= 100)
		return PROCESS_KILL
	amount_grown += growth_progress(seconds_per_tick)
	if(amount_grown < 100)
		return
	INVOKE_ASYNC(src, PROC_REF(poll_for_hatch))
	return PROCESS_KILL

/// Makes a mature egg claimable only after the ghost poll has finished.
/obj/effect/mob_spawn/ghost_role/spider/terror/proc/poll_for_hatch()
	var/list/candidates = poll_terror_spider_candidates(src, mob_type)
	if(QDELETED(src) || !get_turf(src))
		return

	ready = TRUE
	while(length(candidates) && uses > 0 && SSticker.HasRoundStarted())
		var/mob/dead/observer/candidate = pick_n_take(candidates)
		if(QDELETED(candidate) || !isobserver(candidate) || !candidate.client || !candidate.ckey || !can_ghost_take(candidate))
			continue
		create_from_ghost(candidate, apply_prefs = FALSE)
		return

/obj/effect/mob_spawn/ghost_role/spider/terror/Destroy()
	var/obj/structure/spider/eggcluster/physical_egg = egg
	// Let movable destruction remove the spawner from the clutch before deleting it.
	. = ..()
	if(!QDELETED(physical_egg))
		physical_egg.spawner = null
		qdel(physical_egg)

/obj/effect/mob_spawn/ghost_role/spider/terror/special(mob/living/basic/spider/spawned_mob, mob/mob_possessor, apply_prefs)
	. = ..()
	playsound(spawned_mob, 'modular_bandastation/terror_spiders/sound/eggburst.ogg', 100)

/obj/structure/spider/eggcluster/terror/brood
	desc = "Из этой кладки вскоре выберутся паучата."
	/// Adult caste the spiderlings will mature into.
	var/caste
	/// How many spiderlings are in this clutch.
	var/brood_size
	/// Percentage of the clutch's incubation completed.
	var/amount_grown = 0
	/// Directive passed to the spiderlings.
	var/directive
	/// Royal spider responsible for the clutch, if any.
	var/datum/weakref/terror_queen_ref

/obj/structure/spider/eggcluster/terror/brood/Initialize(mapload, mob/living/basic/spider/giant/terror/caste = /mob/living/basic/spider/giant/terror/red, brood_directive, datum/weakref/brood_queen, count = 1)
	. = ..()
	ASSERT(ispath(caste, /mob/living/basic/spider/giant/terror) && count >= 1 && count <= 50)
	src.caste = caste
	name = "Кладка — [initial(caste.name)]"
	directive = brood_directive
	brood_size = count
	terror_queen_ref = brood_queen
	GLOB.terror_brood_eggs += src
	START_PROCESSING(SSobj, src)

/obj/structure/spider/eggcluster/terror/brood/Destroy()
	STOP_PROCESSING(SSobj, src)
	GLOB.terror_brood_eggs -= src
	return ..()

/obj/structure/spider/eggcluster/terror/brood/process(seconds_per_tick)
	amount_grown += 100 * (seconds_per_tick SECONDS) / (1 MINUTES)
	if(amount_grown < 100)
		return

	var/turf/hatch_turf = get_turf(src)
	if(hatch_turf)
		playsound(hatch_turf, 'modular_bandastation/terror_spiders/sound/eggburst.ogg', 100)
		for(var/index in 1 to brood_size)
			new /mob/living/basic/spider/growing/spiderling/terror(hatch_turf, caste, directive, terror_queen_ref)
	qdel(src)
	return PROCESS_KILL

/// Counts living adults, viable spiderlings and eggs by adult caste, optionally from one queen.
/proc/count_terror_brood(datum/weakref/queen)
	var/list/counts = list("total" = 0)
	for(var/mob/living/basic/spider/giant/terror/spider in GLOB.alive_mob_list)
		if(QDELETED(spider) || (queen && spider.terror_queen_ref != queen))
			continue
		counts[spider.type] = (counts[spider.type] || 0) + 1
		counts["total"]++
	for(var/mob/living/basic/spider/growing/spiderling/terror/ling in GLOB.alive_mob_list)
		if(QDELETED(ling) || ling.stillborn || (queen && ling.terror_queen_ref != queen))
			continue
		counts[ling.grow_as] = (counts[ling.grow_as] || 0) + 1
		counts["total"]++
	for(var/obj/structure/spider/eggcluster/terror/brood/clutch as anything in GLOB.terror_brood_eggs)
		if(QDELETED(clutch) || (queen && clutch.terror_queen_ref != queen))
			continue
		counts[clutch.caste] = (counts[clutch.caste] || 0) + clutch.brood_size
		counts["total"] += clutch.brood_size
	return counts

/datum/action/cooldown/mob_cooldown/lay_eggs/terror
	name = "Отложить яйца"
	desc = "Спеленайте три трупа, чтобы отложить яйцо выбранной касты."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "eggs"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	overlay_icon_state = null
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	cooldown_time = 0 SECONDS
	melee_cooldown_time = 0 SECONDS
	/// Number of meals or stored eggs consumed per spiderling.
	var/egg_cost = 3
	/// Castes available without a limit for ordinary broods.
	var/static/list/standard_castes = list(
		/mob/living/basic/spider/giant/terror/red,
		/mob/living/basic/spider/giant/terror/gray,
		/mob/living/basic/spider/giant/terror/green,
		/mob/living/basic/spider/giant/terror/builder,
		/mob/living/basic/spider/giant/terror/reaper,
	)
	/// Castes whose population is limited.
	var/list/advanced_castes = list(
		/mob/living/basic/spider/giant/terror/black = 2,
		/mob/living/basic/spider/giant/terror/brown = 2,
	)

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/basic/spider/giant/terror/egg_layer = owner
	if(egg_layer.terror_degenerating)
		if(feedback)
			egg_layer.balloon_alert(egg_layer, "связь с ульем разорвана!")
		return FALSE
	if(get_egg_reserve() < egg_cost)
		if(feedback)
			owner.balloon_alert(owner, "недостаточно яиц!")
		return FALSE
	if(!isfloorturf(owner.loc))
		if(feedback)
			owner.balloon_alert(owner, "нужен пол!")
		return FALSE
	return TRUE

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/Activate(atom/target)
	var/mob/living/basic/spider/giant/terror/egg_layer = owner
	if(!istype(egg_layer) || !IsAvailable(feedback = TRUE))
		return FALSE
	var/turf/egg_turf = egg_layer.loc
	var/list/caste_choices = list()
	for(var/mob/living/basic/spider/giant/terror/caste as anything in get_castes(egg_layer))
		caste_choices[initial(caste.name)] = caste

	var/choice = tgui_input_list(egg_layer, "Какие яйца отложить?", "Кладка", caste_choices)
	var/caste_type = caste_choices[choice]
	if(!caste_type || QDELETED(src) || QDELETED(egg_layer) || owner != egg_layer || egg_layer.loc != egg_turf || !IsAvailable(feedback = TRUE))
		return FALSE

	var/list/batch_sizes = get_batch_sizes(caste_type)
	if(!length(batch_sizes))
		return FALSE
	var/batch_size = length(batch_sizes) == 1 ? batch_sizes[1] : tgui_input_list(egg_layer, "Сколько яиц отложить?", "Кладка", batch_sizes)
	if(QDELETED(src) || QDELETED(egg_layer) || owner != egg_layer || egg_layer.loc != egg_turf || !IsAvailable(feedback = TRUE))
		return FALSE
	if(!(batch_size in get_batch_sizes(caste_type)) || !(caste_type in get_castes(egg_layer)))
		return FALSE

	var/mob/living/basic/spider/giant/terror/queen/queen = egg_layer
	var/datum/weakref/brood_queen = egg_layer.terror_queen_ref
	if(istype(queen))
		brood_queen = WEAKREF(queen)
		queen.terror_eggs_laid += batch_size
	consume_eggs(batch_size)
	new /obj/structure/spider/eggcluster/terror/brood(egg_turf, caste_type, egg_layer.get_brood_directive(), brood_queen, batch_size)
	egg_layer.visible_message(span_notice("[egg_layer] откладывает кладку."))
	build_all_button_icons(UPDATE_BUTTON_STATUS)
	return TRUE

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/proc/get_egg_reserve()
	var/mob/living/basic/spider/giant/terror/egg_layer = owner
	return egg_layer.fed

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/proc/consume_eggs(count)
	var/mob/living/basic/spider/giant/terror/egg_layer = owner
	egg_layer.fed -= egg_cost * count

/// Available castes after applying the live brood limits.
/datum/action/cooldown/mob_cooldown/lay_eggs/terror/proc/get_castes(mob/living/basic/spider/giant/terror/egg_layer)
	var/list/options = standard_castes.Copy()
	var/list/counts = count_terror_brood()
	for(var/caste in advanced_castes)
		if(counts[caste] < advanced_castes[caste])
			options += caste
	return options

/// Allowed batch sizes for the chosen caste.
/datum/action/cooldown/mob_cooldown/lay_eggs/terror/proc/get_batch_sizes(caste_type)
	return list(1)

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal
	desc = "Отложите кладку выбранной касты. Запас яиц пополняется каждые 160 секунд."
	allow_egg_stacking = TRUE
	egg_cost = 1
	advanced_castes = list(
		/mob/living/basic/spider/giant/terror/black = 4,
		/mob/living/basic/spider/giant/terror/brown = 3,
		/mob/living/basic/spider/giant/terror/purple = 3,
	)
	var/charges = 5

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/get_egg_reserve()
	return charges

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/consume_eggs(count)
	charges -= egg_cost * count

/// Older queens regenerate more eggs each cycle.
/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/proc/recharge_egg()
	var/mob/living/basic/spider/giant/terror/queen/queen = owner
	charges += 1 + round(queen.terror_age_minutes() / 10)
	to_chat(queen, span_notice("Яиц в запасе: [charges]."))
	SEND_SOUND(queen, sound('modular_bandastation/terror_spiders/sound/ping.ogg'))
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/get_castes(mob/living/basic/spider/giant/terror/egg_layer)
	var/mob/living/basic/spider/giant/terror/queen/queen = egg_layer
	if(istype(queen) && queen.terror_age_minutes() >= 25)
		var/list/counts = count_terror_brood(WEAKREF(queen))
		var/static/list/rare_castes = list(
			/mob/living/basic/spider/giant/terror/mother,
			/mob/living/basic/spider/giant/terror/white,
			/mob/living/basic/spider/giant/terror/queen/princess,
		)
		if(!counts[rare_castes[1]] && !counts[rare_castes[2]] && !counts[rare_castes[3]])
			return rare_castes
	return ..()

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/get_batch_sizes(caste_type)
	if(!(caste_type in standard_castes))
		return list(1)
	var/list/sizes = list()
	for(var/count in 1 to (charges >= 5 ? 5 : min(charges, 3)))
		sizes += count
	return sizes

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/princess
	charges = 1

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/princess/get_castes(mob/living/basic/spider/giant/terror/egg_layer)
	var/list/counts = count_terror_brood(WEAKREF(egg_layer))
	var/advanced_count = 0
	for(var/caste in advanced_castes)
		advanced_count += counts[caste] || 0
	if(advanced_count >= 3)
		return standard_castes
	var/list/options = standard_castes.Copy()
	for(var/caste in advanced_castes)
		options += caste
	return options

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/princess/get_batch_sizes(caste_type)
	var/list/sizes = ..()
	var/list/counts = count_terror_brood(WEAKREF(owner))
	var/slots = max(TERROR_PRINCESS_BROOD_CAP - counts["total"], 0)
	if(slots < length(sizes))
		sizes.Cut(slots + 1)
	return sizes

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/princess/recharge_egg()
	var/mob/living/basic/spider/giant/terror/queen/princess/princess = owner
	var/list/counts = count_terror_brood(WEAKREF(princess))
	var/brood_count = counts["total"]
	var/color_stage = !brood_count ? 1 : (brood_count < TERROR_PRINCESS_BROOD_CAP / 2 ? 2 : 3)
	princess.icon_living = "terror_princess[color_stage]"
	princess.icon_dead = "[princess.icon_living]_dead"
	princess.icon_state = princess.icon_living
	switch(color_stage)
		if(1)
			princess.desc = "Огромная паучиха, покрытая мягкой розовой шерстью. Выглядит на удивление мило."
		if(2)
			princess.desc = "Розовую шерсть паучихи местами окрашивает тёмно-красный цвет."
		if(3)
			princess.desc = "Всё тело паучихи приобрело цвет засохшей крови."
	if(brood_count + charges >= TERROR_PRINCESS_BROOD_CAP)
		return
	charges++
	to_chat(princess, span_notice("Яиц в запасе: [charges]."))
	SEND_SOUND(princess, sound('modular_bandastation/terror_spiders/sound/ping.ogg'))
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/empress
	name = "Яйца императрицы"
	desc = "Отложите до пятидесяти яиц за раз. Доступны и яйца королевы."
	charges = 1000

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/empress/get_castes(mob/living/basic/spider/giant/terror/egg_layer)
	return list(
		/mob/living/basic/spider/giant/terror/queen,
		/mob/living/basic/spider/giant/terror/mother,
		/mob/living/basic/spider/giant/terror/prince,
		/mob/living/basic/spider/giant/terror/queen/princess,
		/mob/living/basic/spider/giant/terror/red,
		/mob/living/basic/spider/giant/terror/gray,
		/mob/living/basic/spider/giant/terror/green,
		/mob/living/basic/spider/giant/terror/black,
		/mob/living/basic/spider/giant/terror/purple,
		/mob/living/basic/spider/giant/terror/white,
		/mob/living/basic/spider/giant/terror/brown,
	)

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/empress/get_batch_sizes(caste_type)
	var/list/sizes = list()
	for(var/count in 1 to min(charges, 50))
		sizes += count
	return sizes

/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/empress/recharge_egg()
	var/mob/living/basic/spider/giant/terror/queen/empress/empress = owner
	charges += empress.hatched_from_empress_egg ? 7 : 50
	to_chat(empress, span_notice("Яиц в запасе: [charges]."))
	SEND_SOUND(empress, sound('modular_bandastation/terror_spiders/sound/ping.ogg'))
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/mob/living/basic/spider/giant/terror/queen
	/// Time this royal spider was created, used to unlock rarer eggs.
	var/terror_birth_time
	/// When the royal egg reserve next replenishes.
	var/next_egg_charge
	var/egg_recharge_interval = 160 SECONDS
	/// Total number of eggs laid by this royal spider.
	var/terror_eggs_laid = 0

/mob/living/basic/spider/giant/terror/queen/Initialize(mapload)
	terror_birth_time = world.time
	next_egg_charge = world.time + egg_recharge_interval
	. = ..()
	if(!istype(src, /mob/living/basic/spider/giant/terror/queen/princess))
		set_terror_wall_breaching(ENVIRONMENT_SMASH_WALLS)

/mob/living/basic/spider/giant/terror/queen/Life(seconds_per_tick)
	. = ..()
	if(QDELETED(src) || stat == DEAD || !ckey || world.time <= next_egg_charge)
		return
	var/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/eggs = locate() in actions
	if(!eggs)
		return
	next_egg_charge = world.time + egg_recharge_interval
	eggs.recharge_egg()

/// Age in whole minutes for the egg-laying thresholds.
/mob/living/basic/spider/giant/terror/queen/proc/terror_age_minutes()
	return round((world.time - terror_birth_time) / (1 MINUTES))

/mob/living/basic/spider/giant/terror/queen/death(gibbed)
	. = ..()
	if(!.)
		return
	var/datum/weakref/brood_queen = WEAKREF(src)
	for(var/obj/structure/spider/eggcluster/terror/brood/clutch as anything in GLOB.terror_brood_eggs.Copy())
		if(clutch.terror_queen_ref == brood_queen)
			qdel(clutch)
	for(var/mob/living/basic/spider/giant/terror/offspring in GLOB.alive_mob_list)
		if(offspring.terror_queen_ref != brood_queen)
			continue
		if(offspring.terror_tier >= terror_tier)
			continue
		offspring.terror_degenerating = TRUE
		offspring.visible_message(span_danger("[offspring] корчится от боли!"))
		to_chat(offspring, span_userdanger("Связь с [src] оборвалась. Вы чувствуете, как жизнь покидает вас!"))
	for(var/mob/living/basic/spider/growing/spiderling/terror/ling in GLOB.alive_mob_list.Copy())
		if(ling.terror_queen_ref == brood_queen)
			qdel(ling)

/mob/living/basic/spider/giant/terror/queen/examine(mob/user)
	. = ..()
	if(stat == DEAD || !key || (!isobserver(user) && !istype(user, /mob/living/basic/spider/giant/terror)))
		return
	. += span_notice("Отложено яиц: [terror_eggs_laid].")
	. += span_notice("Возраст: [terror_age_minutes()] мин.")

/datum/action/cooldown/mob_cooldown/terror_nest
	name = "Основать гнездо"
	desc = "Начните откладывать яйца и ломать стены. После этого вы больше не сможете пользоваться вентиляцией."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "terror_queen"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_nest/Activate(atom/target)
	var/mob/living/basic/spider/giant/terror/queen/queen = owner
	if(!istype(queen) || !isfloorturf(queen.loc))
		owner?.balloon_alert(owner, "нужен пол!")
		return FALSE
	var/turf/nest_turf = queen.loc
	if(tgui_alert(queen, "После основания гнезда вы больше не сможете пользоваться вентиляцией.", "Основать гнездо?", list("Да", "Нет")) != "Да")
		return FALSE
	if(QDELETED(src) || QDELETED(queen) || owner != queen || queen.loc != nest_turf || !IsAvailable(feedback = TRUE))
		return FALSE

	REMOVE_TRAIT(queen, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	queen.set_terror_wall_breaching(ENVIRONMENT_SMASH_RWALLS)
	queen.add_movespeed_modifier(/datum/movespeed_modifier/terror_nesting)
	var/egg_action = istype(queen, /mob/living/basic/spider/giant/terror/queen/empress) ? /datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/empress : /datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal
	queen.grant_actions_by_list(list(egg_action, /datum/action/cooldown/mob_cooldown/terror_hive_sense))
	queen.next_egg_charge = world.time + queen.egg_recharge_interval
	var/mob/living/basic/spider/giant/terror/queen/empress/empress = queen
	if(istype(empress) && empress.hatched_from_empress_egg)
		var/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/empress/egg_ability = locate() in queen.actions
		egg_ability.charges = 10
	to_chat(queen, span_notice("Теперь вы можете откладывать яйца и ломать стены. Вентиляция больше недоступна."))
	queen.balloon_alert_to_viewers("основывает гнездо!")
	queen.visible_message(span_userdanger("[queen] издаёт пронзительный визг!"))
	playsound(queen, 'modular_bandastation/terror_spiders/sound/queen_shriek.ogg', 100, TRUE)
	for(var/obj/machinery/light/light in orange(8, queen))
		if(light.on)
			light.break_light_tube()
	for(var/obj/machinery/camera/camera in orange(8, queen))
		if(camera.camera_enabled)
			camera.toggle_cam(queen, displaymessage = FALSE)
	qdel(src)
	return TRUE

/datum/movespeed_modifier/terror_nesting
	multiplicative_slowdown = 0.5

/datum/action/cooldown/mob_cooldown/terror_hive_sense
	name = "Чувство улья"
	desc = "Узнайте местоположение и состояние пауков террора."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "mindswap"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 0 SECONDS

/datum/action/cooldown/mob_cooldown/terror_hive_sense/Activate(atom/target)
	var/list/report = list(span_boldnotice("Улей"))
	for(var/mob/living/basic/spider/giant/terror/spider in GLOB.mob_list)
		if(QDELETED(spider))
			continue
		var/condition = spider.stat == DEAD ? "мёртв" : "[round(spider.health)] / [spider.maxHealth] здоровья"
		report += "[spider] ([get_area_name(spider, format_text = TRUE)]): [condition], [spider.ckey ? "игрок" : "ИИ"]."
	to_chat(owner, report.Join("<br>"))
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_empress_spawn
	name = "Паучата императрицы"
	desc = "Выпустите группу паучат. Часть может оказаться нежизнеспособной."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "spiderling"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 0 SECONDS

/datum/action/cooldown/mob_cooldown/terror_empress_spawn/Activate(atom/target)
	var/mob/living/basic/spider/giant/terror/queen/empress/empress = owner
	if(!istype(empress) || empress.terror_degenerating || !isturf(empress.loc))
		return FALSE
	var/turf/spawn_turf = empress.loc
	var/count = tgui_input_number(empress, "Сколько паучат выпустить?", "Выводок", 10, max_value = 50, min_value = 10, round_value = TRUE)
	if(!count || QDELETED(src) || QDELETED(empress) || owner != empress || empress.loc != spawn_turf || !IsAvailable(feedback = TRUE))
		return FALSE
	var/chance = tgui_input_number(empress, "Доля нежизнеспособных паучат в процентах?", "Выводок", 0, max_value = 100, min_value = 0, round_value = TRUE)
	if(isnull(chance) || QDELETED(src) || QDELETED(empress) || owner != empress || empress.terror_degenerating || empress.loc != spawn_turf || !IsAvailable(feedback = TRUE))
		return FALSE
	var/static/list/castes = list(
		/mob/living/basic/spider/giant/terror/red,
		/mob/living/basic/spider/giant/terror/gray,
		/mob/living/basic/spider/giant/terror/green,
		/mob/living/basic/spider/giant/terror/white,
		/mob/living/basic/spider/giant/terror/black,
	)
	var/brood_directive = empress.get_brood_directive()
	var/datum/weakref/empress_ref = WEAKREF(empress)
	for(var/index in 1 to count)
		new /mob/living/basic/spider/growing/spiderling/terror(spawn_turf, pick(castes), brood_directive, empress_ref, prob(chance))
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_empress_erase
	name = "Уничтожить выводок"
	desc = "Уничтожьте кладки и паучат, оборвав связь взрослых пауков с ульем."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "mgibbl1"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 0 SECONDS

/datum/action/cooldown/mob_cooldown/terror_empress_erase/Activate(atom/target)
	var/mob/living/basic/spider/giant/terror/queen/empress/empress = owner
	if(!istype(empress))
		return FALSE
	if(tgui_alert(empress, "Оборвать связь всего выводка с ульем?", name, list("Да", "Нет")) != "Да")
		return FALSE
	if(QDELETED(src) || QDELETED(empress) || owner != empress || !IsAvailable())
		return FALSE
	erase_terror_brood("Императрица разрывает вашу связь с ульем. Вы чувствуете, как жизнь покидает вас!", empress.terror_tier)
	to_chat(empress, span_notice("Связь выводка с ульем оборвана."))
	return TRUE

/proc/erase_terror_brood(message, spared_tier = INFINITY)
	for(var/mob/living/basic/spider/giant/terror/spider in GLOB.alive_mob_list)
		if(spider.terror_tier >= spared_tier)
			continue
		spider.terror_degenerating = TRUE
		to_chat(spider, span_userdanger(message))
	for(var/obj/structure/spider/eggcluster/terror/brood/clutch as anything in GLOB.terror_brood_eggs.Copy())
		qdel(clutch)
	for(var/mob/living/basic/spider/growing/spiderling/terror/ling in GLOB.alive_mob_list.Copy())
		qdel(ling)
	for(var/obj/item/organ/terror_eggs/infection as anything in GLOB.terror_infections.Copy())
		qdel(infection)
	for(var/group in GLOB.mob_spawners.Copy())
		var/list/spawners = GLOB.mob_spawners[group]
		for(var/obj/effect/mob_spawn/ghost_role/spider/terror/founder in spawners?.Copy())
			if(!QDELETED(founder))
				qdel(founder)

#undef TERROR_PRINCESS_BROOD_CAP

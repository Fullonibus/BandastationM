/mob/living/basic/spider/giant/terror/green/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	. = ..()
	var/mob/living/basic/spider/giant/terror/ally = target
	if(. != BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN || !istype(ally) || ally == src || ally.stat == DEAD || incapacitated)
		return
	var/healing = 4
	var/heal_color = "#00ff00"
	if(fed == 2)
		healing = 6
		heal_color = "#0077ff"
	else if(fed >= 3)
		healing = 8
		heal_color = "#ff0000"
	ally.adjust_brute_loss(-healing)
	new /obj/effect/temp_visual/heal(get_turf(ally), heal_color)

/mob/living/basic/spider/giant/terror/mother/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	. = ..()
	var/mob/living/basic/spider/giant/terror/ally = target
	if(. != BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN || !istype(ally) || ally == src || ally.stat == DEAD || incapacitated)
		return
	ally.adjust_brute_loss(-10)
	new /obj/effect/temp_visual/heal(get_turf(ally), "#8c00ff")

/mob/living/basic/spider/giant/terror/mother/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(QDELETED(src) || stat == DEAD || !isturf(loc))
		return
	var/amount = 3 * seconds_per_tick / 2
	for(var/mob/living/basic/spider/giant/terror/ally in oview(7, src))
		if(ally.stat != DEAD && ally.health < ally.maxHealth)
			ally.adjust_brute_loss(-amount)
			new /obj/effect/temp_visual/heal(get_turf(ally), "#8c00ff")
	for(var/mob/living/carbon/human/prey in view(7, src))
		if(prey.stat != DEAD)
			prey.apply_damage(amount, TOX)
			prey.apply_damage(amount, STAMINA)

/datum/action/cooldown/mob_cooldown/terror_healing
	name = "Исцеляющие феромоны"
	desc = "Восстановите 20 здоровья всем паукам Ужаса в радиусе шести клеток."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "heal"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 30 SECONDS
	/// Brute damage removed per cast.
	var/heal_amount = 20
	/// Maximum distance to spiders receiving the heal.
	var/heal_radius = 6
	/// Whether to grant the same healing effect as royal jelly.
	var/boost_regeneration = FALSE

/datum/action/cooldown/mob_cooldown/terror_healing/Activate(atom/target)
	if(!isturf(owner.loc))
		return FALSE
	playsound(owner, 'modular_bandastation/terror_spiders/sound/heal.ogg', 50, TRUE)
	owner.visible_message(span_notice("[owner] выпускает исцеляющие феромоны!"))
	for(var/mob/living/basic/spider/giant/terror/spider in range(heal_radius, owner))
		if(spider.stat == DEAD)
			continue
		spider.adjust_brute_loss(-heal_amount)
		if(boost_regeneration)
			spider.apply_status_effect(/datum/status_effect/terror_recovery)
		new /obj/effect/temp_visual/heal(get_turf(spider), "#00ff0d")
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_healing/greater
	name = "Массовое исцеление"
	desc = "Восстановите 30 здоровья и ускорьте регенерацию пауков Ужаса в радиусе семи клеток."
	cooldown_time = 40 SECONDS
	heal_amount = 30
	heal_radius = 7
	boost_regeneration = TRUE

/datum/action/cooldown/mob_cooldown/terror_smoke
	name = "Дымовая завеса"
	desc = "Окружите себя облаком дыма."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "smoke"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 8 SECONDS

/datum/action/cooldown/mob_cooldown/terror_smoke/Activate(atom/target)
	if(!isturf(owner.loc))
		return FALSE
	playsound(owner, 'sound/effects/smoke.ogg', 50, TRUE)
	do_smoke(7, owner, owner.loc)
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_parasmoke
	name = "Парализующий дым"
	desc = "Окружите себя облаком нейротоксинов, парализующих противников."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "biohazard2"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 60 SECONDS

/datum/action/cooldown/mob_cooldown/terror_parasmoke/Activate(atom/target)
	if(!isturf(owner.loc))
		return FALSE
	playsound(owner, 'sound/effects/smoke.ogg', 50, TRUE)
	do_chem_smoke(2, owner, owner.loc, list(/datum/reagent/consumable/ethanol/neurotoxin = 500, /datum/reagent/toxin/terror_capulettium = 500))
	StartCooldown()
	return TRUE

/datum/reagent/toxin/terror_capulettium
	name = "Капулеттий+"
	description = "Компонент дыма Осквернителя Ужаса. Лишает жертву голоса и маскирует признаки жизни в состоянии покоя."
	chemical_flags = NONE
	randomized_spawns = NONE
	color = "#60a584"
	toxpwr = 0
	silent_toxin = TRUE

/datum/reagent/toxin/terror_capulettium/on_mob_life(mob/living/carbon/victim, seconds_per_tick, metabolization_ratio)
	victim.set_silence_if_lower(4 SECONDS)
	if(victim.resting)
		victim.fakedeath(type, silent = TRUE)
	else
		victim.cure_fakedeath(type)
	return ..()

/datum/reagent/toxin/terror_capulettium/on_mob_end_metabolize(mob/living/affected_mob)
	affected_mob.cure_fakedeath(type)
	return ..()

/datum/action/cooldown/mob_cooldown/terror_defiler_shriek
	name = "Ужасающий визг"
	desc = "Дезориентируйте ближайших противников и перегрузите датчики синтетиков."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "terror_shriek"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	cooldown_time = 60 SECONDS

/datum/action/cooldown/mob_cooldown/terror_defiler_shriek/Activate(atom/target)
	if(!isturf(owner.loc))
		return FALSE
	playsound(owner, 'modular_bandastation/terror_spiders/sound/white_shriek.ogg', 50, TRUE)
	owner.visible_message(span_danger("[owner] пронзительно визжит!"))
	for(var/mob/living/victim in range(7, owner))
		if(victim.stat == DEAD || owner.faction_check_atom(victim))
			continue
		if(iscarbon(victim))
			to_chat(victim, span_danger("Боль пронзает вашу голову и путает мысли!"))
			victim.adjust_confusion(20 SECONDS)
			victim.set_timed_status_effect(2 SECONDS, /datum/status_effect/terror_slowed, TRUE)
			victim.set_jitter_if_lower(20 SECONDS)
		else if(issilicon(victim))
			to_chat(victim, span_warning("ОШИБКА. СЕНСОРНАЯ ПЕРЕГРУЗКА."))
			SEND_SOUND(victim, sound('modular_bandastation/terror_spiders/sound/interference.ogg'))
			playsound(victim, 'modular_bandastation/terror_spiders/sound/warning-buzzer.ogg', 50, TRUE)
			do_sparks(5, TRUE, victim)
			victim.Paralyze(12 SECONDS, ignore_canstun = TRUE)
	StartCooldown()
	return TRUE

/datum/status_effect/terror_slowed
	id = "terror_slowed"
	duration = 4 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/datum/status_effect/terror_slowed/on_creation(mob/living/new_owner, duration = 4 SECONDS)
	src.duration = duration
	return ..()

/datum/status_effect/terror_slowed/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/terror_slowed)
	return ..()

/datum/status_effect/terror_slowed/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/terror_slowed)
	return ..()

/datum/movespeed_modifier/terror_slowed
	multiplicative_slowdown = 1

/mob/living/basic/spider/giant/terror/builder/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(freeze_with_bite))

/mob/living/basic/spider/giant/terror/builder/update_terror_web_effects(on_web)
	. = ..()
	terror_regeneration = on_web ? 3 : 0

/mob/living/basic/spider/giant/terror/builder/proc/freeze_with_bite(datum/source, mob/living/carbon/prey, success)
	SIGNAL_HANDLER
	if(!success || !iscarbon(prey) || prey.stat == DEAD || faction_check_atom(prey))
		return
	prey.set_timed_status_effect(4 SECONDS, /datum/status_effect/terror_slowed, TRUE)
	if(!(prey.mob_biotypes & MOB_ORGANIC) || !prey.reagents || prey.reagents.has_reagent(/datum/reagent/consumable/frostoil, 100))
		return
	var/obj/item/bodypart/bite_site = prey.get_bodypart(pick(BODY_ZONE_CHEST, BODY_ZONE_HEAD))
	var/unprotected = HAS_TRAIT(prey, TRAIT_INCAPACITATED) || (bite_site && prey.can_inject(null, bite_site, NONE))
	prey.reagents.add_reagent(/datum/reagent/consumable/frostoil, unprotected ? 20 : 10)

/datum/action/cooldown/mob_cooldown/lay_web/terror/airtight/drone
	name = "Сплести паутину Дрона"
	desc = "Быстро сплетите толстую непрозрачную паутину, которая перекрывает утечку воздуха."
	webbing_time = 1 SECONDS
	terror_web_type = /obj/structure/spider/stickyweb/terror/airtight/drone

/obj/structure/spider/stickyweb/terror/airtight/drone
	name = "паутина Дрона Ужаса"
	desc = "Очень толстая, непрозрачная паутина."
	max_integrity = 35
	opacity = TRUE

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_drone_spit
	parent_type = /datum/action/cooldown/mob_cooldown/projectile_attack/rapid_fire
	name = "Плевок Дрона"
	desc = "Выпустите два сгустка яда, изматывающих противника."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "toxin2"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	shared_cooldown = NONE
	cooldown_time = 3 SECONDS
	default_projectile_spread = 10
	shot_count = 2
	shot_delay = 0.2 SECONDS
	projectile_type = /obj/projectile/terror_spider/drone
	projectile_sound = SFX_ALIEN_SPIT_ACID

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_drone_spit/Activate(atom/target_atom)
	var/turf/target_turf = get_turf(target_atom)
	if(QDELETED(target_atom) || !isturf(owner.loc) || !target_turf || target_turf == owner.loc || target_turf.z != owner.z || !can_see(owner, target_turf, 7))
		return FALSE
	return ..()

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_drone_spit/shoot_projectile(atom/origin, atom/target, set_angle, mob/firer, projectile_spread, speed_multiplier, override_projectile_type, override_homing)
	. = ..()
	if(.)
		playsound(origin, projectile_sound, 100, TRUE)

/obj/projectile/terror_spider/drone
	name = "яд Дрона Ужаса"
	icon_state = "toxin"
	damage = 15
	damage_type = TOX
	stamina = 15
	range = 7

/mob/living/basic/spider/giant/terror/red
	/// A new stance replaces the current one and restarts its duration.
	var/terror_stance_timer
	/// The Knight's damage coefficients outside temporary stances.
	var/list/base_terror_damage_coefficients

/mob/living/basic/spider/giant/terror/red/Initialize(mapload)
	. = ..()
	base_terror_damage_coefficients = terror_damage_coefficients
	set_terror_wall_breaching(ENVIRONMENT_SMASH_WALLS)

/mob/living/basic/spider/giant/terror/red/Destroy()
	deltimer(terror_stance_timer)
	return ..()

/mob/living/basic/spider/giant/terror/red/death(gibbed)
	. = ..()
	if(. && terror_stance_timer)
		reset_terror_stance()

/mob/living/basic/spider/giant/terror/red/proc/set_terror_stance(speed_change, bite_damage, list/damage_coefficients)
	deltimer(terror_stance_timer)
	speed = initial(speed) + speed_change
	update_basic_mob_varspeed()
	melee_damage_lower = bite_damage
	melee_damage_upper = bite_damage
	terror_damage_coefficients = damage_coefficients
	terror_stance_timer = addtimer(CALLBACK(src, PROC_REF(reset_terror_stance)), 10 SECONDS, TIMER_STOPPABLE)

/mob/living/basic/spider/giant/terror/red/proc/reset_terror_stance()
	deltimer(terror_stance_timer)
	terror_stance_timer = null
	speed = initial(speed)
	update_basic_mob_varspeed()
	melee_damage_lower = initial(melee_damage_lower)
	melee_damage_upper = initial(melee_damage_upper)
	terror_damage_coefficients = base_terror_damage_coefficients
	if(stat != DEAD)
		playsound(src, 'modular_bandastation/terror_spiders/sound/keratosis_out.ogg', 150)
		to_chat(src, span_notice("Вы возвращаетесь в обычную стойку."))

/datum/action/cooldown/mob_cooldown/terror_knight_mode
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 30 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE
	var/speed_change
	var/bite_damage
	var/list/damage_coefficients
	var/stance_sound
	var/stance_volume = 150

/datum/action/cooldown/mob_cooldown/terror_knight_mode/attack
	name = "Атакующая стойка"
	desc = "На 10 секунд вы двигаетесь быстрее и наносите больше урона, но хуже держите удар."
	button_icon_state = "attack"
	speed_change = -0.8
	bite_damage = 30
	damage_coefficients = list(BRUTE = 0.8, BURN = 1.2, STAMINA = 0, OXY = 0.2)
	stance_sound = 'modular_bandastation/terror_spiders/sound/mod_attack.ogg'
	stance_volume = 120

/datum/action/cooldown/mob_cooldown/terror_knight_mode/defense
	name = "Защитная стойка"
	desc = "На 10 секунд панцирь лучше защищает вас. Вы двигаетесь медленнее и слабее кусаете."
	button_icon_state = "defence"
	speed_change = 0.8
	bite_damage = 10
	damage_coefficients = list(BRUTE = 0.4, BURN = 0.7, STAMINA = 0, OXY = 0.2)
	stance_sound = 'modular_bandastation/terror_spiders/sound/keratosis_in.ogg'

/datum/action/cooldown/mob_cooldown/terror_knight_mode/Activate()
	var/mob/living/basic/spider/giant/terror/red/knight = owner
	if(!istype(knight))
		return FALSE
	knight.set_terror_stance(speed_change, bite_damage, damage_coefficients)
	playsound(knight, stance_sound, stance_volume)
	knight.balloon_alert(knight, name)
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_lurker_stealth
	name = "Невидимость"
	desc = "Станьте полностью невидимым на восемь секунд."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "stealth"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 25 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE
	var/reveal_timer

/datum/action/cooldown/mob_cooldown/terror_lurker_stealth/Activate()
	playsound(owner, 'modular_bandastation/terror_spiders/sound/stealth.ogg', 50, TRUE)
	owner.visible_message(span_warning("[owner] внезапно исчезает!"), span_notice("Вы становитесь невидимым."))
	owner.alpha = 0
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(reveal_lurker))
	reveal_timer = addtimer(CALLBACK(src, PROC_REF(reveal_lurker)), 8 SECONDS, TIMER_STOPPABLE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_lurker_stealth/Remove(mob/removed_from)
	if(removed_from == owner && reveal_timer)
		reveal_lurker()
	return ..()

/datum/action/cooldown/mob_cooldown/terror_lurker_stealth/proc/reveal_lurker()
	SIGNAL_HANDLER

	deltimer(reveal_timer)
	reveal_timer = null
	if(QDELETED(owner))
		return
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)
	owner.alpha = initial(owner.alpha)
	if(owner.stat != DEAD)
		owner.visible_message(span_warning("[owner] появляется из ниоткуда!"), span_notice("Вы снова видимы."))
		playsound(owner, 'modular_bandastation/terror_spiders/sound/stealth_out.ogg', 150, TRUE)

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "fake_death"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/Activate(atom/target)
	var/turf/target_turf = get_turf(target)
	if(!isturf(owner.loc) || !target_turf || target_turf == owner.loc || !can_see(owner, target_turf, 7))
		return FALSE
	playsound(owner, SFX_ALIEN_SPIT_ACID, 50, TRUE)
	return ..()

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/venom
	name = "Ядовитый плевок"
	desc = "Плюньте сгустком кислоты. При попадании он выпустит облако яда и дурманящих веществ."
	cooldown_time = 25 SECONDS
	projectile_type = /obj/projectile/terror_spider/widow/venom

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/smoke
	name = "Дымящийся плевок"
	desc = "Плюньте сгустком кислоты, создающим при попадании дымовую завесу."
	button_icon_state = "smoke"
	cooldown_time = 10 SECONDS
	projectile_type = /obj/projectile/terror_spider/widow/smoke

/obj/projectile/terror_spider/widow
	name = "кислота Вдовы"
	icon_state = "toxin"
	damage = 5
	damage_type = TOX
	stamina = 24
	range = 7

/obj/projectile/terror_spider/widow/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	if(target == firer)
		return FALSE
	return ..()

/obj/projectile/terror_spider/widow/venom/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/turf/impact = get_turf(target)
	if(!impact)
		return
	create_reagents(1250)
	reagents.add_reagent(/datum/reagent/drug/cannabis, 250)
	reagents.add_reagent(/datum/reagent/drug/mushroomhallucinogen, 500)
	reagents.add_reagent(/datum/reagent/drug/space_drugs, 250)
	reagents.add_reagent(/datum/reagent/toxin/terror_black_venom, 250)
	do_chem_smoke(range = 2, location = impact, carry = reagents, carry_limit = reagents.total_volume)

/obj/projectile/terror_spider/widow/smoke/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/turf/impact = get_turf(target)
	if(impact)
		do_smoke(location = impact, amount = 15)

/mob/living/basic/spider/giant/terror/brown/death(gibbed)
	. = ..()
	if(. && !gibbed)
		empulse(get_turf(src), 6, 3, src)

/datum/action/cooldown/mob_cooldown/terror_destroyer_shriek
	name = "Электромагнитный визг"
	desc = "Издайте визг, вызывающий ЭМИ вокруг вас."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "emp_new"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 40 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_destroyer_shriek/Activate()
	if(!isturf(owner.loc))
		return FALSE
	playsound(owner, 'modular_bandastation/terror_spiders/sound/brown_shriek.ogg', 50, TRUE)
	empulse(owner.loc, 3, 2, owner)
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_destroyer_ignite
	name = "Воспламенение"
	desc = "Создайте огненное кольцо вокруг себя."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "explosion"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 60 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_destroyer_ignite/Activate()
	if(!isturf(owner.loc))
		return FALSE
	playsound(owner, 'modular_bandastation/terror_spiders/sound/brown_shriek.ogg', 50, TRUE)
	explosion(owner, flame_range = 5, protect_epicenter = TRUE, explosion_cause = owner)
	StartCooldown()
	return TRUE

/mob/living/basic/spider/giant/terror/purple/proc/on_guardian_bite(datum/source, mob/living/carbon/human/prey, success)
	SIGNAL_HANDLER

	if(!success || !ishuman(prey) || prey.stat == DEAD || faction_check_atom(prey))
		return
	prey.apply_damage(15, STAMINA)
	if(prob(20))
		visible_message(span_danger("[src] сбивает [prey] с ног!"))
		prey.adjust_brute_loss(20)
		prey.Knockdown(4 SECONDS)

/datum/action/cooldown/mob_cooldown/terror_guardian_membrane
	name = "Защитная мембрана"
	desc = "Создайте временный барьер под собой. Через него проходят только пауки улья."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "terror_shield"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 8 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_guardian_membrane/Activate()
	if(!isturf(owner.loc) || (locate(/obj/effect/forcefield/terror_membrane) in owner.loc))
		return FALSE
	new /obj/effect/forcefield/terror_membrane(owner.loc)
	playsound(owner, 'modular_bandastation/terror_spiders/sound/mod_defence.ogg', 50, TRUE)
	StartCooldown()
	return TRUE

/obj/effect/forcefield/terror_membrane
	name = "защитная мембрана"
	desc = "Толстая органическая мембрана, созданная Защитником Ужаса."
	icon = 'modular_bandastation/terror_spiders/icons/terrorspider.dmi'
	icon_state = "terror_shield"
	initial_duration = 16.5 SECONDS

/obj/effect/forcefield/terror_membrane/CanAllowThrough(atom/movable/mover, border_dir)
	if(isliving(mover))
		var/mob/living/spider = mover
		if(spider.has_faction(FACTION_TERROR_SPIDER))
			return TRUE
	return ..()

/mob/living/basic/spider/giant/terror/reaper/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(on_reaper_bite))

/mob/living/basic/spider/giant/terror/reaper/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(!QDELETED(src) && stat != DEAD)
		adjust_brute_loss(seconds_per_tick / 2, forced = TRUE)

/mob/living/basic/spider/giant/terror/reaper/proc/on_reaper_bite(datum/source, mob/living/carbon/human/prey, success)
	SIGNAL_HANDLER

	if(!success || !ishuman(prey) || prey.stat == DEAD || faction_check_atom(prey))
		return
	prey.bleed(25)
	adjust_brute_loss(-15, forced = TRUE)

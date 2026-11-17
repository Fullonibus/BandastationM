/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid
	name = "Плюнуть кислотой"
	desc = "Выстрелите сгустком кислоты."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	projectile_sound = SFX_ALIEN_SPIT_ACID
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/Activate(atom/target_atom)
	var/turf/target_turf = get_turf(target_atom)
	if(!target_turf || !isturf(owner.loc) || target_turf == owner.loc || target_turf.z != owner.z || !can_see(owner, target_turf, 7))
		return FALSE
	return ..()

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/attack_sequence(mob/living/firer, atom/target)
	playsound(firer, projectile_sound, 50, TRUE)
	return ..()

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/queen
	button_icon_state = "toxin3"
	cooldown_time = 2 SECONDS
	projectile_type = /obj/projectile/terror_royal_acid/queen

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/princess
	button_icon_state = "toxin4"
	cooldown_time = 3 SECONDS
	projectile_type = /obj/projectile/terror_royal_acid/princess

/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/empress
	button_icon_state = "toxin5"
	cooldown_time = 2 SECONDS
	projectile_type = /obj/projectile/terror_royal_acid/empress

/obj/projectile/terror_royal_acid
	parent_type = /obj/projectile/terror_spider
	name = "сгусток кислоты"
	icon_state = "toxin"
	damage_type = BURN
	range = 7

/obj/projectile/terror_royal_acid/queen
	damage = 40
	stamina = 40

/obj/projectile/terror_royal_acid/princess
	damage = 25
	stamina = 25

/obj/projectile/terror_royal_acid/empress
	damage = 90
	damage_type = BRUTE

/datum/action/cooldown/mob_cooldown/terror_royal_shriek
	name = "Ужасающий визг"
	desc = "Визг ослабляет гуманоидов и сбивает с ног синтетиков."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "terror_shriek"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	var/shriek_radius = 6
	var/stamina_damage = 30
	var/slow_duration = 10 SECONDS
	var/jitter_duration = 20 SECONDS
	var/carbon_knockdown = 0 SECONDS
	var/silicon_knockdown = 12 SECONDS
	var/breaks_lights = FALSE
	var/shriek_sound = 'modular_bandastation/terror_spiders/sound/princess_shriek.ogg'

/datum/action/cooldown/mob_cooldown/terror_royal_shriek/Activate()
	if(!isturf(owner.loc))
		return FALSE
	var/mob/living/basic/spider/giant/terror/caster = owner
	caster.visible_message(span_danger("[caster] издаёт пронзительный визг!"))
	playsound(caster, shriek_sound, 75, TRUE)
	for(var/mob/living/victim in view(shriek_radius, caster))
		if(victim.stat == DEAD || caster.faction_check_atom(victim))
			continue
		if(iscarbon(victim))
			to_chat(victim, span_userdanger("От визга боль пронзает вашу голову!"))
			victim.apply_damage(stamina_damage, STAMINA)
			victim.set_timed_status_effect(slow_duration, /datum/status_effect/terror_slowed, TRUE)
			victim.set_jitter_if_lower(jitter_duration)
			if(carbon_knockdown)
				victim.Knockdown(carbon_knockdown)
		else if(issilicon(victim))
			to_chat(victim, span_warning("Сенсорная перегрузка!"))
			SEND_SOUND(victim, sound('modular_bandastation/terror_spiders/sound/interference.ogg'))
			playsound(victim, 'modular_bandastation/terror_spiders/sound/warning-buzzer.ogg', 50, TRUE)
			do_sparks(5, TRUE, victim)
			victim.Knockdown(silicon_knockdown)
	if(breaks_lights)
		for(var/obj/machinery/light/light in view(shriek_radius, caster))
			light.break_light_tube()
	StartCooldown()
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_royal_shriek/princess
	name = "Ужасающий визг принцессы"
	cooldown_time = 60 SECONDS

/datum/action/cooldown/mob_cooldown/terror_royal_shriek/queen
	name = "Ужасающий визг королевы"
	desc = "Визг валит врагов с ног, ослабляет их и разбивает лампы поблизости."
	cooldown_time = 45 SECONDS
	shriek_radius = 7
	stamina_damage = 50
	slow_duration = 14 SECONDS
	jitter_duration = 40 SECONDS
	carbon_knockdown = 2 SECONDS
	silicon_knockdown = 16 SECONDS
	breaks_lights = TRUE
	shriek_sound = 'modular_bandastation/terror_spiders/sound/queen_shriek.ogg'

/datum/action/cooldown/mob_cooldown/terror_prince_slam
	name = "Топот"
	desc = "Ударьте по полу, чтобы ранить и замедлить врагов в радиусе двух клеток."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "slam"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	cooldown_time = 35 SECONDS
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_prince_slam/Activate()
	if(!isturf(owner.loc))
		return FALSE
	var/mob/living/basic/spider/giant/terror/caster = owner
	caster.visible_message(span_danger("[caster] с грохотом ударяет по полу!"))
	playsound(caster, 'modular_bandastation/terror_spiders/sound/prince_attack.ogg', 70, TRUE)
	for(var/mob/living/carbon/victim in view(2, caster))
		if(victim.stat == DEAD || caster.faction_check_atom(victim))
			continue
		victim.Knockdown(2 SECONDS)
		victim.adjust_brute_loss(20)
		victim.set_timed_status_effect(8 SECONDS, /datum/status_effect/terror_slowed, TRUE)
	for(var/turf/open/floor/floor in view(2, caster))
		floor.break_tile()
	StartCooldown()
	return TRUE

/mob/living/basic/spider/giant/terror/prince/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	. = ..()
	var/mob/living/carbon/human/prey = target
	if(. || !ishuman(prey) || prey.stat == DEAD || !Adjacent(prey) || HAS_TRAIT(src, TRAIT_PACIFISM) || !prob(10))
		return .
	var/static/list/limb_zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	var/list/limbs = list()
	for(var/obj/item/bodypart/limb as anything in prey.bodyparts)
		if((limb.body_zone in limb_zones) && limb.can_dismember())
			limbs += limb
	if(!length(limbs))
		return BASIC_MOB_CONTINUE_ATTACK_CHAIN
	do_attack_animation(prey)
	if(prey.check_block(src, 25, name, MELEE_ATTACK, armour_penetration))
		return BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN
	var/obj/item/bodypart/torn_limb = pick(limbs)
	if(!torn_limb.dismember(silent = FALSE, dismember_sound = 'modular_bandastation/terror_spiders/sound/rip.ogg'))
		return BASIC_MOB_CONTINUE_ATTACK_CHAIN
	prey.adjust_brute_loss(25)
	prey.Knockdown(2 SECONDS)
	prey.apply_damage(35, STAMINA)
	log_combat(src, prey, "dismembered")
	return BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN

GLOBAL_VAR_INIT(terror_empress_egg_laid, FALSE)
GLOBAL_VAR_INIT(terror_hive_destroyed, FALSE)

/datum/action/cooldown/mob_cooldown/terror_empress_egg
	name = "Отложить яйцо Императрицы"
	desc = "Выведите достаточно пауков, заразите гуманоидов или питайтесь ими, чтобы улей смог вывести Императрицу."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "eggs"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE

/datum/action/cooldown/mob_cooldown/terror_empress_egg/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	var/mob/living/basic/spider/giant/terror/egg_layer = owner
	if(!istype(egg_layer) || egg_layer.terror_degenerating || !isfloorturf(egg_layer.loc) || !is_station_level(egg_layer.z))
		if(feedback)
			owner.balloon_alert(owner, "нужен пол станции!")
		return FALSE
	if(GLOB.terror_empress_egg_laid)
		if(feedback)
			owner.balloon_alert(owner, "яйцо уже отложено!")
		return FALSE
	var/station_population = 0
	var/terror_population = 0
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		var/turf/player_turf = get_turf(player)
		if(!player_turf || !is_station_level(player_turf.z) || player.stat == DEAD)
			continue
		station_population++
		if(istype(player, /mob/living/basic/spider/giant/terror) && player.mind?.has_antag_datum(/datum/antagonist/spider/terror))
			var/mob/living/basic/spider/giant/terror/ally = player
			if(!ally.terror_degenerating)
				terror_population++
	var/progress = terror_population
	if(istype(egg_layer, /mob/living/basic/spider/giant/terror/prince))
		progress = egg_layer.fed
	else if(istype(egg_layer, /mob/living/basic/spider/giant/terror/white))
		progress = 0
		for(var/obj/item/organ/terror_eggs/infection as anything in GLOB.terror_infections)
			var/mob/living/carbon/host = infection.owner
			var/turf/host_turf = get_turf(host)
			if(host_turf && is_station_level(host_turf.z) && host.stat != DEAD)
				progress++
	var/required = round(2 + station_population / 5)
	if(progress >= required)
		return TRUE
	if(feedback)
		owner.balloon_alert(owner, "прогресс [progress]/[required]")
	return FALSE

/datum/action/cooldown/mob_cooldown/terror_empress_egg/Activate()
	var/mob/living/basic/spider/giant/terror/egg_layer = owner
	if(!IsAvailable(feedback = TRUE))
		return FALSE
	var/turf/egg_turf = egg_layer.loc
	if(tgui_alert(egg_layer, "У станции будет время найти и уничтожить яйцо. Улей погибнет, если его разобьют.", name, list("Отложить", "Отмена")) != "Отложить")
		return FALSE
	if(QDELETED(src) || owner != egg_layer || egg_layer.loc != egg_turf || !IsAvailable(feedback = TRUE))
		return FALSE
	GLOB.terror_empress_egg_laid = TRUE
	new /obj/effect/mob_spawn/ghost_role/spider/terror/empress(egg_turf, /mob/living/basic/spider/giant/terror/queen/empress, egg_layer.get_brood_directive())
	for(var/mob/living/basic/spider/giant/terror/spider in GLOB.alive_mob_list)
		to_chat(spider, span_userdanger("Яйцо Императрицы отложено в [get_area_name(egg_layer)]. Защищайте его!"))
	return TRUE

/obj/structure/spider/eggcluster/terror/empress
	name = "яйцо Императрицы Ужаса"
	desc = "В огромном яйце пульсирует сердце будущей Императрицы."
	max_integrity = 1000

/obj/structure/spider/eggcluster/terror/empress/ex_act(severity, target)
	return

/obj/effect/mob_spawn/ghost_role/spider/terror/empress
	mob_type = /mob/living/basic/spider/giant/terror/queen/empress
	cluster_type = /obj/structure/spider/eggcluster/terror/empress
	incubation_time = 3 MINUTES
	var/hatched = FALSE

/obj/effect/mob_spawn/ghost_role/spider/terror/empress/Initialize(mapload, mob/living/basic/spider/giant/terror/caste, brood_directive)
	. = ..()
	addtimer(CALLBACK(src, PROC_REF(announce_empress_egg)), 10 SECONDS)

/obj/effect/mob_spawn/ghost_role/spider/terror/empress/special(mob/living/basic/spider/giant/terror/queen/empress/spawned_mob, mob/mob_possessor, apply_prefs)
	hatched = TRUE
	. = ..()
	spawned_mob.hatched_from_empress_egg = TRUE
	spawned_mob.egg_recharge_interval = 100 SECONDS
	var/datum/action/cooldown/mob_cooldown/terror_empress_spawn/mass_spawn = locate() in spawned_mob.actions
	qdel(mass_spawn)

/obj/effect/mob_spawn/ghost_role/spider/terror/empress/Destroy()
	if(!hatched && GLOB.terror_empress_egg_laid && !GLOB.terror_hive_destroyed)
		GLOB.terror_hive_destroyed = TRUE
		erase_terror_brood("Яйцо Императрицы уничтожено. Вы чувствуете, как жизнь покидает вас!")
	return ..()

/obj/effect/mob_spawn/ghost_role/spider/terror/empress/proc/announce_empress_egg()
	if(QDELETED(egg))
		return
	priority_announce("В [get_area_name(src)] обнаружено яйцо Императрицы Ужаса. Уничтожьте его до вылупления.", "Биологическая угроза", 'modular_bandastation/terror_spiders/sound/siren-spooky.ogg')

/mob/living/basic/spider/giant/terror/queen/empress
	var/hatched_from_empress_egg = FALSE

/// Replaces the wall-tearing element when a caste gains access to reinforced walls.
/mob/living/basic/spider/giant/terror/proc/set_terror_wall_breaching(strength)
	if(environment_smash >= ENVIRONMENT_SMASH_WALLS)
		RemoveElement(/datum/element/wall_tearer, environment_smash == ENVIRONMENT_SMASH_RWALLS, 6 SECONDS, 2, /datum/element/wall_tearer)
	environment_smash = strength
	AddElement(/datum/element/wall_tearer, strength == ENVIRONMENT_SMASH_RWALLS, 6 SECONDS, 2, /datum/element/wall_tearer)

/datum/movespeed_modifier/terror_web
	multiplicative_slowdown = -0.8

/datum/movespeed_modifier/terror_web/drone
	multiplicative_slowdown = -2

/mob/living/basic/spider/giant/terror/get_shove_flags(mob/living/shover, obj/item/weapon)
	. = ..()
	if(HAS_TRAIT(src, TRAIT_PUSHIMMUNE))
		return (. & ~(SHOVE_CAN_MOVE | SHOVE_CAN_HIT_SOMETHING)) | SHOVE_BLOCKED

/// Updates web effects when a web is laid, removed, or moved under this spider.
/mob/living/basic/spider/giant/terror/proc/on_terror_web_changed(datum/source, atom/movable/changed)
	SIGNAL_HANDLER

	if(istype(changed, /obj/structure/spider/stickyweb/terror))
		refresh_terror_web()

/// Checks webbing at the current location, including after the spider moves.
/mob/living/basic/spider/giant/terror/proc/refresh_terror_web()
	SIGNAL_HANDLER

	if(isturf(loc))
		for(var/obj/structure/spider/stickyweb/terror/web in loc)
			if(!QDELETED(web))
				update_terror_web_effects(TRUE)
				return
	update_terror_web_effects(FALSE)

/// Applies the speed modifier and any caste-specific effects of standing on a web.
/mob/living/basic/spider/giant/terror/proc/update_terror_web_effects(on_web)
	SHOULD_CALL_PARENT(TRUE)

	if(on_web)
		add_movespeed_modifier(web_speed_modifier)
	else
		remove_movespeed_modifier(web_speed_modifier)

/mob/living/basic/spider/giant/terror/Life(seconds_per_tick = SSMOBS_DT)
	. = ..()
	if(QDELETED(src) || stat == DEAD)
		return
	if(health < maxHealth && terror_regeneration)
		adjust_brute_loss(-terror_regeneration * seconds_per_tick / 2, forced = TRUE)
	if(terror_degenerating)
		adjust_brute_loss(6 * seconds_per_tick / 2, forced = TRUE)

/// Apply burn damage during ignition so residual body heat cannot keep hurting the brood after extinguishing.
/mob/living/basic/spider/giant/terror/on_fire_stack(seconds_per_tick, datum/status_effect/fire_handler/fire_stacks/fire_handler)
	. = ..()
	adjust_fire_loss(TERROR_SPIDER_FIRE_DAMAGE_PER_SECOND * seconds_per_tick, forced = TRUE)

/mob/living/basic/spider/giant/terror/get_status_tab_items()
	. = ..()
	if(terror_degenerating)
		. += "Состояние: вырождение"

/mob/living/basic/spider/giant/terror/get_incoming_damage_modifier(damage, damagetype, def_zone, sharpness, attack_direction, attacking_item)
	var/coefficient = terror_damage_coefficients[damagetype]
	return ..() * (isnull(coefficient) ? 1 : coefficient)

/mob/living/basic/spider/giant/terror/proc/play_terror_hurt(datum/source, damage, damage_type)
	SIGNAL_HANDLER

	if(damage > 0 && damage_type != STAMINA && stat != DEAD)
		play_terror_voice(40)

/mob/living/basic/spider/giant/terror/proc/play_terror_voice(volume)
	var/static/list/voice_sounds = list(
		'modular_bandastation/terror_spiders/sound/speech_1.ogg',
		'modular_bandastation/terror_spiders/sound/speech_2.ogg',
		'modular_bandastation/terror_spiders/sound/speech_3.ogg',
		'modular_bandastation/terror_spiders/sound/speech_4.ogg',
		'modular_bandastation/terror_spiders/sound/speech_5.ogg',
		'modular_bandastation/terror_spiders/sound/speech_6.ogg',
	)
	playsound(src, pick(voice_sounds), volume, TRUE)

/datum/status_effect/terror_recovery
	id = "terror_recovery"
	duration = 25 SECONDS
	alert_type = null

/datum/status_effect/terror_recovery/tick(seconds_between_ticks)
	owner.adjust_brute_loss(-6 * seconds_between_ticks, forced = TRUE)

/datum/status_effect/terror_recovery/food
	id = "terror_food_recovery"

/datum/status_effect/terror_recovery/food/tick(seconds_between_ticks)
	owner.adjust_brute_loss(-owner.maxHealth / 20 * seconds_between_ticks, forced = TRUE)

/mob/living/basic/spider/giant/terror/death(gibbed)
	. = ..()
	if(!.)
		return
	qdel(GetComponent(/datum/component/ghost_direct_control))
	if(!gibbed)
		notify_terror_hive("[src] погибает в [get_area(src)].")

/mob/living/basic/spider/giant/terror/ObjBump(obj/obstacle)
	if(try_terror_door(obstacle))
		return
	return ..()

/mob/living/basic/spider/giant/terror/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	. = ..()
	if(. || !Adjacent(target))
		return
	if(try_terror_door(target, allow_close = TRUE))
		return BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN
	if(istype(target, /obj/structure/spider/royal_jelly))
		var/obj/structure/spider/royal_jelly/jelly = target
		jelly.attack_hand(src, modifiers)
		return BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN
	if(istype(target, /obj/structure/spider))
		return BASIC_MOB_END_ATTACK_CHAIN
	if(istype(target, /mob/living/basic/spider/giant/terror))
		var/mob/living/basic/spider/giant/terror/other = target
		if(terror_tier >= 4 && other.terror_tier < terror_tier)
			return BASIC_MOB_CONTINUE_ATTACK_CHAIN
		if(other.terror_tier == terror_tier)
			visible_message(span_notice("[src] дружелюбно касается [other]."))
		else if(other.terror_tier > terror_tier)
			balloon_alert(src, "высшая каста!")
		return BASIC_MOB_END_ATTACK_CHAIN_COOLDOWN
	if(istype(target, /mob/living/basic/spider/growing/spiderling/terror))
		return BASIC_MOB_END_ATTACK_CHAIN

/mob/living/basic/spider/giant/terror/proc/try_terror_door(obj/machinery/door/door, allow_close = FALSE)
	if(!istype(door) || door.operating || incapacitated)
		return FALSE
	if(istype(door, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = door
		if(airlock.welded || airlock.locked || airlock.seal)
			return FALSE
		var/has_access = airlock.allowed(src)
		if(!door.density)
			if(!allow_close || !has_access)
				return FALSE
			INVOKE_ASYNC(airlock, TYPE_PROC_REF(/obj/machinery/door, close))
			return TRUE
		if(!has_access && !can_pry_powered_airlocks && airlock.hasPower())
			return FALSE
	else if(istype(door, /obj/machinery/door/firedoor))
		var/obj/machinery/door/firedoor/firedoor = door
		if(firedoor.welded || !firedoor.density)
			return FALSE
	else
		return FALSE
	INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open), FORCING_DOOR_CHECKS, src)
	return TRUE

/mob/living/basic/spider/giant/terror/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(terror_force_threshold)
		var/force = CALCULATE_FORCE(attacking_item, attack_modifiers)
		if(force > 0 && force < terror_force_threshold)
			to_chat(user, span_warning("Удар не пробивает панцирь [src]."))
			return ATTACK_FAILED
	return ..()

/datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести паутину террора"
	desc = "Сплетите паутину под собой. Она задерживает всех, кроме пауков террора."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "stickyweb1"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	overlay_icon_state = null
	webbing_time = 2.5 SECONDS
	var/terror_web_type = /obj/structure/spider/stickyweb/terror

/datum/action/cooldown/mob_cooldown/lay_web/terror/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	if(isspaceturf(owner.loc))
		if(feedback)
			owner.balloon_alert(owner, "нужен пол!")
		return FALSE
	return TRUE

/datum/action/cooldown/mob_cooldown/lay_web/terror/plant_web(turf/target_turf, obj/structure/spider/stickyweb/existing_web)
	new terror_web_type(target_turf)

/datum/action/cooldown/mob_cooldown/lay_web/terror/Activate()
	playsound(owner, 'modular_bandastation/terror_spiders/sound/web.ogg', 50, TRUE)
	return ..()

/datum/action/cooldown/mob_cooldown/lay_web/terror/airtight
	name = "Сплести герметичную паутину"
	desc = "Сплетите паутину, которая перекрывает утечку воздуха."
	webbing_time = 1.5 SECONDS
	terror_web_type = /obj/structure/spider/stickyweb/terror/airtight

/datum/action/cooldown/mob_cooldown/lay_web/terror/airtight/princess
	webbing_time = 2 SECONDS

/obj/projectile/terror_spider
	abstract_type = /obj/projectile/terror_spider

/obj/structure/spider/stickyweb/terror
	name = "паутина террора"
	desc = "Липкие нити, сплетённые пауком террора."
	max_integrity = 20
	stuck_chance = 100
	projectile_stuck_chance = 20

/obj/structure/spider/stickyweb/terror/is_whitelisted(mob/candidate)
	return istype(candidate, /mob/living/basic/spider/giant) || istype(candidate, /mob/living/basic/spider/growing/spiderling/terror)

/obj/structure/spider/stickyweb/terror/on_entered(datum/source, atom/movable/victim, old_loc)
	if(!isliving(victim) || is_whitelisted(victim))
		return
	var/mob/living/walker = victim
	if(walker.body_position != LYING_DOWN)
		stuck_react(walker)

/obj/structure/spider/stickyweb/terror/CanAllowThrough(atom/movable/mover, border_dir)
	if(istype(mover, /obj/projectile/terror_spider))
		return TRUE
	if(isliving(mover))
		var/mob/living/walker = mover
		return is_whitelisted(walker) || walker.body_position == LYING_DOWN || prob(80)
	return ..()

/obj/structure/spider/stickyweb/terror/stuck_react(mob/living/victim)
	if(QDELETED(victim) || victim.stat == DEAD)
		return
	to_chat(victim, span_warning("Вы запутались в паутине!"))
	victim.Knockdown(2 SECONDS)
	victim.set_timed_status_effect(10 SECONDS, /datum/status_effect/terror_slowed, TRUE)

/obj/structure/spider/stickyweb/terror/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE, blocked = 0)
	if(hitting_projectile.damage_type != BRUTE && hitting_projectile.damage_type != BURN)
		return BULLET_ACT_BLOCK
	return ..()

/obj/structure/spider/stickyweb/terror/airtight
	name = "герметичная паутина"
	can_atmos_pass = ATMOS_PASS_NO

/obj/structure/spider/stickyweb/terror/airtight/Initialize(mapload)
	. = ..()
	air_update_turf(TRUE, TRUE)

/obj/structure/spider/stickyweb/terror/airtight/Destroy()
	var/turf/web_turf = get_turf(src)
	. = ..()
	web_turf?.air_update_turf(TRUE, FALSE)

/datum/language/terror_hivemind
	name = "Разум паучьего улья"
	desc = "Общая мысль пауков террора."
	key = "5"
	default_priority = 100
	flags = LANGUAGE_TONGUELESS_SPEECH | LANGUAGE_NO_STUTTER

/datum/language_holder/terror_spider
	understood_languages = list(/datum/language/terror_hivemind = list(LANGUAGE_ATOM))
	spoken_languages = list(/datum/language/terror_hivemind = list(LANGUAGE_ATOM))

/datum/element/terror_hivemind

/datum/element/terror_hivemind/Attach(datum/target)
	. = ..()
	if(!istype(target, /mob/living/basic/spider/giant/terror))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOB_SAY, PROC_REF(transmit))

/datum/element/terror_hivemind/Detach(datum/target)
	UnregisterSignal(target, COMSIG_MOB_SAY)
	return ..()

/datum/element/terror_hivemind/proc/transmit(mob/living/basic/spider/giant/terror/speaker, list/speech_args)
	SIGNAL_HANDLER

	var/list/speech_mods = speech_args[SPEECH_MODS]
	var/segment = speech_mods?[LANGUAGE_MESSAGE_SEGMENT]
	if((!segment || segment == 1) && length(speech_args[SPEECH_MESSAGE]))
		speaker.play_terror_voice(75)
	if(speech_args[SPEECH_LANGUAGE] != /datum/language/terror_hivemind)
		return
	var/message = speech_args[SPEECH_MESSAGE]
	speech_args[SPEECH_MESSAGE] = ""
	speaker.notify_terror_hive("[speaker]: [message]", speaker.loud_hive_voice)

/mob/living/basic/spider/giant/terror/proc/notify_terror_hive(message, emphasize = FALSE)
	var/formatted = "<b>Улей</b> · [message]"
	if(emphasize)
		formatted = span_bold(formatted)
	for(var/mob/listener as anything in GLOB.player_list)
		if(isobserver(listener))
			to_chat(listener, "[FOLLOW_LINK(listener, src)] [formatted]")
		else if(istype(listener, /mob/living/basic/spider/giant/terror) && listener.stat != DEAD)
			to_chat(listener, formatted)

/datum/action/cooldown/mob_cooldown/terror_remote_view
	name = "Взгляд улья"
	desc = "При полном здоровье позволяет смотреть глазами другого паука террора."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "heye"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	click_to_activate = FALSE
	shared_cooldown = NONE
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	var/datum/weakref/watched_spider

/datum/action/cooldown/mob_cooldown/terror_remote_view/Activate(atom/target)
	var/mob/living/basic/spider/giant/terror/viewer = owner
	if(watched_spider)
		stop_viewing()
		return TRUE
	if(!can_watch(viewer))
		viewer.balloon_alert(viewer, "нужен пол и полное здоровье!")
		return FALSE
	var/list/targets = list()
	for(var/mob/living/basic/spider/giant/terror/spider in GLOB.alive_mob_list)
		if(spider != viewer)
			targets["[spider] ([REF(spider)])"] = spider
	if(!length(targets))
		viewer.balloon_alert(viewer, "улей пуст!")
		return FALSE
	var/choice = tgui_input_list(viewer, "Выберите паука, глазами которого хотите смотреть.", name, targets)
	var/mob/living/basic/spider/giant/terror/watched = targets[choice]
	if(QDELETED(src) || owner != viewer || !IsAvailable() || !can_watch(viewer) || QDELETED(watched) || watched.stat == DEAD)
		return FALSE
	watched_spider = WEAKREF(watched)
	RegisterSignals(viewer, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_MOB_LOGOUT, COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH), PROC_REF(stop_viewing))
	RegisterSignals(watched, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(stop_viewing))
	viewer.reset_perspective(watched)
	return TRUE

/datum/action/cooldown/mob_cooldown/terror_remote_view/proc/can_watch(mob/living/basic/spider/giant/terror/viewer)
	return !QDELETED(viewer) && viewer.client?.eye == viewer && isturf(viewer.loc) && viewer.health == viewer.maxHealth

/datum/action/cooldown/mob_cooldown/terror_remote_view/proc/stop_viewing(datum/source)
	SIGNAL_HANDLER

	if(!watched_spider)
		return
	var/mob/living/watched = watched_spider.resolve()
	if(!watched && source != owner && istype(source, /mob/living/basic/spider/giant/terror))
		watched = source
	watched_spider = null
	if(watched)
		UnregisterSignal(watched, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	if(owner)
		UnregisterSignal(owner, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_MOB_LOGOUT, COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH))
		if(owner.client && owner.client.eye == watched)
			owner.reset_perspective()

/datum/action/cooldown/mob_cooldown/terror_remote_view/Remove(mob/removed_from)
	if(removed_from == owner)
		stop_viewing()
	return ..()

/// Toggles the Resomi's ability to step over tables.
/datum/action/innate/resomi_agility
	name = "Перешагивать через столы"
	desc = "Позволяет свободно перемещаться по столам."
	button_icon = 'icons/mob/actions/actions_voidwalker.dmi'
	button_icon_state = "dash"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED
	can_be_shared = FALSE

/datum/action/innate/resomi_agility/Activate()
	ADD_TRAIT(owner, TRAIT_PASSTABLE, REF(src))
	active = TRUE
	to_chat(owner, span_notice("Вы начинаете перешагивать через столы."))

/datum/action/innate/resomi_agility/Deactivate()
	REMOVE_TRAIT(owner, TRAIT_PASSTABLE, REF(src))
	active = FALSE
	to_chat(owner, span_notice("Вы перестаёте перешагивать через столы."))

/datum/action/innate/resomi_agility/Remove(mob/removed_from)
	if(removed_from)
		REMOVE_TRAIT(removed_from, TRAIT_PASSTABLE, REF(src))
		active = FALSE
	return ..()

/// Listens for living creatures within five tiles and shows the Resomi where they were heard.
/datum/action/cooldown/resomi_listen
	name = "Прислушаться"
	desc = "Замирает на мгновение, чтобы уловить звуки живых существ поблизости, даже за стенами."
	button_icon = 'icons/effects/effects.dmi'
	button_icon_state = "sonar_ping_small"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_OPEN_TURF
	cooldown_time = 5 SECONDS
	can_be_shared = FALSE

/datum/action/cooldown/resomi_listen/Activate(atom/target)
	var/mob/living/listener = owner
	if(!istype(listener) || !listener.client || !can_listen(listener))
		return FALSE

	if(!do_after(listener, 0.5 SECONDS, timed_action_flags = IGNORE_HELD_ITEM, interaction_key = src))
		return FALSE
	if(QDELETED(src) || owner != listener || !listener.client || !IsAvailable() || !can_listen(listener))
		return FALSE

	var/turf/origin = get_turf(listener)
	var/list/source_turfs = list()
	for(var/mob/living/creature in range(5, origin))
		if(creature == listener || creature.stat == DEAD)
			continue
		var/turf/source_turf = get_turf(creature)
		var/datum/gas_mixture/air = source_turf?.return_air()
		if(air?.return_pressure() >= SOUND_MINIMUM_PRESSURE)
			source_turfs |= source_turf

	var/static/list/directions = list(
		"north" = "на севере",
		"south" = "на юге",
		"east" = "на востоке",
		"west" = "на западе",
		"northeast" = "на северо-востоке",
		"northwest" = "на северо-западе",
		"southeast" = "на юго-востоке",
		"southwest" = "на юго-западе",
	)
	var/list/noises = list()
	var/list/recipients = list(listener.client)
	for(var/turf/source_turf as anything in source_turfs)
		var/image/ping = image('icons/effects/effects.dmi', origin, "sonar_ping_small", ABOVE_ALL_MOB_LAYER)
		ping.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		ping.pixel_w = (source_turf.x - origin.x) * ICON_SIZE_X
		ping.pixel_z = (source_turf.y - origin.y) * ICON_SIZE_Y
		SET_PLANE_EXPLICIT(ping, ABOVE_LIGHTING_PLANE, origin)
		flick_overlay_global(ping, recipients, 0.8 SECONDS)
		noises |= source_turf == origin ? "совсем рядом" : directions[dir2text(get_dir(origin, source_turf))]

	to_chat(listener, span_notice(length(noises) ? "Вы слышите движение [jointext(noises, ", ")]." : "Вы не слышите движения поблизости."))
	StartCooldown()
	return TRUE

/// Checks whether the listener can hear through the surrounding atmosphere.
/datum/action/cooldown/resomi_listen/proc/can_listen(mob/living/listener)
	if(HAS_TRAIT(listener, TRAIT_DEAF))
		to_chat(listener, span_warning("Вы ничего не слышите."))
		return FALSE
	var/turf/location = get_turf(listener)
	var/datum/gas_mixture/air = location?.return_air()
	if(!air || air.return_pressure() < SOUND_MINIMUM_PRESSURE)
		to_chat(listener, span_warning("Здесь слишком мало воздуха, чтобы услышать движение."))
		return FALSE
	return TRUE

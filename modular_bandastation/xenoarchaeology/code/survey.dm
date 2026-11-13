/obj/item/excavation/depth_scanner
	/// One survey of a specimen source at a time.
	var/surveying = FALSE
	COOLDOWN_DECLARE(pulse_cooldown)

/**
 * The field kit carries one scanner. Besides sounding a large find (handled by the find itself), it tags
 * dig site walls, labels dug artifacts and surveys expedition specimen sources.
 */
/obj/item/excavation/depth_scanner/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(istype(interacting_with, /obj/machinery/artifact))
		return label_find(interacting_with, user)
	if(istype(interacting_with, /turf/closed/mineral))
		var/turf/closed/mineral/wall = interacting_with
		if(!wall.dig_find)
			return NONE
		return wall.tag_dig_site(user)
	if(!istype(interacting_with, /obj/structure/stationtrauma_research_source))
		return ..()
	if(!surveying && user.is_holding(src))
		INVOKE_ASYNC(src, PROC_REF(survey), interacting_with, user)
	return ITEM_INTERACT_SUCCESS

/// Used in hand: dig site walls within reach light up for a few seconds.
/obj/item/excavation/depth_scanner/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!COOLDOWN_FINISHED(src, pulse_cooldown))
		balloon_alert(user, "перезаряжается")
		return TRUE
	COOLDOWN_START(src, pulse_cooldown, 3 SECONDS)
	playsound(src, 'sound/machines/sonar-ping.ogg', 30, FALSE)
	for(var/turf/closed/mineral/wall in RANGE_TURFS(7, get_turf(src)))
		if(wall.dig_find)
			wall.flash_scan()
	return TRUE

/** Survey a source while the operator holds the scanner. */
/obj/item/excavation/depth_scanner/proc/survey(obj/structure/stationtrauma_research_source/source, mob/living/user)
	if(surveying || QDELETED(source) || !user?.is_holding(src) || !user.can_perform_action(source, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	surveying = TRUE
	var/datum/mind/operator = user.mind
	to_chat(user, span_notice("Вы начинаете полевое обследование [source]."))
	var/completed = do_after(user, 6 SECONDS, source)
	if(QDELETED(src))
		return
	surveying = FALSE
	if(!completed || QDELETED(source) || QDELETED(user) || user.mind != operator || !user.is_holding(src) || !user.can_perform_action(source, NEED_HANDS|FORBID_TELEKINESIS_REACH))
		return
	var/datum/stationtrauma_research_record/record = source.research_record()
	var/first_survey = !record.surveyed
	record.log_observation(user, source, first_survey ? "Полевое обследование: [record.field_notes]" : "Повторное полевое обследование.")
	record.surveyed = TRUE
	if(first_survey)
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_SOURCE_SURVEYED, record, user, source)
	to_chat(user, span_notice(record.specimen_text()))
	playsound(src, 'sound/machines/ping.ogg', 30, TRUE)

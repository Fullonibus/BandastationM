/datum/action/cooldown/mob_cooldown/terror_vent_breach
	name = "Вскрыть заваренную вентиляцию"
	desc = "Сорвите крышку с ближайшего заваренного вентиля или скруббера. Работает и изнутри трубы."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "map_vent"
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	shared_cooldown = NONE
	click_to_activate = FALSE

/datum/action/cooldown/mob_cooldown/terror_vent_breach/Activate()
	var/mob/living/spider = owner
	var/obj/machinery/atmospherics/current_pipe = spider.loc
	var/in_pipe = istype(current_pipe) && HAS_TRAIT(spider, TRAIT_MOVE_VENTCRAWLING)
	if(!in_pipe && !isturf(spider.loc))
		return FALSE
	var/list/pipenets = in_pipe ? current_pipe.return_pipenets() : null
	var/obj/machinery/atmospherics/components/unary/vent
	for(var/obj/machinery/atmospherics/components/unary/candidate in range(1, get_turf(spider)))
		if(!candidate.welded || (!istype(candidate, /obj/machinery/atmospherics/components/unary/vent_pump) && !istype(candidate, /obj/machinery/atmospherics/components/unary/vent_scrubber)))
			continue
		if(in_pipe)
			if(candidate != current_pipe && !length(pipenets & candidate.return_pipenets()))
				continue
		else if(!spider.Adjacent(candidate))
			continue
		vent = candidate
		if(istype(vent, /obj/machinery/atmospherics/components/unary/vent_pump))
			break
	if(!vent)
		owner.balloon_alert(owner, "рядом нет доступной заваренной крышки!")
		return FALSE

	var/atom/start_location = spider.loc
	playsound(get_turf(spider), 'modular_bandastation/terror_spiders/sound/ventbreak.ogg', 75, FALSE)
	if(!do_after(spider, 4 SECONDS, target = vent, interaction_key = DOAFTER_SOURCE_SPIDER))
		return FALSE
	if(QDELETED(src) || QDELETED(spider) || QDELETED(vent) || owner != spider || spider.loc != start_location || !vent.welded || !IsAvailable())
		return FALSE
	if(in_pipe)
		if(!HAS_TRAIT(spider, TRAIT_MOVE_VENTCRAWLING) || (vent != current_pipe && !length(current_pipe.return_pipenets() & vent.return_pipenets())))
			return FALSE
	else if(!spider.Adjacent(vent))
		return FALSE
	vent.welded = FALSE
	vent.update_appearance(UPDATE_ICON)
	vent.pipe_vision_img = null
	if(in_pipe)
		spider.forceMove(get_turf(vent))
		REMOVE_TRAIT(spider, TRAIT_MOVE_VENTCRAWLING, VENTCRAWLING_TRAIT)
		if(spider.client)
			spider.update_pipe_vision()
	spider.visible_message(span_danger("[spider] срывает заваренную крышку с [vent]!"))
	return TRUE

/mob/living/basic/spider/giant/terror/green/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(blur_with_bite))

/mob/living/basic/spider/giant/terror/green/proc/blur_with_bite(datum/source, mob/living/carbon/prey, success)
	SIGNAL_HANDLER

	if(!success || !iscarbon(prey) || prey.stat == DEAD || !(prey.mob_biotypes & MOB_ORGANIC) || faction_check_atom(prey))
		return
	var/obj/item/bodypart/bite_site = prey.get_bodypart(pick(BODY_ZONE_CHEST, BODY_ZONE_HEAD))
	if(HAS_TRAIT(prey, TRAIT_INCAPACITATED) || (bite_site && prey.can_inject(null, bite_site, NONE)))
		prey.adjust_eye_blur_up_to(20 SECONDS, 120 SECONDS)

/datum/action/cooldown/mob_cooldown/lay_web/terror_slimy
	parent_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести скользкую паутину"
	desc = "Сплетите паутину, от которой у попавшейся добычи мутнеет зрение."
	webbing_time = 2 SECONDS
	terror_web_type = /obj/structure/spider/stickyweb/terror_slimy

/obj/structure/spider/stickyweb/terror_slimy
	parent_type = /obj/structure/spider/stickyweb/terror
	name = "скользкая паутина"
	desc = "Нити паутины покрыты зелёной слизью."
	color = "#9bb36a"

/obj/structure/spider/stickyweb/terror_slimy/stuck_react(mob/living/victim)
	. = ..()
	if(!QDELETED(victim) && iscarbon(victim) && victim.stat != DEAD)
		victim.adjust_eye_blur_up_to(30 SECONDS, 60 SECONDS)

/mob/living/basic/spider/giant/terror/white/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET, PROC_REF(infect_with_bite))

/mob/living/basic/spider/giant/terror/white/proc/infect_with_bite(datum/source, mob/living/carbon/prey, success)
	SIGNAL_HANDLER

	if(!success || !iscarbon(prey) || prey.stat == DEAD || faction_check_atom(prey))
		return
	prey.adjust_silence(20 SECONDS)
	prey.apply_damage(39, STAMINA)
	if(!ishuman(prey) || !(prey.mob_biotypes & MOB_ORGANIC))
		return
	var/mob/living/carbon/human/host = prey
	var/target_zone = pick(BODY_ZONE_CHEST, BODY_ZONE_HEAD)
	var/obj/item/bodypart/bite_site = host.get_bodypart(target_zone)
	var/pierces = HAS_TRAIT(host, TRAIT_INCAPACITATED) || (bite_site && host.can_inject(null, bite_site, NONE) && prob(50)) || prob(20)
	if(pierces && host.try_implant_terror_eggs(target_zone, ignore_clothing = TRUE))
		log_combat(src, prey, "implanted", addition = "with terror spider eggs")

/datum/action/cooldown/mob_cooldown/lay_web/terror_infested
	parent_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	name = "Сплести заражённую паутину"
	desc = "Сплетите паутину с яйцами, которые могут проникнуть под кожу добычи."
	webbing_time = 1 SECONDS
	terror_web_type = /obj/structure/spider/stickyweb/terror_infested

/obj/structure/spider/stickyweb/terror_infested
	parent_type = /obj/structure/spider/stickyweb/terror
	name = "заражённая паутина"
	desc = "К нитям прилипли мелкие белые яйца."
	color = "#ded5ab"

/obj/structure/spider/stickyweb/terror_infested/stuck_react(mob/living/victim)
	. = ..()
	if(QDELETED(victim) || !ishuman(victim))
		return
	var/mob/living/carbon/human/prey = victim
	if(prey.try_implant_terror_eggs(pick(BODY_ZONE_CHEST, BODY_ZONE_HEAD)))
		prey.log_message("was implanted with terror spider eggs by [src] at [AREACOORD(src)].", LOG_ATTACK)

/mob/living/carbon/human/proc/try_implant_terror_eggs(target_zone = BODY_ZONE_CHEST, ignore_clothing = FALSE)
	if(GLOB.terror_hive_destroyed || QDELETED(src) || stat == DEAD || get_organ_slot(ORGAN_SLOT_PARASITE_EGG))
		return FALSE
	var/obj/item/bodypart/bite_site = get_bodypart(target_zone)
	if(!bite_site || !IS_ORGANIC_LIMB(bite_site) || (!ignore_clothing && !can_inject(null, bite_site, NONE)))
		return FALSE
	var/obj/item/organ/terror_eggs/eggs = new()
	if(!eggs.Insert(src))
		qdel(eggs)
		return FALSE
	to_chat(src, span_warning("Вы чувствуете резкий укол в груди."))
	return TRUE

/// Implanted clutches, including those in dead or off-station hosts.
GLOBAL_LIST_EMPTY(terror_infections)

/obj/item/organ/terror_eggs
	name = "яйца паука Ужаса"
	desc = "Кладка мелких яиц, оплетённых полупрозрачной паутиной."
	icon_state = "innards"
	slot = ORGAN_SLOT_PARASITE_EGG
	organ_flags = ORGAN_ORGANIC | ORGAN_HAZARDOUS
	/// Development since the most recent hatch.
	var/egg_progress = 0
	/// How many spiderlings have already emerged from this host.
	var/eggs_hatched = 0
	/// Whether the poll for this hatch has already started.
	var/poll_started = FALSE
	/// Whether that poll still has to finish.
	var/polling = FALSE
	/// Ghost who accepted the invitation for this hatch, if any.
	var/datum/weakref/reserved_ghost
	/// Gateway infections must hatch locally.
	var/away_infection = FALSE

/obj/item/organ/terror_eggs/on_find(mob/living/finder)
	. = ..()
	to_chat(finder, span_warning("В грудной клетке обнаружена кладка яиц."))

/obj/item/organ/terror_eggs/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	var/turf/host_turf = get_turf(organ_owner)
	away_infection = host_turf && is_away_level(host_turf.z)
	GLOB.terror_infections |= src

/obj/item/organ/terror_eggs/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	GLOB.terror_infections -= src
	if(!QDELETED(src))
		QDEL_IN(src, 1)

/obj/item/organ/terror_eggs/on_life(seconds_per_tick)
	if(QDELETED(owner) || owner.stat == DEAD)
		return
	. = ..()
	if(QDELETED(src) || QDELETED(owner) || (organ_flags & ORGAN_FAILING))
		return
	var/turf/host_turf = get_turf(owner)
	if(!host_turf)
		return
	if(away_infection && !is_away_level(host_turf.z))
		owner.gib()
		qdel(src)
		return
	var/growth = 1
	if(owner.nutrition > NUTRITION_LEVEL_FULL)
		growth += 1
	if(owner.reagents?.get_reagent_amount(/datum/reagent/medicine/spaceacillin) > 15)
		growth -= 0.5
	if(owner.reagents?.get_reagent_amount(/datum/reagent/medicine/salglu_solution) > 1)
		growth += 1
	egg_progress += growth * seconds_per_tick
	if(!away_infection && !poll_started && egg_progress >= 90)
		poll_started = TRUE
		polling = TRUE
		INVOKE_ASYNC(src, PROC_REF(poll_for_hatch))
	if(!polling && egg_progress >= 120)
		hatch_egg()

/obj/item/organ/terror_eggs/proc/poll_for_hatch()
	var/image/portrait = get_terror_spider_poll_portrait(/mob/living/basic/spider/giant/terror/red)
	var/mob/dead/observer/chosen = SSpolling.poll_ghosts_for_target(
		question = "Вы хотите сыграть за паука Ужаса?",
		role = ROLE_ALIEN,
		check_jobban = ROLE_ALIEN,
		poll_time = 30 SECONDS,
		checked_target = src,
		ignore_category = POLL_IGNORE_SPIDER,
		alert_pic = portrait,
		role_name_text = "Паук Ужаса",
		chat_text_border_icon = portrait,
		announce_chosen = FALSE,
	)
	if(QDELETED(src))
		return
	reserved_ghost = WEAKREF(chosen)
	polling = FALSE

/obj/item/organ/terror_eggs/proc/hatch_egg()
	var/mob/living/carbon/host = owner
	var/turf/hatch_turf = get_turf(host)
	if(QDELETED(host) || host.stat == DEAD || !hatch_turf || host.get_organ_slot(slot) != src)
		return
	if(polling || egg_progress < 120 || (organ_flags & ORGAN_FAILING) || (away_infection && !is_away_level(hatch_turf.z)))
		return
	var/caste
	switch(eggs_hatched)
		if(0)
			caste = pick(/mob/living/basic/spider/giant/terror/gray, /mob/living/basic/spider/giant/terror/red, /mob/living/basic/spider/giant/terror/reaper)
		if(1)
			caste = pick(/mob/living/basic/spider/giant/terror/brown, /mob/living/basic/spider/giant/terror/reaper, /mob/living/basic/spider/giant/terror/red, /mob/living/basic/spider/giant/terror/green, /mob/living/basic/spider/giant/terror/builder)
		if(2)
			caste = pick(/mob/living/basic/spider/giant/terror/black, /mob/living/basic/spider/giant/terror/gray, /mob/living/basic/spider/giant/terror/builder, /mob/living/basic/spider/giant/terror/red, /mob/living/basic/spider/giant/terror/red)
	egg_progress -= 120
	eggs_hatched++
	var/mob/living/basic/spider/growing/spiderling/terror/spiderling = new(hatch_turf, caste)
	spiderling.reserved_ghost = reserved_ghost
	spiderling.poll_on_growth = !poll_started
	reserved_ghost = null
	poll_started = FALSE
	to_chat(host, span_userdanger("По коже пробегает колючая дрожь, и весь мир вдруг начинает вращаться!"))
	host.adjust_brute_loss(80)
	host.Paralyze(20 SECONDS)
	host.set_confusion(40 SECONDS)
	if(eggs_hatched >= 3)
		host.adjust_brute_loss(200)
		host.death()
		qdel(src)

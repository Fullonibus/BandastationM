/**
 * # Large finds
 *
 * What a boulder holds, and the finds other than alien artifacts: the bluespace formation, the
 * charged crystal, a sealed research case and, in red sites only, a wrecked combat exosuit.
 *
 * Shares (design): artifact 88%, bluespace formation 6%, charged crystal 4%, sealed case 2%.
 * In red the exosuit wreck takes XENOARCH_FIND_SHARE_EXOSUIT_RED out of the artifact share.
 */

/// Rolls what a boulder in a site of this band holds. Returns a type path.
/proc/xenoarch_roll_large_find(band)
	band = XENOARCH_BAND_INDEX(band)
	var/roll = rand(1, 100)
	var/threshold = XENOARCH_FIND_SHARE_FORMATION
	if(roll <= threshold)
		return /obj/machinery/artifact/bluespace_formation
	threshold += XENOARCH_FIND_SHARE_CRYSTAL
	if(roll <= threshold)
		return /obj/machinery/power/charged_crystal
	threshold += XENOARCH_FIND_SHARE_CASE
	if(roll <= threshold)
		return /obj/structure/closet/crate/xenoarch_case
	if(band == XENOARCH_BAND_RED)
		threshold += XENOARCH_FIND_SHARE_EXOSUIT_RED
		if(roll <= threshold)
			return pick_weight(GLOB.xenoarch_exosuit_wrecks)
	return /obj/machinery/artifact

/// Combat exosuits that turn up wrecked in red dig sites: the two standard frames.
GLOBAL_LIST_INIT(xenoarch_exosuit_wrecks, list(
	/obj/vehicle/sealed/mecha/gygax = 3,
	/obj/vehicle/sealed/mecha/durand = 2,
))

/**
 * Makes a freed large find of `find_type` at `spot`, stamped with `band`. `damaged` is a find that
 * came out without the right field. An artifact keeps the boulder's catalogue number.
 */
/proc/xenoarch_spawn_large_find(find_type, turf/spot, band, damaged = FALSE, serial)
	band = XENOARCH_BAND_INDEX(band)
	if(ispath(find_type, /obj/machinery/artifact))
		var/obj/machinery/artifact/artifact = new find_type(spot, band)
		if(serial)
			artifact.serial = serial
		if(damaged)
			artifact.damaged = TRUE
		artifact.journal_record = new(artifact.serial, spot)
		artifact.journal_note(null, "Извлечено из валуна[damaged ? " с повреждениями" : " целым"].")
		return artifact
	if(ispath(find_type, /obj/machinery/power/charged_crystal))
		var/obj/machinery/power/charged_crystal/crystal = new find_type(spot, band)
		if(damaged)
			crystal.crack()
		return crystal
	if(ispath(find_type, /obj/structure/closet/crate/xenoarch_case))
		var/obj/structure/closet/crate/xenoarch_case/case = new find_type(spot)
		// Tiered by where it was dug, wherever it is opened.
		for(var/i in 1 to rand(1, 2))
			xenoarch_research_draw(case, band)
		return case
	if(ispath(find_type, /obj/vehicle/sealed/mecha))
		return xenoarch_wreck_exosuit(find_type, spot, damaged)
	if(ispath(find_type, /atom/movable))
		return new find_type(spot)
	return null

/// The band a find was dug in, or null if it never came out of a dig site.
/proc/xenoarch_find_band(atom/find)
	if(istype(find, /obj/machinery/artifact))
		var/obj/machinery/artifact/artifact = find
		return artifact.origin_band
	if(istype(find, /obj/item/xenoarch_curio))
		var/obj/item/xenoarch_curio/curio = find
		return curio.origin_band
	if(istype(find, /obj/item/relic/excavated))
		var/obj/item/relic/excavated/relic = find
		return relic.origin_band
	if(istype(find, /obj/machinery/power/charged_crystal))
		var/obj/machinery/power/charged_crystal/crystal = find
		return crystal.origin_band
	if(istype(find, /obj/item/field_artefact))
		var/obj/item/field_artefact/artefact = find
		return artefact.origin_band
	return null

// ===== Exosuit wreck =====

/**
 * A combat exosuit that has been in the rock a long time: a third of its armour, a nearly flat
 * cell, no weapons, and caked in dust until someone washes it. Crews repair and arm it themselves.
 */
/proc/xenoarch_wreck_exosuit(mech_type, turf/spot, damaged = FALSE)
	var/obj/vehicle/sealed/mecha/mech = new mech_type(spot)
	mech.update_integrity(round(mech.max_integrity * (damaged ? 0.2 : 0.35)))
	if(mech.cell)
		mech.cell.charge = round(mech.cell.maxcharge * 0.15)
	mech.add_atom_colour("#b8a88e", WASHABLE_COLOUR_PRIORITY)
	return mech

// ===== Bluespace formation =====

/**
 * # Bluespace formation
 *
 * A growth of bluespace crystal on dark stone. Not a true artifact: it has no effects to study.
 * Each hard knock throws people near it a short way and lets off a small EMP; broken, it leaves
 * a few bluespace crystals. Rewrite of NovaSector (5ce2bd2215c0) artifact_bluespace_crystal.dm
 * without the anomaly it spawned on destruction.
 */
/obj/machinery/artifact/bluespace_formation
	rolls_effects = FALSE
	shape = "shard"
	max_integrity = 240
	/// Next world.time it can lash out again
	var/next_lash = 0

/obj/machinery/artifact/bluespace_formation/Initialize(mapload, band)
	. = ..()
	name = "блюспейс-образование"
	desc = pick(
		"Бледно-голубой кристалл, растущий из тёмного камня. Если долго смотреть, края предметов начинают плыть.",
		"Друза синего кристалла на чёрной породе. Свет внутри неё ниоткуда не берётся.",
	)
	add_filter("formation_glow", 2, drop_shadow_filter(0, 0, 1.5, 0, "#4fb3ff70"))
	add_shared_particles(/particles/artifact/bluespace)
	set_light(2, 0.6, "#4fb3ff")

/obj/machinery/artifact/bluespace_formation/Destroy()
	remove_shared_particles(/particles/artifact/bluespace)
	remove_filter("formation_glow")
	return ..()

/obj/machinery/artifact/bluespace_formation/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	. = ..()
	if(. > 0 && !QDELETED(src) && world.time >= next_lash)
		lash_out()

/// Throws everyone close by a few tiles and lets off a small EMP.
/obj/machinery/artifact/bluespace_formation/proc/lash_out()
	next_lash = world.time + 3 SECONDS
	var/turf/here = get_turf(src)
	if(!here)
		return
	visible_message(span_warning("[src] вспыхивает, и пространство вокруг сворачивается."))
	playsound(here, 'sound/effects/magic/teleport_diss.ogg', 50, TRUE)
	do_sparks(3, FALSE, src)
	empulse(here, 0, 2)
	var/mob/culprit = last_disturbed_by?.resolve()
	for(var/mob/living/victim in range(3, here))
		if(artifact_exposure(victim) <= 0)
			continue
		if(victim.buckled)
			victim.buckled.unbuckle_mob(victim)
		if(do_teleport(victim, get_turf(victim), 4, asoundin = 'sound/effects/phasein.ogg', channel = TELEPORT_CHANNEL_BLUESPACE))
			if(culprit && culprit != victim)
				log_combat(culprit, victim, "displaced with a bluespace formation", src)

/obj/machinery/artifact/bluespace_formation/atom_destruction(damage_flag)
	var/turf/here = get_turf(src)
	if(here)
		new /obj/item/stack/ore/bluespace_crystal(here, rand(2, 4))
	return ..()

// ===== Charged crystal =====

/**
 * # Charged crystal
 *
 * A crystal holding a finite charge. Bolted onto a cable knot and wrapped in wire, it puts about
 * one PACMAN's worth on the net (XENOARCH_CRYSTAL_POWER) until it has given XENOARCH_CRYSTAL_LIFETIME
 * of it, then goes dull for good. Cut the wire to save what is left. Rewrite of NovaSector
 * (5ce2bd2215c0) artifact_power_crystal.dm, which gave free power forever.
 *
 * Art: the core crystal sprite (Nova artifacts.dmi), recoloured amber, with a drawn wire wrap.
 */
/obj/machinery/power/charged_crystal
	name = "заряженный кристалл"
	desc = "Тяжёлый янтарный кристалл. Воздух рядом пахнет надвигающейся грозой."
	icon = 'modular_bandastation/xenoarchaeology/icons/dig_finds.dmi'
	icon_state = "charged_crystal"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	processing_flags = START_PROCESSING_MANUALLY
	max_integrity = 200
	resistance_flags = FIRE_PROOF | ACID_PROOF
	/// ZONE_* it was dug in, or null
	var/origin_band
	/// Wrapped in cable, ready to feed a powernet
	var/wired = FALSE
	/// Deciseconds of output left before it goes dull
	var/charge_left = XENOARCH_CRYSTAL_LIFETIME
	/// Came out of the rock badly: half the charge, and a crack to show for it
	var/cracked = FALSE
	/// Putting power on the net right now
	var/running = FALSE
	/// The hum while it runs
	var/datum/looping_sound/hum

/obj/machinery/power/charged_crystal/Initialize(mapload, band)
	. = ..()
	if(!isnull(band))
		origin_band = XENOARCH_BAND_INDEX(band)
	update_appearance()

/obj/machinery/power/charged_crystal/Destroy()
	QDEL_NULL(hum)
	return ..()

/// Came out of the rock badly.
/obj/machinery/power/charged_crystal/proc/crack()
	if(cracked)
		return
	cracked = TRUE
	charge_left = round(charge_left / 2)

/// Has any charge left to give.
/obj/machinery/power/charged_crystal/proc/is_dull()
	return charge_left <= 0

/obj/machinery/power/charged_crystal/proc/can_run()
	return wired && anchored && powernet && !is_dull()

/// Starts or stops feeding the net to match what it can do now.
/obj/machinery/power/charged_crystal/proc/refresh_running()
	var/should_run = can_run()
	if(should_run == running)
		return
	running = should_run
	if(running)
		begin_processing()
		if(!hum)
			hum = new /datum/looping_sound/artifact_hum/electromagnetic(src)
		hum.start()
		playsound(src, 'sound/effects/magic/charge.ogg', 40, TRUE)
		visible_message(span_notice("[src] занимается, и по нему ползёт свет."))
	else
		end_processing()
		hum?.stop()
	update_appearance()

/obj/machinery/power/charged_crystal/process(seconds_per_tick)
	if(!can_run())
		refresh_running()
		return
	add_avail(power_to_energy(XENOARCH_CRYSTAL_POWER))
	charge_left -= seconds_per_tick * (1 SECONDS)
	if(is_dull())
		go_dull()
		return
	update_light_level()

/// Spent: dark through and through, and no use to anyone.
/obj/machinery/power/charged_crystal/proc/go_dull()
	charge_left = 0
	visible_message(span_notice("Последний свет уходит из [src], и он темнеет."))
	playsound(src, 'sound/effects/stealthoff.ogg', 40, TRUE)
	refresh_running()

/// Brighter while it has more to give.
/obj/machinery/power/charged_crystal/proc/update_light_level()
	if(!running)
		set_light(0)
		return
	var/fraction = clamp(charge_left / XENOARCH_CRYSTAL_LIFETIME, 0, 1)
	set_light(2, 0.4 + fraction * 0.6, "#ffb347")

/obj/machinery/power/charged_crystal/update_icon_state()
	if(is_dull())
		icon_state = "charged_crystal_dull"
	else if(running)
		icon_state = "charged_crystal_active"
	else
		icon_state = "charged_crystal"
	return ..()

/obj/machinery/power/charged_crystal/update_overlays()
	. = ..()
	if(wired)
		. += mutable_appearance(icon, "charged_crystal_wires")

/obj/machinery/power/charged_crystal/update_appearance(updates = ALL)
	. = ..()
	update_light_level()

/obj/machinery/power/charged_crystal/examine(mob/user)
	. = ..()
	if(is_dull())
		. += "Он тёмный насквозь."
	else
		var/fraction = charge_left / XENOARCH_CRYSTAL_LIFETIME
		if(fraction > 0.66)
			. += "В глубине движется свет."
		else if(fraction > 0.33)
			. += "Свет внутри поредел."
		else
			. += "В нём осталась лишь слабая искра."
	if(cracked)
		. += span_warning("Через него проходит трещина.")
	if(wired)
		. += "Основание обмотано медным проводом[running ? ", тёплым на ощупь" : ""]."
	if(anchored)
		. += "Закреплено болтами к полу."

/obj/machinery/power/charged_crystal/wrench_act(mob/living/user, obj/item/tool)
	if(running)
		balloon_alert(user, "сначала срежьте провод")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool, 3 SECONDS) != SUCCESSFUL_UNFASTEN)
		return ITEM_INTERACT_BLOCKING
	if(anchored)
		connect_to_network()
	else
		disconnect_from_network()
	refresh_running()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/charged_crystal/wirecutter_act(mob/living/user, obj/item/tool)
	if(!wired)
		return NONE
	if(!tool.use_tool(src, user, 2 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	wired = FALSE
	new /obj/item/stack/cable_coil(drop_location(), 2)
	user.visible_message(span_notice("[user] срезает провод с [src]."), span_notice("Вы срезаете провод с [src]."))
	refresh_running()
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/charged_crystal/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stack/cable_coil))
		return NONE
	if(wired)
		balloon_alert(user, "уже подключено")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/stack/cable_coil/coil = tool
	if(coil.get_amount() < 2)
		balloon_alert(user, "нужно больше кабеля")
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_notice("[user] начинает обматывать [src] кабелем."), span_notice("Вы начинаете обматывать [src] кабелем."))
	if(!do_after(user, 2 SECONDS, src) || wired || !coil.use(2))
		return ITEM_INTERACT_BLOCKING
	wired = TRUE
	playsound(src, 'sound/items/deconstruct.ogg', 40, TRUE)
	refresh_running()
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/power/charged_crystal/atom_destruction(damage_flag)
	var/turf/here = get_turf(src)
	if(here)
		visible_message(span_warning("[src] разбивается вдребезги!"), blind_message = span_hear("Вы слышите, как разбивается кристалл."))
		playsound(here, 'sound/effects/glass/glassbr3.ogg', 60, TRUE)
		for(var/i in 1 to 2)
			new /obj/item/shard(here)
	return ..()

/// A sealed case from a dig, holding research materials tiered by the band it came from.
/obj/structure/closet/crate/xenoarch_case
	name = "запечатанный исследовательский кейс"
	desc = "Тяжёлый герметичный кейс неизвестного производителя. Внутри что-то перекатывается."

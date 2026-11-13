/**
 * # Veined boulder
 *
 * What a large find sits in once its site wall is mined. Ported from NovaSector (5ce2bd2215c0)
 * modular_nova/modules/xenoarchartifacts/artifacts/artifact.dm (/obj/structure/boulder), reworked:
 * - All state lives in a /datum/dig_boulder_record held by the planet's dig reserve, so a rebuilt
 *   planet puts the boulder back exactly as the crew left it.
 * - One depth scanner sounds and measures it (Nova's scanner plus tape measure); the advanced one
 *   reads the exact depth and the stabilising field on site, skipping the spectrometer trip.
 * - One hammer with a fitted head, a pick or drill for rough work, and the brush to finish:
 *   brushing never overshoots, it only takes a centimetre at a time until the find shows.
 * - Cutting past the find loses it. Freeing it without the right stabilising field loses it half
 *   the time and damages it otherwise. A lost find leaves nothing behind: no artifact is made and
 *   no burst fires (Nova spawned and deleted one, setting off its destroy effect).
 * - It shrinks visibly by depth cut (never by depth left, which would give the find away), chips
 *   and dusts on every strike, and the find comes out of a settling cloud of grit.
 */
/obj/structure/xenoarch_boulder
	name = "валун с прожилками"
	desc = "Тяжёлая глыба породы с прожилками, отколотая от стены. Внутри что-то твёрже камня."
	icon = 'modular_bandastation/xenoarchaeology/icons/dig_site.dmi'
	icon_state = "boulder1_0"
	anchored = TRUE
	density = TRUE
	max_integrity = 150
	resistance_flags = FIRE_PROOF | LAVA_PROOF
	/// Everything about this boulder; kept in its site's record while it is unopened
	var/datum/dig_boulder_record/record
	/// The dig site it came from (weakref to /datum/dig_site_record), if any
	var/datum/weakref/site_ref
	/// Next world.time a working tool makes its noise
	var/next_work_noise = 0

/obj/structure/xenoarch_boulder/Initialize(mapload, datum/dig_boulder_record/new_record, datum/dig_site_record/site)
	. = ..()
	record = new_record || new /datum/dig_boulder_record()
	if(site)
		site_ref = WEAKREF(site)
	color = record.rock_color || "#8f8a83"
	if(record.tagged)
		AddComponent(/datum/component/gps, "раскопка [record.serial]")
	update_appearance()

/obj/structure/xenoarch_boulder/Destroy()
	QDEL_NULL(record)
	site_ref = null
	return ..()

/// How far it has been cut down, by depth cut: 0 untouched to 3 a stub of rock.
/obj/structure/xenoarch_boulder/proc/cut_stage()
	switch(record?.dug)
		if(140 to INFINITY)
			return 3
		if(80 to 140)
			return 2
		if(30 to 80)
			return 1
	return 0

/obj/structure/xenoarch_boulder/update_icon_state()
	icon_state = "boulder[record?.variant || 1]_[cut_stage()]"
	return ..()

/obj/structure/xenoarch_boulder/update_overlays()
	. = ..()
	if(!record)
		return
	. += mutable_appearance(icon, "boulder[record.variant]_[cut_stage()]_vein", appearance_flags = RESET_COLOR)
	if(record.sounded)
		. += mutable_appearance(icon, "survey_pin", appearance_flags = RESET_COLOR)
	if(record.tagged)
		. += mutable_appearance(icon, "holotag", appearance_flags = RESET_COLOR)
	if(record.field_applied)
		. += mutable_appearance(icon, "field", appearance_flags = RESET_COLOR)

/obj/structure/xenoarch_boulder/examine(mob/user)
	. = ..()
	if(!record)
		return
	if(record.tagged)
		. += "На голобирке: <b>[record.serial]</b>."
	switch(record.sounded)
		if(1)
			. += "На приколотой метке: <i>находка на глубине [max(1, record.rough_depth - XENOARCH_SCAN_ERROR)]–[record.rough_depth + XENOARCH_SCAN_ERROR] см. Снято [record.dug] см.</i>"
		if(2)
			. += "На приколотой метке: <i>находка на глубине [record.target_depth] см. Снято [record.dug] см.</i>"
	if(record.field_applied)
		. += span_notice("Его удерживает слабая световая решётка: [record.field_applied].")

// ===== Tools =====

/obj/structure/xenoarch_boulder/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!record || record.settled)
		return NONE
	if(istype(tool, /obj/item/mining_scanner) || istype(tool, /obj/item/t_scanner/adv_mining_scanner))
		return tag_with(tool, user)
	if(istype(tool, /obj/item/excavation/hammer))
		return hammer_with(tool, user)
	if(istype(tool, /obj/item/excavation/brush))
		return brush_with(tool, user)
	if(istype(tool, /obj/item/excavation/depth_scanner))
		return sound_with(tool, user)
	if(istype(tool, /obj/item/excavation/core_sampler))
		return sample_with(tool, user)
	if(istype(tool, /obj/item/excavation/stabiliser))
		return stabilise_with(tool, user)
	if(tool.tool_behaviour == TOOL_MINING)
		return rough_cut_with(tool, user)
	return NONE

/// The holotag: a GPS signal under its catalogue number, so the crew (and anyone else) can find it again.
/obj/structure/xenoarch_boulder/proc/tag_with(obj/item/scanner, mob/living/user)
	if(record.tagged)
		balloon_alert(user, "уже помечено")
		return ITEM_INTERACT_BLOCKING
	record.tagged = TRUE
	AddComponent(/datum/component/gps, "раскопка [record.serial]")
	playsound(src, 'sound/machines/beep/twobeep.ogg', 40, TRUE)
	user.visible_message(
		span_notice("[user] закрепляет голобирку на [src]."),
		span_notice("Вы закрепляете голобирку на [src]. Она загорается: <b>[record.serial]</b>."),
	)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/hammer_with(obj/item/excavation/hammer/hammer, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	var/cm = hammer.head
	user.visible_message(
		span_notice("[user] начинает скалывать [src] с помощью [hammer]."),
		span_notice("Вы начинаете скалывать [src] насадкой на [cm] см."),
		blind_message = span_hear("Вы слышите размеренный стук."),
	)
	if(!do_after(user, cm * XENOARCH_HAMMER_TIME_PER_CM, src, extra_checks = CALLBACK(src, PROC_REF(work_noise), SFX_ROCK_TAP, 0.6 SECONDS, TRUE), interaction_key = DOAFTER_SOURCE_XENOARCH))
		// Stopping mid-swing is how a careful hand slips.
		if(!QDELETED(src) && record && !record.settled && prob(50))
			to_chat(user, span_warning("Молоток соскальзывает и откалывает кусок от [src]."))
			cut(rand(1, 2), user)
		return ITEM_INTERACT_BLOCKING
	cut(cm, user)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/rough_cut_with(obj/item/tool, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_notice("[user] начинает откалывать породу от [src] с помощью [tool]."),
		span_notice("Вы начинаете откалывать породу от [src]."),
		blind_message = span_hear("Вы слышите, как крошится порода."),
	)
	if(!tool.use_tool(src, user, 2.5 SECONDS, volume = 50, extra_checks = CALLBACK(src, PROC_REF(work_noise), 'sound/effects/pickaxe/picaxe1.ogg', 0.8 SECONDS, TRUE)))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	cut(rand(XENOARCH_PICK_CUT_MIN, XENOARCH_PICK_CUT_MAX), user)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/brush_with(obj/item/excavation/brush/brush, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, brush.brush_time, src, extra_checks = CALLBACK(src, PROC_REF(work_noise), SFX_RUSTLE, 0.9 SECONDS, FALSE), interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	if(record.dug > record.target_depth)
		lose_find(user, "слишком глубоко")
		return ITEM_INTERACT_SUCCESS
	if(record.dug == record.target_depth)
		free_find(user)
		return ITEM_INTERACT_SUCCESS
	record.dug++
	dust_puff(small = TRUE)
	if(record.sounded)
		balloon_alert(user, "[record.dug] см")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/sound_with(obj/item/excavation/depth_scanner/scanner, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/effects/industrial_scan/industrial_scan1.ogg', 35, TRUE)
	if(!do_after(user, scanner.scan_time, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	record.sounded = max(record.sounded, scanner.exact ? 2 : 1)
	if(!record.tagged)
		record.tagged = TRUE
		AddComponent(/datum/component/gps, "раскопка [record.serial]")
	playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
	var/list/reading = list()
	if(scanner.exact)
		reading += "Находка на глубине [record.target_depth] см."
	else
		reading += "Находка на глубине [max(1, record.rough_depth - XENOARCH_SCAN_ERROR)]–[record.rough_depth + XENOARCH_SCAN_ERROR] см."
	reading += "Снято [record.dug] см."
	if(scanner.reads_field)
		reading += "Поле: [record.field]."
	to_chat(user, span_notice("[scanner] прикалывает метку к [src] и показывает: <i>[jointext(reading, " ")]</i>"))
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/sample_with(obj/item/excavation/core_sampler/sampler, mob/living/user)
	if(sampler.sample_serial)
		balloon_alert(user, "пробоотборник полон")
		return ITEM_INTERACT_BLOCKING
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/effects/rock/rocktap2.ogg', 40, TRUE)
	if(!do_after(user, 2 SECONDS, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled || sampler.sample_serial)
		return ITEM_INTERACT_BLOCKING
	sampler.take_core(record)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_CORE_TAKEN, sampler, user, src)
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	user.visible_message(
		span_notice("[user] вгоняет [sampler] в [src] и извлекает керн породы."),
		span_notice("Вы вгоняете [sampler] в [src] и извлекаете керн породы."),
	)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/stabilise_with(obj/item/excavation/stabiliser/stabiliser, mob/living/user)
	if(!stabiliser.selected_field)
		balloon_alert(user, "поле не выбрано")
		return ITEM_INTERACT_BLOCKING
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_notice("[user] медленно проводит [stabiliser] над [src]."),
		span_notice("Вы проводите [stabiliser] над [src], накладывая поле: [stabiliser.selected_field]."),
		blind_message = span_hear("Вы слышите низкое электрическое гудение."),
	)
	playsound(src, 'sound/effects/magic/forcewall.ogg', 25, TRUE)
	if(!do_after(user, 5 SECONDS, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	// Correct or not, the field looks the same. Only the spectrometer or a field reading can tell.
	record.field_applied = stabiliser.selected_field
	record.stabilised = (record.field_applied == record.field)
	playsound(src, 'sound/machines/clockcult/steam_whoosh.ogg', 25, TRUE)
	to_chat(user, span_notice("На [src] ложится слабая световая решётка."))
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/// Plays a tool's noise, with a chip of rock and a puff of dust for striking tools, at most every `interval`. Always TRUE (a do_after check).
/obj/structure/xenoarch_boulder/proc/work_noise(noise, interval, striking)
	if(world.time < next_work_noise)
		return TRUE
	next_work_noise = world.time + interval
	playsound(src, noise, striking ? 45 : 30, TRUE)
	if(striking)
		dust_puff(small = TRUE)
		Shake(1, 0, 0.15 SECONDS)
	return TRUE

// ===== Cutting down =====

/// Takes `cm` off the boulder. Past the find, the find is lost.
/obj/structure/xenoarch_boulder/proc/cut(cm, mob/living/user)
	var/old_stage = cut_stage()
	record.dug += cm
	if(record.dug > record.target_depth)
		lose_find(user, "слишком глубоко")
		return
	dust_puff(small = FALSE)
	if(cut_stage() != old_stage)
		// A whole slab comes away: the boulder is visibly smaller.
		playsound(src, 'sound/effects/rock/rock_break.ogg', 40, TRUE)
		visible_message(span_notice("От [src] откалывается пласт породы."))
		new /obj/effect/temp_visual/xenoarch_dust(get_turf(src), color, FALSE)
	if(record.sounded && user)
		balloon_alert(user, "[record.dug] см")
	update_appearance()

/// A puff of dust off the cut face, tinted like the rock.
/obj/structure/xenoarch_boulder/proc/dust_puff(small = TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(get_turf(src), color, small)

/// The settle: brushed clean at the right depth. Without the right field it may come apart anyway.
/obj/structure/xenoarch_boulder/proc/free_find(mob/living/user)
	var/turf/spot = get_turf(src)
	var/damaged = FALSE
	if(!record.stabilised)
		if(prob(XENOARCH_UNSTABLE_CRUMBLE_CHANCE))
			lose_find(user, "unstabilised")
			return null
		damaged = TRUE
	var/find_type = record.find_type
	var/band = record.band
	var/serial = record.serial
	settle()
	playsound(spot, 'sound/effects/break_stone.ogg', 50, TRUE)
	playsound(spot, 'sound/effects/rustle/rustle3.ogg', 40, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(spot, color, FALSE)
	new /obj/effect/decal/cleanable/rubble(spot)
	var/atom/movable/find = xenoarch_spawn_large_find(find_type, spot, band, damaged, serial)
	if(find)
		// It comes up out of the grit.
		find.alpha = 0
		find.pixel_z = -6
		animate(find, alpha = 255, pixel_z = 0, time = 1.2 SECONDS, easing = SINE_EASING | EASE_OUT)
		new /obj/effect/temp_visual/xenoarch_glint(spot)
		visible_message(span_notice("Последние остатки породы осыпаются, и из пыли показывается [find]."))
		if(damaged)
			visible_message(span_warning("По [find] идут трещины там, где порода отпустила находку неудачно."))
		SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPEDITION_FIND_RECOVERED, find, user, spot)
	xenoarch_dig_ambush(spot, band, user, site_ref?.resolve())
	qdel(src)
	return find

/**
 * The find is gone: cut into, come apart unheld, smashed or blown up. Nothing is made and
 * nothing goes off. `reason` picks the message.
 */
/obj/structure/xenoarch_boulder/proc/lose_find(mob/living/user, reason, delete_self = TRUE)
	var/turf/spot = get_turf(src)
	settle()
	switch(reason)
		if("слишком глубоко")
			visible_message(
				span_warning("Глубоко внутри [src] что-то глухо хрустит, и валун раскалывается по трещине. Всё, что было внутри, теперь щебень."),
				blind_message = span_hear("Вы слышите хруст и треск породы."),
			)
		if("unstabilised")
			visible_message(
				span_warning("Когда осыпается последняя крошка, [src] содрогается и разваливается на куски. Ничто не удерживало его целым."),
				blind_message = span_hear("Вы слышите, как оседает и осыпается порода."),
			)
		else
			visible_message(
				span_warning("[src] разлетается фонтаном каменной крошки."),
				blind_message = span_hear("Вы слышите, как разлетается порода."),
			)
	playsound(spot, 'sound/effects/break_stone.ogg', 60, TRUE)
	playsound(spot, 'sound/effects/rock/rock_break.ogg', 50, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(spot, color, FALSE)
	new /obj/effect/decal/cleanable/rubble(spot)
	if(delete_self)
		qdel(src)

/// Done with: out of its site's record for good.
/obj/structure/xenoarch_boulder/proc/settle()
	if(record.settled)
		return
	record.settled = TRUE

/obj/structure/xenoarch_boulder/atom_destruction(damage_flag)
	if(record && !record.settled)
		lose_find(null, damage_flag == BOMB ? "blast" : "smashed", delete_self = FALSE)
	return ..()

/**
 * # Dig dust
 *
 * A short puff of grit tinted like the rock it came off. Small for each strike, big when a slab
 * comes away or the boulder lets go. Reuses the mook leap cloud.
 */
/obj/effect/temp_visual/xenoarch_dust
	name = "dust"
	icon = 'icons/mob/simple/jungle/mook.dmi'
	icon_state = "mook_leap_cloud"
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE
	pixel_x = -16
	pixel_y = -16
	base_pixel_x = -16
	base_pixel_y = -16
	duration = 1 SECONDS
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/temp_visual/xenoarch_dust/Initialize(mapload, dust_color, small = TRUE)
	. = ..()
	if(dust_color)
		color = dust_color
	var/matrix/size = matrix()
	if(small)
		size.Scale(0.35)
		size.Translate(rand(-6, 6), rand(-2, 8))
		alpha = 170
	else
		size.Scale(0.8)
	transform = size
	animate(src, alpha = 0, time = duration, easing = EASE_IN)

/**
 * # Find glint
 *
 * A warm glitter over a find the moment the last grit comes off it. tg's shield sparkles, tinted.
 */
/obj/effect/temp_visual/xenoarch_glint
	name = "glint"
	icon = 'icons/effects/effects.dmi'
	icon_state = "shieldsparkles"
	color = "#ffe6a8"
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE
	randomdir = FALSE
	duration = 1.2 SECONDS
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/temp_visual/xenoarch_glint/Initialize(mapload)
	. = ..()
	animate(src, alpha = 0, time = duration, easing = EASE_IN)

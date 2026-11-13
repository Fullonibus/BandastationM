// The seven simple fields of the Sierra anomaly mod.

/// Lightning: strikes everything living around it and burns conductive items to ash. The detector hears its charge.
/obj/effect/anomaly_field/electra
	energy_kind = ARTIFACT_ENERGY_ELECTROMAGNETIC
	name = "электростатическая аномалия"
	icon_state = "electra_idle"
	activation_state = "electra_activation"
	activation_sound = 'modular_bandastation/anomaly_fields/sound/electra_blast.ogg'
	preload_chance = 30
	preload_state = "electra_preload"
	preload_sound = 'modular_bandastation/anomaly_fields/sound/electra_preload.ogg'
	cooldown_min = 5 SECONDS
	cooldown_max = 15 SECONDS
	effect_range = 1
	flash_range = 3
	item_trigger = FIELD_ITEMS_METAL
	idle_loop = /datum/looping_sound/anomaly_field/electra
	artefact_types = list(
		/obj/item/field_artefact/pruzhina = 80,
		/obj/item/field_artefact/svetlyak = 20,
	)
	/// Burn of one strike; insulated gloves do not help.
	var/shock_damage = 40

/obj/effect/anomaly_field/electra/field_effect()
	for(var/mob/living/victim in range(effect_range, src))
		Beam(victim, icon_state = "electra_long", icon = icon, time = 0.3 SECONDS)
		victim.electrocute_act(shock_damage, src, 1, SHOCK_NOGLOVES)
	for(var/obj/item/thing in range(effect_range, src))
		if((thing.obj_flags & CONDUCTS_ELECTRICITY) && anomaly_field_can_affect(thing))
			Beam(thing, icon_state = "electra_long", icon = icon, time = 0.3 SECONDS)
			anomaly_field_ash(thing)

/// Jet of flame: sets everything living around it alight for a few seconds and burns what lies in it.
/obj/effect/anomaly_field/zharka
	energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	name = "пирогенная аномалия"
	icon_state = "zharka_idle"
	activation_state = "zharka_active"
	activation_sound = 'modular_bandastation/anomaly_fields/sound/zharka.ogg'
	cooldown_min = 8 SECONDS
	cooldown_max = 20 SECONDS
	effect_duration = 5 SECONDS
	effect_range = 1
	flash_range = 3
	light_color = LIGHT_COLOR_FIRE
	item_trigger = FIELD_ITEMS_METAL
	artefact_types = list(/obj/item/field_artefact/zjar = 1)
	/// Burn per pulse.
	var/burn_damage = 5

/obj/effect/anomaly_field/zharka/field_effect()
	for(var/mob/living/victim in range(effect_range, src))
		victim.adjust_fire_stacks(2)
		victim.ignite_mob()
		victim.apply_damage(burn_damage, BURN, spread_damage = TRUE)
	for(var/obj/item/thing in loc)
		thing.fire_act(1000, 500)

/**
 * Gravitational funnel: drags the fallen in and pins whoever is at its heart, then rips them and flings
 * everything out. Small items do not wake it.
 */
/obj/effect/anomaly_field/rvach
	energy_kind = ARTIFACT_ENERGY_BLUESPACE
	name = "приливная гравитационная аномалия"
	icon_state = "rvach_idle"
	activation_sound = 'modular_bandastation/anomaly_fields/sound/rvach_activation.ogg'
	cooldown_min = 25 SECONDS
	cooldown_max = 25 SECONDS
	effect_duration = 3.5 SECONDS
	effect_range = 1
	item_trigger = FIELD_ITEMS_ANY
	idle_loop = /datum/looping_sound/anomaly_field/rvach
	artefact_types = list(
		/obj/item/field_artefact/gravi = 1,
		/obj/item/field_artefact/flyer = 2,
	)

/obj/effect/anomaly_field/rvach/is_trigger(atom/movable/thing)
	if(isitem(thing))
		var/obj/item/item = thing
		if(item.w_class < WEIGHT_CLASS_BULKY)
			return FALSE
	return ..()

/obj/effect/anomaly_field/rvach/strike()
	. = ..()
	anomaly_field_warp(loc, 0.3, 0.08, effect_duration)

/obj/effect/anomaly_field/rvach/field_effect()
	for(var/mob/living/victim in range(effect_range, src))
		if(field_artefact_protection(victim) & FIELD_ARTEFACT_ANCHOR)
			continue
		if(victim.loc == loc)
			victim.Knockdown(2 SECONDS)
		else if(victim.body_position == LYING_DOWN && !victim.anchored)
			step_towards(victim, src)
	for(var/obj/item/thing in orange(effect_range, src))
		if(anomaly_field_can_affect(thing))
			step_towards(thing, src)

/obj/effect/anomaly_field/rvach/end_effect()
	anomaly_field_warp(loc, 0.08, 0.6, 0.2 SECONDS)
	for(var/mob/living/victim in loc)
		if(field_artefact_protection(victim) & FIELD_ARTEFACT_ANCHOR)
			continue
		playsound(src, 'modular_bandastation/anomaly_fields/sound/rvach_gibbed.ogg', 100, FALSE)
		if(!iscarbon(victim))
			victim.gib()
			continue
		var/mob/living/carbon/carbon = victim
		var/obj/item/bodypart/limb = carbon.get_bodypart(pick(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		if(!limb?.dismember())
			carbon.apply_damage(40, BRUTE, BODY_ZONE_CHEST)
	for(var/obj/item/thing in loc)
		if(anomaly_field_can_affect(thing))
			qdel(thing)
	for(var/atom/movable/thing in range(effect_range + 1, src))
		if(thing.anchored || (!isliving(thing) && !anomaly_field_throwable(thing)))
			continue
		var/reach = 1
		if(isliving(thing))
			var/protection = field_artefact_protection(thing)
			if(protection & FIELD_ARTEFACT_ANCHOR)
				continue
			if(protection & FIELD_ARTEFACT_LIFT)
				reach = 5
		var/direction = thing.loc == loc ? pick(GLOB.alldirs) : get_dir(src, thing)
		thing.throw_at(get_ranged_target_turf(thing, direction, reach), reach, 2)

/// Springboard: flings whatever touches it a few tiles one way.
/obj/effect/anomaly_field/tramplin
	energy_kind = ARTIFACT_ENERGY_PARTICLE
	name = "репульсивная гравитационная аномалия"
	icon_state = "trampline_idle"
	activation_sound = 'modular_bandastation/anomaly_fields/sound/tramplin.ogg'
	cooldown_min = 3 SECONDS
	cooldown_max = 8 SECONDS
	item_trigger = FIELD_ITEMS_ANY
	/// Where it throws, rolled once.
	var/throw_dir
	/// How far it throws, rolled once.
	var/fling_range

/obj/effect/anomaly_field/tramplin/Initialize(mapload)
	. = ..()
	throw_dir = pick(GLOB.alldirs)
	fling_range = rand(2, 5)

/obj/effect/anomaly_field/tramplin/strike()
	. = ..()
	anomaly_field_warp(loc, 0.05, 0.3, 0.2 SECONDS)

/obj/effect/anomaly_field/tramplin/field_effect()
	for(var/atom/movable/thing in loc)
		if(thing.anchored ||(!isliving(thing) && !anomaly_field_throwable(thing)))
			continue
		var/reach = fling_range
		if(isliving(thing))
			var/mob/living/victim = thing
			var/protection = field_artefact_protection(victim)
			if(protection & FIELD_ARTEFACT_ANCHOR)
				continue
			if(protection & FIELD_ARTEFACT_LIFT)
				reach *= 3
			victim.Knockdown(1 SECONDS)
		thing.throw_at(get_ranged_target_turf(thing, throw_dir, reach), reach, 2)

/// Flash: winds up, then blinds and dazes everyone in sight of it.
/obj/effect/anomaly_field/vspishka
	energy_kind = ARTIFACT_ENERGY_PARTICLE
	name = "фотоимпульсная аномалия"
	icon_state = "vspishka_idle"
	activation_sound = 'modular_bandastation/anomaly_fields/sound/vspishka_activated.ogg'
	preload_chance = 80
	preload_time = 1.5 SECONDS
	preload_sound = 'modular_bandastation/anomaly_fields/sound/vspishka_preload.ogg'
	cooldown_min = 30 SECONDS
	cooldown_max = 75 SECONDS
	effect_range = 5
	flash_range = 6

/obj/effect/anomaly_field/vspishka/field_effect()
	for(var/mob/living/victim in view(effect_range, get_turf(src)))
		if(field_artefact_protection(victim) & FIELD_ARTEFACT_BLINDPROOF)
			continue
		Beam(victim, icon_state = "vspishka_beam", icon = icon, time = 0.3 SECONDS)
		if(victim.flash_act(affect_silicon = TRUE))
			victim.adjust_confusion(5 SECONDS)

/// For half a minute heats or chills everyone around it; the air over it shimmers while it works.
/obj/effect/anomaly_field/thermal
	abstract_type = /obj/effect/anomaly_field/thermal
	cooldown_min = 30 SECONDS
	cooldown_max = 30 SECONDS
	effect_duration = 30 SECONDS
	effect_tick = 1 SECONDS
	effect_range = 2
	/// Body temperature change per pulse.
	var/temperature_step = 0
	/// Shimmer over it while it works.
	var/atom/movable/warp_effect/haze

/obj/effect/anomaly_field/thermal/Destroy()
	QDEL_NULL(haze)
	return ..()

/obj/effect/anomaly_field/thermal/strike()
	. = ..()
	haze = new(loc)
	haze.transform = matrix().Scale(0.45)

/obj/effect/anomaly_field/thermal/end_effect()
	QDEL_NULL(haze)

/obj/effect/anomaly_field/thermal/field_effect()
	for(var/mob/living/victim in range(effect_range, src))
		victim.adjust_bodytemperature(temperature_step, min_temp = 200)

/obj/effect/anomaly_field/thermal/heater
	energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	name = "экзотермическая аномалия"
	temperature_step = 20
	artefact_types = list(/obj/item/field_artefact/zjar = 1)

/obj/effect/anomaly_field/thermal/cooler
	energy_kind = ARTIFACT_ENERGY_SYNTHESIS
	name = "криогенная аномалия"
	temperature_step = -60

/// Whether a field may throw this movable: an item it may affect.
/proc/anomaly_field_throwable(atom/movable/thing)
	return isitem(thing) && anomaly_field_can_affect(thing)

/// The faint hum that gives an idle field away to a careful ear, thin air or not.
/datum/looping_sound/anomaly_field
	volume = 35
	extra_range = -9
	falloff_distance = 4
	pressure_affected = FALSE

/datum/looping_sound/anomaly_field/electra
	mid_sounds = list('modular_bandastation/anomaly_fields/sound/electra_idle.ogg' = 1)
	mid_length = 5.5 SECONDS

/datum/looping_sound/anomaly_field/rvach
	mid_sounds = list('modular_bandastation/anomaly_fields/sound/gravi_idle.ogg' = 1)
	mid_length = 2.6 SECONDS

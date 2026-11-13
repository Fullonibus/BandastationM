/**
 * # Anomaly field
 *
 * A one-tile hazard nobody can see. Something living, or a fitting item, entering its tile sets it off:
 * a field with its own wind-up or activation sprite shows it while it acts, the rest only by their
 * effects; then it sleeps for its cooldown and goes again if something still stands in it. Long fields act every tick for a while; the rest act once. A detector or a thrown bolt finds them.
 * Someone shaking a person caught in a field pulls them out onto their own tile.
 *
 * Adapted from the Sierra anomaly mod (SierraBay12 `mods/anomaly`), rewritten for our codebase.
 */
/obj/effect/anomaly_field
	name = "аномалия"
	icon = 'modular_bandastation/anomaly_fields/icons/fields.dmi'
	icon_state = "any_anomaly"
	abstract_type = /obj/effect/anomaly_field
	anchored = TRUE
	invisibility = INVISIBILITY_OBSERVER
	layer = ABOVE_MOB_LAYER
	light_color = COLOR_WHITE
	/// Icon state while it acts.
	var/activation_state
	/// Sound when it acts.
	var/activation_sound
	/// Chance to be a field that winds up before it acts.
	var/preload_chance = 0
	/// How long the wind-up takes.
	var/preload_time = 1 SECONDS
	/// Icon state during the wind-up.
	var/preload_state
	/// Sound of the wind-up.
	var/preload_sound
	/// Whether this one winds up, rolled once.
	var/needs_preload = FALSE
	/// Cooldown range, rolled once.
	var/cooldown_min = 5 SECONDS
	var/cooldown_max = 5 SECONDS
	/// Cooldown after each activation.
	var/cooldown
	/// How long it keeps acting; zero acts once.
	var/effect_duration = 0
	/// Time between its pulses.
	var/effect_tick = 0.5 SECONDS
	/// Reach of its pulses, in tiles.
	var/effect_range = 0
	/// Light range while it acts; zero gives none.
	var/flash_range = 0
	/// Which items set it off: FIELD_ITEMS_*.
	var/item_trigger = FIELD_ITEMS_IGNORED
	/// Artefacts it can hold, weighted.
	var/list/artefact_types
	/// ARTIFACT_ENERGY_* the anomaly analyser reads off it.
	var/energy_kind = ARTIFACT_ENERGY_PARTICLE
	/// Acting or winding up now.
	var/active = FALSE
	/// When it can act again.
	var/next_ready = 0
	/// When the current activation ends.
	var/effect_ends = 0
	/// Quiet hum it gives off while idle, if any.
	var/datum/looping_sound/idle_loop

/obj/effect/anomaly_field/Initialize(mapload)
	. = ..()
	cooldown = rand(cooldown_min, cooldown_max)
	needs_preload = prob(preload_chance)
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
		COMSIG_ATOM_EXITED = PROC_REF(on_exited),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	if(ispath(idle_loop))
		idle_loop = new idle_loop(src, TRUE)

/obj/effect/anomaly_field/Destroy()
	QDEL_NULL(idle_loop)
	return ..()

/obj/effect/anomaly_field/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(iscarbon(arrived))
		RegisterSignal(arrived, COMSIG_CARBON_PRE_MISC_HELP, PROC_REF(on_rescue), override = TRUE) // A carbon re-entering before Exited ran keeps one registration.
	if(can_trigger(arrived))
		INVOKE_ASYNC(src, PROC_REF(activate))

/obj/effect/anomaly_field/proc/on_exited(datum/source, atom/movable/gone)
	SIGNAL_HANDLER
	if(iscarbon(gone))
		UnregisterSignal(gone, COMSIG_CARBON_PRE_MISC_HELP)

/// A friend shakes someone standing in the field: they are yanked out onto the friend's tile, and both fall.
/obj/effect/anomaly_field/proc/on_rescue(mob/living/carbon/victim, mob/living/carbon/helper)
	SIGNAL_HANDLER
	if(helper.loc == loc || !isturf(helper.loc) || !helper.Adjacent(victim))
		return NONE
	victim.visible_message(
		span_warning("[helper] рывком выдёргивает [victim] на себя!"),
		span_userdanger("[helper] рывком выдёргивает вас на себя!"),
	)
	victim.forceMove(helper.loc)
	victim.Knockdown(2 SECONDS)
	helper.Knockdown(2 SECONDS)
	return COMPONENT_BLOCK_MISC_HELP

/// Whether `thing` would set the field off now.
/obj/effect/anomaly_field/proc/can_trigger(atom/movable/thing)
	if(active || world.time < next_ready)
		return FALSE
	return is_trigger(thing)

/// Whether `thing` is something this field reacts to at all.
/obj/effect/anomaly_field/proc/is_trigger(atom/movable/thing)
	if(isliving(thing))
		var/mob/living/living = thing
		return !(living.movement_type & PHASING)
	if(!isitem(thing) || istype(thing, /obj/item/field_artefact))
		return FALSE
	var/obj/item/item = thing
	switch(item_trigger)
		if(FIELD_ITEMS_ANY)
			return TRUE
		if(FIELD_ITEMS_METAL)
			return !!(item.obj_flags & CONDUCTS_ELECTRICITY)
	return FALSE

/// Sets the field off if it is ready, as when someone grabs at its artefact.
/obj/effect/anomaly_field/proc/provoke()
	if(active || world.time < next_ready)
		return
	INVOKE_ASYNC(src, PROC_REF(activate))

/obj/effect/anomaly_field/proc/activate()
	active = TRUE
	if(needs_preload)
		if(preload_state)
			invisibility = 0
			icon_state = preload_state
		if(preload_sound)
			playsound(src, preload_sound, 100, FALSE)
		addtimer(CALLBACK(src, PROC_REF(strike)), preload_time)
		return
	strike()

/obj/effect/anomaly_field/proc/strike()
	if(activation_state)
		invisibility = 0
		icon_state = activation_state
	else
		invisibility = INVISIBILITY_OBSERVER
		icon_state = initial(icon_state)
	if(activation_sound)
		playsound(src, activation_sound, 100, FALSE)
	if(flash_range)
		set_light(flash_range, 2)
	effect_ends = world.time + effect_duration
	pulse()

/obj/effect/anomaly_field/proc/pulse()
	field_effect()
	if(world.time >= effect_ends)
		addtimer(CALLBACK(src, PROC_REF(finish)), effect_tick)
		return
	addtimer(CALLBACK(src, PROC_REF(pulse)), effect_tick)

/obj/effect/anomaly_field/proc/finish()
	end_effect()
	active = FALSE
	invisibility = INVISIBILITY_OBSERVER
	icon_state = initial(icon_state)
	if(flash_range)
		set_light(0)
	next_ready = world.time + cooldown
	addtimer(CALLBACK(src, PROC_REF(recheck)), cooldown)

/// Goes again straight away while anything that sets it off is still in it.
/obj/effect/anomaly_field/proc/recheck()
	for(var/atom/movable/thing as anything in loc)
		if(can_trigger(thing))
			activate()
			return

/// One pulse of the field's effect.
/obj/effect/anomaly_field/proc/field_effect()
	return

/// Runs once when an activation ends.
/obj/effect/anomaly_field/proc/end_effect()
	return

/// Grows one of its artefacts on its tile, held in place by the field. Returns it, or null.
/obj/effect/anomaly_field/proc/bear_artefact(band)
	if(!length(artefact_types))
		return null
	var/artefact_type = pick_weight(artefact_types)
	var/obj/item/field_artefact/artefact = new artefact_type(loc, band)
	artefact.set_bound(TRUE)
	return artefact

/// Burns a thing on the floor down to ash.
/proc/anomaly_field_ash(obj/item/thing)
	new /obj/effect/decal/cleanable/ash(thing.loc)
	thing.visible_message(span_warning("[thing] рассыпается пеплом!"))
	qdel(thing)

/// Whether a field may destroy or throw this item: not a field artefact, not bolted down, not indestructible.
/proc/anomaly_field_can_affect(obj/item/thing)
	return !thing.anchored && !istype(thing, /obj/item/field_artefact) && !(thing.resistance_flags & INDESTRUCTIBLE)

/// Field protections from the artefacts `victim` carries in hands, pockets and worn slots.
/proc/field_artefact_protection(mob/living/victim)
	. = NONE
	for(var/obj/item/thing in victim.get_equipped_items(INCLUDE_POCKETS | INCLUDE_HELD))
		if(istype(thing, /obj/item/field_artefact))
			var/obj/item/field_artefact/artefact = thing
			. |= artefact.field_protection
		else if(istype(thing, /obj/item/anomaly_resonator))
			var/obj/item/anomaly_resonator/resonator = thing
			. |= resonator.field_protection()

/// Bends the air over `where` from `start_scale` to `end_scale` of a supermatter warp, then fades it out.
/proc/anomaly_field_warp(turf/where, start_scale, end_scale, grow_time, fade_time = 0.2 SECONDS)
	var/atom/movable/warp_effect/warp = new(where)
	warp.transform = matrix().Scale(start_scale)
	animate(warp, transform = matrix().Scale(end_scale), time = grow_time, easing = SINE_EASING)
	animate(alpha = 0, time = fade_time)
	QDEL_IN(warp, grow_time + fade_time)

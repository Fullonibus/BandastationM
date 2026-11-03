/** An independently owned inherited profile incubates only in a supported real habitat. */
/obj/item/phoenix_egg
	name = "яйцо янтарного ткача"
	desc = "Полупрозрачная янтарная оболочка защищает развивающееся членистоногое. Возьмите яйцо в руку и нажмите им на станцию адаптации, чтобы загрузить образец."
	icon = 'icons/mob/simple/lavaland/raptor_baby.dmi'
	icon_state = "raptor_egg"
	color = "#dfad55"
	density = FALSE
	anchored = FALSE
	max_integrity = 30
	w_class = WEIGHT_CLASS_SMALL
	/// Owned inherited profile; adaptation changes this egg alone.
	var/datum/phoenix_strain/strain
	/// Project provenance passed unchanged to the hatchling.
	var/project_id
	/// Natural generation of the hatchling.
	var/generation = 1
	/// Seconds of incubation in reproductive conditions.
	var/growth_seconds = 0
	/// Last diagnosis used between bounded environment scans.
	var/list/last_environment
	/// World time of the next scheduled environment snapshot.
	var/next_environment_check = 0
	/// Registry entry reserves a population slot until hatching or destruction.
	var/datum/weakref/population_reference

/obj/item/phoenix_egg/Initialize(mapload, datum/phoenix_strain/source_strain, project_id, generation = 1)
	strain = source_strain ? source_strain.copy() : new
	src.project_id = project_id
	src.generation = generation
	. = ..()
	population_reference = WEAKREF(src)
	GLOB.phoenix_population += population_reference
	START_PROCESSING(SSobj, src)

/obj/item/phoenix_egg/Destroy()
	STOP_PROCESSING(SSobj, src)
	GLOB.phoenix_population -= population_reference
	population_reference = null
	QDEL_NULL(strain)
	last_environment = null
	return ..()

/** Explicit inspection refreshes the same diagnostic snapshot used by incubation. */
/obj/item/phoenix_egg/proc/assess_environment()
	last_environment = strain.assess_environment(src)
	next_environment_check = world.time + PHOENIX_ENVIRONMENT_SECONDS SECONDS
	return last_environment

/obj/item/phoenix_egg/process(seconds_per_tick)
	if(HAS_TRAIT(src, TRAIT_STASIS) || seconds_per_tick <= 0)
		return
	if(!last_environment || world.time >= next_environment_check)
		assess_environment()
	if(last_environment["state"] == PHOENIX_DANGER)
		take_damage(seconds_per_tick * 0.2, BRUTE)
		return
	if(last_environment["state"] != PHOENIX_BREEDING)
		return
	growth_seconds += seconds_per_tick
	if(growth_seconds < PHOENIX_EGG_SECONDS)
		return
	new /mob/living/basic/phoenix_weaver(drop_location(), strain, project_id, generation)
	visible_message(span_notice("Из [src] вылупляется янтарная личинка."))
	qdel(src)

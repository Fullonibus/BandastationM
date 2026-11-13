/**
 * # Full extraction
 *
 * The harvester can spend an untouched artifact whole and condense it into a TG anomaly core of its
 * main effect's energy kind, for the station's ordinary core uses. The artifact is gone: a harvested
 * one can't be extracted, so a crew chooses between drawing its effect and giving it up for a core.
 * TG's per-round core limits still apply. Our addition on top of Voidcrew PR #506.
 */

/// Energy kind of the main effect -> the TG anomaly core a full extraction yields. Checked against
/// the effects of each kind: organic effects mutate and drain flesh, psionic ones work on the mind,
/// particle ones are mists, gases and radiation.
GLOBAL_LIST_INIT(xenoarch_core_by_energy, list(
	ARTIFACT_ENERGY_CONCENTRATED = /obj/item/assembly/signaler/anomaly/pyro,
	ARTIFACT_ENERGY_PSIONIC = /obj/item/assembly/signaler/anomaly/hallucination,
	ARTIFACT_ENERGY_ELECTROMAGNETIC = /obj/item/assembly/signaler/anomaly/flux,
	ARTIFACT_ENERGY_PARTICLE = /obj/item/assembly/signaler/anomaly/weather,
	ARTIFACT_ENERGY_ORGANIC = /obj/item/assembly/signaler/anomaly/bioscrambler,
	ARTIFACT_ENERGY_BLUESPACE = /obj/item/assembly/signaler/anomaly/bluespace,
	ARTIFACT_ENERGY_SYNTHESIS = /obj/item/assembly/signaler/anomaly/dimensional,
))

/// Condenses the untouched artifact beside it into an anomaly core. Returns the core, or FALSE.
/obj/machinery/artifact_harvester/proc/extract_core(mob/living/user)
	if(drawing)
		return refuse(user, "идёт сбор!")
	if(!is_operational)
		return refuse(user, "нет питания!")
	var/obj/machinery/artifact/source = find_source()
	if(!source?.main_effect)
		return refuse(user, "нечего извлекать!")
	if(source.harvests_left < ARTIFACT_MAX_HARVESTS)
		return refuse(user, "находка уже истощена!")
	var/core_type = GLOB.xenoarch_core_by_energy[source.main_effect.energy_kind]
	if(!SSresearch.is_core_available(core_type))
		return refuse(user, "ядро не стабилизируется!")
	if(!source.try_lock(src))
		return refuse(user, "помехи!")
	SSresearch.increment_existing_anomaly_cores(core_type)
	var/turf/spot = get_turf(source)
	source.journal_note(user, "Полное извлечение: находка переработана в ядро аномалии.")
	log_game("[user ? key_name(user) : "Nobody"] fully extracted artifact [source.serial] ([source.main_effect.log_name]) into [core_type] with [src] at [AREACOORD(src)].")
	source.visible_message(span_notice("[source] тускнеет и сжимается в светящееся ядро."))
	playsound(spot, 'sound/machines/chime.ogg', 40, FALSE)
	var/obj/item/core = new core_type(spot)
	qdel(source)
	return core

/// TG anomaly core -> list(energy kind, effect a harvester pours from it into a battery, spending it).
GLOBAL_LIST_INIT(xenoarch_tg_core_battery, list(
	/obj/item/assembly/signaler/anomaly/pyro = list(ARTIFACT_ENERGY_CONCENTRATED, /datum/artifact_effect/temperature/heat),
	/obj/item/assembly/signaler/anomaly/flux = list(ARTIFACT_ENERGY_ELECTROMAGNETIC, /datum/artifact_effect/tesla),
	/obj/item/assembly/signaler/anomaly/grav = list(ARTIFACT_ENERGY_PARTICLE, /datum/artifact_effect/gravity),
	/obj/item/assembly/signaler/anomaly/bluespace = list(ARTIFACT_ENERGY_BLUESPACE, /datum/artifact_effect/teleport),
	/obj/item/assembly/signaler/anomaly/hallucination = list(ARTIFACT_ENERGY_PSIONIC, /datum/artifact_effect/hallucination),
	/obj/item/assembly/signaler/anomaly/bioscrambler = list(ARTIFACT_ENERGY_ORGANIC, /datum/artifact_effect/bodyhorror),
	/obj/item/assembly/signaler/anomaly/dimensional = list(ARTIFACT_ENERGY_SYNTHESIS, /datum/artifact_effect/gas_vent/air),
	/obj/item/assembly/signaler/anomaly/ectoplasm = list(ARTIFACT_ENERGY_PSIONIC, /datum/artifact_effect/poltergeist),
	/obj/item/assembly/signaler/anomaly/weather = list(ARTIFACT_ENERGY_PARTICLE, /datum/artifact_effect/gas_vent/air),
	/obj/item/assembly/signaler/anomaly/vortex = list(ARTIFACT_ENERGY_BLUESPACE, /datum/artifact_effect/gravity_wave),
))

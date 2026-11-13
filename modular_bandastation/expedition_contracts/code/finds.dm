// Orders for one find from the destination: bring it out where it lies, then catalogue that very find on the station.

/// Whether `site` is a planet that rolled the anomalous zone, where fields and live anomalies grow.
/proc/expedition_site_has_anomaly_zone(datum/stationtrauma_overmap_site/space/planet/site)
	return istype(site) && (/datum/expedition_planet_modifier/anomaly_zone::name in site.modifier_log)

/// Dig a large artifact out on the destination and have it analysed in full.
/datum/expedition_contract/large_find
	name = "Крупная находка"
	research_reward = 300
	credit_reward = 2500

/datum/expedition_contract/large_find/build_steps(datum/stationtrauma_overmap_site/space/site)
	steps += new /datum/expedition_contract_step/recover(/obj/machinery/artifact, "извлечь на раскопках [target_name] крупный артефакт")
	steps += new /datum/expedition_contract_step/catalogue("провести полный анализ этого артефакта на анализаторе станции")

/// Neutralize a live anomaly on the destination and catalogue its core.
/datum/expedition_contract/containment
	name = "Сдерживание аномалии"
	research_reward = 300
	credit_reward = 2000

/datum/expedition_contract/containment/can_target(datum/stationtrauma_overmap_site/space/site)
	return expedition_site_has_anomaly_zone(site)

/datum/expedition_contract/containment/build_steps(datum/stationtrauma_overmap_site/space/site)
	steps += new /datum/expedition_contract_step/recover(/obj/item/assembly/signaler/anomaly/planetary, "нейтрализовать живую аномалию на [target_name] и забрать её ядро")
	steps += new /datum/expedition_contract_step/catalogue("каталогизировать это ядро на сканирующей площадке станции")

/// Take a field artefact out of its field on the destination and catalogue it.
/datum/expedition_contract/field_artefact
	name = "Артефакт поля"
	research_reward = 300
	credit_reward = 2000

/datum/expedition_contract/field_artefact/can_target(datum/stationtrauma_overmap_site/space/site)
	return expedition_site_has_anomaly_zone(site)

/datum/expedition_contract/field_artefact/build_steps(datum/stationtrauma_overmap_site/space/site)
	steps += new /datum/expedition_contract_step/recover(/obj/item/field_artefact, "извлечь коллектором артефакт аномального поля на [target_name]")
	steps += new /datum/expedition_contract_step/catalogue("каталогизировать этот артефакт на сканирующей площадке станции")

/// Draw a core from a boulder on the destination and read it on the spectrometer.
/datum/expedition_contract/core_sample
	name = "Керн"
	research_reward = 200

/datum/expedition_contract/core_sample/build_steps(datum/stationtrauma_overmap_site/space/site)
	steps += new /datum/expedition_contract_step/core_sample(target_name)

/// A find of `find_type` comes out on the destination; it becomes the order's own find.
/datum/expedition_contract_step/recover
	event_signal = COMSIG_GLOB_EXPEDITION_FIND_RECOVERED
	/// What kind of find counts.
	var/find_type

/datum/expedition_contract_step/recover/New(new_find_type, new_text)
	find_type = new_find_type
	text = new_text

/datum/expedition_contract_step/recover/counts(atom/movable/find, atom/location)
	return istype(find, find_type) && expedition_site_id_at(location) == contract.target_id

/datum/expedition_contract_step/recover/counted(atom/movable/find)
	contract.bind(find, src)

/// The order's own find is catalogued.
/datum/expedition_contract_step/catalogue
	event_signal = COMSIG_GLOB_EXPEDITION_FIND_CATALOGUED

/datum/expedition_contract_step/catalogue/New(new_text)
	text = new_text

/datum/expedition_contract_step/catalogue/counts(atom/movable/find, atom/location)
	return find in contract.bound

/**
 * A core drawn on the destination and read on the spectrometer. One step hears both events: a sampler can be
 * knocked empty by hand, and the corps then just draws another core.
 */
/datum/expedition_contract_step/core_sample
	event_signal = COMSIG_GLOB_EXPEDITION_CORE_READ
	/// Event of a core drawn; heard alongside the reading.
	var/taken_signal = COMSIG_GLOB_EXPEDITION_CORE_TAKEN
	/// Labels of cores drawn on the destination.
	var/list/core_serials = list()

/datum/expedition_contract_step/core_sample/New(place)
	text = "отобрать керновым пробоотборником керн из валуна на [place] и прочитать его на спектрометре станции"

/datum/expedition_contract_step/core_sample/activate()
	. = ..()
	RegisterSignal(SSdcs, taken_signal, PROC_REF(on_core_taken))

/datum/expedition_contract_step/core_sample/deactivate()
	. = ..()
	UnregisterSignal(SSdcs, taken_signal)

/datum/expedition_contract_step/core_sample/proc/on_core_taken(datum/source, obj/item/excavation/core_sampler/sampler, mob/user, atom/location)
	SIGNAL_HANDLER
	if(expedition_site_id_at(location) != contract.target_id)
		return
	core_serials |= sampler.sample_serial
	GLOB.expedition_contracts.notify("[contract.summary()]: керн [sampler.sample_serial] засчитан, прочитайте его на спектрометре.")

/datum/expedition_contract_step/core_sample/counts(obj/item/excavation/core_sampler/sampler, atom/location)
	return sampler.sample_serial in core_serials

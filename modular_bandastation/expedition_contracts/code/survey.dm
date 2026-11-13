/// Survey a planet's specimen sources and bring the samples to the station laboratory.
/datum/expedition_contract/survey
	name = "Полевое обследование"
	research_reward = 150

/datum/expedition_contract/survey/build_steps(datum/stationtrauma_overmap_site/space/planet/site)
	// Each planet profile grows one kind of specimen source; the order names it as the crew will see it.
	var/datum/map_generator/expedition_barren/generator_type = site.generator_type
	var/obj/structure/stationtrauma_research_source/source_type = initial(generator_type.source_type)
	var/source_name = initial(source_type.name)
	steps += new /datum/expedition_contract_step/survey_sources(2, source_name, target_name)
	steps += new /datum/expedition_contract_step/analyze_samples(2, target_name)

/// Field surveys of specimen sources on the destination; each source counts once.
/datum/expedition_contract_step/survey_sources
	event_signal = COMSIG_GLOB_EXPEDITION_SOURCE_SURVEYED

/datum/expedition_contract_step/survey_sources/New(amount, source_name, place)
	required = amount
	text = "обследовать стратиграфическим сканером [amount] образца «[source_name]» на [place]"

/datum/expedition_contract_step/survey_sources/counts(datum/stationtrauma_research_record/record, atom/location)
	return record.site_id == contract.target_id

/// Laboratory analysis of samples taken on the destination.
/datum/expedition_contract_step/analyze_samples
	event_signal = COMSIG_GLOB_EXPEDITION_SAMPLE_ANALYZED

/datum/expedition_contract_step/analyze_samples/New(amount, place)
	required = amount
	text = "проанализировать в лаборатории станции [amount] пробы с [place]"

/datum/expedition_contract_step/analyze_samples/counts(datum/stationtrauma_research_record/record, atom/location)
	return record.site_id == contract.target_id

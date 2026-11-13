// Research nodes of Voidcrew PR #506, in our typepath techweb format.

/// The corps' field kit prints from round start: hand tools on an autolathe, the detector, the collector and the specimen crate on a protolathe.
/datum/techweb_node/fundamental_sci/New()
	. = ..()
	unlocked_designs += list(
		/datum/design/xenoarch_kit,
		/datum/design/xenoarch_hammer,
		/datum/design/xenoarch_brush,
		/datum/design/xenoarch_depth_scanner,
		/datum/design/xenoarch_core_sampler,
		/datum/design/xenoarch_find_bag,
		/datum/design/field_bolts,
		/datum/design/field_detector,
		/datum/design/field_collector,
		/datum/design/specimen_crate,
	)

/datum/techweb_node/xenoarchaeology
	display_name = "Ксеноархеология"
	description = "Полевые стабилизаторы и спектрометр проб, чтобы извлекать крупные находки целыми, и лабораторный анализатор с площадкой."
	prerequisite_nodes = list(/datum/techweb_node/fundamental_sci)
	unlocked_designs = list(
		/datum/design/xenoarch_stabiliser,
		/datum/design/board/xenoarch_spectrometer,
		/datum/design/board/artifact_analyser,
		/datum/design/board/artifact_scanpad,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
	experiments_to_unlock = list(/datum/experiment/xenoarch_analysis)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/datum/techweb_node/xenoarch_excavation
	display_name = "Продвинутые раскопки"
	description = "Продвинутый стратиграфический сканер, сразу определяющий нужное стабилизирующее поле, и быстрая кисть."
	prerequisite_nodes = list(/datum/techweb_node/xenoarchaeology)
	unlocked_designs = list(
		/datum/design/xenoarch_scanner_advanced,
		/datum/design/xenoarch_brush_quick,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/// Voidcrew gated this node behind faction standing; here it needs three different dug artifacts analysed.
/datum/techweb_node/xenoarch_exotic_particles
	display_name = "Экзотические частицы"
	description = "Сборщик, вытягивающий пробуждённое излучение крупной находки в батарею, и ручной утилизатор, высвобождающий его снова."
	prerequisite_nodes = list(/datum/techweb_node/xenoarchaeology)
	unlocked_designs = list(
		/datum/design/board/artifact_harvester,
		/datum/design/anomaly_battery,
		/datum/design/anomaly_utilizer,
	)
	required_experiments = list(/datum/experiment/xenoarch_analysis)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)
	experiments_to_unlock = list(/datum/experiment/xenoarch_analysis/five)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/// Belt power from exotic batteries, for corps members bound to it.
/datum/techweb_node/anomalous_energy
	display_name = "Аномальная энергетика"
	description = "Аномальный резонатор: пояс, дающий носителю силу экзотической батареи."
	prerequisite_nodes = list(/datum/techweb_node/xenoarch_exotic_particles)
	unlocked_designs = list(/datum/design/anomaly_resonator)
	required_experiments = list(/datum/experiment/xenoarch_analysis/five)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/// Finds of three different energy kinds studied on the scan pad, from any source.
/datum/experiment/xenoarch_analysis
	name = "Виды аномальной энергии"
	description = "Изучите на сканирующей площадке находки трёх разных видов энергии: крупные артефакты, артефакты аномальных полей или ядра аномалий."
	exp_tag = "Ксеноархеология"
	performance_hint = "Засчитываются первый анализ крупного артефакта и первая каталогизация артефакта поля или ядра."
	/// Different energy kinds required
	var/required = 3
	/// ARTIFACT_ENERGY_* kinds studied so far
	var/list/kinds = list()

/datum/experiment/xenoarch_analysis/is_complete()
	return length(kinds) >= required

/datum/experiment/xenoarch_analysis/check_progress()
	return list(EXPERIMENT_PROG_INT("Изучено видов энергии", length(kinds), required))

/// The same, for five kinds: what Anomalous Energy asks for.
/datum/experiment/xenoarch_analysis/five
	name = "Спектр аномальной энергии"
	description = "Изучите на сканирующей площадке находки пяти разных видов энергии: крупные артефакты, артефакты аномальных полей или ядра аномалий."
	required = 5

/// Counts a newly studied find's energy kind toward the station's open energy experiments.
/proc/xenoarch_record_study(kind)
	if(!kind)
		return
	var/datum/techweb/web = locate(/datum/techweb/science) in SSresearch.techwebs
	for(var/datum/experiment/xenoarch_analysis/experiment in web?.available_experiments)
		experiment.kinds |= kind
		if(experiment.is_complete())
			experiment.finish_experiment(null, web)

/datum/design/specimen_crate
	name = "Ящик для образцов"
	desc = "Мягкий, обшитый свинцом ящик для одной крупной находки."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/structure/closet/crate/specimen
	category = list(RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/board/artifact_analyser
	name = "Плата анализатора артефактов"
	desc = "Печатная плата настольного анализатора артефактов."
	build_path = /obj/item/circuitboard/machine/artifact_analyser
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/artifact_scanpad
	name = "Плата сканирующей площадки"
	desc = "Печатная плата площадки, через которую анализатор считывает находку."
	build_path = /obj/item/circuitboard/machine/artifact_scanpad
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

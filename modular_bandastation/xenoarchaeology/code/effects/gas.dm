// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/gas.dm.
// Voidcrew: oxygen, nitrogen or carbon dioxide only (plasma and nitrous oxide are their own
// effects); room-temperature gas; vents indoors only, never into planet air; stops at a modest
// pressure; no destroy burst. Like the Polaris vents (effects_polaris/plasma_vent.dm) it holds a
// finite reserve, less than one gas contract asks for, shared with any battery drawn off it, so it
// is never a free nitrogen well for gas contracts.

/datum/artifact_effect/gas_vent/air
	label_name = "Выпускает газ"
	log_name = "Gas"
	tier = ARTIFACT_TIER_COMMON
	possible_kinds = list(ARTIFACT_ENERGY_PARTICLE, ARTIFACT_ENERGY_SYNTHESIS)
	harvestable = TRUE
	harmful = FALSE
	reserve_low = 150
	reserve_high = 300

/datum/artifact_effect/gas_vent/air/setup()
	. = ..()
	var/static/list/gas_weights = list(
		/datum/gas/oxygen = 4,
		/datum/gas/nitrogen = 4,
		/datum/gas/carbon_dioxide = 2,
	)
	gas_type = pick_weight(gas_weights)

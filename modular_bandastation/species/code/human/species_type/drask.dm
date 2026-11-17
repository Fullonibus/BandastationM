// Body, eyes and arm-spine sprites by @cluwnya (Discord: t_ch42).

/datum/species/drask
	name = "\improper Драск"
	plural_form = "Драски"
	id = SPECIES_DRASK
	required_donator_level = DONATOR_TIER_2
	inherent_traits = list(TRAIT_MUTANT_COLORS, TRAIT_FIXED_MUTANT_COLORS)
	inherent_biotypes = MOB_ORGANIC | MOB_HUMANOID
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_MAGIC | MIRROR_PRIDE | ERT_SPAWN | RACE_SWAP | SLIME_EXTRACT

	species_language_holder = /datum/language_holder/drask
	mutantbrain = /obj/item/organ/brain/drask
	mutantheart = /obj/item/organ/heart/drask
	mutantlungs = /obj/item/organ/lungs/drask
	mutanteyes = /obj/item/organ/eyes/drask
	mutanttongue = /obj/item/organ/tongue/drask
	mutantliver = /obj/item/organ/liver/drask
	mutant_organs = list(
		/obj/item/organ/thermal_spine/central,
		/obj/item/organ/thermal_spine/arm_l,
		/obj/item/organ/thermal_spine/arm_r,
	)
	exotic_bloodtype = /datum/blood_type/drask
	heatmod = 2
	bodytemp_normal = T0C - 20
	bodytemp_heat_damage_limit = T20C
	bodytemp_cold_damage_limit = BODYTEMP_COLD_DAMAGE_LIMIT - 120

	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/drask,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/drask,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/drask,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/drask,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/drask,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/drask,
	)

/datum/species/drask/prepare_human_for_preview(mob/living/carbon/human/human)
	human.dna.features[FEATURE_DRASK_ARM_SPINES_COLOR] = "#66FFAA"
	human.dna.features[FEATURE_DRASK_SKIN_TONE] = "drask_mid"
	human.dna.features[FEATURE_MUTANT_COLOR] = get_drask_tone_color("drask_mid")
	human.update_body(is_creating = TRUE)

/datum/species/drask/get_features()
	. = ..()
	. |= FEATURE_DRASK_SKIN_TONE

/datum/species/drask/on_species_gain(mob/living/carbon/human/human, datum/species/old_species, pref_load, regenerate_icons = TRUE, replace_missing = TRUE)
	human.dna.features[FEATURE_DRASK_SKIN_TONE] ||= "drask_mid"
	human.dna.features[FEATURE_DRASK_ARM_SPINES_COLOR] ||= "#66FFAA"
	human.dna.features[FEATURE_MUTANT_COLOR] = get_drask_tone_color(human.dna.features[FEATURE_DRASK_SKIN_TONE])
	var/is_new_character = pref_load || !(human.flags_1 & INITIALIZED_1)
	if(is_new_character && human.coretemperature == BODYTEMP_NORMAL && human.bodytemperature == BODYTEMP_NORMAL)
		human.set_coretemperature(bodytemp_normal)
		human.adjust_bodytemperature(bodytemp_normal - human.bodytemperature)
	return ..()

/datum/species/drask/create_pref_unique_perks()
	return list(
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "snowflake",
			SPECIES_PERK_NAME = "Привычка к холоду",
			SPECIES_PERK_DESC = "Тело драска переносит гораздо более низкие температуры. Целые терморегулятор и наросты помогают отводить тепло.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "temperature-high",
			SPECIES_PERK_NAME = "Чувствительность к жаре",
			SPECIES_PERK_DESC = "Драски перегреваются раньше людей и получают больше урона от высокой температуры.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = "heart-pulse",
			SPECIES_PERK_NAME = "Другая анатомия",
			SPECIES_PERK_DESC = "Сердце находится в голове. Для восполнения объёма крови можно использовать криоксадон.",
		),
	)

/datum/species/drask/get_physical_attributes()
	return "Хладнокровные гуманоиды с тремя глазами и светящимися наростами на руках."

/datum/species/drask/get_species_description()
	return "Драски — уроженцы ледяного Урлума, четвёртой планеты системы Оумм. Их города лежат под толщей льда и соединены туннелями и блюспейс-вратами."

/datum/species/drask/get_species_lore()
	return list(
		"Гегемония Маарун выросла из подлёдных городов Урлума. Блюспейс-кристаллы были для неё и важным ресурсом, и святыней.",
		"Скреллианская оккупация оставила глубокий след в истории Урлума. Часть храмов была разрушена, а реликвии вывезены из системы.",
	)

/datum/species/drask/proc/thermal_efficiency(mob/living/carbon/human/human)
	var/obj/item/organ/thermal_spine/central = human.get_organ_slot(ORGAN_SLOT_THERMAL_REGULATOR)
	var/obj/item/organ/thermal_spine/left_spine = human.get_organ_slot(ORGAN_SLOT_ARM_SPINES_L)
	var/obj/item/organ/thermal_spine/right_spine = human.get_organ_slot(ORGAN_SLOT_ARM_SPINES_R)
	var/integrity = (central?.get_thermal_integrity() + left_spine?.get_thermal_integrity() + right_spine?.get_thermal_integrity()) / 3
	return integrity ** 1.356

/datum/species/drask/body_temperature_skin(mob/living/carbon/human/humi, seconds_per_tick)
	var/datum/gas_mixture/environment = humi.loc?.return_air()
	if(!environment || humi.stat == DEAD)
		return ..()
	var/area_temp = humi.get_temperature(environment)
	var/thermal_protection = humi.get_insulation_protection(area_temp)

	var/area_skin_diff = area_temp - humi.bodytemperature
	if(!humi.on_fire || area_skin_diff > 0)
		var/area_skin_change = get_temp_change_amount(area_skin_diff, 0.05 * seconds_per_tick)
		var/sweating = humi.get_body_temp_normal(apply_change = FALSE) + 30 < humi.coretemperature
		var/skin_protection = thermal_protection * (sweating ? 0.7 : 1)
		humi.adjust_bodytemperature((1 - skin_protection) * area_skin_change)

	if(!humi.on_fire)
		var/efficiency = thermal_efficiency(humi)
		var/delta = clamp((area_temp - humi.coretemperature) * (1 - thermal_protection) * (1 - efficiency) * 0.4, -40, 40)
		var/skin_diff = humi.coretemperature + delta - humi.bodytemperature
		humi.adjust_bodytemperature(clamp(get_temp_change_amount(skin_diff, 0.08 * seconds_per_tick), min(0, skin_diff), max(0, skin_diff)))
	// Burning prevents skin cooling, but its heat must still reach the core used for temperature damage.
	var/core_skin_diff = humi.bodytemperature - humi.coretemperature
	humi.adjust_coretemperature(clamp(get_temp_change_amount(core_skin_diff, 0.015 * seconds_per_tick), min(0, core_skin_diff), max(0, core_skin_diff)))

/datum/species/drask/body_temperature_core(mob/living/carbon/human/humi, seconds_per_tick)
	var/datum/gas_mixture/environment = humi.loc?.return_air()
	if(!environment)
		return ..()
	var/area_temp = humi.get_temperature(environment)
	var/thermal_protection = humi.get_insulation_protection(area_temp)
	area_temp = LERP(area_temp, humi.bodytemperature, thermal_protection)
	var/efficiency = thermal_efficiency(humi)
	var/impairment = 1 - efficiency
	var/warm_target = humi.get_body_temp_normal() + 93 * impairment - 26 * impairment ** 2
	var/target_temp
	if(warm_target >= area_temp)
		var/heating_delta = max(134 * efficiency ** 2 - 121 * efficiency + 27, 0)
		target_temp = min(warm_target, area_temp + heating_delta)
	else
		var/cooling_delta = max(80 * efficiency - 40, 0)
		target_temp = max(warm_target, area_temp - cooling_delta)
	var/natural_change = (target_temp - humi.coretemperature) * min(0.06 * seconds_per_tick, 1)
	humi.adjust_coretemperature(humi.metabolism_efficiency * natural_change)

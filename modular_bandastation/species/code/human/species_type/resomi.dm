/// Feathered humanoids from the Resomi colonies.
/datum/species/resomi
	name = "\improper Резоми"
	plural_form = "Резоми"
	id = SPECIES_RESOMI
	required_donator_level = DONATOR_TIER_4
	inherent_traits = list(TRAIT_MUTANT_COLORS)
	changesource_flags = MIRROR_BADMIN | RACE_SWAP

	species_language_holder = /datum/language_holder/resomi
	exotic_bloodtype = /datum/blood_type/resomi
	mutanteyes = /obj/item/organ/eyes/resomi
	mutantlungs = /obj/item/organ/lungs/resomi
	mutantstomach = /obj/item/organ/stomach/resomi
	mutanttongue = /obj/item/organ/tongue/resomi
	mutant_organs = list(
		/obj/item/organ/resomi_crest = /datum/sprite_accessory/resomi_crest/plumage::name,
		/obj/item/organ/tail/resomi,
	)
	body_markings = list(
		/datum/bodypart_overlay/simple/body_marking/resomi = SPRITE_ACCESSORY_NONE,
	)

	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/resomi,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/resomi,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/resomi,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/resomi,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/resomi,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/resomi,
	)

	bodytemp_normal = 314.15
	bodytemp_cold_damage_limit = 180
	bodytemp_heat_damage_limit = 320

	/// Personal action for climbing over tables.
	var/datum/action/innate/resomi_agility/agility
	/// Personal action for listening to nearby movement.
	var/datum/action/cooldown/resomi_listen/listen

/datum/species/resomi/on_species_gain(mob/living/carbon/human/human, datum/species/old_species, pref_load, regenerate_icons = TRUE, replace_missing = TRUE)
	. = ..()
	if(istype(human, /mob/living/carbon/human/dummy))
		return
	agility = new(human)
	agility.Grant(human)
	listen = new(human)
	listen.Grant(human)

/datum/species/resomi/on_species_loss(mob/living/carbon/human/human, datum/species/new_species, pref_load)
	QDEL_NULL(agility)
	QDEL_NULL(listen)
	return ..()

/datum/species/resomi/Destroy()
	QDEL_NULL(agility)
	QDEL_NULL(listen)
	return ..()

/datum/species/resomi/prepare_human_for_preview(mob/living/carbon/human/human)
	human.dna.features[FEATURE_MUTANT_COLOR] = "#505D89"
	human.dna.features[FEATURE_RESOMI_CREST_COLOR] = "#B6C4E7"
	human.set_eye_color("#D3AE52")
	human.update_body(is_creating = TRUE)

/datum/species/resomi/get_physical_attributes()
	return "Невысокие пернатые гуманоиды с когтистыми лапами, подвижным хохолком и хвостом. У них острый слух и глаза, приспособленные к сумеркам."

/datum/species/resomi/get_species_description()
	return "Резоми произошли от стайных хищников холодного мира. Они полагались на слух и ловкость, чтобы подкрасться к добыче и избежать ранений."

/datum/species/resomi/get_species_lore()
	return list(
		"Резоми живут как в собственных колониях, так и среди людей и скреллов. Одни выросли на Эремусе или Асранде, другие — в общинах переселенцев.",
		"В родной речи резоми много свистов и трелей. Их язык называется Schechi.",
	)

/datum/species/resomi/create_pref_unique_perks()
	return list(
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "assistive-listening-systems",
			SPECIES_PERK_NAME = "Прислушаться",
			SPECIES_PERK_DESC = "Резоми могут остановиться и определить, откуда доносится движение поблизости.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "running",
			SPECIES_PERK_NAME = "Проворство",
			SPECIES_PERK_DESC = "Резоми могут включать и выключать возможность проходить через столы.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = "eye",
			SPECIES_PERK_NAME = "Сумеречное зрение",
			SPECIES_PERK_DESC = "Глаза резоми лучше видят в темноте и сильнее реагируют на вспышки.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "drumstick-bite",
			SPECIES_PERK_NAME = "Быстрый обмен веществ",
			SPECIES_PERK_DESC = "Резоми быстрее проголодаются.",
		),
	)

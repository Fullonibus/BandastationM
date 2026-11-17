/// Becoming and leaving Resomi changes the body, languages, and actions together.
/datum/unit_test/resomi_species_roundtrip/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.set_species(/datum/species/resomi)

	TEST_ASSERT_EQUAL(length(human.get_bodyparts()), 6, "Resomi did not receive all six body parts.")
	for(var/obj/item/bodypart/part as anything in human.get_bodyparts())
		TEST_ASSERT_EQUAL(part.limb_id, SPECIES_RESOMI, "Resomi retained a limb from their previous species.")
	TEST_ASSERT(istype(human.get_organ_slot(ORGAN_SLOT_EYES), /obj/item/organ/eyes/resomi), "Resomi did not receive their eyes.")
	TEST_ASSERT(istype(human.get_bloodtype(), /datum/blood_type/resomi), "Resomi did not receive their blood type.")
	TEST_ASSERT(human.has_language(/datum/language/resomi, SPOKEN_LANGUAGE), "Resomi cannot speak Schechi.")

	var/datum/action/innate/resomi_agility/agility = locate() in human.actions
	TEST_ASSERT_NOTNULL(agility, "Resomi did not receive the table action.")
	TEST_ASSERT_NOTNULL(locate(/datum/action/cooldown/resomi_listen) in human.actions, "Resomi did not receive the listening action.")
	TEST_ASSERT(!(human.pass_flags & PASSTABLE), "Resomi can pass tables before toggling agility.")
	TEST_ASSERT(agility.Trigger(human), "Resomi could not toggle agility on.")
	TEST_ASSERT(human.pass_flags & PASSTABLE, "Agility did not enable table passage.")
	TEST_ASSERT(agility.Trigger(human), "Resomi could not toggle agility off.")
	TEST_ASSERT(!(human.pass_flags & PASSTABLE), "Turning agility off left table passage enabled.")
	TEST_ASSERT(agility.Trigger(human), "Resomi could not re-enable agility before changing species.")
	ADD_TRAIT(human, TRAIT_PASSTABLE, TRAIT_SOURCE_UNIT_TESTS)

	human.set_species(/datum/species/human)
	TEST_ASSERT_NULL(locate(/datum/action/innate/resomi_agility) in human.actions, "Human retained the table action.")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/resomi_listen) in human.actions, "Human retained the listening action.")
	TEST_ASSERT(!human.has_language(/datum/language/resomi, SPOKEN_LANGUAGE), "Human retained the Resomi species language.")
	TEST_ASSERT(human.pass_flags & PASSTABLE, "Changing species removed an unrelated source of table passage.")
	REMOVE_TRAIT(human, TRAIT_PASSTABLE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!(human.pass_flags & PASSTABLE), "Human retained table passage from Resomi agility.")

/// The main station and EVA gear must select fitted sprites without affecting other species.
/datum/unit_test/resomi_fitted_clothing/Run()
	var/list/gear = list(
		/obj/item/clothing/under/color/grey = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/under/color/jumpskirt/grey = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/under/rank/engineering/engineer = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/under/rank/medical/doctor = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/under/rank/security/officer = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/under/rank/prisoner = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/under/costume/buttondown/slacks/service = ITEM_SLOT_ICLOTHING,
		/obj/item/clothing/gloves/color/yellow = ITEM_SLOT_GLOVES,
		/obj/item/clothing/gloves/color/black/security = ITEM_SLOT_GLOVES,
		/obj/item/clothing/shoes/workboots = ITEM_SLOT_FEET,
		/obj/item/clothing/shoes/jackboots/sec = ITEM_SLOT_FEET,
		/obj/item/clothing/shoes/sneakers/black = ITEM_SLOT_FEET,
		/obj/item/clothing/mask/gas = ITEM_SLOT_MASK,
		/obj/item/clothing/mask/bandana = ITEM_SLOT_MASK,
		/obj/item/clothing/head/helmet = ITEM_SLOT_HEAD,
		/obj/item/clothing/head/helmet/space/eva = ITEM_SLOT_HEAD,
		/obj/item/clothing/head/beret = ITEM_SLOT_HEAD,
		/obj/item/clothing/head/hooded/winterhood = ITEM_SLOT_HEAD,
		/obj/item/clothing/suit/space/eva = ITEM_SLOT_OCLOTHING,
		/obj/item/clothing/suit/armor/vest/alt = ITEM_SLOT_OCLOTHING,
		/obj/item/clothing/suit/toggle/labcoat = ITEM_SLOT_OCLOTHING,
		/obj/item/clothing/suit/toggle/labcoat/cmo = ITEM_SLOT_OCLOTHING,
		/obj/item/clothing/suit/hooded/wintercoat = ITEM_SLOT_OCLOTHING,
		/obj/item/radio/headset = ITEM_SLOT_EAR_LEFT,
		/obj/item/radio/headset/headset_eng = ITEM_SLOT_EAR_RIGHT,
		/obj/item/storage/backpack = ITEM_SLOT_BACK,
		/obj/item/storage/backpack/duffelbag/engineering = ITEM_SLOT_BACK,
		/obj/item/tank/internals/oxygen = ITEM_SLOT_BACK,
		/obj/item/tank/jetpack/security = ITEM_SLOT_BACK,
		/obj/item/watertank/atmos = ITEM_SLOT_BACK,
		/obj/item/defibrillator = ITEM_SLOT_BACK,
		/obj/item/defibrillator/compact = ITEM_SLOT_BELT,
		/obj/item/storage/belt/utility = ITEM_SLOT_BELT,
		/obj/item/clothing/neck/cloak/cap = ITEM_SLOT_NECK,
		/obj/item/clothing/neck/cloak/ce = ITEM_SLOT_NECK,
		/obj/item/clothing/neck/scarf/zebra = ITEM_SLOT_NECK,
	)
	for(var/item_type in gear)
		var/obj/item/item = allocate(item_type)
		var/state = item.get_worn_icon_state(gear[item_type])
		TEST_ASSERT_NOTNULL(item.get_species_worn_icon(SPECIES_RESOMI, state), "[item_type] has no Resomi sprite for [state].")
		TEST_ASSERT_NULL(item.get_species_worn_icon(SPECIES_RESOMI, "resomi_missing_worn_state"), "[item_type] returned a missing Resomi sprite.")
		TEST_ASSERT_NULL(item.get_species_worn_icon(SPECIES_HUMAN, state), "[item_type] selected a fitted sprite for a human.")

	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT_NOTNULL(uniform.get_species_worn_icon(SPECIES_RESOMI, "jumpsuit_d"), "Rolled Resomi jumpsuit has no fitted sprite.")
	var/obj/item/clothing/under/rank/engineering/engineer/engineering_uniform = allocate(/obj/item/clothing/under/rank/engineering/engineer)
	TEST_ASSERT_NOTNULL(engineering_uniform.get_species_worn_icon(SPECIES_RESOMI, "engine_d"), "Rolled engineering jumpsuit has no fitted sprite.")
	var/obj/item/clothing/head/beanie/beanie = allocate(/obj/item/clothing/head/beanie)
	TEST_ASSERT_NOTNULL(beanie.get_species_worn_icon(SPECIES_RESOMI), "Resomi has no fitted greyscale beanie.")
	TEST_ASSERT_NULL(beanie.get_species_worn_icon(SPECIES_RESOMI, "helmet"), "A greyscale beanie selected an unrelated fitted state.")
	var/obj/item/clothing/shoes/wheelys/skates = allocate(/obj/item/clothing/shoes/wheelys/rollerskates)
	TEST_ASSERT_EQUAL(skates.get_species_worn_icon(SPECIES_RESOMI), 'icons/bandastation/mob/species/resomi/clothing/feet_64.dmi', "Resomi skates lost their 64-pixel anchor.")
	TEST_ASSERT_NOTNULL(skates.get_species_worn_icon(SPECIES_RESOMI, "rollerskates-on"), "Deployed Resomi skates lost their fitted sprite.")
	TEST_ASSERT_NULL(skates.get_species_worn_icon(SPECIES_RESOMI, "workboots"), "Large footwear used a 32-pixel fitted sprite.")

	var/obj/item/clothing/head/utility/hardhat/welding/hardhat = allocate(/obj/item/clothing/head/utility/hardhat/welding)
	var/hat_icon = hardhat.get_species_worn_icon(SPECIES_RESOMI)
	TEST_ASSERT_NOTNULL(hat_icon, "Resomi has no fitted engineering hardhat.")
	TEST_ASSERT_NOTNULL(hardhat.get_species_worn_icon(SPECIES_RESOMI, "hardhat1_yellow"), "The lit hardhat has no fitted sprite.")
	var/list/hat_overlays = hardhat.worn_overlays(mutable_appearance(hat_icon, hardhat.icon_state), FALSE, hat_icon)
	var/mutable_appearance/visor = locate() in hat_overlays
	TEST_ASSERT_NOTNULL(visor, "The welding hardhat lost its lowered visor.")
	TEST_ASSERT_EQUAL(visor.icon, hat_icon, "The lowered visor uses the human sprite.")

	var/obj/item/clothing/mask/gas/atmos/atmos_mask = allocate(/obj/item/clothing/mask/gas/atmos)
	var/atmos_icon = atmos_mask.get_species_worn_icon(SPECIES_RESOMI)
	TEST_ASSERT_NOTNULL(atmos_icon, "Resomi has no fitted atmospheric mask.")
	var/datum/component/clothing_dirt/dirt = atmos_mask.GetComponent(/datum/component/clothing_dirt)
	dirt.dirtiness = 1
	var/list/dirt_overlays = atmos_mask.separate_worn_overlays(null, null, FALSE, atmos_icon)
	var/mutable_appearance/mask_dirt = locate() in dirt_overlays
	TEST_ASSERT_NOTNULL(mask_dirt, "The dirty atmospheric mask lost its worn dirt overlay.")
	TEST_ASSERT_EQUAL(mask_dirt.icon, atmos_icon, "Dirt on a fitted mask used the human sprite.")

	var/mob/living/carbon/human/resomi = allocate(/mob/living/carbon/human/dummy/consistent)
	resomi.set_species(/datum/species/resomi)
	resomi.dna.species.prepare_human_for_preview(resomi)
	var/obj/item/clothing/glasses/sunglasses/glasses = allocate(/obj/item/clothing/glasses/sunglasses)
	TEST_ASSERT(resomi.equip_to_slot_if_possible(glasses, ITEM_SLOT_EYES), "Resomi could not wear fitted sunglasses.")
	var/fitted_icon = glasses.get_species_worn_icon(SPECIES_RESOMI, glasses.get_worn_icon_state(ITEM_SLOT_EYES))
	TEST_ASSERT_NOTNULL(fitted_icon, "Resomi has no fitted sunglasses sprite.")
	var/mutable_appearance/worn = resomi.overlays_standing[GLASSES_LAYER]
	TEST_ASSERT_NOTNULL(worn, "Resomi sunglasses produced no worn overlay.")
	TEST_ASSERT_EQUAL(worn.icon, fitted_icon, "Resomi did not render fitted sunglasses.")
	var/mutable_appearance/fitted = glasses.build_worn_icon(default_layer = GLASSES_LAYER, override_file = fitted_icon, bodyshape = resomi.bodyshape, slot_id = ITEM_SLOT_EYES)
	resomi.apply_height(fitted, UPPER_BODY)
	TEST_ASSERT_EQUAL(worn.pixel_z, fitted.pixel_z, "Fitted sunglasses were shifted by the human-sprite fallback offset.")

	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	resomi.setDir(SOUTH)
	TEST_ASSERT(resomi.put_in_hand(wrench, 1), "Resomi could not hold the wrench.")
	var/list/held = resomi.get_held_overlays()
	var/mutable_appearance/grip = held[1]
	var/mutable_appearance/native_grip = wrench.build_worn_icon(default_layer = HANDS_LAYER, default_icon_file = wrench.lefthand_file, isinhands = TRUE, bodyshape = resomi.bodyshape)
	resomi.apply_height(native_grip, LOWER_BODY)
	TEST_ASSERT_EQUAL(grip.pixel_z, native_grip.pixel_z - 2, "Held items were not lowered to the Resomi hand.")
	TEST_ASSERT_EQUAL(grip.pixel_w, native_grip.pixel_w - 1, "Held items were not moved to the Resomi hand.")

	resomi.equipOutfit(/datum/outfit/job/engineer, visuals_only = TRUE)
	test_screenshot("engineer", get_flat_icon_for_all_directions(resomi))

	var/mob/living/carbon/human/eva_resomi = allocate(/mob/living/carbon/human/dummy/consistent)
	eva_resomi.set_species(/datum/species/resomi)
	eva_resomi.dna.species.prepare_human_for_preview(eva_resomi)
	eva_resomi.equip_to_slot_or_del(allocate(/obj/item/clothing/suit/space/eva), ITEM_SLOT_OCLOTHING)
	eva_resomi.equip_to_slot_or_del(allocate(/obj/item/clothing/head/helmet/space/eva), ITEM_SLOT_HEAD)
	test_screenshot("eva", get_flat_icon_for_all_directions(eva_resomi))

	var/obj/item/tank/internals/emergency_oxygen/emergency_tank = allocate(/obj/item/tank/internals/emergency_oxygen)
	TEST_ASSERT(eva_resomi.equip_to_slot_if_possible(emergency_tank, ITEM_SLOT_SUITSTORE), "Resomi could not carry an emergency tank in the EVA suit slot.")
	var/mutable_appearance/stored_tank = eva_resomi.overlays_standing[SUIT_STORE_LAYER]
	TEST_ASSERT_NOTNULL(stored_tank, "The emergency tank produced no suit storage overlay.")
	TEST_ASSERT_EQUAL(stored_tank.icon, 'icons/bandastation/mob/species/resomi/clothing/belt_mirror.dmi', "Suit storage used the belt-side sprite for an emergency tank.")
	TEST_ASSERT_NULL(emergency_tank.get_species_worn_icon(SPECIES_HUMAN, slot_id = ITEM_SLOT_SUITSTORE), "Human suit storage used a Resomi sprite.")
	var/obj/item/tank/internals/oxygen/oxygen_tank = allocate(/obj/item/tank/internals/oxygen)
	TEST_ASSERT_EQUAL(oxygen_tank.get_species_worn_icon(SPECIES_RESOMI, slot_id = ITEM_SLOT_SUITSTORE), 'icons/bandastation/mob/species/resomi/clothing/back.dmi', "Suit storage did not honor the full-size tank's own sprite sheet.")

	var/obj/item/mod/control/pre_equipped/engineering/mod = allocate(/obj/item/mod/control/pre_equipped/engineering)
	TEST_ASSERT(eva_resomi.equip_to_slot_if_possible(mod, ITEM_SLOT_BACK), "Resomi could not wear the standard engineering MOD.")
	var/mutable_appearance/mod_overlay = eva_resomi.overlays_standing[BACK_LAYER]
	TEST_ASSERT_NOTNULL(mod_overlay, "The engineering MOD did not produce a back overlay.")
	TEST_ASSERT_NOTEQUAL(mod_overlay.icon, mod.worn_icon, "The engineering MOD did not use a fitted back sprite.")

/// Exercise both styles and recoloring through the worn uniform layer.
/datum/unit_test/resomi_seifuku/Run()
	var/mob/living/carbon/human/resomi = allocate(/mob/living/carbon/human/dummy/consistent)
	resomi.set_species(/datum/species/resomi)
	resomi.dna.species.prepare_human_for_preview(resomi)
	var/obj/item/clothing/under/costume/seifuku/uniform = allocate(/obj/item/clothing/under/costume/seifuku)
	TEST_ASSERT(resomi.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Resomi could not wear the school uniform.")
	var/native_icon = uniform.worn_icon
	for(var/style in list("normal", "adjusted", "recolored"))
		if(style != "normal")
			uniform.rolldown()
		if(style == "recolored")
			uniform.set_greyscale(list("#3F4453", "#BB2E2E", "#EBEBEB"))
			uniform.update_slot_icon()
		var/expected_state = style == "adjusted" ? "seifuku_d" : "seifuku"
		var/mutable_appearance/worn = resomi.overlays_standing[UNIFORM_LAYER]
		TEST_ASSERT_NOTNULL(worn, "School uniform produced no worn overlay.")
		TEST_ASSERT_EQUAL(worn.icon_state, expected_state, "School uniform lost its current worn style.")
		TEST_ASSERT_NOTEQUAL(worn.icon, native_icon, "Resomi used the regular uniform sheet.")
		TEST_ASSERT_EQUAL(worn.icon, SSgreyscale.GetColoredIconByType(/datum/greyscale_config/seifuku/worn/resomi, uniform.greyscale_colors), "School uniform lost its Resomi fit or chosen colors.")
		test_screenshot(style, get_flat_icon_for_all_directions(resomi))

/// Wearing, removing and transferring underclothes preserves the item and uses the wearer's fit.
/datum/unit_test/resomi_underclothing/Run()
	var/mob/living/carbon/human/resomi = allocate(/mob/living/carbon/human/consistent)
	resomi.set_species(/datum/species/resomi)
	resomi.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs::name
	resomi.underwear_color = "#34ab56"
	resomi.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra::name
	resomi.socks = /datum/sprite_accessory/clothing/socks/black_knee::name
	resomi.dna.species.prepare_human_for_preview(resomi)

	var/list/worn = resomi.get_underwear_overlays()
	TEST_ASSERT_EQUAL(length(worn), 3, "Resomi did not render all three underclothing slots.")
	for(var/mutable_appearance/overlay as anything in worn)
		TEST_ASSERT_EQUAL(overlay.icon, 'icons/bandastation/mob/species/resomi/clothing/underwear.dmi', "Resomi used a human underclothing sprite.")
	var/mutable_appearance/briefs = worn[1]
	TEST_ASSERT_EQUAL(LOWER_TEXT(briefs.color), "#34ab56", "Fitted underwear lost its selected color.")
	test_screenshot("fitted", get_flat_icon_for_all_directions(resomi))

	var/obj/item/clothing/underwear/garment = resomi.w_underwear
	TEST_ASSERT_NOTNULL(garment, "The fitted underwear did not create a physical garment.")
	TEST_ASSERT(resomi.dropItemToGround(garment), "Resomi could not remove the fitted underwear.")
	TEST_ASSERT_EQUAL(length(resomi.get_underwear_overlays()), 2, "Removing underwear left its fitted sprite on the wearer.")
	TEST_ASSERT_EQUAL(garment.icon, 'icons/mob/clothing/underwear.dmi', "The loose garment inherited the Resomi fit.")

	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.underwear = /datum/sprite_accessory/clothing/underwear/nude::name
	recipient.undershirt = /datum/sprite_accessory/clothing/undershirt/nude::name
	recipient.socks = /datum/sprite_accessory/clothing/socks/nude::name
	recipient.update_body()
	TEST_ASSERT(recipient.equip_to_slot_if_possible(garment, ITEM_SLOT_UNDERWEAR), "A human could not put on the same garment.")
	var/list/recipient_overlays = recipient.get_underwear_overlays()
	TEST_ASSERT_EQUAL(length(recipient_overlays), 1, "The recipient did not render the transferred underwear.")
	var/mutable_appearance/transferred = recipient_overlays[1]
	TEST_ASSERT_EQUAL(transferred.icon, 'icons/mob/clothing/underwear.dmi', "The recipient rendered the Resomi fit.")
	TEST_ASSERT_EQUAL(recipient.underwear_color, "#34ab56", "Transferring underwear changed its color.")

	resomi.underwear = /datum/sprite_accessory/clothing/underwear/male_hearts::name
	resomi.update_body()
	var/list/patterned_overlays = resomi.get_underwear_overlays()
	var/mutable_appearance/patterned = patterned_overlays[1]
	TEST_ASSERT_EQUAL(patterned.icon, 'icons/bandastation/mob/species/resomi/clothing/underwear.dmi', "Patterned underwear lost its fitted sprite.")
	TEST_ASSERT_NULL(patterned.color, "Patterned underwear received a tint over its original colors.")

/// Wound, burn and husk effects follow the fitted limb shape.
/datum/unit_test/resomi_damage_appearance/Run()
	var/mob/living/carbon/human/resomi = allocate(/mob/living/carbon/human/consistent)
	resomi.set_species(/datum/species/resomi)
	resomi.dna.species.prepare_human_for_preview(resomi)
	var/obj/item/bodypart/chest/chest = resomi.get_bodypart(BODY_ZONE_CHEST)
	chest.receive_damage(chest.max_damage / 4, chest.max_damage / 4, wound_bonus = CANT_WOUND)
	var/list/damage = chest.get_bodypart_damage_state()
	TEST_ASSERT_EQUAL(length(damage), 3, "Resomi chest did not generate blood, wound and burn overlays.")
	var/fitted_sheet = 'icons/bandastation/mob/species/resomi/damage.dmi'
	for(var/mutable_appearance/effect as anything in damage)
		TEST_ASSERT_EQUAL(effect.icon, fitted_sheet, "Damaged Resomi chest used an unfitted effect.")
		TEST_ASSERT(icon_exists(effect.icon, effect.icon_state), "Damaged Resomi chest selected a missing effect.")
	test_screenshot("damaged", get_flat_icon_for_all_directions(resomi))

	TEST_ASSERT(resomi.become_husk(TRAIT_SOURCE_UNIT_TESTS), "Could not husk the Resomi fixture.")
	resomi.update_body()
	var/found_husk = FALSE
	for(var/image/effect as anything in chest.get_limb_icon())
		if(effect.icon_state != "resomi_husk_chest")
			continue
		TEST_ASSERT_EQUAL(effect.icon, fitted_sheet, "Husked Resomi chest used an unfitted effect.")
		found_husk = TRUE
	TEST_ASSERT(found_husk, "Husked Resomi chest did not generate its fitted layer.")
	test_screenshot("husk", get_flat_icon_for_all_directions(resomi))

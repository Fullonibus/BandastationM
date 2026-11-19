#define CHECK_OUTFIT_SLOT(outfit_key, slot_name) if (outfit.##outfit_key) { \
	H.equip_to_slot_or_del(new outfit.##outfit_key(H), ##slot_name, TRUE); \
	/* We don't check the result of equip_to_slot_or_del because it returns false for random jumpsuits, as they delete themselves on init */ \
	var/obj/item/outfit_item = H.get_item_by_slot(##slot_name); \
	if (!outfit_item) { \
		TEST_FAIL("[outfit.name]'s [#outfit_key] is invalid! Could not equip a [outfit.##outfit_key] into that slot."); \
	} \
	else { \
		outfit_item.on_outfit_equip(H, FALSE, ##slot_name); \
	} \
}

/// See #66313 and #60901. outfit_sanity used to runtime whenever you had two mergable sheets in either hand. Previously, this only had a 3% chance of occuring. Now 100%.
/datum/outfit/stacks_in_hands
	name = "Mr. Runtime"

	uniform = /obj/item/clothing/under/suit/tuxedo
	glasses = /obj/item/clothing/glasses/sunglasses
	mask = /obj/item/cigarette/cigar/havana
	shoes = /obj/item/clothing/shoes/laceup
	l_hand = /obj/item/stack/spacecash/c1000
	r_hand = /obj/item/stack/spacecash/c1000

/// outfit_sanity needs to cover insertions into duffelbags
/datum/outfit/duffel_user
	name = "Mr. Runtime"
	back = /obj/item/storage/backpack/duffelbag
	backpack_contents = list(/obj/item/cigarette/cigar/havana)

/// Satchels too
/datum/outfit/stachel_user
	name = "Mr. Runtime"
	back = /obj/item/storage/backpack/satchel
	backpack_contents = list(/obj/item/cigarette/cigar/havana)

/// And just in case we'll check backpacks
/datum/outfit/backpack_user
	name = "Mr. Runtime"
	back = /obj/item/storage/backpack
	backpack_contents = list(/obj/item/cigarette/cigar/havana)

/datum/unit_test/outfit_sanity/Run()
	var/datum/outfit/prototype_outfit = /datum/outfit
	var/prototype_name = initial(prototype_outfit.name)
	var/mob/living/carbon/human/H = allocate(/mob/living/carbon/human/consistent)

	var/list/outfits_to_check = subtypesof(/datum/outfit)
	outfits_to_check -= typesof(/datum/outfit/deathmatch_loadout)

	for (var/outfit_type in outfits_to_check)
		// Only make one human and keep undressing it because it's much faster
		for (var/obj/item/I in H.get_equipped_items(INCLUDE_POCKETS|INCLUDE_ABSTRACT))
			qdel(I)

		var/datum/outfit/outfit = new outfit_type

		if(outfit.name == prototype_name)
			TEST_FAIL("[outfit.type]'s name is invalid! Uses default outfit name!")
		outfit.pre_equip(H, TRUE)

		CHECK_OUTFIT_SLOT(uniform, ITEM_SLOT_ICLOTHING)
		CHECK_OUTFIT_SLOT(suit, ITEM_SLOT_OCLOTHING)
		CHECK_OUTFIT_SLOT(belt, ITEM_SLOT_BELT)
		CHECK_OUTFIT_SLOT(gloves, ITEM_SLOT_GLOVES)
		CHECK_OUTFIT_SLOT(shoes, ITEM_SLOT_FEET)
		CHECK_OUTFIT_SLOT(head, ITEM_SLOT_HEAD)
		CHECK_OUTFIT_SLOT(mask, ITEM_SLOT_MASK)
		CHECK_OUTFIT_SLOT(neck, ITEM_SLOT_NECK)
		// AI EDIT START - Dual ear slots
		// BANDASTATION EDIT START - Dual ear slots
		CHECK_OUTFIT_SLOT(ear_right, ITEM_SLOT_EAR_RIGHT)
		CHECK_OUTFIT_SLOT(ear_left, ITEM_SLOT_EAR_LEFT)
		// BANDASTATION EDIT END
		// AI EDIT END
		CHECK_OUTFIT_SLOT(glasses, ITEM_SLOT_EYES)
		CHECK_OUTFIT_SLOT(back, ITEM_SLOT_BACK)
		CHECK_OUTFIT_SLOT(id, ITEM_SLOT_ID)
		CHECK_OUTFIT_SLOT(l_pocket, ITEM_SLOT_LPOCKET)
		CHECK_OUTFIT_SLOT(r_pocket, ITEM_SLOT_RPOCKET)
		CHECK_OUTFIT_SLOT(suit_store, ITEM_SLOT_SUITSTORE)
		if (outfit.backpack_contents || outfit.box)
			var/list/backpack_contents = outfit.backpack_contents?.Copy()
			if (outfit.box)
				if (!backpack_contents)
					backpack_contents = list()
				backpack_contents.Insert(1, outfit.box)
				backpack_contents[outfit.box] = 1

			for (var/path in backpack_contents)
				var/number = backpack_contents[path] || 1
				for (var/_ in 1 to number)
					if (!H.equip_to_storage(new path(H), ITEM_SLOT_BACK, indirect_action = TRUE, del_on_fail = TRUE))
						TEST_FAIL("[outfit.name]'s backpack_contents are invalid! Couldn't add [path] to backpack.")

		if (outfit.belt_contents)
			var/list/belt_contents = outfit.belt_contents?.Copy()
			for (var/path in belt_contents)
				var/number = belt_contents[path] || 1
				for (var/_ in 1 to number)
					if (!H.equip_to_storage(new path(H), ITEM_SLOT_BELT, indirect_action = TRUE, del_on_fail = TRUE))
						TEST_FAIL("[outfit.name]'s belt_contents are invalid! Couldn't add [path] to backpack.")


#undef CHECK_OUTFIT_SLOT


/// The subtype default must not opt outfits saved before conditioning into the new trait.
/datum/unit_test/outfit_conditioning_import/Run()
	var/datum/outfit/outfit = allocate(/datum/outfit/centcom/ert/security)
	var/list/saved_outfit = list("name" = "Legacy ERT Outfit")
	TEST_ASSERT(outfit.load_from(saved_outfit), "The legacy outfit failed to load.")
	TEST_ASSERT(!outfit.mental_conditioning, "The legacy outfit acquired conditioning from its subtype's default.")

	saved_outfit["mental_conditioning"] = TRUE
	TEST_ASSERT(outfit.load_from(saved_outfit), "The outfit with explicit conditioning failed to load.")
	TEST_ASSERT(outfit.mental_conditioning, "The explicitly saved conditioning setting was not restored.")

/// A custom outfit retains container quantities and implants after a save and load.
/datum/unit_test/custom_outfit_storage/Run()
	var/datum/outfit/source = allocate(/datum/outfit)
	source.uniform = /obj/item/clothing/under/color/grey
	source.back = /obj/item/storage/backpack
	source.belt = /obj/item/storage/belt/utility
	source.box = /obj/item/storage/box
	source.backpack_contents = list(/obj/item/pen = 2)
	source.belt_contents = list(/obj/item/screwdriver = 2)
	source.implants = list(/obj/item/implant/mindshield)
	source.box_contents = list(/obj/item/paper = 2)
	var/list/saved_outfit = source.get_json_data()

	var/datum/outfit/restored = allocate(/datum/outfit)
	TEST_ASSERT(restored.load_from(json_decode(json_encode(saved_outfit))), "The exported outfit couldn't be loaded.")
	TEST_ASSERT_EQUAL(restored.belt_contents[/obj/item/screwdriver], 2, "The belt item type or quantity was lost on load.")

	// The same stored outfit can be equipped more than once.
	for(var/attempt in 1 to 2)
		var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
		TEST_ASSERT(human.equipOutfit(restored), "The restored outfit couldn't be equipped.")
		TEST_ASSERT_NOTNULL(human.back, "The outfit didn't equip a backpack.")
		TEST_ASSERT_EQUAL(length(human.back.contents), 3, "The backpack should have two pens and one box.")
		TEST_ASSERT_NOTNULL(human.belt, "The outfit didn't equip a belt.")
		TEST_ASSERT_EQUAL(length(human.belt.contents), 2, "The belt should have two screwdrivers.")
		var/obj/item/storage/box/box = locate(/obj/item/storage/box) in human.back
		TEST_ASSERT_NOTNULL(box, "The backpack should contain a box.")
		TEST_ASSERT_EQUAL(length(box.contents), 2, "The box should have two sheets of paper.")
		TEST_ASSERT(locate(/obj/item/implant/mindshield) in human.implants, "The mindshield implant was lost.")

	// Old exports could include a flat belt array and a generated box in the backpack list.
	saved_outfit.Remove("box_contents")
	saved_outfit["belt_contents"] = list("/obj/item/screwdriver", "/obj/item/screwdriver")
	saved_outfit["backpack_contents"] = list(/obj/item/storage/box = 1, /obj/item/pen = 2)
	TEST_ASSERT(restored.load_from(json_decode(json_encode(saved_outfit))), "A legacy outfit couldn't be loaded.")
	TEST_ASSERT_EQUAL(restored.belt_contents[/obj/item/screwdriver], 2, "The legacy belt array lost an item or its type.")
	TEST_ASSERT_EQUAL(restored.box, /obj/item/storage/box, "The legacy outfit lost the selected box.")
	TEST_ASSERT(!(/obj/item/storage/box in restored.backpack_contents), "The legacy outfit kept a duplicate of the selected box.")

/// Fitting uses real slot and container rules and reports what did not make it onto the mannequin.
/datum/unit_test/outfit_fitting/Run()
	var/datum/outfit/outfit = allocate(/datum/outfit)
	outfit.head = /obj/item/wrench
	outfit.back = /obj/item/storage/backpack
	outfit.belt = /obj/item/storage/belt/utility
	outfit.belt_contents = list(/obj/item/screwdriver = 2)
	outfit.box = /obj/item/storage/box
	outfit.box_contents = list(/obj/item/paper = 12, /obj/item/pen = 1)
	outfit.backpack_contents = list(/obj/item/disk/nuclear = 1, /obj/item/shrapnel = 1)

	var/mob/living/carbon/human/dummy/outfit_check/body = allocate(/mob/living/carbon/human/dummy/outfit_check)
	outfit.equip_items(body, TRUE, body)

	TEST_ASSERT_NULL(body.head, "The wrench should not equip as headwear.")
	TEST_ASSERT_NULL(body.belt, "The belt should not equip without a uniform.")
	TEST_ASSERT_NOTNULL(body.back, "The compatible backpack should still equip.")
	var/obj/item/disk/nuclear/disk = locate() in body.back
	TEST_ASSERT_NOTNULL(disk, "Fitting should keep the disk in the mannequin's backpack.")
	TEST_ASSERT_NULL(disk.GetComponent(/datum/component/stationloving), "The preview disk must not register live station relocation.")
	TEST_ASSERT_NULL(locate(/obj/item/shrapnel) in body.back, "The shrapnel should disappear on transfer.")
	var/obj/item/storage/box/box = locate() in body.back
	TEST_ASSERT_NOTNULL(box, "The box should go inside the backpack.")
	TEST_ASSERT_EQUAL(length(box.contents), 7, "The box should contain the copies that actually fit.")

	var/list/failures = list()
	for(var/key in body.outfit_issues)
		var/list/issue = body.outfit_issues[key]
		failures[issue["path"]] = issue
	TEST_ASSERT_EQUAL(length(body.outfit_issues), 6, "Expected separate failures for each rejected item and no split reason for the paper.")
	var/list/head_failure = failures["/obj/item/wrench"]
	TEST_ASSERT_EQUAL(head_failure?["reason"], "Предмет не подходит для этого слота.", "Expected a slot incompatibility reason.")
	var/list/shrapnel_failure = failures["/obj/item/shrapnel"]
	TEST_ASSERT_EQUAL(shrapnel_failure?["reason"], "Предмет не остался в контейнере после переноса.", "A disappearing item must not report a successful insertion.")
	var/list/belt_failure = failures["/obj/item/storage/belt/utility"]
	TEST_ASSERT_EQUAL(belt_failure?["reason"], "Сначала нужно надеть форму.", "Expected the uniform requirement.")
	var/list/belt_contents_failure = failures["/obj/item/screwdriver"]
	TEST_ASSERT_EQUAL(belt_contents_failure?["reason"], "Контейнер не надет.", "Expected the missing destination to be explained.")
	TEST_ASSERT_EQUAL(belt_contents_failure?["count"], 2, "Repeated failures should be counted together.")
	var/list/box_failure = failures["/obj/item/paper"]
	TEST_ASSERT_EQUAL(box_failure?["count"], 5, "Only the copies outside the box limit should fail.")
	TEST_ASSERT_EQUAL(box_failure?["reason"], "В контейнере закончились свободные ячейки.", "The copies that could not fit should report the actual capacity constraint.")
	var/list/pen_failure = failures["/obj/item/pen"]
	TEST_ASSERT_EQUAL(pen_failure?["count"], 1, "The report should show the actual storage rejection after the box fills.")

	outfit.uniform = /obj/item/clothing/under/color/grey
	outfit.head = null
	outfit.backpack_contents = list(/obj/item/stack/sheet/iron = 2)
	outfit.box_contents = list(/obj/item/paper = 2)
	var/mob/living/carbon/human/dummy/outfit_check/second_body = allocate(/mob/living/carbon/human/dummy/outfit_check)
	outfit.equip_items(second_body, TRUE, second_body)
	TEST_ASSERT_EQUAL(length(second_body.outfit_issues), 0, "A fresh fitting should accept a compatible outfit.")
	TEST_ASSERT_NOTNULL(second_body.belt, "The belt should equip with a uniform.")
	TEST_ASSERT_EQUAL(length(second_body.belt.contents), 2, "The accepted belt contents should actually be inserted.")
	var/obj/item/stack/sheet/iron/fitted_stack = locate() in second_body.back
	TEST_ASSERT_EQUAL(fitted_stack?.get_amount(), 2, "A stack merged during fitting must count as inserted.")

	var/mob/living/carbon/human/dummy/regular_preview = allocate(/mob/living/carbon/human/dummy)
	regular_preview.equipOutfit(outfit, visuals_only = TRUE)
	TEST_ASSERT_NOTNULL(regular_preview.back, "A visual preview still equips its backpack.")
	TEST_ASSERT_EQUAL(length(regular_preview.back.contents), 0, "The normal visual preview should still skip container contents.")

	outfit.box_contents = list(/obj/item/storage/backpack = 12)
	var/mob/living/carbon/human/dummy/outfit_check/oversize_body = allocate(/mob/living/carbon/human/dummy/outfit_check)
	outfit.equip_items(oversize_body, TRUE, oversize_body)
	TEST_ASSERT_EQUAL(length(oversize_body.outfit_issues), 1, "An empty box should consistently reject oversized copies for the same reason.")
	var/list/oversize_failure = oversize_body.outfit_issues[oversize_body.outfit_issues[1]]
	TEST_ASSERT_EQUAL(oversize_failure["reason"], "Предмет слишком большой для этого контейнера.", "Size failures do not mean the box ran out of slots.")
	TEST_ASSERT_EQUAL(oversize_failure["count"], 12, "All oversized copies should be accounted for.")

/datum/unit_test/saved_outfit_copy/Run()
	var/datum/outfit/varedit/original = allocate(/datum/outfit/varedit)
	original.name = "Event outfit"
	original.mental_conditioning = TRUE
	original.backpack_contents = list(/obj/item/wrench = 2)
	original.belt_contents = list(/obj/item/screwdriver = 3)
	original.box_contents = list(/obj/item/paper = 4)
	original.implants = list(/obj/item/implant/tracking)
	original.organs = list(/obj/item/organ/heart)
	original.stored_access = list(ACCESS_ENGINEERING)
	original.update_id_name = TRUE
	var/icon/custom_icon = icon('icons/obj/tools.dmi')
	original.vv_values = list("LHAND" = list("name" = "Custom tool", "icon" = custom_icon))

	var/datum/outfit/varedit/copied = original.duplicate()
	allocated += copied
	TEST_ASSERT(istype(copied), "The copy should preserve the VV outfit subtype.")
	TEST_ASSERT_EQUAL(copied.name, "Event outfit (copy)", "The draft should have a distinct default name.")
	TEST_ASSERT(!(copied in GLOB.custom_outfits), "The copy should stay a draft until explicitly saved.")
	TEST_ASSERT(copied.mental_conditioning, "The copy should retain the configured conditioning setting.")
	TEST_ASSERT_EQUAL(copied.backpack_contents?[/obj/item/wrench], 2, "The copy should preserve backpack counts.")
	TEST_ASSERT_EQUAL(copied.belt_contents?[/obj/item/screwdriver], 3, "The copy should preserve belt counts.")
	TEST_ASSERT_EQUAL(copied.box_contents?[/obj/item/paper], 4, "The copy should preserve box counts.")
	TEST_ASSERT_EQUAL(copied.implants?[1], /obj/item/implant/tracking, "The copy should preserve implants.")
	TEST_ASSERT_EQUAL(copied.organs?[1], /obj/item/organ/heart, "The copy should preserve organs.")
	TEST_ASSERT_EQUAL(copied.stored_access?[1], ACCESS_ENGINEERING, "The copy should preserve ID access.")
	TEST_ASSERT(copied.update_id_name, "The copy should preserve ID name settings.")
	var/list/edits = copied.vv_values?["LHAND"]
	TEST_ASSERT_EQUAL(edits?["name"], "Custom tool", "The copy should preserve slot VV edits.")
	TEST_ASSERT(isicon(edits["icon"]), "The copy should preserve in-memory VV icons.")

	copied.name = "Another event"
	copied.backpack_contents[/obj/item/wrench] = 1
	copied.belt_contents[/obj/item/screwdriver] = 1
	copied.box_contents[/obj/item/paper] = 1
	copied.implants.Cut()
	copied.organs.Cut()
	copied.stored_access.Cut()
	edits["name"] = "Another tool"
	var/list/original_edits = original.vv_values["LHAND"]
	TEST_ASSERT_EQUAL(original.name, "Event outfit", "Renaming the copy should leave the original name intact.")
	TEST_ASSERT_EQUAL(original.backpack_contents[/obj/item/wrench], 2, "Editing the copy should leave the original backpack contents intact.")
	TEST_ASSERT_EQUAL(original.belt_contents[/obj/item/screwdriver], 3, "Editing the copy should leave the original belt contents intact.")
	TEST_ASSERT_EQUAL(original.box_contents[/obj/item/paper], 4, "Editing the copy should leave the original box contents intact.")
	TEST_ASSERT_EQUAL(length(original.implants), 1, "Editing the copy should leave the original implants intact.")
	TEST_ASSERT_EQUAL(length(original.organs), 1, "Editing the copy should leave the original organs intact.")
	TEST_ASSERT_EQUAL(length(original.stored_access), 1, "Editing the copy should leave the original access intact.")
	TEST_ASSERT_EQUAL(original_edits["name"], "Custom tool", "Editing the copy should leave the original VV edits intact.")
	TEST_ASSERT(REF(edits["icon"]) != REF(custom_icon), "The copy should own its VV icon.")

/datum/unit_test/outfit_cybernetics/Run()
	var/datum/outfit/configured = allocate(/datum/outfit)
	configured.undershirt = /datum/sprite_accessory/clothing/undershirt/sports_bra
	configured.underwear = /datum/sprite_accessory/clothing/underwear/male_briefs
	configured.socks = /datum/sprite_accessory/clothing/socks/black_knee
	configured.prosthetics = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/robot,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/robot/bishop,
	)
	configured.cyber_organs = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain/cybernetic,
		ORGAN_SLOT_HEART = /obj/item/organ/heart/cybernetic,
		ORGAN_SLOT_LEFT_ARM_AUG = /obj/item/organ/cyberimp/arm/toolkit/surgery,
		ORGAN_SLOT_STOMACH_AID = /obj/item/organ/cyberimp/chest/ipc_upgrade/repair,
	)
	configured.organs = list(/obj/item/organ/eyes/robotic/tacvisor)
	configured.glasses = /obj/item/clothing/glasses/sunglasses

	var/datum/outfit/loaded = allocate(/datum/outfit)
	var/list/record = json_decode(json_encode(configured.get_json_data()))
	var/list/saved_prosthetics = record["prosthetics"]
	saved_prosthetics[BODY_ZONE_R_ARM] = "/obj/item/bodypart/arm/left/robot"
	var/list/saved_organs = record["cyber_organs"]
	saved_organs[ORGAN_SLOT_LIVER] = "/obj/item/organ/heart/cybernetic"
	saved_organs[ORGAN_SLOT_RIGHT_ARM_AUG] = "/obj/item/organ/cyberimp/arm/toolkit/mantis/left"

	TEST_ASSERT(loaded.load_from(record), "The outfit export should load again.")
	TEST_ASSERT_EQUAL(loaded.undershirt, configured.undershirt, "The undershirt style must survive an outfit export.")
	TEST_ASSERT_EQUAL(loaded.underwear, configured.underwear, "The underwear style must survive an outfit export.")
	TEST_ASSERT_EQUAL(loaded.socks, configured.socks, "The sock style must survive an outfit export.")
	TEST_ASSERT_EQUAL(loaded.prosthetics?[BODY_ZONE_L_ARM], configured.prosthetics[BODY_ZONE_L_ARM], "The prosthesis must survive export in its own zone.")
	TEST_ASSERT_NULL(loaded.prosthetics?[BODY_ZONE_R_ARM], "A left-arm prosthesis must not load in a right-arm slot.")
	TEST_ASSERT_NULL(loaded.cyber_organs?[ORGAN_SLOT_LIVER], "A heart must not load in the liver slot.")
	TEST_ASSERT_NULL(loaded.cyber_organs?[ORGAN_SLOT_RIGHT_ARM_AUG], "A fixed left arm implant must not load on the right.")
	TEST_ASSERT_EQUAL(loaded.organs?[1], /obj/item/organ/eyes/robotic/tacvisor, "Legacy organ arrays must still load.")

	var/datum/outfit/copied = loaded.duplicate()
	allocated += copied
	copied.prosthetics -= BODY_ZONE_L_ARM
	copied.cyber_organs -= ORGAN_SLOT_HEART
	TEST_ASSERT(loaded.prosthetics[BODY_ZONE_L_ARM], "Clearing a copied prosthesis must keep the original.")
	TEST_ASSERT(loaded.cyber_organs[ORGAN_SLOT_HEART], "Clearing a copied organ must keep the original.")

	var/mob/living/carbon/human/consistent/reference = allocate(/mob/living/carbon/human/consistent)
	var/wardrobe_hits = SSwardrobe.stock_hit
	var/wardrobe_misses = SSwardrobe.stock_miss
	var/mob/living/carbon/human/dummy/outfit_check/mannequin = allocate(/mob/living/carbon/human/dummy/outfit_check)
	generate_dummy_lookalike(null, reference, mannequin)
	TEST_ASSERT_NOTNULL(mannequin.get_organ_slot(ORGAN_SLOT_HEART), "The fitting mannequin must start with normal internal organs.")
	loaded.equip_items(mannequin, TRUE, mannequin)
	TEST_ASSERT_EQUAL(SSwardrobe.stock_hit, wardrobe_hits, "Fitting must not consume preloaded wardrobe organs.")
	TEST_ASSERT_EQUAL(SSwardrobe.stock_miss, wardrobe_misses, "Fitting must not request stock from the wardrobe.")
	TEST_ASSERT_NOTNULL(mannequin.glasses, "Legacy organs must be fitted after eyewear.")

	var/obj/item/bodypart/left_arm = mannequin.get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/organ/left_device = mannequin.get_organ_slot(ORGAN_SLOT_LEFT_ARM_AUG)
	TEST_ASSERT_EQUAL(left_arm?.type, /obj/item/bodypart/arm/left/robot/bishop, "The mannequin must be fitted with the selected model.")
	TEST_ASSERT_EQUAL(left_device?.zone, BODY_ZONE_L_ARM, "The implant must be switched to the chosen side.")
	TEST_ASSERT_NULL(mannequin.get_organ_slot(ORGAN_SLOT_RIGHT_ARM_AUG), "The mirrored implant must not occupy the opposite slot.")
	TEST_ASSERT_EQUAL(length(mannequin.outfit_issues), 1, "Only the IPC-only organ should be rejected.")
	var/list/failure = mannequin.outfit_issues[mannequin.outfit_issues[1]]
	TEST_ASSERT_EQUAL(failure["destination"], "cyber_organs:[ORGAN_SLOT_STOMACH_AID]", "The incompatibility should point to its organ slot.")

	var/mob/living/carbon/human/consistent/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.mind_initialize()
	var/datum/mind/original_mind = recipient.mind
	TEST_ASSERT_NOTNULL(original_mind, "The recipient must have an identity before replacing its brain.")
	var/obj/item/skillchip/basketweaving/chip = allocate(/obj/item/skillchip/basketweaving)
	recipient.implant_skillchip(chip, force = TRUE)
	TEST_ASSERT_NOTNULL(chip.holding_brain, "The replacement test needs a chip in the old brain.")
	TEST_ASSERT(loaded.equip(recipient), "The normal outfit path should apply the outfit.")
	var/obj/item/organ/brain = recipient.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/organ/eyes = recipient.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT_EQUAL(brain?.type, /obj/item/organ/brain/cybernetic, "The real outfit must install the cybernetic brain.")
	TEST_ASSERT_EQUAL(original_mind.current, recipient, "Replacing a brain from an outfit must preserve the player's identity.")
	TEST_ASSERT_EQUAL(eyes?.type, /obj/item/organ/eyes/robotic/tacvisor, "The normal outfit path must still apply legacy organs.")
	TEST_ASSERT_NOTNULL(recipient.glasses, "Legacy organs must keep their original order relative to eyewear.")
	TEST_ASSERT_EQUAL(chip.holding_brain, brain, "A brain replaced by an outfit must retain its skillchips.")

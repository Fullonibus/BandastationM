/datum/unit_test/drask_eye_transplant/Run()
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent)
	holder.set_eye_color("#36c5f0", "#e76ba4")
	var/obj/item/organ/eyes/drask/eyes = allocate(/obj/item/organ/eyes/drask)
	TEST_ASSERT(eyes.Insert(holder, movement_flags = DELETE_IF_REPLACED), "Could not insert Drask eyes.")
	TEST_ASSERT(HAS_TRAIT(holder, TRAIT_LUMINESCENT_EYES), "Transplanted Drask eyes did not grant luminescence.")
	var/obj/item/bodypart/head/head = holder.get_bodypart(BODY_ZONE_HEAD)
	var/center_eyes = 0
	var/center_masks = 0
	var/center_eyelids = 0
	for (var/mutable_appearance/overlay as anything in head.get_eye_overlays())
		if (overlay.icon_state == "drask_eyes_c")
			TEST_ASSERT(icon_exists(overlay.icon, overlay.icon_state), "The central eye overlay has no sprite.")
			if (json_encode(overlay.color) == json_encode(GLOB.emissive_color))
				center_masks++
			else if (overlay.color == "#36c5f0")
				center_eyes++
		else if (overlay.render_source == "*[REF(holder)]_eyelid_center")
			center_eyelids++
	TEST_ASSERT_EQUAL(center_eyes, 1, "The central eye should appear once in the left eye's color.")
	TEST_ASSERT_EQUAL(center_masks, 1, "The central eye should have exactly one emissive mask.")
	TEST_ASSERT_EQUAL(center_eyelids, 1, "The central eye should have exactly one animated eyelid.")
	var/obj/effect/abstract/eyelid_effect/eyelid = eyes.eyelid_center
	TEST_ASSERT(eyelid in holder.vis_contents, "The central eyelid has no render target on the wearer.")
	TEST_ASSERT(icon_exists(eyelid.icon, eyelid.icon_state), "The central eyelid has no sprite.")
	eyes.Remove(holder)
	TEST_ASSERT_NULL(holder.get_organ_slot(ORGAN_SLOT_EYES), "Could not remove the Drask eyes.")
	TEST_ASSERT(!HAS_TRAIT(holder, TRAIT_LUMINESCENT_EYES), "Removed Drask eyes left their luminescence behind.")
	TEST_ASSERT(!(eyelid in holder.vis_contents), "Removed Drask eyes left their central eyelid behind.")
	TEST_ASSERT(!(eyes.eyelid_left in holder.vis_contents) && !(eyes.eyelid_right in holder.vis_contents), "Removed Drask eyes left a side eyelid behind.")

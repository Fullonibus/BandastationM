/// Test you can mouse-drop a defib off your back to unequip it
/datum/unit_test/unequip_defib

/datum/unit_test/unequip_defib/Run()
	var/mob/living/carbon/human/consistent/dummy = EASY_ALLOCATE()
	dummy.mock_client = new()
	dummy.set_hud_used(new dummy.hud_type(dummy))
	var/obj/item/defibrillator/defib = EASY_ALLOCATE()
	dummy.equip_to_slot(defib, ITEM_SLOT_BACK)

	var/old_usr = usr

	usr = dummy // mouse drop still uses usr

	defib.MouseDrop(dummy.hud_used.screen_objects[HUD_KEY_HAND_SLOT(1)])
	if(!dummy.is_holding(defib))
		TEST_FAIL("The dummy failed to remove the defib from their back via mouse drop.")

	usr = old_usr

// AI EDIT START - Cover floor defibrillation and paddle cable range
// BANDASTATION ADDITION START - Floor defibrillator regression tests
/datum/unit_test/defib_from_floor/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/defibrillator/loaded/defib = allocate(/obj/item/defibrillator/loaded)
	click_wrapper(user, defib)
	TEST_ASSERT(user.is_holding(defib.paddles), "Clicking a defibrillator on the floor did not give the user its paddles.")
	TEST_ASSERT_EQUAL(defib.loc, run_loc_floor_bottom_left, "Taking the paddles picked up the main defibrillator unit.")

	defib.paddles.attack_self(user)
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_heartattack(TRUE)
	var/initial_charge = defib.cell.charge
	click_wrapper(user, patient)
	TEST_ASSERT(!patient.undergoing_cardiac_arrest(), "The defibrillator on the floor did not restart the patient's heart.")
	TEST_ASSERT(defib.cell.charge < initial_charge, "Defibrillation from the floor did not consume battery charge.")
	user.dropItemToGround(defib.paddles, TRUE)

/datum/unit_test/defib_from_floor_range/Run()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.reach_length = 2
	var/turf/far_turf = get_step(get_step(run_loc_floor_bottom_left, EAST), EAST)
	var/obj/item/defibrillator/loaded/defib = allocate(/obj/item/defibrillator/loaded, far_turf)
	click_wrapper(user, defib)
	TEST_ASSERT_EQUAL(defib.paddles.loc, defib, "The user took the paddles from a defibrillator outside their reach.")
	TEST_ASSERT(!user.is_holding(defib.paddles), "Extended reach left out-of-range paddles in the user's hands.")

	defib.forceMove(get_step(run_loc_floor_bottom_left, EAST))
	click_wrapper(user, defib)
	TEST_ASSERT(user.is_holding(defib.paddles), "The user could not take the paddles from an adjacent defibrillator.")
	defib.paddles.attack_self(user)
	defib.forceMove(far_turf)
	TEST_ASSERT_EQUAL(defib.paddles.loc, defib, "The paddles did not return when the main unit moved out of cable range.")
	TEST_ASSERT(!HAS_TRAIT(defib.paddles, TRAIT_WIELDED), "The user kept wielding the paddles after they returned to the main unit.")
// BANDASTATION ADDITION END
// AI EDIT END

/// NT paddles cannot stun or overload hearts; EMP shielding preserves their charge and medical operation.
/datum/unit_test/nanotrasen_defib_medical_only/Run()
	// Teardown deletes allocations in order; the unit must return its paddles before their holder is deleted.
	var/obj/item/defibrillator/compact/combat/loaded/nanotrasen/defib = allocate(/obj/item/defibrillator/compact/combat/loaded/nanotrasen)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	click_wrapper(user, defib)
	defib.paddles.attack_self(user)
	user.set_combat_mode(TRUE)
	click_wrapper(user, patient, list(RIGHT_CLICK = TRUE))
	TEST_ASSERT_EQUAL(patient.get_stamina_loss(), 0, "NT paddles still inflicted stamina damage.")
	TEST_ASSERT(!patient.has_status_effect(/datum/status_effect/incapacitating/knockdown), "NT paddles still knocked the patient down.")
	click_wrapper(user, patient)
	TEST_ASSERT_EQUAL(patient.get_fire_loss(), 0, "NT paddles still inflicted combat burns.")
	TEST_ASSERT(!patient.undergoing_cardiac_arrest(), "NT paddles still overloaded the patient's heart.")

	var/charge_before_emp = defib.cell.charge
	defib.emp_act(EMP_HEAVY)
	TEST_ASSERT_EQUAL(defib.cell.charge, charge_before_emp, "An EMP drained the shielded NT battery.")
	click_wrapper(user, patient, list(RIGHT_CLICK = TRUE))
	TEST_ASSERT_EQUAL(patient.get_stamina_loss(), 0, "An EMP disabled the NT medical safeties.")
	user.set_combat_mode(FALSE)
	patient.set_heartattack(TRUE)
	click_wrapper(user, patient)
	TEST_ASSERT(!patient.undergoing_cardiac_arrest(), "Shielded NT paddles could not restart the patient's heart.")
	TEST_ASSERT(defib.cell.charge < charge_before_emp, "NT defibrillation still used an infinite battery.")

/// Nerfing NT's child type must not disable the Syndicate defibrillator's offensive shock.
/datum/unit_test/syndicate_defib_still_offensive/Run()
	// Teardown deletes allocations in order; the unit must return its paddles before their holder is deleted.
	var/obj/item/defibrillator/compact/combat/loaded/defib = allocate(/obj/item/defibrillator/compact/combat/loaded)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	click_wrapper(user, defib)
	defib.paddles.attack_self(user)
	user.set_combat_mode(TRUE)
	click_wrapper(user, patient, list(RIGHT_CLICK = TRUE))
	TEST_ASSERT_EQUAL(patient.get_stamina_loss(), 60, "Syndicate paddles lost their offensive stamina shock.")

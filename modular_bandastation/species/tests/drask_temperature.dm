/obj/structure/drask_thermal_test_chamber
	var/datum/gas_mixture/test_air

/obj/structure/drask_thermal_test_chamber/return_air()
	return test_air

/datum/unit_test/drask_temperature_regression/Run()
	var/mob/living/carbon/human/drask = allocate(/mob/living/carbon/human/species/drask)
	var/datum/species/drask/species = drask.dna.species
	TEST_ASSERT_EQUAL(drask.coretemperature, species.bodytemp_normal, "A directly spawned Drask must start at its normal core temperature.")
	TEST_ASSERT_EQUAL(drask.bodytemperature, species.bodytemp_normal, "A directly spawned Drask must start at its normal skin temperature.")

	var/mob/living/carbon/human/transformed = allocate(/mob/living/carbon/human/consistent)
	transformed.adjust_fire_loss(5)
	var/core_before = transformed.coretemperature
	var/skin_before = transformed.bodytemperature
	var/burns_before = transformed.get_fire_loss()
	transformed.set_species(/datum/species/drask)
	TEST_ASSERT_EQUAL(transformed.coretemperature, core_before, "An existing mob must retain core temperature when transformed.")
	TEST_ASSERT_EQUAL(transformed.bodytemperature, skin_before, "An existing mob must retain skin temperature when transformed.")
	TEST_ASSERT_EQUAL(transformed.get_fire_loss(), burns_before, "Transforming into a Drask must preserve existing burns.")

	var/obj/item/mod/control/pre_equipped/standard/mod = allocate(/obj/item/mod/control/pre_equipped/standard)
	TEST_ASSERT(drask.equip_to_slot_if_possible(mod, ITEM_SLOT_BACK, disable_warning = TRUE), "The Drask must be able to equip a MOD.")
	mod.quick_activation()
	TEST_ASSERT(mod.active && mod.get_part_datum(drask.head)?.sealed, "The MOD must be sealed.")

	var/obj/structure/drask_thermal_test_chamber/chamber = allocate(/obj/structure/drask_thermal_test_chamber)
	chamber.test_air = allocate(/datum/gas_mixture, 2500)
	drask.forceMove(chamber)
	for(var/air_temperature in list(T0C + 70, T0C - 165))
		chamber.test_air.temperature = air_temperature
		TEST_ASSERT_EQUAL(drask.get_insulation_protection(air_temperature), 1, "The sealed MOD must insulate against the test temperature.")
		for(var/tick in 1 to 60)
			species.handle_body_temperature(drask, 2)
		TEST_ASSERT_EQUAL(drask.coretemperature, species.bodytemp_normal, "External temperatures must not bypass full insulation.")
		TEST_ASSERT_EQUAL(drask.get_fire_loss(), 0, "The insulated Drask must not receive thermal damage.")

/// Burning skin must still heat the core that controls temperature damage.
/datum/unit_test/drask_fire_heat_transfer/Run()
	var/mob/living/carbon/human/drask = allocate(/mob/living/carbon/human/species/drask)
	var/datum/species/drask/species = drask.dna.species
	var/obj/structure/drask_thermal_test_chamber/chamber = allocate(/obj/structure/drask_thermal_test_chamber)
	chamber.test_air = allocate(/datum/gas_mixture, 2500)
	chamber.test_air.temperature = species.bodytemp_normal
	drask.forceMove(chamber)
	drask.set_fire_stacks(5)
	drask.ignite_mob()
	TEST_ASSERT(drask.on_fire, "The Drask must be burning to check skin-to-core heat transfer.")
	// Keep the skin below the burn-wound threshold to isolate heat transfer from random wounds.
	drask.adjust_bodytemperature(T0C + 30 - drask.bodytemperature)
	var/core_before = drask.coretemperature
	species.handle_body_temperature(drask, 2)
	TEST_ASSERT(drask.coretemperature > core_before, "Burning skin did not heat the Drask's core.")

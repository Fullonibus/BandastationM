/// Restore the shared test floor even if a tear or repair assertion aborts early.
/datum/unit_test/torn_wall
	abstract_type = /datum/unit_test/torn_wall
	/// Turf references survive the wall's native destruction and replacement.
	var/turf/test_wall

/datum/unit_test/torn_wall/Destroy()
	if(test_wall)
		test_wall.ChangeTurf(/turf/open/indestructible)
	test_wall = null
	return ..()

/// Default tears, weaker impacts and mixed damage use the same native wall state.
/datum/unit_test/torn_wall/stages/Run()
	test_wall = run_loc_floor_bottom_left
	for(var/strength in list(1, 0.5))
		test_wall = test_wall.ChangeTurf(/turf/closed/wall)
		var/hits_to_break = strength == 1 ? 3 : 6
		for(var/hit in 1 to hits_to_break)
			if(strength == 1)
				test_wall.AddComponent(/datum/component/torn_wall)
			else
				test_wall.AddComponent(/datum/component/torn_wall, null, strength)
			TEST_ASSERT_EQUAL(test_wall.density, hit < hits_to_break, "A [strength]-strength tear destroyed the wall on the wrong hit ([hit]/[hits_to_break]).")
	test_wall = test_wall.ChangeTurf(/turf/closed/wall)
	test_wall.AddComponent(/datum/component/torn_wall, current_stage = 1)
	TEST_ASSERT(test_wall.density, "Seeding a badly damaged wall destroyed it before another blow.")
	test_wall.AddComponent(/datum/component/torn_wall)
	TEST_ASSERT(!test_wall.density, "A legacy full-strength tear did not finish a seeded damaged wall.")
	test_wall = test_wall.ChangeTurf(/turf/closed/wall)
	for(var/hit in 1 to 5)
		test_wall.AddComponent(/datum/component/torn_wall, null, 0.5)
	TEST_ASSERT(test_wall.density, "Five half-strength blows destroyed a wall before the finishing blow.")
	test_wall.AddComponent(/datum/component/torn_wall)
	TEST_ASSERT(!test_wall.density, "Mixed half- and full-strength tears skipped the destruction threshold.")

/// One real welder cycle leaves a fractional crack; refuelling allows the next cycle to finish repair.
/datum/unit_test/torn_wall/repair/Run()
	test_wall = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/wall)
	var/datum/component/torn_wall/cracks = test_wall.AddComponent(/datum/component/torn_wall, current_stage = 0.5)
	var/mob/living/carbon/human/consistent/worker = allocate(__IMPLIED_TYPE__, get_step(test_wall, EAST))
	var/obj/item/weldingtool/welder = allocate(__IMPLIED_TYPE__, worker)
	TEST_ASSERT(worker.put_in_active_hand(welder), "Could not hold the wall-repair welder.")
	// Two units fund exactly one native repair cycle; zero tool delay keeps unrelated subsystems out.
	welder.toolspeed = 0
	welder.reagents.clear_reagents()
	welder.reagents.add_reagent(/datum/reagent/fuel, 2)
	welder.attack_self(worker)
	click_wrapper(worker, test_wall)
	TEST_ASSERT_EQUAL(welder.get_fuel(), 0, "The wall repair did not consume one real welder cycle.")
	TEST_ASSERT(!QDELETED(cracks), "One repair cycle discarded the wall's remaining fractional damage.")
	TEST_ASSERT_EQUAL(cracks.current_stage, -0.5, "One repair cycle removed the wrong amount of native tear damage.")
	welder.reagents.add_reagent(/datum/reagent/fuel, 2)
	welder.attack_self(worker)
	click_wrapper(worker, test_wall)
	TEST_ASSERT(QDELETED(cracks) && test_wall.density, "Completing the repair failed to clear the cracks or destroyed the wall.")
	TEST_ASSERT_NULL(test_wall.GetComponent(/datum/component/torn_wall), "The repaired wall retained its tear component.")

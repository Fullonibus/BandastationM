/// Both autonomous orders and manual attacks use the same melee chain against an airlock.
/datum/unit_test/droid_relay_attack_airlock/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/unit_turf = get_step(home, NORTH)
	var/turf/door_turf = get_step(unit_turf, EAST)
	var/obj/machinery/overmap_droid_relay/relay = allocate(/obj/machinery/overmap_droid_relay, home)
	var/obj/item/relay_chassis/chassis = allocate(/obj/item/relay_chassis, relay)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, door_turf)
	TEST_ASSERT(relay.launch(chassis, unit_turf, null, null), "The fixture must deploy an autonomous droid.")
	var/mob/living/basic/relay_droid/unit = relay.droids[1]
	allocated += unit

	TEST_ASSERT(unit.receive_order("attack", door), "The relay droid must accept an attack order against a reachable airlock.")
	var/initial_integrity = door.get_integrity()
	unit.ClickOn(door, "")
	TEST_ASSERT(door.get_integrity() < initial_integrity, "A manual droid melee attack must overcome normal airlock deflection.")

	door.resistance_flags |= INDESTRUCTIBLE
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.order, "hold", "The droid must stop attacking a target that it can no longer damage.")
	TEST_ASSERT_NULL(unit.ai_controller.blackboard[BB_CURRENT_PET_TARGET], "The invalid attack target must be removed.")

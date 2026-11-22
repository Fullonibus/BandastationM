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
	var/post_manual_integrity = door.get_integrity()
	var/attack_deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(door) || door.get_integrity() < post_manual_integrity || world.time >= attack_deadline)
	TEST_ASSERT(!QDELETED(door) && door.get_integrity() < post_manual_integrity, "The autonomous melee subtree must also reach and damage the airlock.")

	door.resistance_flags |= INDESTRUCTIBLE
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.order, "hold", "The droid must stop attacking a target that it can no longer damage.")
	TEST_ASSERT_NULL(unit.ai_controller.blackboard[BB_CURRENT_PET_TARGET], "The invalid attack target must be removed.")

/// Combat pathing should choose the reachable flank and reroute when an ally steps into the passage.
/datum/unit_test/droid_relay_combat_path/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/start = locate(home.x, home.y + 2, home.z)
	var/turf/target_turf = locate(home.x + 4, home.y + 2, home.z)
	var/turf/shortest_flank = locate(home.x + 3, home.y + 3, home.z)
	var/turf/passage = locate(home.x + 2, home.y + 3, home.z)
	var/obj/machinery/overmap_droid_relay/relay = allocate(/obj/machinery/overmap_droid_relay, home)
	var/obj/item/relay_chassis/chassis = allocate(/obj/item/relay_chassis, relay)
	var/obj/item/relay_chassis/blocker_chassis = allocate(/obj/item/relay_chassis, relay)
	var/obj/machinery/door/airlock/target = allocate(/obj/machinery/door/airlock, target_turf)
	// A public closed airlock and two windows block the direct route.
	allocate(/obj/machinery/door/airlock/glass, locate(home.x + 2, home.y + 2, home.z))
	allocate(/obj/structure/window/fulltile, locate(home.x + 2, home.y + 1, home.z))
	allocate(/obj/structure/window/fulltile, locate(home.x + 2, home.y, home.z))
	TEST_ASSERT(relay.launch(chassis, start, null, null), "The fixture must deploy its attacker.")
	TEST_ASSERT(relay.launch(blocker_chassis, get_step(home, EAST), null, null), "The fixture must deploy its idle squadmate.")
	var/mob/living/basic/relay_droid/unit = relay.droids[1]
	var/mob/living/basic/relay_droid/blocker = relay.droids[2]
	allocated += list(unit, blocker)
	TEST_ASSERT(unit.receive_order("attack", target), "The attack order must be accepted.")

	unit.ai_controller.SelectBehaviors(0.1)
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.ai_controller.blackboard["BB_relay_melee_slot"], shortest_flank, "The first reservation should be the flank with the shortest walkable route.")
	var/datum/move_loop/has_target/jps/initial_route = GLOB.move_manager.processing_on(unit, SSai_movement)
	TEST_ASSERT(initial_route && (passage in initial_route.movement_path), "The first planned route should use the open passage.")

	blocker.forceMove(passage)
	var/initial_integrity = target.get_integrity()
	var/attack_deadline = world.time + 6 SECONDS
	UNTIL(target.get_integrity() < initial_integrity || world.time >= attack_deadline)
	TEST_ASSERT(target.get_integrity() < initial_integrity, "The droid should take the other passage and attack after the original passage is blocked.")
	TEST_ASSERT_EQUAL(blocker.loc, passage, "The attacking droid must not displace its idle squadmate.")

/// A real attacker prompts nearby autonomous units to defend a deployed body.
/datum/unit_test/droid_relay_defend_squad/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/victim_turf = get_step(home, NORTH)
	var/turf/guard_turf = get_step(victim_turf, EAST)
	var/turf/hostile_turf = get_step(victim_turf, NORTH)
	var/obj/machinery/overmap_droid_relay/relay = allocate(/obj/machinery/overmap_droid_relay, home)
	var/obj/item/relay_chassis/victim_stock = allocate(/obj/item/relay_chassis, relay)
	var/obj/item/relay_chassis/guard_stock = allocate(/obj/item/relay_chassis, relay)
	TEST_ASSERT(relay.launch(victim_stock, victim_turf, null, null), "The fixture must deploy the defender's squadmate.")
	TEST_ASSERT(relay.launch(guard_stock, guard_turf, null, null), "The fixture must deploy the nearby guard.")
	var/mob/living/basic/relay_droid/victim = relay.droids[1]
	var/mob/living/basic/relay_droid/guard = relay.droids[2]
	allocated += list(victim, guard)
	var/mob/living/basic/relay_droid/attacker = allocate(/mob/living/basic/relay_droid, hostile_turf)

	guard.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(guard.order, "hold", "An unmarked and peaceful target must be ignored.")
	var/turf/follow_destination = get_step(guard_turf, EAST)
	TEST_ASSERT(guard.receive_order("move", follow_destination), "The guard must start with a movement order.")
	SEND_SIGNAL(victim, COMSIG_ATOM_WAS_ATTACKED, attacker, ATTACKER_DAMAGING_ATTACK, NORTH)
	guard.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(guard.order, "attack", "An autonomous squadmate who sees the attacker must respond.")
	TEST_ASSERT_EQUAL(guard.ai_controller.blackboard[BB_CURRENT_PET_TARGET], attacker, "The temporary order must target the actual attacker.")
	TEST_ASSERT_EQUAL(length(relay.hostile_targets), 0, "Self-defense must not add an operator's hostile mark.")
	// Each changed subtree starts on the tick after its order was set.
	guard.ai_controller.SelectBehaviors(0.1)
	victim.ai_controller.SelectBehaviors(0.1)
	victim.ai_controller.SelectBehaviors(0.1)
	var/turf/victim_slot = victim.ai_controller.blackboard["BB_relay_melee_slot"]
	var/turf/guard_slot = guard.ai_controller.blackboard["BB_relay_melee_slot"]
	TEST_ASSERT(victim_slot && guard_slot && victim_slot != guard_slot, "The two attacking droids must reserve distinct melee positions.")

	attacker.death()
	guard.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(guard.order, "move", "The guard must resume its previous order after the attacker is defeated.")
	TEST_ASSERT_EQUAL(guard.ai_controller.blackboard[BB_CURRENT_PET_TARGET], follow_destination, "The movement destination must survive temporary combat.")

/// A hostile identification requires sight and ends immediately when the operator clears it.
/datum/unit_test/droid_relay_marked_contact/Run()
	var/turf/home = run_loc_floor_bottom_left
	var/turf/unit_turf = get_step(home, NORTH)
	var/turf/contact_turf = get_step(unit_turf, EAST)
	var/turf/hiding_turf = get_step(contact_turf, EAST)
	var/obj/machinery/overmap_droid_relay/relay = allocate(/obj/machinery/overmap_droid_relay, home)
	var/obj/item/relay_chassis/chassis = allocate(/obj/item/relay_chassis, relay)
	TEST_ASSERT(relay.launch(chassis, unit_turf, null, null), "The fixture must deploy the mark observer.")
	var/mob/living/basic/relay_droid/unit = relay.droids[1]
	allocated += unit
	var/mob/living/basic/relay_droid/marked = allocate(/mob/living/basic/relay_droid, contact_turf)
	var/obj/structure/closet/concealment = allocate(/obj/structure/closet, hiding_turf)
	TEST_ASSERT(!relay.mark_hostile(unit), "A squadmate cannot be registered as an enemy.")
	TEST_ASSERT(relay.mark_hostile(marked), "The identified external body must be added.")
	marked.forceMove(concealment)
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.order, "hold", "An unseen marked body must not draw aggro.")

	marked.forceMove(contact_turf)
	COOLDOWN_RESET(unit, hostile_scan)
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.ai_controller.blackboard[BB_CURRENT_PET_TARGET], marked, "A visible marked body must be acquired.")

	marked.forceMove(concealment)
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.ai_controller.blackboard[BB_CURRENT_PET_TARGET], contact_turf, "A search must use the last visible tile, not the hidden body or its new tile.")
	TEST_ASSERT(relay.unmark_hostile(WEAKREF(marked)), "A mark can be removed after the body moves out of sight.")
	unit.ai_controller.SelectBehaviors(0.1)
	TEST_ASSERT_EQUAL(unit.order, "hold", "Removing a mark must end an engagement based on that mark.")

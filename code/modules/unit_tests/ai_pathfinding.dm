/// Retargeting an active JPS move must discard the old request and its deletion subscription.
/datum/unit_test/ai_pathfinding_retarget/Run()
	var/mob/living/basic/bot/secbot/bot = allocate(/mob/living/basic/bot/secbot, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = bot.ai_controller
	controller.force_ai_off()
	var/obj/item/old_target = allocate(/obj/item, run_loc_floor_top_right)
	var/turf/new_target = get_step(run_loc_floor_bottom_left, NORTH)
	controller.ai_movement.start_moving_towards(controller, old_target, 0)
	controller.ai_movement.start_moving_towards(controller, new_target, 0)
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(bot, SSai_movement)
	TEST_ASSERT_NOTNULL(loop, "Retargeting stopped movement without replacing it")
	loop.pause_for(30 SECONDS)
	qdel(old_target)
	TEST_ASSERT(!QDELETED(loop), "Deleting the previous target stopped movement to the new target")
	var/deadline = world.time + 10 SECONDS
	while(loop.is_pathing && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(!loop.is_pathing, "Retargeted JPS request did not finish")
	TEST_ASSERT(length(loop.movement_path), "Retargeted JPS request returned no route")
	TEST_ASSERT_EQUAL(loop.movement_path[length(loop.movement_path)], new_target, "JPS still routes to the previous target")
	TEST_ASSERT_EQUAL(loop.move(), MOVELOOP_SUCCESS, "The new route could not be followed")
	TEST_ASSERT_EQUAL(get_turf(bot), new_target, "Bot did not reach its replacement target")

/// A patrol must build a route beyond the short interaction path limit.
/datum/unit_test/ai_pathfinding_patrol_range
	/// Original turf types for the corridor extending outside the small test room.
	var/list/corridor_turfs = list()

/datum/unit_test/ai_pathfinding_patrol_range/Destroy()
	for(var/turf/changed as anything in corridor_turfs)
		changed.ChangeTurf(corridor_turfs[changed])
	corridor_turfs = null
	return ..()

/datum/unit_test/ai_pathfinding_patrol_range/Run()
	for(var/offset in 1 to 34)
		var/turf/next = locate(run_loc_floor_bottom_left.x + offset, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
		var/old_type = next.type
		next = next.ChangeTurf(/turf/open/indestructible)
		corridor_turfs[next] = old_type
	var/turf/destination = locate(run_loc_floor_bottom_left.x + 34, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/obj/machinery/navbeacon/beacon = allocate(/obj/machinery/navbeacon, destination)
	beacon.codes[NAVBEACON_PATROL_MODE] = TRUE
	beacon.glob_lists_register()
	var/mob/living/basic/bot/secbot/bot = allocate(/mob/living/basic/bot/secbot, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = bot.ai_controller
	controller.force_ai_off()
	bot.bot_mode_flags |= BOT_MODE_AUTOPATROL
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/bot_patrol))
	controller.SelectBehaviors(1)
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(bot, SSai_movement)
	TEST_ASSERT_NOTNULL(loop, "Patrol did not start moving to its beacon")
	loop.pause_for(30 SECONDS)
	var/deadline = world.time + 10 SECONDS
	while(loop.is_pathing && world.time < deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(!loop.is_pathing, "Patrol JPS request did not finish")
	TEST_ASSERT(length(loop.movement_path), "Patrol cannot route to a beacon 34 tiles away")
	TEST_ASSERT_EQUAL(loop.movement_path[length(loop.movement_path)], destination, "Patrol route does not reach the distant beacon")

/// A failed patrol backs off and excludes the failed beacon from subsequent selection.
/datum/unit_test/ai_pathfinding_patrol_failure/Run()
	var/obj/machinery/navbeacon/beacon = allocate(/obj/machinery/navbeacon, run_loc_floor_top_right)
	beacon.codes[NAVBEACON_PATROL_MODE] = TRUE
	beacon.glob_lists_register()
	var/mob/living/basic/bot/secbot/bot = allocate(/mob/living/basic/bot/secbot, run_loc_floor_bottom_left)
	var/datum/ai_controller/basic_controller/bot/controller = bot.ai_controller
	controller.force_ai_off()
	bot.bot_mode_flags |= BOT_MODE_AUTOPATROL
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/bot_patrol))
	controller.SelectBehaviors(1)
	TEST_ASSERT_EQUAL(controller.blackboard[BB_BEACON_TARGET], beacon, "Patrol did not select the test beacon")
	controller.ai_movement.fail_movement(controller)
	controller.SelectBehaviors(1)
	TEST_ASSERT(controller.blackboard[BB_BOT_BEACON_COOLDOWN] > world.time, "Failed patrol did not back off")
	TEST_ASSERT(LAZYACCESS(controller.blackboard[BB_TEMPORARY_IGNORE_LIST], beacon), "Failed patrol did not exclude its beacon")
	controller.clear_blackboard_key(BB_PREVIOUS_BEACON_TARGET)
	var/datum/bt_node/ai_behavior/find_first_beacon_target/find_first = allocate(/datum/bt_node/ai_behavior/find_first_beacon_target)
	find_first.target_key = BB_BEACON_TARGET
	TEST_ASSERT(find_first.perform(1, controller) & AI_BEHAVIOR_FAILED, "Patrol immediately reselected the ignored beacon")

/// Interrupting patrol must not blacklist the beacon or impose a failure cooldown.
/datum/unit_test/ai_pathfinding_patrol_cancel/Run()
	var/obj/machinery/navbeacon/beacon = allocate(/obj/machinery/navbeacon, run_loc_floor_top_right)
	beacon.codes[NAVBEACON_PATROL_MODE] = TRUE
	beacon.glob_lists_register()
	var/mob/living/basic/bot/secbot/bot = allocate(/mob/living/basic/bot/secbot, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = bot.ai_controller
	controller.force_ai_off()
	bot.bot_mode_flags |= BOT_MODE_AUTOPATROL
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/bot_patrol))
	controller.SelectBehaviors(1)
	controller.cancel_current_plan()
	TEST_ASSERT(!LAZYACCESS(controller.blackboard[BB_TEMPORARY_IGNORE_LIST], beacon), "Interrupted patrol blacklisted its beacon")
	TEST_ASSERT(!controller.blackboard[BB_BOT_BEACON_COOLDOWN], "Interrupted patrol imposed a failure cooldown")

/// The shared patrol tree must retain medbot's stationary-mode movement restriction.
/datum/unit_test/ai_pathfinding_medbot_stationary/Run()
	var/obj/machinery/navbeacon/beacon = allocate(/obj/machinery/navbeacon, run_loc_floor_top_right)
	beacon.codes[NAVBEACON_PATROL_MODE] = TRUE
	beacon.glob_lists_register()
	var/mob/living/basic/bot/medbot/bot = allocate(/mob/living/basic/bot/medbot, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = bot.ai_controller
	controller.force_ai_off()
	bot.bot_mode_flags |= BOT_MODE_AUTOPATROL
	var/datum/bt_node/subtree/bot_patrol/patrol
	var/list/nodes = controller.behavior_nodes.Copy()
	var/index = 1
	while(index <= length(nodes))
		var/datum/bt_node/node = nodes[index++]
		if(istype(node, /datum/bt_node/subtree/bot_patrol))
			patrol = node
			break
		var/list/children = node.get_children()
		if(children)
			nodes += children
	TEST_ASSERT_NOTNULL(patrol, "Medbot's tree has no patrol subtree")
	controller.cancelled_during_tick = FALSE
	patrol.tick(controller, 1)
	var/datum/move_loop/loop = GLOB.move_manager.processing_on(bot, SSai_movement)
	TEST_ASSERT_NOTNULL(loop, "Medbot patrol did not start moving")
	bot.medical_mode_flags &= ~MEDBOT_STATIONARY_MODE
	TEST_ASSERT(controller.ai_movement.allowed_to_move(loop), "Mobile medbot cannot patrol")
	bot.medical_mode_flags |= MEDBOT_STATIONARY_MODE
	TEST_ASSERT(!controller.ai_movement.allowed_to_move(loop), "Patrol bypasses medbot's stationary mode")

/// Failure before monkey_equip runs must still discard the unreachable pickup target.
/datum/unit_test/ai_pathfinding_monkey_failure/Run()
	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = monkey.ai_controller
	TEST_ASSERT_NOTNULL(controller, "Monkey has no AI controller")
	controller.force_ai_off()
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/monkey_find_weapon))
	var/obj/item/weapon = allocate(/obj/item/crowbar, run_loc_floor_top_right)
	controller.set_blackboard_key(BB_MONKEY_PICKUPTARGET, weapon)
	controller.SelectBehaviors(1)
	TEST_ASSERT(controller.ai_movement.moving_controllers[controller], "Monkey did not start approaching its item")
	controller.ai_movement.fail_movement(controller)
	controller.SelectBehaviors(1)
	TEST_ASSERT(controller.blackboard[BB_MONKEY_BLACKLISTITEMS][weapon], "Failed approach did not exclude the item")
	TEST_ASSERT_NULL(controller.blackboard[BB_MONKEY_PICKUPTARGET], "Failed approach kept its pickup target")

/// Cancelling a monkey's approach is not evidence that its target is unreachable.
/datum/unit_test/ai_pathfinding_monkey_cancel/Run()
	var/mob/living/carbon/human/species/monkey/monkey = allocate(/mob/living/carbon/human/species/monkey, run_loc_floor_bottom_left)
	var/datum/ai_controller/controller = monkey.ai_controller
	TEST_ASSERT_NOTNULL(controller, "Monkey has no AI controller")
	controller.force_ai_off()
	controller.replace_behavior_nodes(list(/datum/bt_node/subtree/monkey_find_weapon))
	var/obj/item/weapon = allocate(/obj/item/crowbar, run_loc_floor_top_right)
	controller.set_blackboard_key(BB_MONKEY_PICKUPTARGET, weapon)
	controller.SelectBehaviors(1)
	controller.cancel_current_plan()
	TEST_ASSERT(!controller.blackboard[BB_MONKEY_BLACKLISTITEMS][weapon], "Cancelling an approach incorrectly excluded its item")

/// An airlock route must agree with the mechanical barriers that prevent opening.
/datum/unit_test/ai_pathfinding_airlock/Run()
	var/obj/machinery/door/airlock/instant/door = allocate(/obj/machinery/door/airlock/instant)
	var/datum/can_pass_info/pass_info = allocate(/datum/can_pass_info)
	TEST_ASSERT(door.CanAStarPass(NORTH, pass_info), "An ordinary public airlock should be traversable")
	door.welded = TRUE
	TEST_ASSERT(!door.CanAStarPass(NORTH, pass_info), "Pathfinding accepts a welded airlock")
	door.welded = FALSE
	door.seal = allocate(/obj/item/door_seal)
	TEST_ASSERT(!door.CanAStarPass(NORTH, pass_info), "Pathfinding accepts a sealed airlock")
	QDEL_NULL(door.seal)
	TEST_ASSERT(door.CanAStarPass(NORTH, pass_info), "Removing the seal did not restore traversal")
	door.req_access = list("access nothing has")
	TEST_ASSERT(!door.CanAStarPass(NORTH, pass_info), "Pathfinding bypassed airlock access")

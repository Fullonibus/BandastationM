/// The module's private movement key; assertions distinguish investigation from actual combat.
#define TEST_PLANET_HELP_LOCATION "expedition_help_location"

/// Real fauna, an opaque wall with a route around it, and a stationary attacker on an isolated level.
/datum/unit_test/overmap_planet_help
	abstract_type = /datum/unit_test/overmap_planet_help
	/// A shared empty level, whose arena and mobs are restored between cases.
	var/static/datum/space_level/arena
	/// Actual attacker used through the native combat-hand entry point.
	var/mob/living/carbon/human/attacker
	/// Tough enough to survive the cooldown test's repeated punches.
	var/mob/living/basic/hivebot/strong/victim
	/// Same-faction creature initially hidden behind the wall.
	var/mob/living/basic/hivebot/helper

/datum/unit_test/overmap_planet_help/New()
	..()
	if(!arena)
		arena = SSmapping.add_new_zlevel("Planet fauna help tests", list(ZTRAIT_AWAY = TRUE))
	for(var/turf/tile as anything in block(locate(40, 40, arena.z_value), locate(85, 75, arena.z_value)))
		tile.ChangeTurf(/turf/open/misc/asteroid, /turf/open/misc/asteroid)
	for(var/turf/tile as anything in block(locate(55, 47, arena.z_value), locate(55, 53, arena.z_value)))
		tile.ChangeTurf(/turf/closed/wall)
	attacker = allocate(/mob/living/carbon/human/consistent, locate(50, 50, arena.z_value))
	ADD_TRAIT(attacker, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(attacker, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(attacker, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	attacker.set_combat_mode(TRUE)
	victim = allocate(/mob/living/basic/hivebot/strong, locate(51, 50, arena.z_value))
	helper = allocate(/mob/living/basic/hivebot, locate(59, 50, arena.z_value))
	for(var/mob/living/basic/member as anything in list(victim, helper))
		member.add_expedition_help()
		// Native off-screen idling is unrelated to movement/targeting; this test has no player client.
		member.ai_controller.ai_traits |= RUN_WHILE_UNWATCHED
		member.ai_controller.reset_ai_status()

/datum/unit_test/overmap_planet_help/Destroy()
	for(var/turf/tile as anything in block(locate(40, 40, arena.z_value), locate(85, 75, arena.z_value)))
		for(var/mob/living/creature in tile)
			qdel(creature)
	attacker = null
	victim = null
	helper = null
	return ..()

/// A real melee attack recruits an unseen ally, which paths around the wall, attacks, then loses a distant enemy normally.
/datum/unit_test/overmap_planet_help/pursuit/Run()
	TEST_ASSERT(!can_see(helper, attacker, 12), "The ally must initially be unable to see the attacker")
	var/turf/start = get_turf(helper)
	victim.attack_hand(attacker, list())
	victim.ai_controller.force_ai_off() // Only the helper may damage the attacker in the observed combat.
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[BB_CURRENT_TARGET], "A call must not grant an unseen combat target")
	TEST_ASSERT_EQUAL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], get_turf(victim), "The ally must investigate the actual reported location")
	sleep(3 SECONDS)
	TEST_ASSERT(get_turf(helper) != start, "The native movement subsystem must bring the ally towards the call")
	TEST_ASSERT(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION] || helper.ai_controller.blackboard[BB_CURRENT_TARGET] == attacker, "The report must survive ordinary sight revalidation while the ally approaches")
	var/health_before = attacker.health
	var/deadline = world.time + 15 SECONDS
	UNTIL(attacker.health < health_before || world.time >= deadline)
	TEST_ASSERT(attacker.health < health_before && get_dist(helper, attacker) <= 1, "The ally must reach and actually attack through its original combat tree")
	attacker.forceMove(locate(80, 70, arena.z_value))
	deadline = world.time + 6 SECONDS
	UNTIL(!helper.ai_controller.blackboard[BB_CURRENT_TARGET] || world.time >= deadline)
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[BB_CURRENT_TARGET], "An enemy escaping normal loss range must not remain a permanent combat target")
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "Combat handover must release the investigation")

/// Calls respect faction, distance, existing fights and explicitly disabled AI; detaching restores the original tree.
/datum/unit_test/overmap_planet_help/filters/Run()
	var/mob/living/basic/hivebot/stranger = allocate(/mob/living/basic/hivebot, locate(59, 51, arena.z_value))
	stranger.set_faction(list("unrelated_test_faction"))
	stranger.add_expedition_help()
	var/mob/living/basic/hivebot/distant = allocate(/mob/living/basic/hivebot, locate(65, 50, arena.z_value))
	distant.add_expedition_help()
	var/mob/living/basic/hivebot/busy = allocate(/mob/living/basic/hivebot, locate(59, 52, arena.z_value))
	busy.add_expedition_help()
	var/mob/living/carbon/human/other_enemy = allocate(/mob/living/carbon/human/consistent, locate(60, 52, arena.z_value))
	busy.ai_controller.set_blackboard_key(BB_CURRENT_TARGET, other_enemy)
	var/mob/living/basic/hivebot/disabled = allocate(/mob/living/basic/hivebot, locate(59, 49, arena.z_value))
	disabled.add_expedition_help()
	disabled.ai_controller.force_ai_off()
	var/mob/living/basic/hivebot/dead = allocate(/mob/living/basic/hivebot, locate(60, 50, arena.z_value))
	dead.add_expedition_help()
	dead.set_stat(DEAD)
	helper.add_expedition_help()
	TEST_ASSERT_EQUAL(length(helper.ai_controller.behavior_nodes), 2, "Repeated attachment must not duplicate the native investigation node")
	var/datum/bt_node/original_tree = helper.ai_controller.behavior_nodes[2]
	victim.attack_hand(attacker, list())
	var/cooldown = victim.ai_controller.blackboard[BB_BASIC_MOB_REINFORCEMENTS_COOLDOWN]
	TEST_ASSERT(cooldown > world.time && helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "A damaging attack must call an eligible nearby ally and start the cooldown")
	var/turf/reported_location = get_turf(victim)
	victim.forceMove(locate(52, 50, arena.z_value))
	TEST_ASSERT_EQUAL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], reported_location, "A report must retain its original location instead of tracking its moving caller")
	for(var/mob/living/basic/excluded as anything in list(stranger, distant, busy, disabled, dead))
		TEST_ASSERT_NULL(excluded.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "The call must not recruit [excluded]")
	TEST_ASSERT_EQUAL(busy.ai_controller.blackboard[BB_CURRENT_TARGET], other_enemy, "An existing fight must retain its own target")
	helper.RemoveElement(/datum/element/stationtrauma_call_for_help)
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "Detaching before the first AI tick must also clear the pending report")
	TEST_ASSERT_EQUAL(length(helper.ai_controller.behavior_nodes), 1, "Detaching must remove only the additional node")
	TEST_ASSERT_EQUAL(helper.ai_controller.behavior_nodes[1], original_tree, "The exact original behaviour tree must survive attachment and removal")
	helper.add_expedition_help()
	victim.attack_hand(attacker, list())
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "A second hit during cooldown must not recruit the same ally again")
	TEST_ASSERT_EQUAL(victim.ai_controller.blackboard[BB_BASIC_MOB_REINFORCEMENTS_COOLDOWN], cooldown, "Repeated hits must not refresh the call on every frame")

/// A slow ally must stop investigating when the real deadline elapses, even with an otherwise valid enemy and path.
/datum/unit_test/overmap_planet_help/expiry/Run()
	helper.ai_controller.movement_delay = 20 SECONDS
	victim.attack_hand(attacker, list())
	victim.ai_controller.force_ai_off()
	var/datum/bt_node/ai_behavior/move_to_target/expedition_help/investigation = locate() in helper.ai_controller.behavior_nodes
	var/deadline = investigation.expires_at
	TEST_ASSERT_EQUAL(deadline, world.time + 30 SECONDS, "A report must have a finite thirty-second deadline")
	sleep(2 SECONDS)
	TEST_ASSERT(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "A still-valid investigation must survive early sight rechecks")
	UNTIL(!helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION] || world.time >= deadline + 2 SECONDS)
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "A timed-out call must return the mob to its normal behaviour")
	TEST_ASSERT_EQUAL(investigation.expires_at, 0, "Finishing must release the deadline")
	TEST_ASSERT_NULL(investigation.attacker_ref, "Finishing must release the enemy identity")

/// Deleted enemies must release a report without retaining their references.
/datum/unit_test/overmap_planet_help/deleted_enemy/Run()
	victim.attack_hand(attacker, list())
	victim.ai_controller.force_ai_off()
	qdel(attacker)
	attacker = null
	var/deadline = world.time + 3 SECONDS
	UNTIL(!helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION] || world.time >= deadline)
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "Deleting an unseen attacker must end the investigation")

/// A completely enclosed ally must give up its report without walking through walls or pursuing forever.
/datum/unit_test/overmap_planet_help/unreachable/Run()
	var/turf/start = get_turf(helper)
	for(var/turf/tile in RANGE_TURFS(1, helper))
		if(tile != start)
			tile.ChangeTurf(/turf/closed/wall)
	victim.attack_hand(attacker, list())
	victim.ai_controller.force_ai_off()
	TEST_ASSERT(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "The enclosed ally must initially hear the report")
	var/deadline = world.time + 32 SECONDS
	UNTIL(!helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION] || world.time >= deadline)
	TEST_ASSERT_NULL(helper.ai_controller.blackboard[TEST_PLANET_HELP_LOCATION], "Failed movement or the report deadline must release an unreachable call")
	TEST_ASSERT_EQUAL(get_turf(helper), start, "Reinforcement must not bypass actual walls")

/// Planet nest offspring receive the same behaviour through the actual native spawner callback.
/datum/unit_test/overmap_planet_help/offspring/Run()
	victim.ai_controller.force_ai_off()
	helper.ai_controller.force_ai_off()
	var/obj/structure/spawner/stationtrauma_xeno_hive/den = allocate(/obj/structure/spawner/stationtrauma_xeno_hive, locate(70, 60, arena.z_value))
	den.AddElement(/datum/element/stationtrauma_help_spawner)
	den.AddElement(/datum/element/stationtrauma_help_spawner)
	var/datum/component/spawner/spawning = den.GetComponent(/datum/component/spawner)
	// Dynamically created native nests wait a full spawn interval before their first offspring.
	var/deadline = world.time + den.spawn_time + 5 SECONDS
	UNTIL(length(spawning.spawned_things) || world.time >= deadline)
	TEST_ASSERT(length(spawning.spawned_things), "The native nest must create an actual creature")
	for(var/datum/weakref/member as anything in spawning.spawned_things)
		var/mob/living/creature = member.resolve()
		var/datum/bt_node/ai_behavior/move_to_target/expedition_help/investigation = locate() in creature.ai_controller.behavior_nodes
		TEST_ASSERT(investigation, "Future nest offspring must be able to answer local calls")
	den.RemoveElement(/datum/element/stationtrauma_help_spawner)

#undef TEST_PLANET_HELP_LOCATION

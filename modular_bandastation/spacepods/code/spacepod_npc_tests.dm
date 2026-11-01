/// Basic AI must discover an occupied pod, respect its crew's factions, and damage its real hull.
/datum/unit_test/spacepod_npc_basic_targeting/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	var/mob/living/basic/mining/goliath/monster = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/datum/ai_controller/controller = monster.ai_controller
	var/datum/targeting_strategy/basic/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/basic)
	var/datum/target_source/hearers/target_source = GET_TARGET_SOURCE(/datum/target_source/hearers)
	TEST_ASSERT_NOTNULL(controller, "The native goliath did not have its real AI controller.")
	TEST_ASSERT(GLOB.target_interested_atoms[pod.type], "The pod is missing from the native AI target typecache.")
	TEST_ASSERT((pod in GLOB.hostile_machines_by_z[origin.z]), "The pod did not register as a native hostile-machine candidate.")
	var/list/candidates = target_source.collect_candidates(monster, controller, 9)
	TEST_ASSERT((pod in candidates), "The native target source could not discover the pod.")
	TEST_ASSERT(!strategy.is_valid_target(monster, pod, 9, controller), "A goliath considered an empty pod hostile.")

	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, WEST))
	pilot.set_faction(monster.get_faction())
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The friendly pilot could not board the AI fixture.")
	TEST_ASSERT(!strategy.is_valid_target(monster, pod, 9, controller), "A goliath targeted a pod containing only its own faction.")
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, WEST))
	TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The hostile passenger could not board the AI fixture.")
	TEST_ASSERT(strategy.is_valid_target(monster, pod, 9, controller), "A hostile passenger did not make the occupied pod a valid target.")
	var/datum/bt_node/ai_behavior/acquire_target/update_combat_targets/acquire = allocate(__IMPLIED_TYPE__)
	acquire.owning_controller = controller
	acquire.target_key = BB_CURRENT_TARGET
	acquire.tick(controller, SSMOBS_DT)
	TEST_ASSERT_EQUAL(controller.blackboard[BB_CURRENT_TARGET], pod, "The native acquisition behavior did not select the occupied pod.")
	var/integrity_before = pod.get_integrity()
	TEST_ASSERT(monster.melee_attack(pod), "The native basic-mob attack chain refused the pod.")
	TEST_ASSERT(pod.get_integrity() < integrity_before, "The acquired pod did not take actual hull damage from the basic mob.")
	TEST_ASSERT_EQUAL(passenger.health, passenger.maxHealth, "A hull attack bypassed the pod and hit its passenger.")
	qdel(pod)
	TEST_ASSERT_NULL(controller.blackboard[BB_CURRENT_TARGET], "Deleting the targeted pod left a stale native AI blackboard target.")
	TEST_ASSERT(!(pod in GLOB.hostile_machines_by_z[origin.z]), "Deleting the pod left it registered as a hostile machine.")

/// Legacy hostiles must use the same crew checks, discovery and target cleanup as their existing mech path.
/datum/unit_test/spacepod_npc_legacy_targeting/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, origin)
	var/mob/living/simple_animal/hostile/ooze/monster = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT((pod in monster.ListTargets()), "Legacy hostile discovery did not include the pod.")
	TEST_ASSERT(!monster.CanAttack(pod), "A legacy hostile selected an empty pod.")
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, WEST))
	pilot.set_faction(monster.get_faction())
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The friendly pilot could not board the legacy AI fixture.")
	TEST_ASSERT(!monster.CanAttack(pod), "A legacy hostile selected a pod containing only its own faction.")
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(origin, WEST))
	TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The hostile passenger could not board the legacy AI fixture.")
	TEST_ASSERT(monster.CanAttack(pod), "A legacy hostile ignored an enemy passenger inside the pod.")
	TEST_ASSERT_EQUAL(monster.FindTarget(list(pod)), pod, "Legacy target acquisition did not accept the discovered occupied pod.")
	TEST_ASSERT_EQUAL(monster.target, pod, "Legacy acquisition did not retain the actual pod as its target.")
	var/integrity_before = pod.get_integrity()
	TEST_ASSERT(monster.AttackingTarget(pod), "The native legacy attack chain refused the pod.")
	TEST_ASSERT(pod.get_integrity() < integrity_before, "The acquired pod did not take actual hull damage from the legacy hostile.")
	passenger.death()
	TEST_ASSERT(!monster.CanAttack(pod), "A dead enemy passenger kept the otherwise friendly pod hostile.")
	monster.FindTarget(list(pod))
	TEST_ASSERT_NULL(monster.target, "Revalidation retained a pod without a living hostile occupant.")

/// Separate physical z-levels can share a rendering plane; the AI registry must still follow movement.
/datum/unit_test/spacepod_npc_z_registration
	parent_type = /datum/unit_test/spacepod_vacuum

/datum/unit_test/spacepod_npc_z_registration/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve the separate z-level registration fixture.")
	var/turf/origin = run_loc_floor_bottom_left
	TEST_ASSERT(origin.z != vacuum_origin.z, "The registration fixture must cross physical z-levels.")
	TEST_ASSERT_EQUAL(GET_TURF_PLANE_OFFSET(origin), GET_TURF_PLANE_OFFSET(vacuum_origin), "The registration fixture must cross z-levels with the same rendering offset.")
	for(var/subject_type in list(/obj/vehicle/sealed/spacepod, /obj/vehicle/sealed/spacepod/civilian, /obj/vehicle/sealed/mecha/ripley, /obj/machinery/porta_turret))
		var/atom/movable/subject = allocate(subject_type, origin)
		TEST_ASSERT((subject in GLOB.hostile_machines_by_z[origin.z]), "[subject_type] did not register at its initial z-level.")
		TEST_ASSERT(subject.forceMove(get_step(origin, EAST)), "[subject_type] could not move within its initial z-level.")
		TEST_ASSERT((subject in GLOB.hostile_machines_by_z[origin.z]), "Moving within a z-level unregistered [subject_type].")
		TEST_ASSERT(subject.forceMove(vacuum_origin), "[subject_type] could not move to the separate z-level.")
		TEST_ASSERT(!(subject in GLOB.hostile_machines_by_z[origin.z]), "Moving [subject_type] left an AI registry reference on its old z-level.")
		TEST_ASSERT((subject in GLOB.hostile_machines_by_z[vacuum_origin.z]), "Moving [subject_type] did not register it on its new z-level.")
		TEST_ASSERT(subject.moveToNullspace(), "[subject_type] could not move into nullspace.")
		TEST_ASSERT(!(subject in GLOB.hostile_machines_by_z[vacuum_origin.z]), "Moving [subject_type] into nullspace left an AI registry reference.")
		TEST_ASSERT(subject.forceMove(origin), "[subject_type] could not return from nullspace.")
		TEST_ASSERT((subject in GLOB.hostile_machines_by_z[origin.z]), "Returning [subject_type] from nullspace did not restore its AI registration.")
		TEST_ASSERT(subject.forceMove(vacuum_origin), "[subject_type] could not move before deletion.")
		qdel(subject)
		TEST_ASSERT(!(subject in GLOB.hostile_machines_by_z[origin.z]), "Deleting [subject_type] left an AI registry reference on its previous z-level.")
		TEST_ASSERT(!(subject in GLOB.hostile_machines_by_z[vacuum_origin.z]), "Deleting [subject_type] left an AI registry reference on its final z-level.")

/// Only the occupied hull enters the sensor field; hidden crew cannot wake the turret for it.
/datum/unit_test/spacepod_turret_tracking
	parent_type = /datum/unit_test/spacepod_vacuum

/datum/unit_test/spacepod_turret_tracking/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not board the turret sensor fixture.")
	var/turf/corner = vacuum_block.bottom_left_turfs[1]
	var/turf/far_turf = locate(corner.x + 13, pod.y, pod.z)
	pod.forceMove(far_turf)
	var/obj/machinery/porta_turret/syndicate/energy/ruin/turret = allocate(__IMPLIED_TYPE__, locate(corner.x + 2, pod.y, pod.z))
	TEST_ASSERT(!(turret.datum_flags & DF_ISPROCESSING), "A turret without anything in its sensor field started processing.")
	for(var/step in 1 to 3)
		TEST_ASSERT(pod.Move(get_step(pod, WEST), WEST, 0, FALSE), "The occupied hull could not enter the sensor field.")
	TEST_ASSERT(pod in turret.tracker.tracking, "The turret sensor did not discover the occupied hull.")
	TEST_ASSERT(turret.datum_flags & DF_ISPROCESSING, "The occupied hull did not wake the native turret processor.")
	for(var/step in 1 to 3)
		TEST_ASSERT(pod.Move(get_step(pod, EAST), EAST, 0, FALSE), "The occupied hull could not leave the sensor field.")
	TEST_ASSERT(!(pod in turret.tracker.tracking), "The sensor retained a hull beyond its field.")
	TEST_ASSERT(!(turret.datum_flags & DF_ISPROCESSING), "Leaving the sensor field did not stop turret processing.")
	for(var/step in 1 to 3)
		TEST_ASSERT(pod.Move(get_step(pod, WEST), WEST, 0, FALSE), "The occupied hull could not re-enter the sensor field.")
	TEST_ASSERT(turret.datum_flags & DF_ISPROCESSING, "Returning the occupied hull did not wake the turret again.")
	pod.pilot.set_faction(turret.get_faction())
	qdel(pod)
	TEST_ASSERT(!length(turret.tracker.tracking), "Deleting the hull left a stale sensor target.")
	TEST_ASSERT(!(turret.datum_flags & DF_ISPROCESSING), "Deleting the last hull left turret processing active.")

/// Observe real ruin-turret fire without replacing acquisition, shooting or projectile impacts.
/datum/unit_test/spacepod_turret_targeting
	parent_type = /datum/unit_test/spacepod_vacuum
	/// Native shots observed in the current turret case.
	var/shots = 0
	/// Record identity without retaining a target beyond fixture teardown.
	var/last_target_ref

/datum/unit_test/spacepod_turret_targeting/proc/on_projectile(datum/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	allocated |= projectile
	shots++
	last_target_ref = REF(projectile.original)

/datum/unit_test/spacepod_turret_targeting/Run()
	for(var/turret_type in list(/obj/machinery/porta_turret/syndicate/energy/ruin, /obj/machinery/porta_turret/syndicate/pod))
		shots = 0
		last_target_ref = null
		var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
		STOP_PROCESSING(SSobj, pod)
		var/obj/machinery/porta_turret/turret = allocate(turret_type, locate(pod.x + 4, pod.y, pod.z))
		RegisterSignal(turret, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_projectile))
		var/ready_deadline = world.time + 3 SECONDS
		while((!turret.raised || turret.last_fired + turret.shot_delay > world.time) && world.time < ready_deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(turret.raised && turret.last_fired + turret.shot_delay <= world.time, "The native ruin turret did not finish its popup and initial cooldown.")
		turret.end_processing()
		turret.process()
		TEST_ASSERT_EQUAL(shots, 0, "A ruin turret fired at an empty pod.")
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
		var/list/neutral_faction = pilot.get_faction()
		neutral_faction = neutral_faction.Copy()
		var/obj/item/clothing/under/color/grey/uniform = allocate(__IMPLIED_TYPE__)
		TEST_ASSERT(pilot.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not equip the pilot's uniform before attaching its ID.")
		var/obj/item/card/id/advanced/id = allocate(__IMPLIED_TYPE__)
		id.set_access(list(ACCESS_SYNDICATE), FORCE_ADD_ALL)
		TEST_ASSERT(pilot.equip_to_slot_if_possible(id, ITEM_SLOT_ID), "Could not equip the ruin-access fixture card.")
		pilot.set_faction(turret.get_faction())
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The friendly turret-test pilot could not board.")
		turret.process()
		TEST_ASSERT_EQUAL(shots, 0, "A ruin turret fired at its own faction inside a pod.")
		pilot.set_faction(neutral_faction)
		if(istype(turret, /obj/machinery/porta_turret/syndicate/energy/ruin))
			turret.process()
			TEST_ASSERT_EQUAL(shots, 0, "The ruin turret ignored a crew member's authorized access card.")
		TEST_ASSERT(pilot.temporarilyRemoveItemFromInventory(id, force = TRUE), "Could not remove authorization before the dead-crew check.")
		pilot.death()
		turret.process()
		TEST_ASSERT_EQUAL(shots, 0, "A dead crew member made the pod a turret target.")
		qdel(pilot)
		pilot = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
		pilot.set_faction(turret.get_faction())
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The replacement friendly pilot could not board.")
		var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
		TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The hostile passenger could not board.")
		var/initial_hull = pod.get_integrity()
		var/pilot_health = pilot.health
		var/passenger_health = passenger.health
		turret.process()
		turret.end_processing()
		TEST_ASSERT_EQUAL(shots, 1, "The ruin turret did not fire exactly once at a pod with a hostile passenger.")
		TEST_ASSERT_EQUAL(last_target_ref, REF(pod), "The ruin turret aimed at hidden crew instead of the real hull.")
		var/hit_deadline = world.time + 3 SECONDS
		while(pod.get_integrity() == initial_hull && world.time < hit_deadline)
			sleep(world.tick_lag)
		TEST_ASSERT(pod.get_integrity() < initial_hull, "The real ruin-turret projectile did not damage the hull.")
		TEST_ASSERT_EQUAL(pilot.health, pilot_health, "The turret projectile bypassed the hull and hit the pilot.")
		TEST_ASSERT_EQUAL(passenger.health, passenger_health, "The turret projectile bypassed the hull and hit the passenger.")
		qdel(turret)
		qdel(pod)
		qdel(pilot)
		qdel(passenger)
		qdel(id)

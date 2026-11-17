/// Tests that every joinable roundstart job has a spawn point.
/datum/unit_test/maptest_job_roundstart_spawnpoints
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/maptest_job_roundstart_spawnpoints/Run()
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(job.spawn_positions <= 0)
			// Zero spawn positions means we don't need to care if they don't have a roundstart landmark
			continue
		var/atom/spawn_point = job.required_donator_level ? job.get_roundstart_spawn_point() : job.get_default_roundstart_spawn_point()
		if(spawn_point && get_turf(spawn_point) != get_turf(GET_ERROR_ROOM))
			continue

		TEST_FAIL("Job [job.title] ([job.type]) has no roundstart spawn point.")

/// Big Brother can spawn without claiming an AI core or its spawn landmark.
/datum/unit_test/maptest_human_ai_spawn
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/maptest_human_ai_spawn/Run()
	var/datum/job/human_ai/big_brother = SSjob.get_job_type(/datum/job/human_ai)
	if(!big_brother)
		return // This map or server can disable AI jobs.
	var/list/available_cores = GLOB.latejoin_ai_cores.Copy()
	var/turf/spawn_turf = get_turf(big_brother.get_latejoin_spawn_point())
	TEST_ASSERT(spawn_turf && spawn_turf != get_turf(GET_ERROR_ROOM), "Big Brother has no valid spawn turf.")
	TEST_ASSERT(!locate(/obj/effect/landmark/start/ai) in spawn_turf, "Big Brother spawns on a station AI landmark.")
	TEST_ASSERT_EQUAL(length(GLOB.latejoin_ai_cores), length(available_cores), "Big Brother consumed an AI core.")

	var/area/ai_chamber = GLOB.areas_by_type[/area/station/ai/satellite/chamber]
	if(!ai_chamber)
		return
	var/list/mapped_spawn_points = GLOB.jobspawn_overrides[big_brother.title]
	if(length(mapped_spawn_points))
		GLOB.jobspawn_overrides -= big_brother.title
	GLOB.areas_by_type[/area/station/ai/satellite/chamber] = null
	var/area/fallback_area = get_area(big_brother.get_latejoin_spawn_point())
	GLOB.areas_by_type[/area/station/ai/satellite/chamber] = ai_chamber
	if(length(mapped_spawn_points))
		GLOB.jobspawn_overrides[big_brother.title] = mapped_spawn_points
	TEST_ASSERT(!istype(fallback_area, /area/station/command/bridge), "Big Brother has no command access to leave the bridge.")

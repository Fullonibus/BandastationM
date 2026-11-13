/// Map-specific jobs must keep their saved playtime in the shared experience categories.
/datum/unit_test/job_experience/Run()
	var/datum/job/spacepod_pilot/pilot = locate() in SSjob.experience_jobs_map[EXP_TYPE_CREW]
	TEST_ASSERT_NOTNULL(pilot, "Spacepod Pilot playtime is missing from crew experience on this map.")
	TEST_ASSERT(pilot in SSjob.experience_jobs_map[EXP_TYPE_SECURITY], "Spacepod Pilot playtime is missing from security experience on this map.")

	for(var/experience_type in SSjob.experience_jobs_map)
		var/list/unique_jobs = list()
		for(var/datum/job/job as anything in SSjob.experience_jobs_map[experience_type])
			TEST_ASSERT(!(job in unique_jobs), "[job] would count more than once toward [experience_type] experience.")
			unique_jobs += job

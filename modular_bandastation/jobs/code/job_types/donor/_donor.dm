// Role designs adapted from https://github.com/ss220club/Paradise-SS220/tree/0fffca1f1f29a63aff49d9b56524813eedf82c6d/modular_ss220/jobs/code/donor
/datum/job/donor
	abstract_type = /datum/job/donor
	faction = FACTION_STATION
	supervisors = JOB_HEAD_OF_PERSONNEL_RU
	exp_granted_type = EXP_TYPE_CREW
	departments_list = list(/datum/job_department/service)
	paycheck = PAYCHECK_LOWER
	paycheck_department = ACCOUNT_SRV
	plasmaman_outfit = /datum/outfit/plasmaman
	job_flags = (STATION_JOB_FLAGS | JOB_CANNOT_OPEN_SLOTS) & ~JOB_CAN_BE_INTERN
	allow_bureaucratic_error = FALSE
	random_spawns_possible = FALSE
	/// A regular job landmark the donor role may share at roundstart.
	var/donor_spawn_landmark

/datum/job/donor/config_check()
	return type != abstract_type && ..()

/datum/job/donor/get_default_roundstart_spawn_point()
	if(donor_spawn_landmark)
		for(var/obj/effect/landmark/start/spawn_point as anything in GLOB.start_landmarks_list)
			if(spawn_point.name == donor_spawn_landmark)
				return spawn_point
	return ..()

/datum/id_trim/job/donor
	trim_icon = 'modular_bandastation/jobs/icons/obj/donor_id_trims.dmi'
	trim_state = null
	department_color = COLOR_SERVICE_LIME
	subdepartment_color = COLOR_SERVICE_LIME
	sechud_icon = 'modular_bandastation/jobs/icons/donor_job_hud.dmi'
	minimal_access = list(ACCESS_MAINT_TUNNELS)
	template_access = null

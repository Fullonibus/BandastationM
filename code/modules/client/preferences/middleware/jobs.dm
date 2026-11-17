/datum/preference_middleware/jobs
	action_delegations = list(
		"set_job_preference" = PROC_REF(set_job_preference),
		"set_job_to_profile" = PROC_REF(set_job_to_profile),
		"set_donor_job_title" = PROC_REF(set_donor_job_title),
	)

/datum/preference_middleware/jobs/proc/set_job_preference(list/params, mob/user)
	var/job_title = params["job"]
	var/level = params["level"]

	if (level != null && level != JP_LOW && level != JP_MEDIUM && level != JP_HIGH)
		return FALSE

	var/datum/job/job = SSjob.get_job(job_title)

	if (isnull(job))
		return FALSE

	if (job.faction != FACTION_STATION)
		return FALSE
	if (!isnull(level) && !job.can_access_donor_job(user.client))
		return FALSE

	if (!preferences.set_job_preference_level(job, level))
		return FALSE

	preferences.character_preview_view?.update_body()

	return TRUE

/datum/preference_middleware/jobs/proc/set_job_to_profile(list/params, mob/user)
	var/job_title = params["job"]
	var/profile_slot = params["profile"]
	var/datum/job/job = SSjob.get_job(job_title)
	if (!job || job.faction != FACTION_STATION || !isnum(profile_slot))
		return FALSE
	if (profile_slot == -1)
		LAZYREMOVE(preferences.job_assigned_profiles, job_title)
		LAZYREMOVE(preferences.pref_job_slots, job_title)
		return TRUE
	if (round(profile_slot) != profile_slot || profile_slot < 1 || profile_slot > preferences.max_save_slots)
		return FALSE
	if (profile_slot != preferences.default_slot && !preferences.can_load_job_profile(preferences.savefile.get_entry("character[profile_slot]")))
		return FALSE

	LAZYSET(preferences.job_assigned_profiles, job_title, profile_slot)
	return TRUE

/datum/preference_middleware/jobs/proc/set_donor_job_title(list/params, mob/user)
	var/datum/job/donor/job = SSjob.get_job(params["job"])
	var/public_title = params["title"]
	if(!istype(job) || !istext(public_title) || !(public_title in job.alternate_titles) || !job.can_access_donor_job(user.client))
		return FALSE
	var/datum/job_character_selection/selection = preferences.select_job_character(job)
	var/slot = selection.slot
	var/error = selection.error
	qdel(selection)
	if(error)
		return FALSE
	var/datum/preference/title_preference = GLOB.preference_entries[/datum/preference/donor_job_titles]
	if(slot == preferences.default_slot)
		var/list/titles = preferences.read_preference(title_preference.type)
		titles = titles.Copy()
		titles[job.title] = public_title
		return preferences.write_preference(title_preference, titles)
	var/list/profile = preferences.savefile.get_entry("character[slot]")
	var/list/titles = title_preference.read(profile, preferences) || list()
	titles[job.title] = public_title
	if(!title_preference.write(profile, titles, preferences))
		return FALSE
	preferences.savefile.save()
	return TRUE

/datum/preference_middleware/jobs/get_constant_data()
	var/list/data = list()

	var/list/departments = list()
	var/list/jobs = list()
	var/list/jobs_sorted = list()

	for (var/datum/job/job as anything in SSjob.joinable_occupations)
		if ((job.job_flags & JOB_LATEJOIN_ONLY) && !job.donor_unlock_trait)
			continue
		var/datum/job_department/department_type = job.department_for_prefs || job.departments_list?[1]
		if (isnull(department_type))
			stack_trace("[job] does not have a department set, yet is a joinable occupation!")
			continue

		if (isnull(job.description))
			stack_trace("[job] does not have a description set, yet is a joinable occupation!")
			continue

		var/department_name = initial(department_type.department_name)
		if (isnull(departments[department_name]))
			var/datum/job/department_head_type = initial(department_type.department_head)

			departments[department_name] = list(
				"head" = department_head_type && initial(department_head_type.title),
				"color" = department_type.ui_color, // Prob shouldnt be here.
			)

		// Use the built in sorting of the main occupation list to keep it sorted how we want instead of asc
		jobs_sorted += job.title

		jobs[job.title] = list(
			"description" = job.description,
			"department" = department_name,
			"donor_tier" = job.required_donator_level,
		)
		if(job.required_donator_level)
			jobs[job.title]["job_icon"] = icon2base64(get_job_hud_icon(job))
		if(istype(job, /datum/job/donor))
			jobs[job.title]["variant_titles"] = job.alternate_titles

	data["departments"] = departments
	data["jobs"] = jobs
	data["jobs_sorted"] = jobs_sorted

	return data

/datum/preference_middleware/jobs/get_ui_data(mob/user)
	var/list/data = list()
	var/list/locked_donor_jobs = list()
	var/list/donor_job_titles = list()
	for(var/datum/job/job as anything in SSjob.joinable_occupations)
		if(!job.can_access_donor_job(user.client))
			locked_donor_jobs[job.title] = job.required_donator_level
		if(istype(job, /datum/job/donor))
			var/datum/job_character_selection/selection = preferences.select_job_character(job)
			if(!selection.error)
				donor_job_titles[job.title] = preferences.get_donor_job_title(job, selection.slot)
			qdel(selection)
	data["locked_donor_jobs"] = locked_donor_jobs
	data["donor_job_titles"] = donor_job_titles

	data["job_preferences"] = list()
	for(var/job, priority in preferences.job_preferences)
		data["job_preferences"] += list(list(
			"job" = job,
			"priority" = priority,
			"assigned_profile_slot" = LAZYACCESS(preferences.job_assigned_profiles, job),
		))

	for(var/job, slot in SANITIZE_LIST(preferences.job_assigned_profiles) - SANITIZE_LIST(preferences.job_preferences))
		data["job_preferences"] += list(list(
			"job" = job,
			"priority" = null,
			"assigned_profile_slot" = slot,
		))

	return data

/datum/preference_middleware/jobs/get_ui_static_data(mob/user)
	var/list/data = list()

	var/list/required_job_playtime = get_required_job_playtime(user)
	if (!isnull(required_job_playtime))
		data += required_job_playtime

	var/list/job_bans = get_job_bans(user)
	if (job_bans.len)
		data["job_bans"] = job_bans

	return data.len > 0 ? data : null

/datum/preference_middleware/jobs/proc/get_required_job_playtime(mob/user)
	var/list/data = list()

	var/list/job_days_left = list()
	var/list/job_required_experience = list()

	for (var/datum/job/job as anything in SSjob.all_occupations)
		if ((job.job_flags & JOB_LATEJOIN_ONLY) && !job.donor_unlock_trait)
			continue
		var/required_playtime_remaining = job.required_playtime_remaining(user.client)
		if (required_playtime_remaining)
			job_required_experience[job.title] = list(
				"experience_type" = job.get_exp_req_type(),
				"required_playtime" = required_playtime_remaining,
			)

			continue

		if (!job.player_old_enough(user.client))
			job_days_left[job.title] = job.available_in_days(user.client)

	if (job_days_left.len)
		data["job_days_left"] = job_days_left

	if (job_required_experience)
		data["job_required_experience"] = job_required_experience

	return data

/datum/preference_middleware/jobs/proc/get_job_bans(mob/user)
	var/list/data = list()

	for (var/datum/job/job as anything in SSjob.all_occupations)
		if (job.is_role_banned(user.client?.ckey))
			data += job.title

	return data

#define JOB_SLOT_RANDOMISED_SLOT -1
#define JOB_SLOT_CURRENT_SLOT 0
#define JOB_SLOT_RANDOMISED_TEXT "Случайное имя и внешность"
#define JOB_SLOT_CURRENT_TEXT "Текущий слот"

/datum/preferences
	/// Assoc list of [job title] = [slot number]. Stores which character slot to use for each job.
	var/list/pref_job_slots = list()

/mob/dead/new_player
	/// The character slot reserved along with this player's job.
	var/datum/job_character_selection/assigned_job_character

/datum/job_character_selection
	var/slot
	var/randomized = FALSE
	var/age
	var/species
	var/error

/// Resolve an assigned profile without loading it into the player's editor.
/datum/preferences/proc/select_job_character(datum/job/job, latejoin = FALSE, forced_slot)
	var/datum/job_character_selection/selection = new
	selection.slot = default_slot
	var/use_current = latejoin ? read_preference(/datum/preference/toggle/late_join_always_current_slot) : read_preference(/datum/preference/toggle/round_start_always_join_current_slot)
	if(!isnull(forced_slot))
		selection.slot = forced_slot
	else if(!use_current)
		var/requested_slot = job_assigned_profiles?[job.title]
		if(isnull(requested_slot))
			requested_slot = pref_job_slots?[job.title]
		if(requested_slot == JOB_SLOT_RANDOMISED_SLOT)
			selection.randomized = TRUE
		else if(!isnull(requested_slot) && requested_slot != JOB_SLOT_CURRENT_SLOT)
			selection.slot = requested_slot

	if(!isnum(selection.slot) || round(selection.slot) != selection.slot || selection.slot < 1 || selection.slot > max_save_slots)
		selection.error = "Некорректный слот персонажа."
		return selection
	if(selection.slot == default_slot)
		selection.age = read_preference(/datum/preference/numeric/age)
		selection.species = read_preference(/datum/preference/choiced/species)
		return selection

	var/list/profile = savefile.get_entry("character[selection.slot]")
	if(!can_load_job_profile(profile))
		selection.error = "Назначенный профиль персонажа отсутствует."
		return selection
	var/datum/preference/age_preference = GLOB.preference_entries[/datum/preference/numeric/age]
	var/datum/preference/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	selection.age = age_preference.read(profile, src)
	selection.species = species_preference.read(profile, src) || /datum/species/human
	if(!can_select_character_species(selection.species))
		selection.species = /datum/species/human
	return selection

/datum/job_character_selection/proc/get_eligibility(datum/job/job)
	if(error)
		return JOB_UNAVAILABLE_PROFILE
	if(randomized)
		return JOB_AVAILABLE
	if(isnum(job.required_character_age) && (!isnum(age) || age < job.required_character_age))
		return JOB_UNAVAILABLE_AGE
	if(!job.is_character_species_allowed(species))
		return JOB_UNAVAILABLE_SPECIES
	return JOB_AVAILABLE

/datum/job/proc/is_character_species_allowed(species_type)
	if(!ispath(spawn_type, /mob/living/carbon/human) || !(title in CONFIG_GET(str_list/job_restrictions)))
		return TRUE
	if(locate(/datum/station_trait/xenobureaucracy_error) in GLOB.lobby_station_traits)
		return TRUE
	var/list/allowed_species = CONFIG_GET(str_list/allowed_species)
	return !length(allowed_species) || ("[species_type]" in allowed_species)

/datum/preferences/proc/has_species_restricted_job_preferences()
	for(var/job_title in job_preferences)
		var/datum/job/job = SSjob.get_job(job_title)
		if(!job)
			continue
		var/datum/job_character_selection/selection = select_job_character(job)
		var/restricted = !selection.error && !selection.randomized && !job.is_character_species_allowed(selection.species)
		qdel(selection)
		if(restricted)
			return TRUE
	return FALSE

/**
 * Generates available slot selection options
 *
 * Returns associative list of slot IDs to display names, including:
 * - Current slot
 * - All saved character slots
 * - Randomized appearance option
 *
 * Format: list("[slot_id]" = "[display_name]")
 */
/datum/preferences/proc/get_slot_options()
	var/list/slot_options = list(num2text(JOB_SLOT_CURRENT_SLOT) = JOB_SLOT_CURRENT_TEXT)
	var/real_name = read_preference(/datum/preference/name/real_name)
	for(var/index in 1 to max_save_slots)
		var/slot_name = (index == default_slot) \
			? real_name \
			: savefile.get_entry("character[index]")?["real_name"]

		if(slot_name)
			slot_options[num2text(index)] = slot_name

	return slot_options += list(num2text(JOB_SLOT_RANDOMISED_SLOT) = JOB_SLOT_RANDOMISED_TEXT)

/// Resets pref_job_slots to empty list and saves preferences
/datum/preferences/proc/reset_job_slots()
	pref_job_slots = list()
	save_preferences()

/**
 * Loads assigned character slot for a job
 *
 * Loads appropriate character slot for the given job as assigned in preferences,
 *
 * Arguments:
 * * job_title - Job title to load configuration for
 * * is_late_join - Whether this is for late join
 *
 * Returns TRUE if randomized appearance should be used
 */
/datum/preferences/proc/set_assigned_slot(job_title, is_late_join = FALSE)
	if(is_late_join ? read_preference(/datum/preference/toggle/late_join_always_current_slot) : read_preference(/datum/preference/toggle/round_start_always_join_current_slot))
		return
	var/slot = pref_job_slots[job_title] || JOB_SLOT_CURRENT_SLOT
	switch(slot)
		if(JOB_SLOT_RANDOMISED_SLOT)
			return TRUE
		if(JOB_SLOT_CURRENT_SLOT)
			return

	if(slot != default_slot)
		switch_to_slot(slot)

/// Whether joining at roundstart ignores assigned character slot for the job and uses currently selected slot.
/datum/preference/toggle/round_start_always_join_current_slot
	savefile_key = "round_start_always_join_current_slot"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = FALSE
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES

/// Whether joining during the round ignores assigned character slot for the job and uses currently selected slot.
/datum/preference/toggle/late_join_always_current_slot
	savefile_key = "late_join_always_current_slot"
	savefile_identifier = PREFERENCE_PLAYER
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES

#undef JOB_SLOT_RANDOMISED_TEXT
#undef JOB_SLOT_CURRENT_TEXT

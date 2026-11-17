/datum/preference/donor_job_titles
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "donor_job_titles"
	can_randomize = FALSE

/datum/preference/donor_job_titles/create_default_value()
	return list()

/datum/preference/donor_job_titles/deserialize(input, datum/preferences/preferences)
	var/list/titles = list()
	if(islist(input))
		for(var/job_title in input)
			var/datum/job/donor/job = SSjob.get_job(job_title)
			if(istype(job) && (input[job_title] in job.alternate_titles))
				titles[job_title] = input[job_title]
	return titles

/datum/preference/donor_job_titles/is_valid(value, datum/preferences/preferences)
	return islist(value)

/datum/preference/donor_job_titles/should_show_on_page(preference_tab)
	return FALSE

/datum/preference/donor_job_titles/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/// A public title only. The job, outfit, bans and vacancy remain shared by all titles.
/datum/preferences/proc/get_donor_job_title(datum/job/job, slot = default_slot)
	if(!istype(job, /datum/job/donor))
		return null
	var/list/titles
	if(slot == default_slot)
		titles = read_preference(/datum/preference/donor_job_titles)
	else
		var/datum/preference/title_preference = GLOB.preference_entries[/datum/preference/donor_job_titles]
		titles = title_preference.read(savefile.get_entry("character[slot]"), src)
	var/selected_title = titles?[job.title]
	return (selected_title in job.alternate_titles) ? selected_title : null

/datum/job/donor/after_spawn(mob/living/spawned, client/player_client)
	. = ..()
	var/mob/living/carbon/human/human = spawned
	if(!istype(human))
		return
	var/public_title = player_client?.prefs?.get_donor_job_title(src)
	if(!public_title)
		return
	var/obj/item/card/id/advanced/card = human.get_idcard(FALSE)
	if(!istype(card))
		return
	card.assignment = public_title
	card.job_variant_title = public_title
	card.update_label()
	human.update_ID_card()

	var/datum/outfit/job/job_outfit = outfit
	if(job_outfit::pda_slot)
		var/obj/item/modular_computer/pda/pda = human.get_item_by_slot(job_outfit::pda_slot)
		if(istype(pda))
			pda.imprint_id(human.real_name, public_title)

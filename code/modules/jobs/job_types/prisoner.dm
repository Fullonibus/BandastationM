/datum/job/prisoner
	title = JOB_PRISONER
	description = "Окажитесь заточенным в пермабриге."
	faction = FACTION_STATION
	total_positions = 0
	spawn_positions = 4
	supervisors = "Службой Безопасности"
	exp_granted_type = EXP_TYPE_CREW
	paycheck = PAYCHECK_LOWER
	config_tag = "PRISONER"

	outfit = /datum/outfit/job/prisoner
	plasmaman_outfit = /datum/outfit/plasmaman/prisoner

	display_order = JOB_DISPLAY_ORDER_PRISONER
	department_for_prefs = /datum/job_department/security

	exclusive_mail_goodies = TRUE
	mail_goodies = list (
		/obj/effect/spawner/random/contraband/prison = 1
	)

	family_heirlooms = list(/obj/item/pen/blue)
	rpg_title = "Defeated Miniboss"
	job_flags = (STATION_JOB_FLAGS | JOB_CANNOT_OPEN_SLOTS | JOB_ANTAG_PROTECTED) & ~JOB_REOPEN_ON_ROUNDSTART_LOSS
	tgui_icon = FA_ICON_LOCK

/mob/living/carbon/human
	/// The crime selected for this prisoner at spawn, shared by the record and outfit.
	var/datum/prisoner_crime/initial_prisoner_crime
	/// Whether this body has already received its prison tattoos.
	var/prison_tattoos_applied = FALSE

/datum/job/prisoner/get_spawn_mob(client/player_client, atom/spawn_point)
	. = ..()
	var/mob/living/carbon/human/prisoner = .
	if(!istype(prisoner))
		return
	var/crime_name = player_client?.prefs?.read_preference(/datum/preference/choiced/prisoner_crime)
	prisoner.initial_prisoner_crime = GLOB.prisoner_crimes[crime_name] || pick(assoc_to_values(GLOB.prisoner_crimes))

/datum/job/prisoner/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_CREWMEMBER_JOINED, PROC_REF(handle_prisoner_joining))

/datum/job/prisoner/proc/handle_prisoner_joining(datum/source, mob/living/crewmember, rank)
	SIGNAL_HANDLER
	if(rank != title || !ishuman(crewmember))
		return
	var/mob/living/carbon/human/prisoner = crewmember
	if(prisoner.initial_prisoner_crime)
		to_chat(prisoner, span_warning("You are imprisoned for \"[prisoner.initial_prisoner_crime.name]\"."))

/// Sets up the exact record created by the initial spawn, before any in-game edits.
/datum/job/prisoner/proc/register_initial_prisoner_record(mob/living/carbon/human/prisoner, datum/record/crew/crew_record)
	var/datum/prisoner_crime/crime = prisoner.initial_prisoner_crime
	if(!crime)
		return
	var/datum/crime/past_crime = new(crime.name, crime.desc, "Central Command", "Indefinite.")
	crew_record.crimes += past_crime
	crew_record.wanted_status = WANTED_PRISONER
	prisoner.sec_hud_set_security_status()
	crew_record.recreate_manifest_photos(add_height_chart = TRUE)
	prisoner.add_mob_memory(/datum/memory/key/permabrig_crimes, crimes = crime.name)

/datum/outfit/job/prisoner
	name = "Prisoner"
	jobtype = /datum/job/prisoner

	id = /obj/item/card/id/advanced/prisoner
	id_trim = /datum/id_trim/job/prisoner
	uniform = /obj/item/clothing/under/rank/prisoner
	belt = null
	// AI EDIT START - Support independent left and right ear slots
	ear_right = null // BANDASTATION EDIT - Dual ear slots
	// AI EDIT END
	shoes = /obj/item/clothing/shoes/sneakers/orange
	box = /obj/item/storage/box/survival/prisoner
	pda_slot = null

/datum/outfit/job/prisoner/pre_equip(mob/living/carbon/human/H)
	..()
	if(prob(1)) // D BOYYYYSSSSS
		head = /obj/item/clothing/head/beanie/black/dboy

/datum/outfit/job/prisoner/post_equip(mob/living/carbon/human/new_prisoner, visuals_only)
	. = ..()

	var/datum/prisoner_crime/crime = new_prisoner.initial_prisoner_crime
	if(visuals_only || !crime || new_prisoner.prison_tattoos_applied)
		return
	new_prisoner.prison_tattoos_applied = TRUE
	var/list/limbs_to_tat = new_prisoner.get_bodyparts()
	for(var/i in 1 to crime.tattoos)
		if(!length(SSpersistence.prison_tattoos_to_use) || !length(limbs_to_tat))
			return
		var/obj/item/bodypart/tatted_limb = pick_n_take(limbs_to_tat)
		var/list/tattoo = pick_n_take(SSpersistence.prison_tattoos_to_use)
		tatted_limb.AddComponent(/datum/component/tattoo, tattoo["story"])

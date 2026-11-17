/// This test spawns various station traits and looks through them to see if there's any errors.
/datum/unit_test/station_traits

/datum/unit_test/station_traits/Run()
	var/datum/station_trait/cybernetic_revolution/cyber_trait = allocate(/datum/station_trait/cybernetic_revolution)
	for(var/datum/job/job as anything in subtypesof(/datum/job))
		if(initial(job.abstract_type) == job)
			continue
		if(!(initial(job.job_flags) & JOB_CREW_MEMBER))
			continue
		if((initial(job.job_flags) & STATION_TRAIT_JOB_FLAGS) == STATION_TRAIT_JOB_FLAGS)
			continue
		if(!(job in cyber_trait.job_to_cybernetic))
			TEST_FAIL("Job [job] does not have an assigned cybernetic for [cyber_trait.type] station trait.")

/datum/unit_test/donor_job_access
	var/datum/station_trait/job/veteran_advisor/veteran_trait

/datum/unit_test/donor_job_access/Run()
	var/datum/job/barber = allocate(/datum/job/donor/barber)
	var/datum/job/veteran = allocate(/datum/job/veteran_advisor)
	var/datum/client_interface/player_client = allocate(/datum/client_interface)
	TEST_ASSERT(!barber.can_access_donor_job(player_client), "A non-donor can select Barber.")
	TEST_ASSERT(!veteran.can_access_donor_job(player_client), "A non-donor can select Veteran without the trait.")

	player_client.donator_level = DONATOR_TIER_2
	TEST_ASSERT(barber.can_access_donor_job(player_client), "A higher tier did not unlock Barber.")
	TEST_ASSERT(!veteran.can_access_donor_job(player_client), "A lower tier unlocked Veteran without the trait.")
	player_client.donator_level = DONATOR_TIER_3
	TEST_ASSERT(veteran.can_access_donor_job(player_client), "The required tier did not unlock Veteran.")

	veteran_trait = allocate(/datum/station_trait/job/veteran_advisor)
	SSstation.station_traits += veteran_trait
	player_client.donator_level = BASIC_DONATOR_LEVEL
	TEST_ASSERT(veteran.can_access_donor_job(player_client), "The Veteran trait did not unlock Veteran for a non-donor.")
	TEST_ASSERT(!barber.can_access_donor_job(player_client), "The Veteran trait unlocked an unrelated donor job.")

/datum/unit_test/donor_job_access/Destroy()
	SSstation.station_traits -= veteran_trait
	veteran_trait = null
	return ..()

/datum/unit_test/donor_newscaster_access/Run()
	var/obj/machinery/newscaster/newscaster = allocate(/obj/machinery/newscaster, run_loc_floor_bottom_left)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	SSid_access.apply_trim_to_card(card, /datum/id_trim/job/donor/barber)
	TEST_ASSERT(ACCESS_LIBRARY in card.GetAccess(), "Barber lost library door access.")
	TEST_ASSERT(!newscaster.has_moderation_access(card), "A donor card grants Newscaster moderation through library access.")
	SSid_access.apply_trim_to_card(card, /datum/id_trim/job/curator)
	TEST_ASSERT(newscaster.has_moderation_access(card), "Curator lost Newscaster moderation access.")

/datum/unit_test/donor_navy_junior_officer_access/Run()
	var/obj/item/card/id/advanced/gold/captain_card = allocate(/obj/item/card/id/advanced/gold)
	var/obj/item/card/id/advanced/officer_card = allocate(/obj/item/card/id/advanced/nanotrasen_official/navy_junior_officer)
	TEST_ASSERT(SSid_access.apply_trim_to_card(captain_card, /datum/id_trim/job/captain), "The Captain's card rejected its trim.")
	TEST_ASSERT(SSid_access.apply_trim_to_card(officer_card, /datum/id_trim/job/donor/navy_junior_officer), "The Junior Officer's card rejected its trim.")
	var/list/expected_access = captain_card.GetAccess() | list(ACCESS_CENT_GENERAL, ACCESS_CENT_LIVING)
	var/list/officer_access = officer_card.GetAccess()
	TEST_ASSERT_EQUAL(length(expected_access - officer_access), 0, "The Junior Officer's card is missing expected access.")
	TEST_ASSERT_EQUAL(length(officer_access - expected_access), 0, "The Junior Officer's card has extra access.")

/datum/unit_test/donor_job_card_art/Run()
	var/list/faction_cards = list(
		/datum/job/donor/tourist_tsf = /obj/item/card/id/advanced/tsf/donor,
		/datum/job/donor/representative_tsf = /obj/item/card/id/advanced/tsf/donor,
		/datum/job/donor/tourist_ussp = /obj/item/card/id/advanced/ussp/donor,
		/datum/job/donor/representative_ussp = /obj/item/card/id/advanced/ussp/donor,
	)
	for(var/datum/job/job as anything in SSjob.all_occupations)
		if(!job.required_donator_level)
			continue
		TEST_ASSERT(get_job_hud_icon(job), "[job.title] did not have a lobby icon.")
		if(!job.outfit)
			continue
		var/mob/living/carbon/human/dummy/consistent/model = allocate(/mob/living/carbon/human/dummy/consistent, run_loc_floor_bottom_left)
		model.job = job.title
		model.equipOutfit(job.outfit)
		var/obj/item/card/id/advanced/card = model.get_idcard(FALSE)
		TEST_ASSERT(istype(card) && length(card.GetAccess()), "[job.title] did not receive a working ID.")
		TEST_ASSERT(card.icon_state in icon_states(card.icon), "[job.title] has a missing ID card body.")
		TEST_ASSERT(card.trim?.trim_state in icon_states(card.trim?.trim_icon), "[job.title] has a missing ID trim.")
		TEST_ASSERT(card.trim?.sechud_icon_state in icon_states(card.trim?.sechud_icon), "[job.title] has a missing HUD icon.")
		if(job.type in faction_cards)
			TEST_ASSERT_EQUAL(card.type, faction_cards[job.type], "[job.title] did not receive a faction card.")
			TEST_ASSERT(!(ACCESS_CENT_GENERAL in card.GetAccess()), "[job.title] inherited Central Command access from the faction card.")

	var/obj/item/card/id/advanced/reprinted_card = allocate(/obj/item/card/id/advanced)
	SSid_access.apply_trim_to_card(reprinted_card, /datum/id_trim/job/donor/waiter)
	reprinted_card.job_variant_title = "Хост сервиса"
	TEST_ASSERT_EQUAL(reprinted_card.get_trim_assignment(), "Хост сервиса", "The issued card hid the selected job title.")
	SSid_access.apply_trim_to_card(reprinted_card, /datum/id_trim/job/assistant)
	TEST_ASSERT_EQUAL(reprinted_card.get_trim_assignment(), reprinted_card.trim.assignment, "Reprinting a card retained its old job variant.")

/datum/unit_test/donor_crew_monitor/Run()
	var/list/expected_departments = list(
		/datum/job/donor/representative_tsf = 10,
		/datum/job/donor/representative_ussp = 10,
		/datum/job/donor/barber = 80,
		/datum/job/donor/waiter = 80,
		/datum/job/donor/administrator = 80,
		/datum/job/donor/guard = 80,
		/datum/job/donor/dealer = 80,
		/datum/job/donor/banker = 80,
		/datum/job/donor/tourist_tsf = 80,
		/datum/job/donor/tourist_ussp = 80,
		/datum/job/donor/migrant = 80,
		/datum/job/donor/navy_junior_officer = 200,
	)
	var/list/crew = list()
	for(var/job_type in expected_departments)
		var/datum/job/job = SSjob.get_job_type(job_type)
		var/mob/living/carbon/human/consistent/member = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
		member.job = job.title
		member.equipOutfit(job.outfit)
		var/obj/item/card/id/card = member.get_idcard(hand_first = FALSE)
		var/public_title = job.alternate_titles[length(job.alternate_titles)]
		card.job_variant_title = public_title
		card.assignment = public_title
		var/obj/item/clothing/under/uniform = member.w_uniform
		uniform.set_sensor_mode(SENSOR_COORDS)
		crew[REF(member)] = job

	var/datum/crewmonitor/monitor = allocate(/datum/crewmonitor)
	for(var/list/entry as anything in monitor.update_data(run_loc_floor_bottom_left.z))
		var/datum/job/job = crew[entry["ref"]]
		if(!job)
			continue
		var/department = expected_departments[job.type]
		var/job_id = entry["ijob"]
		var/department_end = department + 10
		switch(department)
			if(80)
				department_end = 200
			if(200)
				department_end = 230
		TEST_ASSERT_EQUAL(entry["assignment"], job.alternate_titles[length(job.alternate_titles)], "The monitor lost the chosen title for [job.title].")
		if(job_id <= department || job_id >= department_end || !(job_id % 10))
			TEST_FAIL("The monitor gave [job.title] an incorrect job ID: [job_id].")
		crew -= entry["ref"]
	TEST_ASSERT_EQUAL(length(crew), 0, "The monitor did not report every active donor sensor.")

/datum/unit_test/donor_medical_record_icon/Run()
	var/obj/machinery/computer/records/medical/console = allocate(/obj/machinery/computer/records/medical)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/datum/record/crew/officer_record = allocate(/datum/record/crew)
	officer_record.rank = "Младший офицер флота Нанотрейзен"
	officer_record.trim = officer_record.rank
	var/list/data = console.ui_data(user)
	for(var/list/entry as anything in data["records"])
		if(entry["crew_ref"] != REF(officer_record))
			continue
		TEST_ASSERT_EQUAL(entry["rank"], officer_record.rank, "The medical record lost the chosen title.")
		TEST_ASSERT_EQUAL(entry["job_icon"], FA_ICON_ANCHOR, "The medical record lost the junior officer's icon.")
		return
	TEST_FAIL("The junior officer's record was missing from the medical console.")

/datum/unit_test/donor_dealer_card_access/Run()
	var/mob/living/carbon/human/dummy/consistent/dealer = allocate(/mob/living/carbon/human/dummy/consistent)
	dealer.equipOutfit(/datum/outfit/job/donor/dealer)
	var/obj/item/card/id/card = dealer.get_idcard(hand_first = FALSE)
	TEST_ASSERT_NOTNULL(card, "The Dealer did not receive an ID.")
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock)
	door.req_access = list(ACCESS_SERVICE)
	if(!door.check_access(card))
		TEST_FAIL("The Dealer could not open a service door.")
	for(var/supply_access in list(ACCESS_CARGO, ACCESS_SHIPPING, ACCESS_MINERAL_STOREROOM))
		door.req_access = list(supply_access)
		if(door.check_access(card))
			TEST_FAIL("The Dealer could open a door with [supply_access].")

/datum/unit_test/prisoner_initial_record
	var/mob/living/carbon/human/dummy/consistent/prisoner

/datum/unit_test/prisoner_initial_record/Run()
	var/datum/job/prisoner/prisoner_job = SSjob.get_job_type(/datum/job/prisoner)
	TEST_ASSERT_NOTNULL(prisoner_job, "The fixture needs the canonical prisoner job.")
	prisoner = allocate(/mob/living/carbon/human/dummy/consistent)
	prisoner.real_name = "Prisoner Record Test"
	prisoner.mind = allocate(/datum/mind)
	prisoner.mind.set_assigned_role(prisoner_job)
	var/datum/prisoner_crime/selected_crime = GLOB.prisoner_crimes["Tax Evasion"]
	TEST_ASSERT_NOTNULL(selected_crime, "The fixture crime is missing.")
	prisoner.initial_prisoner_crime = selected_crime

	var/list/previous_crew_records = GLOB.manifest.general.Copy()
	var/list/previous_locked_records = GLOB.manifest.locked.Copy()
	GLOB.manifest.inject(prisoner, initial_join = TRUE)
	GLOB.manifest.inject(prisoner)
	var/list/new_crew_records = GLOB.manifest.general - previous_crew_records
	var/list/new_locked_records = GLOB.manifest.locked - previous_locked_records
	allocated += new_crew_records + new_locked_records
	for(var/datum/record/crew/record as anything in new_crew_records)
		allocated += record.crimes
	for(var/datum/record/locked/record as anything in new_locked_records)
		allocated += record.locked_dna

	TEST_ASSERT_EQUAL(length(new_crew_records), 2, "Each injection should create one crew record.")
	var/datum/record/crew/initial_record = new_crew_records[1]
	var/datum/record/crew/later_record = new_crew_records[2]
	TEST_ASSERT_EQUAL(initial_record.wanted_status, WANTED_PRISONER, "The initial record did not mark the prisoner as incarcerated.")
	TEST_ASSERT_EQUAL(length(initial_record.crimes), 1, "The initial record should have exactly one crime.")
	var/datum/crime/recorded_crime = initial_record.crimes[1]
	TEST_ASSERT_EQUAL(recorded_crime.name, selected_crime.name, "The record did not use the selected crime.")
	TEST_ASSERT_EQUAL(later_record.wanted_status, WANTED_NONE, "Ordinary injection applied the initial prisoner status.")
	TEST_ASSERT_EQUAL(length(later_record.crimes), 0, "Ordinary injection duplicated the prisoner's crime.")

/datum/unit_test/prisoner_initial_record/Destroy()
	if(!QDELETED(prisoner))
		prisoner.mind = null
	prisoner = null
	return ..()

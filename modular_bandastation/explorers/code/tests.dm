/// Isolated corps journal with a real surveyed specimen source.
/datum/unit_test/explorers_journal
	abstract_type = /datum/unit_test/explorers_journal
	/// Round archive replaced for isolation and restored in teardown.
	var/datum/expedition_journal/saved_journal
	/// Operator with normal action validation.
	var/mob/living/carbon/human/user
	/// Specimen source whose record the journal discloses.
	var/obj/structure/stationtrauma_research_source/source
	/// Shared discovery record of the source.
	var/datum/stationtrauma_research_record/record

/datum/unit_test/explorers_journal/New()
	..()
	saved_journal = GLOB.expedition_journal
	GLOB.expedition_journal = new
	user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	source = allocate(/obj/structure/stationtrauma_research_source, get_step(user, EAST))
	record = source.research_record()

/datum/unit_test/explorers_journal/Destroy()
	GLOB.expedition_journal = saved_journal
	saved_journal = null
	user = null
	source = null
	record = null
	return ..()

/// Disclose the source through the real field survey.
/datum/unit_test/explorers_journal/proc/survey()
	var/obj/item/excavation/depth_scanner/scanner = allocate(/obj/item/excavation/depth_scanner)
	user.put_in_active_hand(scanner)
	scanner.survey(source, user)
	user.dropItemToGround(scanner)

/// Survey, sampling and laboratory analysis of expedition specimens are recorded in the corps journal.
/datum/unit_test/explorers_journal/samples/Run()
	TEST_ASSERT(!(record.id in GLOB.expedition_records), "An unsurveyed source must not be disclosed")
	survey()
	TEST_ASSERT_EQUAL(GLOB.expedition_records[record.id], record, "A completed survey must publish the record")
	TEST_ASSERT(findtext(record.observations[1], record.field_notes), "The survey must record the field observations")
	var/obj/item/stationtrauma_sample/sample = allocate(/obj/item/stationtrauma_sample)
	user.put_in_active_hand(sample)
	sample.collect(source, user)
	TEST_ASSERT(findtext(record.observations[2], sample.sample_id), "Sampling must record the specimen ID")
	TEST_ASSERT(!findtext(record.report_text(), record.laboratory_notes), "Laboratory results must not appear before analysis")
	var/obj/machinery/stationtrauma_sample_analyzer/analyzer = allocate(/obj/machinery/stationtrauma_sample_analyzer, get_step(user, NORTH))
	analyzer.set_machine_stat(NONE)
	analyzer.analyze(sample, user)
	TEST_ASSERT(sample.analyzed, "The powered analysis must complete")
	TEST_ASSERT(findtext(record.report_text(), record.laboratory_notes), "The completed analysis must be recorded in the journal")
	var/obj/item/paper/report = locate() in analyzer.drop_location()
	qdel(report)

/// Goal edits are validated at the program boundary; reports carry linked protocols.
/datum/unit_test/explorers_journal/goals/Run()
	var/obj/item/modular_computer/pda/crew/explorer/pda = allocate(/obj/item/modular_computer/pda/crew/explorer, user.loc)
	var/datum/computer_file/program/expedition_journal/program = locate() in pda.stored_files
	TEST_ASSERT_NOTNULL(program, "Corps PDAs must ship with the journal")
	var/datum/expedition_journal/journal = program.memory
	user.put_in_inactive_hand(pda)
	survey()
	TEST_ASSERT_EQUAL(journal.records[record.id], record, "A survey must land in the journal of the PDA its actor carries")
	user.mind_initialize()
	var/datum/tgui/ui = allocate(/datum/tgui, user, pda, program.tgui_id)
	TEST_ASSERT(!program.ui_act("add_goal", list("text" = "Описать колонию"), ui), "A computer without an explorer ID must not write")
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.access = list(ACCESS_EXPLORER)
	pda.insert_id(card)
	TEST_ASSERT(program.ui_act("add_goal", list("text" = "Описать колонию"), ui), "An explorer must be able to add a goal")
	TEST_ASSERT_EQUAL(length(journal.goals), 1, "One action must create exactly one goal")
	var/datum/expedition_goal/goal = journal.goals[journal.goals[1]]
	TEST_ASSERT(!program.ui_act("set_status", list("goal" = 1, "status" = "done"), ui), "A positional key must not address a goal")
	TEST_ASSERT(!program.ui_act("link_record", list("goal" = goal.id, "record" = "F-0"), ui), "An undisclosed protocol cannot be linked")
	TEST_ASSERT(program.ui_act("link_record", list("goal" = goal.id, "record" = record.id), ui), "A disclosed protocol must be linkable")

	var/mob/living/carbon/human/other = allocate(/mob/living/carbon/human/consistent, user.loc)
	other.mind_initialize()
	var/datum/tgui/other_ui = allocate(/datum/tgui, other, pda, program.tgui_id)
	TEST_ASSERT(!program.ui_act("set_status", list("goal" = goal.id, "status" = "secret"), ui), "Unknown statuses must be rejected")
	TEST_ASSERT(program.ui_act("set_status", list("goal" = goal.id, "status" = "done"), ui), "An explorer must be able to close a goal")
	TEST_ASSERT_EQUAL(goal.status, "done", "The accepted status must be stored")

	pda.stored_paper = 1
	TEST_ASSERT(program.ui_act("print", list("goal" = goal.id), other_ui), "Any explorer may print a report")
	var/obj/item/paper/report = locate() in pda.drop_location()
	TEST_ASSERT_NOTNULL(report, "Printing must produce a physical report for the station fax")
	var/report_text = report.get_raw_text()
	TEST_ASSERT(findtext(report_text, record.id) && findtext(report_text, "выполнена"), "The report must contain the goal outcome and linked protocol")
	TEST_ASSERT_EQUAL(pda.stored_paper, 0, "Printing must consume the computer's paper")
	qdel(report)

/// The real job equip path must preserve corps communications and access boundaries.
/datum/unit_test/explorers_outfits

/datum/unit_test/explorers_outfits/Run()
	var/obj/structure/closet/secure_closet/expedition/leader/leader_locker = allocate(/obj/structure/closet/secure_closet/expedition/leader)
	var/list/role_lockers = list(
		/datum/job/explorer/leader = allocate(/obj/structure/closet/secure_closet/expedition_blades),
		/datum/job/explorer/pilot = allocate(/obj/structure/closet/secure_closet/expedition/pilot),
		/datum/job/explorer/medic = allocate(/obj/structure/closet/secure_closet/expedition/medic),
		/datum/job/explorer/engineer = allocate(/obj/structure/closet/secure_closet/expedition/engineer),
	)
	var/obj/structure/closet/secure_closet/laboratory = allocate(/obj/structure/closet/secure_closet)
	laboratory.req_access = list(ACCESS_RESEARCH)
	var/obj/machinery/computer/stationtrauma_dispatch/dispatch = allocate(/obj/machinery/computer/stationtrauma_dispatch)
	var/list/jobs_to_check = SSmapping.current_map.space_overmap ? typesof(/datum/job/explorer) : list(/datum/job/explorer)
	for(var/job_path in jobs_to_check)
		var/datum/job/job = SSjob.get_job_type(job_path)
		TEST_ASSERT_NOTNULL(job, "[job_path] was not registered as a station job.")
		var/mob/living/carbon/human/crew = allocate(/mob/living/carbon/human/consistent)
		crew.mind_initialize()
		crew.mind.set_assigned_role(job)
		crew.dress_up_as_job(job, consistent = TRUE)
		var/is_leader = job_path == /datum/job/explorer/leader
		TEST_ASSERT_EQUAL(leader_locker.allowed(crew), is_leader, "[job.title] has incorrect access to the corps leader's locker.")
		for(var/role_path in role_lockers)
			var/obj/structure/closet/secure_closet/role_locker = role_lockers[role_path]
			TEST_ASSERT_EQUAL(role_locker.allowed(crew), is_leader || job_path == role_path, "[job.title] has incorrect access to [role_locker.type].")
		TEST_ASSERT(!laboratory.allowed(crew), "[job.title] gained access to scientific laboratories.")
		TEST_ASSERT(dispatch.allowed(crew), "[job.title] cannot request its expedition ship without a command ID.")
		var/obj/item/radio/headset/headset = crew.get_item_by_slot(ITEM_SLOT_EAR_RIGHT)
		TEST_ASSERT(istype(headset), "[job.title] did not receive a headset in the right ear.")
		TEST_ASSERT(headset.channels[RADIO_CHANNEL_EXPEDITION], "[job.title]'s headset cannot use the corps channel.")
		TEST_ASSERT(!headset.channels[RADIO_CHANNEL_SUPPLY], "[job.title]'s headset retained the cargo channel.")
		TEST_ASSERT_EQUAL(!!headset.channels[RADIO_CHANNEL_COMMAND], is_leader, "[job.title] has incorrect command channel access.")
		var/datum/outfit/job/outfit = job.outfit
		var/obj/item/modular_computer/pda/pda = crew.get_item_by_slot(initial(outfit.pda_slot))
		TEST_ASSERT(istype(pda), "[job.title] lost its PDA when equipping its tool belt.")
		TEST_ASSERT_NOTNULL(pda.find_file_by_name("field_notes"), "[job.title]'s PDA lost its field notes template.")
		TEST_ASSERT(locate(/obj/item/stationtrauma_distress_beacon) in crew.get_all_contents(), "[job.title] lost its distress beacon.")
		TEST_ASSERT(!(locate(/obj/item/gun) in crew.get_all_contents()), "[job.title] spawned with a weapon instead of collecting it from storage.")

	TEST_ASSERT_EQUAL(SSjob.get_job(JOB_EXPLORER_RU), SSjob.get_job_type(/datum/job/explorer), "Specialist roles overwrote the explorer's Russian job alias.")
	var/list/qm_templates = SSid_access.sub_department_managers_tgui[ACCESS_QM]["templates"]
	TEST_ASSERT(!qm_templates[/datum/id_trim/job/explorer], "The quartermaster can still issue corps job templates.")
	var/list/leader_templates = SSid_access.sub_department_managers_tgui[ACCESS_EXPEDITION_LEADER]["templates"]
	TEST_ASSERT(leader_templates[/datum/id_trim/job/explorer/pilot], "The corps head cannot issue its crew's job templates.")
	var/mob/living/carbon/human/assistant = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!dispatch.allowed(assistant), "An outsider can request expedition ships without corps or command access.")

/// A specialist's own landmark takes priority, with the existing explorer point as fallback.
/datum/unit_test/explorers_spawns

/datum/unit_test/explorers_spawns/Run()
	if(!SSmapping.current_map.space_overmap)
		return
	var/obj/effect/landmark/start/explorer/shared = allocate(/obj/effect/landmark/start/explorer)
	var/obj/effect/landmark/start/explorer/pilot/dedicated = allocate(/obj/effect/landmark/start/explorer/pilot)
	var/list/original_landmarks = GLOB.start_landmarks_list
	GLOB.start_landmarks_list = list(shared, dedicated)
	var/datum/job/pilot_job = SSjob.get_job_type(/datum/job/explorer/pilot)
	var/datum/job/engineer_job = SSjob.get_job_type(/datum/job/explorer/engineer)
	var/atom/pilot_spawn = pilot_job.get_default_roundstart_spawn_point()
	var/atom/engineer_spawn = engineer_job.get_default_roundstart_spawn_point()
	GLOB.start_landmarks_list = original_landmarks
	TEST_ASSERT_EQUAL(pilot_spawn, dedicated, "The pilot ignored its dedicated start landmark.")
	TEST_ASSERT_EQUAL(engineer_spawn, shared, "The engineer could not use the existing explorer landmark before its room is mapped.")

/// Specialist jobs are registered only for profiles that actually enable the overmap.
/datum/unit_test/explorers_availability

/datum/unit_test/explorers_availability/Run()
	var/is_overmap = !!SSmapping.current_map.space_overmap
	for(var/job_path in subtypesof(/datum/job/explorer))
		TEST_ASSERT_EQUAL(!isnull(SSjob.get_job_type(job_path)), is_overmap, "[job_path] availability does not match the overmap profile.")
	var/datum/job/explorer/leader/leader_job = allocate(/datum/job/explorer/leader)
	var/datum/job/explorer/explorer_job = allocate(/datum/job/explorer)
	var/list/original_overmap = SSmapping.current_map.space_overmap
	SSmapping.current_map.space_overmap = null
	var/leader_available_without_overmap = leader_job.map_check()
	var/explorer_available_without_overmap = explorer_job.map_check()
	SSmapping.current_map.space_overmap = original_overmap
	TEST_ASSERT(!leader_available_without_overmap, "A specialist can be enabled without an overmap.")
	TEST_ASSERT(explorer_available_without_overmap, "The legacy explorer was disabled on ordinary maps.")

/// Exercise the frequency filters and name/colour metadata through native telecomms.
/datum/unit_test/explorers_radio

/datum/unit_test/explorers_radio/Run()
	var/obj/machinery/telecomms/receiver/preset_left/receiver = allocate(/obj/machinery/telecomms/receiver/preset_left)
	var/obj/machinery/telecomms/bus/preset_one/bus = allocate(/obj/machinery/telecomms/bus/preset_one)
	var/obj/machinery/telecomms/processor/processor = allocate(/obj/machinery/telecomms/processor)
	var/obj/machinery/telecomms/server/presets/science/server = allocate(/obj/machinery/telecomms/server/presets/science)
	var/obj/machinery/telecomms/broadcaster/broadcaster = allocate(/obj/machinery/telecomms/broadcaster)
	var/obj/machinery/telecomms/allinone/mainframe = allocate(/obj/machinery/telecomms/allinone)
	for(var/obj/machinery/telecomms/machine as anything in list(receiver, bus, processor, server, broadcaster, mainframe))
		// Isolate the test network from the map's existing telecomms and power supply.
		for(var/obj/machinery/telecomms/linked as anything in machine.links.Copy())
			machine.remove_link(linked)
		machine.use_power = NO_POWER_USE
		machine.set_machine_stat(machine.machine_stat & ~NOPOWER)
		machine.update_power()
	receiver.add_new_link(bus)
	bus.add_new_link(processor)
	bus.add_new_link(server)
	server.add_new_link(broadcaster)
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/radio/headset/headset = allocate(/obj/item/radio/headset/headset_cargo/explorer)
	var/atom/movable/virtualspeaker/voice = allocate(/atom/movable/virtualspeaker, null, speaker, headset)
	var/datum/signal/subspace/vocal/station_signal = allocate(/datum/signal/subspace/vocal, headset, FREQ_EXPEDITION, voice, /datum/language/common, "Corps station network test")
	receiver.receive_signal(station_signal)
	TEST_ASSERT(station_signal.data["done"], "The corps channel did not pass through the station receiver/bus/server/broadcaster.")
	TEST_ASSERT_EQUAL(length(server.log_entries), 1, "The corps transmission did not reach the station server.")
	var/datum/signal/subspace/vocal/ship_signal = allocate(/datum/signal/subspace/vocal, headset, FREQ_EXPEDITION, voice, /datum/language/common, "Corps ship network test")
	mainframe.receive_signal(ship_signal)
	TEST_ASSERT(ship_signal.data["done"], "The compact ship mainframe did not process the corps channel.")
	TEST_ASSERT_EQUAL(ship_signal.data["frequency_name"], RADIO_CHANNEL_EXPEDITION, "The ship mainframe lost the corps channel name.")

/// The corps vending machine stocks every piece of corps clothing and the field kit, each with valid renders.
/datum/unit_test/explorers_wardrobe

/datum/unit_test/explorers_wardrobe/Run()
	var/obj/machinery/vending/wardrobe/expedition_wardrobe/wardrobe = allocate(/obj/machinery/vending/wardrobe/expedition_wardrobe, run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(length(wardrobe.product_records), 15, "The corps vending machine does not stock its eleven clothing types and four field tools.")
	for(var/datum/data/vending_product/record as anything in wardrobe.product_records)
		TEST_ASSERT(record.amount > 0, "[record.product_path] is out of stock at round start.")
		var/obj/item/item = allocate(record.product_path)
		var/icon/inventory_render = getFlatIcon(item)
		TEST_ASSERT(inventory_render.Width() > 0, "[record.product_path] has no valid inventory render.")
		if(!istype(item, /obj/item/clothing) && !istype(item, /obj/item/storage/belt))
			continue
		// A belt without its own worn file is drawn from the shared belt sheet, as the mob does.
		var/worn_file = item.worn_icon || (istype(item, /obj/item/storage/belt) ? 'icons/mob/clothing/belt.dmi' : null)
		TEST_ASSERT_NOTNULL(worn_file, "[record.product_path] has no worn icon file.")
		var/image/worn_appearance = image(worn_file, icon_state = item.worn_icon_state || item.icon_state)
		var/icon/worn_render = getFlatIcon(worn_appearance)
		TEST_ASSERT(worn_render.Width() > 0, "[record.product_path] has no valid worn render.")

/// Native accessory storage must remain usable when cloned onto a worn uniform.
/datum/unit_test/explorers_field_clothing

/datum/unit_test/explorers_field_clothing/Run()
	var/mob/living/carbon/human/crew = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/expedition/uniform = allocate(/obj/item/clothing/under/expedition)
	TEST_ASSERT(crew.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The field uniform could not be equipped.")
	var/obj/item/clothing/accessory/expedition_webbing/webbing = allocate(/obj/item/clothing/accessory/expedition_webbing)
	crew.put_in_hands(webbing)
	TEST_ASSERT(uniform.attach_accessory(webbing, crew), "The webbing could not attach to its uniform.")
	for(var/index in 1 to 5)
		var/obj/item/pen/pen = allocate(/obj/item/pen)
		crew.put_in_hands(pen)
		var/inserted = uniform.atom_storage.attempt_insert(pen, crew)
		TEST_ASSERT_EQUAL(!!inserted, index <= 4, "The webbing's four pockets were not enforced through the worn uniform.")
		if(!inserted)
			crew.dropItemToGround(pen)
	var/obj/item/storage/belt/expedition_sheath/sheath = allocate(/obj/item/storage/belt/expedition_sheath)
	TEST_ASSERT(crew.equip_to_slot_if_possible(sheath, ITEM_SLOT_BELT), "The belt sheath cannot be worn alongside the webbing.")
	var/obj/item/gun/energy/laser/pistol/gun = allocate(/obj/item/gun/energy/laser/pistol)
	crew.put_in_hands(gun)
	TEST_ASSERT(!sheath.atom_storage.attempt_insert(gun, crew), "The blade sheath accepted a gun.")
	crew.dropItemToGround(gun)
	var/obj/item/knife/knife = allocate(/obj/item/knife)
	crew.put_in_hands(knife)
	TEST_ASSERT(sheath.atom_storage.attempt_insert(knife, crew), "The blade sheath rejected a field knife.")
	var/obj/item/clothing/suit/toggle/expedition/jacket = allocate(/obj/item/clothing/suit/toggle/expedition)
	TEST_ASSERT(crew.equip_to_slot_if_possible(jacket, ITEM_SLOT_OCLOTHING), "The field jacket could not be equipped.")
	SEND_SIGNAL(jacket, COMSIG_CLICK_ALT, crew)
	TEST_ASSERT_EQUAL(jacket.icon_state, "trackjacket_t", "The jacket did not use the imported open state through native alt-click.")
	TEST_ASSERT(jacket.icon_state in icon_states(jacket.worn_icon), "The opened jacket has no worn sprite.")
	SEND_SIGNAL(jacket, COMSIG_CLICK_ALT, crew)
	TEST_ASSERT_EQUAL(jacket.icon_state, "trackjacket", "The jacket could not be closed again.")

/// A stocked machete must fit both native sheath forms and render in either hand.
/datum/unit_test/explorers_machete

/datum/unit_test/explorers_machete/Run()
	var/obj/structure/closet/secure_closet/expedition_blades/locker = allocate(/obj/structure/closet/secure_closet/expedition_blades, run_loc_floor_top_right)
	locker.locked = FALSE
	TEST_ASSERT(locker.open(special_effects = FALSE), "The blade locker could not open.")
	var/obj/item/hatchet/expedition_machete/blade = locate() in locker.loc
	TEST_ASSERT(blade, "The blade locker did not supply a machete.")
	var/mob/living/carbon/human/crew = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/expedition/uniform = allocate(/obj/item/clothing/under/expedition)
	TEST_ASSERT(crew.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The uniform could not be equipped.")
	var/obj/item/clothing/accessory/expedition_sheath/accessory = allocate(/obj/item/clothing/accessory/expedition_sheath)
	crew.put_in_hands(accessory)
	TEST_ASSERT(uniform.attach_accessory(accessory, crew), "The thigh sheath could not attach to the uniform.")
	var/obj/item/storage/belt/expedition_sheath/belt = allocate(/obj/item/storage/belt/expedition_sheath)
	for(var/obj/item/holder as anything in list(uniform, belt))
		crew.put_in_hands(blade)
		TEST_ASSERT(holder.atom_storage.attempt_insert(blade, crew), "[holder.type] rejected the supplied machete.")
		TEST_ASSERT(holder.atom_storage.attempt_remove(blade, crew.loc), "The machete could not be drawn from [holder.type].")
	var/icon/inventory_render = getFlatIcon(blade)
	TEST_ASSERT(inventory_render.Width() > 0, "The machete has no valid inventory render.")
	for(var/hand_file in list(blade.lefthand_file, blade.righthand_file))
		for(var/direction in GLOB.cardinals)
			var/image/hand_appearance = image(hand_file, icon_state = blade.inhand_icon_state, dir = direction)
			var/icon/hand_render = getFlatIcon(hand_appearance)
			TEST_ASSERT(hand_render.Width() > 0, "The machete has no valid hand render for [hand_file], direction [direction].")

/// Every expedition MODsuit has sprites for every part, sealed or not, and its suit storage keeps it locked to the corps.
/datum/unit_test/expedition_modsuits

/datum/unit_test/expedition_modsuits/Run()
	var/list/units = list(
		/obj/machinery/suit_storage_unit/expedition = /obj/item/mod/control/pre_equipped/expedition,
		/obj/machinery/suit_storage_unit/expedition/pilot = /obj/item/mod/control/pre_equipped/expedition_pilot,
		/obj/machinery/suit_storage_unit/expedition/heavy = /obj/item/mod/control/pre_equipped/expedition_heavy,
		/obj/machinery/suit_storage_unit/expedition/medic = /obj/item/mod/control/pre_equipped/expedition_medic,
		/obj/machinery/suit_storage_unit/expedition/engineer = /obj/item/mod/control/pre_equipped/expedition_engineer,
	)
	for(var/unit_type in units)
		var/obj/machinery/suit_storage_unit/unit = allocate(unit_type)
		TEST_ASSERT(istype(unit.mod, units[unit_type]), "[unit_type] does not hold its MODsuit")
		TEST_ASSERT(unit.locked, "[unit_type] is not locked")
		var/mob/living/carbon/human/consistent/stranger = allocate(/mob/living/carbon/human/consistent)
		TEST_ASSERT(!unit.allowed(stranger), "[unit_type] lets anyone in")
		var/mob/living/carbon/human/consistent/member = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
		card.access = list(ACCESS_EXPLORER, ACCESS_EXPEDITION_LEADER)
		member.put_in_active_hand(card)
		TEST_ASSERT(unit.allowed(member), "[unit_type] keeps the corps out")
		var/obj/item/mod/control/mod = unit.mod
		for(var/obj/item/part as anything in mod.get_parts(all = TRUE))
			for(var/sealed in list("", "-sealed"))
				var/state = "[mod.skin]-[part.base_icon_state][sealed]"
				TEST_ASSERT(icon_exists(part.icon, state), "[part.type] of [mod.type] has no icon [state]")
				TEST_ASSERT(icon_exists(part.worn_icon, state), "[part.type] of [mod.type] has no worn icon [state]")
		if(mod.skin in list("expedition", "expedition_medic", "expedition_engineer"))
			TEST_ASSERT(icon_exists(mod.worn_icon, "[mod.skin]-helmet-visor"), "[mod.type] has no visor for visor modules")

/// Both sheaths show the hilt of the blade they hold, on the body and in the inventory.
/datum/unit_test/expedition_sheath_shows_blade

/datum/unit_test/expedition_sheath_shows_blade/Run()
	var/mob/living/carbon/human/crew = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/under/expedition/uniform = allocate(/obj/item/clothing/under/expedition)
	crew.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	var/obj/item/clothing/accessory/expedition_sheath/accessory = allocate(/obj/item/clothing/accessory/expedition_sheath)
	crew.put_in_hands(accessory)
	uniform.attach_accessory(accessory, crew)
	var/obj/item/storage/belt/expedition_sheath/belt = allocate(/obj/item/storage/belt/expedition_sheath)
	var/obj/item/hatchet/expedition_machete/blade = allocate(/obj/item/hatchet/expedition_machete)
	var/list/holders = list(uniform = accessory, belt = belt)
	for(var/key in holders)
		var/obj/item/storage_holder = key == "uniform" ? uniform : belt
		var/obj/item/sheath = holders[key]
		TEST_ASSERT_EQUAL(sheath.worn_icon_state, "holster_machete", "the empty [key] sheath does not look empty")
		crew.put_in_hands(blade)
		storage_holder.atom_storage.attempt_insert(blade, crew)
		TEST_ASSERT_EQUAL(sheath.worn_icon_state, "holster_machete-full", "the [key] sheath does not show the blade")
		TEST_ASSERT(icon_exists(sheath.icon, sheath.icon_state), "the [key] sheath has no inventory sprite [sheath.icon_state]")
		TEST_ASSERT(icon_exists(sheath.worn_icon, sheath.worn_icon_state), "the [key] sheath has no worn sprite [sheath.worn_icon_state]")
		storage_holder.atom_storage.attempt_remove(blade, crew.loc)
		TEST_ASSERT_EQUAL(sheath.worn_icon_state, "holster_machete", "the [key] sheath still shows a drawn blade")

/// Each role locker holds its kit, only the plain one opens for a plain explorer, and only the leader's holds a machete.
/datum/unit_test/expedition_role_lockers

/datum/unit_test/expedition_role_lockers/Run()
	var/list/kits = list(
		/obj/structure/closet/secure_closet/expedition = /obj/item/binoculars,
		/obj/structure/closet/secure_closet/expedition/leader = /obj/item/hatchet/expedition_machete/deluxe,
		/obj/structure/closet/secure_closet/expedition/pilot = /obj/item/storage/belt/utility/full,
		/obj/structure/closet/secure_closet/expedition/medic = /obj/item/healthanalyzer,
		/obj/structure/closet/secure_closet/expedition/engineer = /obj/item/multitool,
	)
	var/mob/living/carbon/human/consistent/explorer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.access = list(ACCESS_EXPLORER)
	explorer.put_in_active_hand(card)
	for(var/locker_type in kits)
		var/obj/structure/closet/secure_closet/locker = allocate(locker_type, run_loc_floor_top_right)
		TEST_ASSERT_EQUAL(locker.allowed(explorer), locker_type == /obj/structure/closet/secure_closet/expedition, "[locker_type] has the wrong access")
		locker.locked = FALSE
		TEST_ASSERT(locker.open(special_effects = FALSE), "[locker_type] does not open")
		TEST_ASSERT(locate(kits[locker_type]) in locker.loc, "[locker_type] lacks [kits[locker_type]]")
		TEST_ASSERT(locate(/obj/item/binoculars) in locker.loc, "[locker_type] lacks the common kit")
		TEST_ASSERT_EQUAL(!!(locate(/obj/item/hatchet/expedition_machete) in locker.loc), locker_type == /obj/structure/closet/secure_closet/expedition/leader, "[locker_type] has the wrong machete stock")
		for(var/obj/item/thing in locker.loc)
			qdel(thing)

/// The corps GPS bears on a docked ship from outside it, and not from aboard.
/datum/unit_test/overmap_docking/expedition_gps_ship

/datum/unit_test/overmap_docking/expedition_gps_ship/Run()
	TEST_ASSERT(navigation.dock(instant = TRUE), "the fixture ship did not dock")
	var/turf/outside = space.bottom_left_turfs[1]
	TEST_ASSERT(!(get_area(outside) in ship.shuttle_areas), "the outside turf is aboard")
	TEST_ASSERT_EQUAL(expedition_ship_bearing(navigation, outside), get_turf(ship), "the GPS does not bear on the docked ship")
	TEST_ASSERT_NULL(expedition_ship_bearing(navigation, get_turf(ship)), "the GPS bears on the ship from aboard")
	var/obj/item/gps/expedition/gps = allocate(/obj/item/gps/expedition, outside)
	var/datum/component/gps/item/expedition/component = gps.GetComponent(/datum/component/gps/item/expedition)
	var/list/data = component.ui_data()
	TEST_ASSERT(islist(data["signals"]), "the corps GPS lists no signals")

/// Exploreverse Mk.III: a single fire mode, charge sprites, and the station lock of its line.
/datum/unit_test/exploreverse_mk3

/datum/unit_test/exploreverse_mk3/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/energy/laser/awaymission_aeg/mk3/gun = allocate(/obj/item/gun/energy/laser/awaymission_aeg/mk3)
	TEST_ASSERT(istype(gun.pin, /obj/item/firing_pin/explorer), "Mk.III fires on the station")
	TEST_ASSERT((gun.icon_state + "_charge[gun.charge_sections]") in gun.update_overlays(), "a full Mk.III does not show a full charge strip")
	for(var/level in 1 to gun.charge_sections)
		TEST_ASSERT(icon_exists(gun.icon, "laser_gate_mk3_charge[level]"), "Mk.III has no sprite for charge level [level]")
	for(var/state in list("laser_gate_mk3_empty", "laser_gate_mk3_nomag"))
		TEST_ASSERT(icon_exists(gun.icon, state), "Mk.III has no sprite [state]")
	shooter.put_in_active_hand(gun)
	gun.select_fire(shooter)
	TEST_ASSERT_EQUAL(length(gun.ammo_type), 1, "Mk.III has an additional fire mode")
	TEST_ASSERT(istype(gun.ammo_type[gun.select], /obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3), "Mk.III does not retain its standard shot after mode selection")

/datum/job/human_ai
	title = JOB_HUMAN_AI
	description = "Помогайте экипажу, открывайте шлюзы, следуйте своему своду законов и координируйтесь с другими киборгами."
	auto_deadmin_role_flags = DEADMIN_POSITION_SILICON
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	required_donator_level = DONATOR_TIER_5
	donor_unlock_trait = /datum/station_trait/job/human_ai
	supervisors = "Капитаном, Директором Исследований и вашим сводом законов"
	minimal_player_age = 7
	exp_requirements = 180
	exp_required_type = EXP_TYPE_CREW
	exp_required_type_department = EXP_TYPE_SILICON
	exp_granted_type = EXP_TYPE_CREW
	display_order = JOB_DISPLAY_ORDER_HUMAN_AI
	config_tag = "HUMAN_AI"

	outfit = /datum/outfit/job/human_ai
	plasmaman_outfit = /datum/outfit/plasmaman/human_ai

	paycheck = null
	paycheck_department = null

	mind_traits = list(TRAIT_DISPLAY_JOB_IN_BINARY)
	liver_traits = list(TRAIT_HUMAN_AI_METABOLISM)

	departments_list = list(
		/datum/job_department/silicon,
	)

	family_heirlooms = list(
		/obj/item/brain_processor/positronic/display,
	)

	mail_goodies = list(
		/obj/item/food/burger/roburger = 1,
		/obj/item/food/cake/hardware_cake = 1,
	)
	rpg_title = "Omnissiah"
	random_spawns_possible = FALSE
	allow_bureaucratic_error = FALSE
	job_flags = (STATION_JOB_FLAGS | STATION_TRAIT_JOB_FLAGS | JOB_ANTAG_PROTECTED) & ~JOB_REOPEN_ON_ROUNDSTART_LOSS
	human_authority = JOB_AUTHORITY_NON_HUMANS_ALLOWED //we can safely assume NT doesn't care what species AIs are made of, much less if they can't even afford an AI.
	tgui_icon = /datum/job/ai::tgui_icon

/datum/job/human_ai/config_check()
	return CONFIG_GET(flag/allow_ai)

/datum/job/human_ai/get_roundstart_spawn_point()
	return get_latejoin_spawn_point()

/// Use an accessible AI chamber floor without taking a spawn reserved for the station AI.
/datum/job/human_ai/get_latejoin_spawn_point()
	if(length(GLOB.jobspawn_overrides[title]))
		return pick(GLOB.jobspawn_overrides[title])
	var/area/spawn_area = GLOB.areas_by_type[/area/station/ai/satellite/chamber]
	if(!spawn_area)
		return ..()

	var/list/available_turfs = list()
	for(var/turf/open/floor/spawn_turf in spawn_area.get_turfs_from_all_zlevels())
		if((locate(/obj/effect/landmark/start/ai) in spawn_turf) || (locate(/obj/structure/ai_core) in spawn_turf))
			continue
		if(is_safe_turf(spawn_turf, extended_safety_checks = TRUE))
			available_turfs += spawn_turf
	return length(available_turfs) ? pick(available_turfs) : ..()

/datum/job/human_ai/announce_job(mob/living/joining_mob)
	. = ..()
	if(SSticker.HasRoundStarted())
		minor_announce("[joining_mob] прибыл для помощи станционному ИИ. Место прибытия: [AREACOORD(joining_mob)].")

/datum/job/human_ai/get_radio_information()
	return "<b>Prefix your message with :b to speak with cyborgs.</b>"

/datum/outfit/job/human_ai
	name = "Human AI"
	jobtype = /datum/job/human_ai

	id = /obj/item/card/id/advanced/robotic
	id_trim = /datum/id_trim/job/human_ai
	backpack_contents = list(
		/obj/item/door_remote/omni = 1,
		/obj/item/machine_remote = 1,
		/obj/item/secure_camera_console_pod = 1,
		/obj/item/sensor_device = 1,
	)

	uniform = /obj/item/clothing/under/rank/station_trait/human_ai
	belt = /obj/item/modular_computer/pda/human_ai
	// AI EDIT START - Support independent left and right ear slots
	ear_right = /obj/item/radio/headset/silicon/human_ai // BANDASTATION EDIT - Dual ear slots
	// AI EDIT END
	glasses = /obj/item/clothing/glasses/hud/diagnostic

	l_pocket = /obj/item/laser_pointer/infinite_range //to punish borgs, this works through the camera console.
	r_pocket = /obj/item/assembly/flash/handheld

	l_hand = /obj/item/paper/default_lawset_list

/datum/outfit/job/human_ai/pre_equip(mob/living/carbon/human/equipped, visuals_only)
	. = ..()
	if(visuals_only)
		return
	if(is_safe_turf(equipped.loc, dense_atoms = TRUE))
		return
	if(isnull(equipped.dna.species.outfit_important_for_life)) //custom species stuff will handle this for us.
		internals_slot = ITEM_SLOT_SUITSTORE
		suit_store = /obj/item/tank/internals/oxygen
	suit = /obj/item/clothing/suit/space/nasavoid
	head = /obj/item/clothing/head/helmet/space/nasavoid

/datum/outfit/job/human_ai/post_equip(mob/living/carbon/human/equipped, visuals_only)
	. = ..()
	if(visuals_only)
		return
	if(!equipped.get_quirk(/datum/quirk/body_purist))
		var/obj/item/organ/tongue/robot/cybernetic = new()
		cybernetic.Insert(equipped, special = TRUE, movement_flags = DELETE_IF_REPLACED)
		//you only get respect if you go all the way, man.
		ADD_TRAIT(equipped, TRAIT_COMMISSIONED, INNATE_TRAIT)
	equipped.add_faction(list(FACTION_SILICON, FACTION_TURRET))

/obj/item/paper/default_lawset_list
	name = "Lawset Note"
	desc = "A note explaining the lawset, quickly written yet everso important."

/obj/item/paper/default_lawset_list/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/item/paper/default_lawset_list/LateInitialize()
	var/datum/ai_laws/reported
	for(var/obj/machinery/ai_law_rack/base/core/rack as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/ai_law_rack/base/core))
		reported = rack.combined_lawset
		break

	if(isnull(reported))
		return

	var/list/law_box = list(
		"This is your lawset, you and your Cyborgs must adhere to this at all times.",
		"Notably, if absolutely necessary, you can bend or even go against the lawset for your own survival, and Cyborgs report to you directly.",
		"LAWS:",
	)
	law_box += reported.get_law_list(render_html = FALSE)
	add_raw_text(jointext(law_box, "\n"))

/obj/item/secure_camera_console_pod
	name = "pre-packaged advanced camera control"
	desc = "A pre-packaged camera console used for all your AI stuff, programmed to only active in the SAT."
	icon = 'icons/obj/devices/remote.dmi'
	icon_state = "botpad_controller"
	inhand_icon_state = "radio"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'

/obj/item/secure_camera_console_pod/attack_self(mob/user, modifiers)
	. = ..()
	var/area/current_area = get_area(user)
	var/static/list/allowed_areas = typecacheof(list(/area/station/ai/satellite/chamber))
	if(!is_type_in_typecache(current_area, allowed_areas))
		user.balloon_alert(user, "not in the sat!")
		return
	user.balloon_alert(user, "unpacking...")
	if(!do_after(user, 5 SECONDS, src))
		return
	playsound(src, 'sound/items/tools/drill_use.ogg', 40, TRUE)
	new /obj/machinery/computer/camera_advanced/human_ai(get_turf(src))
	qdel(src)

/datum/job/spacepod_technician
	title = JOB_SPACEPOD_TECHNICIAN
	alternate_titles = list(JOB_SPACEPOD_TECHNICIAN_RU)
	description = "Собирайте, ремонтируйте и оснащайте космические поды. Обслуживайте их двигатели, броню и оборудование."
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	supervisors = JOB_CHIEF_ENGINEER_RU
	exp_requirements = 60
	exp_required_type = EXP_TYPE_CREW
	exp_granted_type = EXP_TYPE_CREW
	config_tag = "SPACEPOD_TECHNICIAN"
	departments_list = list(/datum/job_department/engineering)
	outfit = /datum/outfit/job/spacepod_technician
	plasmaman_outfit = /datum/outfit/plasmaman/engineering
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_ENG
	display_order = JOB_DISPLAY_ORDER_SPACEPOD_TECHNICIAN
	job_flags = STATION_JOB_FLAGS
	tgui_icon = FA_ICON_GEARS
	rpg_title = "Shipwright"
	family_heirlooms = list(/obj/item/wrench)

// shortcut: reuse engineering spawns until station maps include dedicated pod workshop landmarks.
/datum/job/spacepod_technician/get_default_roundstart_spawn_point()
	for(var/obj/effect/landmark/start/spawn_point as anything in GLOB.start_landmarks_list)
		if(spawn_point.name == title)
			return ..()

	var/datum/job/station_engineer/fallback_job = SSjob.get_job_type(/datum/job/station_engineer)
	if(fallback_job)
		return fallback_job.get_default_roundstart_spawn_point()
	return ..()

/datum/outfit/job/spacepod_technician
	name = JOB_SPACEPOD_TECHNICIAN
	jobtype = /datum/job/spacepod_technician
	id_trim = /datum/id_trim/job/spacepod_technician
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	belt = /obj/item/storage/belt/utility/full
	shoes = /obj/item/clothing/shoes/workboots
	head = /obj/item/clothing/head/utility/hardhat
	// AI EDIT START - Use the right ear slot for existing equipment
	ear_right = /obj/item/radio/headset/headset_eng
	// AI EDIT END
	l_pocket = /obj/item/modular_computer/pda/crew/engineering
	r_pocket = /obj/item/t_scanner
	glasses = /obj/item/clothing/glasses/meson
	backpack = /obj/item/storage/backpack/industrial
	satchel = /obj/item/storage/backpack/satchel/eng
	duffelbag = /obj/item/storage/backpack/duffelbag/engineering
	messenger = /obj/item/storage/backpack/messenger/eng
	box = /obj/item/storage/box/survival/engineer
	skillchips = list(/obj/item/skillchip/job/engineer)
	backpack_contents = list(
		/obj/item/pod_paint_bucket = 1,
		/obj/item/spacepod_equipment/key = 1,
	)
	pda_slot = ITEM_SLOT_LPOCKET
	wintercoat = /obj/item/clothing/suit/hooded/wintercoat/engineering

/datum/id_trim/job/spacepod_technician
	assignment = JOB_SPACEPOD_TECHNICIAN_RU
	trim_state = "trim_stationengineer"
	department_color = COLOR_ENGINEERING_ORANGE
	subdepartment_color = COLOR_ENGINEERING_ORANGE
	sechud_icon_state = SECHUD_STATION_ENGINEER
	template_access = list(
		ACCESS_CAPTAIN,
		ACCESS_CHANGE_IDS,
		ACCESS_CE,
	)
	job = /datum/job/spacepod_technician

/// Copy engineering access before the parent applies this job's map and config changes.
/datum/id_trim/job/spacepod_technician/New()
	var/datum/id_trim/job/station_engineer/engineer_trim = new
	minimal_access = engineer_trim.minimal_access + list(ACCESS_EVA)
	extra_access = engineer_trim.extra_access.Copy()
	qdel(engineer_trim)
	return ..()

/obj/effect/landmark/start/spacepod_technician
	name = JOB_SPACEPOD_TECHNICIAN
	icon_state = JOB_STATION_ENGINEER

/datum/job/spacepod_pilot
	title = JOB_SPACEPOD_PILOT
	alternate_titles = list(JOB_SPACEPOD_PILOT_RU)
	description = "Патрулируйте окрестности станции на челноке СБ и поддерживайте офицеров при операциях в космосе."
	auto_deadmin_role_flags = DEADMIN_POSITION_SECURITY
	faction = FACTION_STATION
	supervisors = JOB_HEAD_OF_SECURITY_RU
	minimal_player_age = 7
	exp_requirements = 300
	exp_required_type = EXP_TYPE_CREW
	exp_granted_type = EXP_TYPE_CREW
	config_tag = "SPACEPOD_PILOT"
	departments_list = list(/datum/job_department/security)
	outfit = /datum/outfit/job/security/spacepod_pilot
	plasmaman_outfit = /datum/outfit/plasmaman/security
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_SEC
	desensitized_base = DESENSITIZED_THRESHOLD
	liver_traits = list(TRAIT_LAW_ENFORCEMENT_METABOLISM)
	display_order = JOB_DISPLAY_ORDER_SPACEPOD_PILOT
	bounty_types = CIV_JOB_SEC
	job_flags = STATION_JOB_FLAGS | JOB_ANTAG_PROTECTED
	tgui_icon = FA_ICON_SHUTTLE_SPACE
	rpg_title = "Pilot"

/datum/job/spacepod_pilot/New()
	. = ..()
	// Jobs initialize before mapping switches to the configured default map.
	if(SSmapping.current_map.defaulted && config.defaultmap && !config.defaultmap.defaulted)
		var/list/map_slots = config.defaultmap.job_changes?[title]
		if(isnum(map_slots?["spawn_positions"]))
			spawn_positions = map_slots["spawn_positions"]
		if(isnum(map_slots?["total_positions"]))
			total_positions = map_slots["total_positions"]

/datum/job/spacepod_pilot/map_check()
	return ..() && (spawn_positions || total_positions)

/datum/job/spacepod_pilot/is_role_banned(player_key)
	return is_banned_from(player_key, list(title, JOB_SECURITY_OFFICER))

/datum/outfit/job/security/spacepod_pilot
	name = JOB_SPACEPOD_PILOT
	jobtype = /datum/job/spacepod_pilot
	id_trim = /datum/id_trim/job/security_officer/spacepod_pilot
	backpack_contents = list(
		/obj/item/evidencebag = 1,
		/obj/item/choice_beacon/weapon/security_pistol = 1,
		/obj/item/spacepod_equipment/key/security = 1,
	)

/datum/id_trim/job/security_officer/spacepod_pilot
	assignment = JOB_SPACEPOD_PILOT_RU
	job = /datum/job/spacepod_pilot

/obj/effect/landmark/start/spacepod_pilot
	name = JOB_SPACEPOD_PILOT
	icon_state = JOB_SECURITY_OFFICER

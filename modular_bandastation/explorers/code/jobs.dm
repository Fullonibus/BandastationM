/datum/job/explorer
	title = JOB_EXPLORER
	alternate_titles = list(JOB_EXPLORER_RU)
	supervisors = JOB_EXPEDITION_LEADER_RU
	description = "Исследуйте объекты овермапы, собирайте находки и пробы, работайте с учёными и ведите полевые записи."
	display_order = JOB_DISPLAY_ORDER_EXPLORER
	departments_list = list(/datum/job_department/expedition)
	outfit = /datum/outfit/job/explorer
	plasmaman_outfit = /datum/outfit/plasmaman/explorer
	faction = FACTION_STATION
	total_positions = 4
	spawn_positions = 3
	minimal_player_age = 18
	exp_requirements = 180
	exp_required_type = EXP_TYPE_CREW
	exp_required_type_department = EXP_TYPE_CREW
	exp_granted_type = EXP_TYPE_CREW
	config_tag = "EXPLORER"
	tgui_icon = FA_ICON_BINOCULARS
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_CIV
	bounty_types = CIV_JOB_BASIC
	family_heirlooms = list(/obj/item/gps, /obj/item/multitool)
	mail_goodies = list(/obj/item/stack/spacecash/c500 = 3)
	rpg_title = "Explorer"
	job_flags = STATION_JOB_FLAGS

/datum/job/explorer/map_check()
	if(type != /datum/job/explorer && !SSmapping.current_map.space_overmap)
		return FALSE
	return ..()

// Until dedicated landmarks are mapped, specialists share the existing explorer spawn.
/datum/job/explorer/get_default_roundstart_spawn_point()
	if(type == /datum/job/explorer)
		return ..()
	for(var/obj/effect/landmark/start/spawn_point as anything in GLOB.start_landmarks_list)
		if(spawn_point.name == title)
			return ..()
	var/datum/job/explorer/default_job = SSjob.get_job_type(/datum/job/explorer)
	return default_job?.get_default_roundstart_spawn_point()

/datum/job/explorer/leader
	title = JOB_EXPEDITION_LEADER
	alternate_titles = list(JOB_EXPEDITION_LEADER_RU)
	supervisors = "Центральным Командованием"
	description = "Руководите экспедиционным корпусом Нанотрейзен, планируйте вылеты и координируйте работу с главами станции. Корпус подчиняется ЦК; на станции соблюдает Корпоративный Закон."
	display_order = JOB_DISPLAY_ORDER_EXPEDITION_LEADER
	departments_list = list(/datum/job_department/expedition, /datum/job_department/command)
	outfit = /datum/outfit/job/explorer/leader
	total_positions = 1
	spawn_positions = 1
	exp_requirements = 1200
	exp_granted_type = EXP_TYPE_COMMAND
	config_tag = "EXPEDITION_LEADER"
	paycheck = PAYCHECK_COMMAND
	auto_deadmin_role_flags = DEADMIN_POSITION_HEAD
	head_announce = RADIO_CHANNEL_EXPEDITION
	req_admin_notify = TRUE
	mind_traits = list(HEAD_OF_STAFF_MIND_TRAITS)
	job_flags = STATION_JOB_FLAGS | HEAD_OF_STAFF_JOB_FLAGS
	voice_of_god_power = 1.4

/datum/job/explorer/pilot
	title = JOB_EXPEDITION_PILOT
	alternate_titles = list(JOB_EXPEDITION_PILOT_RU)
	description = "Пилотируйте экспедиционный корабль, прокладывайте маршруты, обеспечивайте высадку и возвращение отряда."
	display_order = JOB_DISPLAY_ORDER_EXPEDITION_PILOT
	outfit = /datum/outfit/job/explorer/pilot
	total_positions = 1
	spawn_positions = 1
	config_tag = "EXPEDITION_PILOT"

/datum/job/explorer/medic
	title = JOB_EXPEDITION_MEDIC
	alternate_titles = list(JOB_EXPEDITION_MEDIC_RU)
	description = "Оказывайте полевую медицинскую помощь экспедиционному отряду и эвакуируйте пострадавших."
	display_order = JOB_DISPLAY_ORDER_EXPEDITION_MEDIC
	outfit = /datum/outfit/job/explorer/medic
	total_positions = 1
	spawn_positions = 1
	config_tag = "EXPEDITION_MEDIC"

/datum/job/explorer/engineer
	title = JOB_EXPEDITION_ENGINEER
	alternate_titles = list(JOB_EXPEDITION_ENGINEER_RU)
	description = "Обслуживайте экспедиционный корабль, устраняйте повреждения и обеспечивайте работу оборудования в полевых условиях."
	display_order = JOB_DISPLAY_ORDER_EXPEDITION_ENGINEER
	outfit = /datum/outfit/job/explorer/engineer
	total_positions = 1
	spawn_positions = 1
	config_tag = "EXPEDITION_ENGINEER"

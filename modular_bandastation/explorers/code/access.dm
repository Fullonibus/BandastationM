/datum/id_trim/job/explorer
	assignment = JOB_EXPLORER_RU
	trim_icon = 'modular_bandastation/jobs/icons/obj/card.dmi'
	trim_state = "trim_explorer"
	department_color = RADIO_COLOR_EXPEDITION
	subdepartment_color = RADIO_COLOR_EXPEDITION
	sechud_icon_state = SECHUD_EXPLORER
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	template_access = list(ACCESS_CAPTAIN, ACCESS_CHANGE_IDS, ACCESS_EXPEDITION_LEADER)
	job = /datum/job/explorer

/datum/id_trim/job/explorer/leader
	assignment = JOB_EXPEDITION_LEADER_RU
	department_color = COLOR_COMMAND_BLUE
	department_state = "departmenthead"
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_LEADER,
		ACCESS_EXPEDITION_PILOT,
		ACCESS_EXPEDITION_MEDIC,
		ACCESS_EXPEDITION_ENGINEER,
		ACCESS_COMMAND,
		ACCESS_RC_ANNOUNCE,
		ACCESS_KEYCARD_AUTH,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	template_access = list(ACCESS_CAPTAIN, ACCESS_CHANGE_IDS)
	job = /datum/job/explorer/leader

/datum/id_trim/job/explorer/pilot
	assignment = JOB_EXPEDITION_PILOT_RU
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_PILOT,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	job = /datum/job/explorer/pilot

/datum/id_trim/job/explorer/medic
	assignment = JOB_EXPEDITION_MEDIC_RU
	subdepartment_color = COLOR_MEDICAL_BLUE
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_MEDIC,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	job = /datum/job/explorer/medic

/datum/id_trim/job/explorer/engineer
	assignment = JOB_EXPEDITION_ENGINEER_RU
	subdepartment_color = COLOR_ENGINEERING_ORANGE
	minimal_access = list(
		ACCESS_EXPLORER,
		ACCESS_EXPEDITION_ENGINEER,
		ACCESS_EVA,
		ACCESS_MAINT_TUNNELS,
		ACCESS_EXTERNAL_AIRLOCKS,
		ACCESS_GATEWAY,
		ACCESS_WEAPONS,
	)
	job = /datum/job/explorer/engineer

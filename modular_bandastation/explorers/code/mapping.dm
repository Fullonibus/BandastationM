/area/station/expedition
	name = "Экспедиционный корпус"
	icon = 'modular_bandastation/explorers/icons/mapping.dmi'
	icon_state = "common"

/area/station/expedition/storage
	name = "Склад оборудования экспедиционного корпуса"
	icon_state = "storage"

/area/station/expedition/common
	name = "Общая комната экспедиционного корпуса"
	icon_state = "common"

/area/station/expedition/office
	name = "Кабинет главы экспедиционного корпуса"
	icon_state = "office"

/obj/effect/mapping_helpers/airlock/access/all/expedition
	icon = 'modular_bandastation/explorers/icons/mapping.dmi'
	icon_state = "access_team"

/obj/effect/mapping_helpers/airlock/access/all/expedition/general
	name = "expedition corps access"

/obj/effect/mapping_helpers/airlock/access/all/expedition/general/get_access()
	return list(ACCESS_EXPLORER)

/obj/effect/mapping_helpers/airlock/access/all/expedition/leader
	name = "expedition leader access"
	icon_state = "access_leader"

/obj/effect/mapping_helpers/airlock/access/all/expedition/leader/get_access()
	return list(ACCESS_EXPEDITION_LEADER)

/datum/area_spawn/explorer_landmark
	target_areas = list(/area/station/expedition, /area/station/command/gateway)
	desired_atom = /obj/effect/landmark/start/explorer

/obj/effect/landmark/start/explorer
	name = JOB_EXPLORER
	icon = 'modular_bandastation/jobs/icons/mob/landmarks.dmi'
	icon_state = JOB_EXPLORER

/obj/effect/landmark/start/explorer/leader
	name = JOB_EXPEDITION_LEADER

/obj/effect/landmark/start/explorer/pilot
	name = JOB_EXPEDITION_PILOT

/obj/effect/landmark/start/explorer/medic
	name = JOB_EXPEDITION_MEDIC

/obj/effect/landmark/start/explorer/engineer
	name = JOB_EXPEDITION_ENGINEER

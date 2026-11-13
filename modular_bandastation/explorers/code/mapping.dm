/area/station/expedition
	name = "Экспедиционный корпус"
	icon_state = "cargo_office"

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

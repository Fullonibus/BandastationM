/// Placed donor landmarks override the usual job spawn at roundstart and latejoin.
/obj/effect/landmark/start/donor
	jobspawn_override = TRUE
	delete_after_roundstart = FALSE

/obj/effect/landmark/start/donor/barber
	name = /datum/job/donor/barber::title
	icon_state = JOB_CURATOR

/obj/effect/landmark/start/donor/waiter
	name = /datum/job/donor/waiter::title
	icon_state = JOB_BARTENDER

/obj/effect/landmark/start/donor/administrator
	name = /datum/job/donor/administrator::title
	icon_state = JOB_BARTENDER

/obj/effect/landmark/start/donor/guard
	name = /datum/job/donor/guard::title
	icon_state = JOB_BARTENDER

/obj/effect/landmark/start/donor/dealer
	name = /datum/job/donor/dealer::title
	icon_state = JOB_CURATOR

/obj/effect/landmark/start/donor/banker
	name = /datum/job/donor/banker::title
	icon_state = JOB_ASSISTANT

/obj/effect/landmark/start/donor/tourist_tsf
	name = /datum/job/donor/tourist_tsf::title
	icon_state = JOB_ASSISTANT

/obj/effect/landmark/start/donor/tourist_ussp
	name = /datum/job/donor/tourist_ussp::title
	icon_state = JOB_ASSISTANT

/obj/effect/landmark/start/donor/migrant
	name = /datum/job/donor/migrant::title
	icon_state = JOB_ASSISTANT

/obj/effect/landmark/start/donor/representative_tsf
	name = /datum/job/donor/representative_tsf::title
	icon_state = JOB_HEAD_OF_PERSONNEL

/obj/effect/landmark/start/donor/representative_ussp
	name = /datum/job/donor/representative_ussp::title
	icon_state = JOB_HEAD_OF_PERSONNEL

/obj/effect/landmark/start/donor/navy_junior_officer
	name = /datum/job/donor/navy_junior_officer::title
	icon_state = JOB_CAPTAIN

/obj/effect/landmark/start/donor/cargo_gorilla
	name = JOB_CARGO_GORILLA
	icon_state = JOB_CARGO_TECHNICIAN

/obj/effect/landmark/start/donor/bridge_assistant
	name = JOB_BRIDGE_ASSISTANT
	icon_state = JOB_CAPTAIN

/obj/effect/landmark/start/donor/human_ai
	name = JOB_HUMAN_AI
	icon_state = JOB_AI

/obj/effect/landmark/start/donor/veteran_advisor
	name = JOB_VETERAN_ADVISOR
	icon_state = JOB_SECURITY_OFFICER

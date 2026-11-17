/** Cancelling prepared token roles must restore ordinary candidacy and pre-existing job restrictions. */
/datum/unit_test/antag_token_reservation_cancellation
	/// Preserve the job subsystem's original restriction table even if an assertion fails.
	var/list/original_prevented_occupations
	/// Only save/restore the live subsystem's token fields; constructing a subsystem replaces its global.
	var/list/original_dynamic_state

/datum/unit_test/antag_token_reservation_cancellation/Destroy()
	if(original_dynamic_state)
		SSjob.prevented_occupations = original_prevented_occupations
		SSdynamic.antag_token_rulesets = original_dynamic_state["rulesets"]
		SSdynamic.antag_token_previous_occupations = original_dynamic_state["occupations"]
		SSdynamic.antag_token_candidates = original_dynamic_state["candidates"]
		SSdynamic.antag_tokens_enabled = original_dynamic_state["enabled"]
		SSdynamic.antag_token_execution_started = original_dynamic_state["execution_started"]
	original_prevented_occupations = null
	original_dynamic_state = null
	return ..()

/datum/unit_test/antag_token_reservation_cancellation/Run()
	original_prevented_occupations = SSjob.prevented_occupations
	original_dynamic_state = list(
		"rulesets" = SSdynamic.antag_token_rulesets,
		"occupations" = SSdynamic.antag_token_previous_occupations,
		"candidates" = SSdynamic.antag_token_candidates,
		"enabled" = SSdynamic.antag_tokens_enabled,
		"execution_started" = SSdynamic.antag_token_execution_started,
	)
	SSjob.prevented_occupations = list()
	var/datum/controller/subsystem/dynamic/dynamic = SSdynamic
	dynamic.antag_token_rulesets = list()
	dynamic.antag_token_previous_occupations = list()
	dynamic.antag_token_execution_started = FALSE
	var/mob/dead/new_player/player = allocate(/mob/dead/new_player)
	var/datum/mind/player_mind = allocate(/datum/mind)
	player.mind = player_mind
	player_mind.current = player
	player.ready = PLAYER_READY_TO_PLAY
	var/datum/dynamic_ruleset/roundstart/traitor/ruleset = allocate(/datum/dynamic_ruleset/roundstart/traitor)
	ruleset.selected_minds += player_mind
	dynamic.antag_token_rulesets += ruleset
	dynamic.antag_token_previous_occupations[ruleset] = list(JOB_MEDICAL_DOCTOR)
	dynamic.antag_token_candidates = list()
	SSjob.prevented_occupations[player_mind] = list(JOB_MEDICAL_DOCTOR, JOB_AI)
	dynamic.antag_tokens_enabled = FALSE

	dynamic.cancel_antag_token_rulesets()

	TEST_ASSERT(player in dynamic.antag_token_candidates, "Cancelled token user was not returned to ordinary antagonist candidates.")
	var/list/restrictions = SSjob.prevented_occupations[player_mind]
	TEST_ASSERT_EQUAL(length(restrictions), 1, "Token-only job restrictions remained after cancellation.")
	TEST_ASSERT(JOB_MEDICAL_DOCTOR in restrictions, "Cancellation removed a restriction that existed before the token request.")
	TEST_ASSERT_EQUAL(length(dynamic.antag_token_rulesets), 0, "Cancelled token rulesets remained prepared.")
	TEST_ASSERT_EQUAL(length(dynamic.antag_token_previous_occupations), 0, "Cancellation retained references to prepared rulesets.")
	dynamic.antag_token_candidates = null

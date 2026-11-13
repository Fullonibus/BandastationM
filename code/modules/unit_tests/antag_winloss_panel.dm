/datum/unit_test/antag_winloss_completed_custom_objective/Run()
	var/datum/antag_winloss_panel/panel = allocate(/datum/antag_winloss_panel)
	var/datum/objective/custom/ritual = allocate(/datum/objective/custom)
	ritual.completed = TRUE
	var/datum/objective/custom/narrative_goal = allocate(/datum/objective/custom)
	var/list/objective_rows = list()

	var/list/result = panel.evaluate_objectives(list(ritual, narrative_goal), objective_rows)
	var/list/ritual_row = objective_rows[ritual]
	var/list/narrative_row = objective_rows[narrative_goal]
	TEST_ASSERT_EQUAL(result["outcome"], 1, "Explicitly completed custom objectives must count as wins.")
	TEST_ASSERT_EQUAL(ritual_row["completed"], TRUE, "The panel must show the ritual objective as completed.")
	TEST_ASSERT_NULL(narrative_row["completed"], "Narrative objectives without a completion marker must remain unscored.")

/datum/unit_test/antag_winloss_mutiny_preview/Run()
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/mind/target = allocate(/datum/mind)
	target.current = body
	var/datum/objective/mutiny/mutiny = allocate(/datum/objective/mutiny)
	mutiny.target = target
	var/datum/antag_winloss_panel/panel = allocate(/datum/antag_winloss_panel)
	TEST_ASSERT(considered_alive(target) && considered_afk(target), "The target must be alive and disconnected.")

	panel.evaluate_objectives(list(mutiny), list())
	TEST_ASSERT(!COOLDOWN_STARTED(mutiny, disconnect_timer), "Viewing the panel started the mutiny disconnect grace period.")

	mutiny.check_completion()
	TEST_ASSERT(COOLDOWN_STARTED(mutiny, disconnect_timer), "The gameplay check failed to start the disconnect grace period.")

	COOLDOWN_START(mutiny, disconnect_timer, 1 SECONDS)
	panel.evaluate_objectives(list(mutiny), list())
	TEST_ASSERT(!mutiny.warned_admins, "Viewing the panel consumed the gameplay warning.")

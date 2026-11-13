/// Shared real-mob setup for Khaaroot task, UI permission, and subscription regressions.
/datum/unit_test/khaaroot_hivemind
	abstract_type = /datum/unit_test/khaaroot_hivemind
	/// Current source body.
	var/mob/living/carbon/human/source
	/// Current infected body.
	var/mob/living/carbon/human/member
	/// Controller destroyed before its allocated bodies and minds.
	var/datum/khaaroot_hivemind/hive

/datum/unit_test/khaaroot_hivemind/Destroy()
	QDEL_NULL(hive)
	source = null
	member = null
	return ..()

/// Allocate a real body and retain its initialized mind for test teardown.
/datum/unit_test/khaaroot_hivemind/proc/create_person()
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent)
	person.mind_initialize()
	allocated += person.mind
	return person

/// Create the source and infect the member through the production conversion entry point.
/datum/unit_test/khaaroot_hivemind/proc/create_hive()
	source = create_person()
	member = create_person()
	hive = allocate(/datum/khaaroot_hivemind, source.mind)
	return hive.infect(member, source)

/// Assign using the same current-membership and revision snapshot as the source UI.
/datum/unit_test/khaaroot_hivemind/proc/assign_task(text)
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	return hive.set_thrall_objective(member.mind, text, source, antag.objective_revision, antag)

/// Exercise the real UI action boundary without opening an interactive browser window.
/datum/unit_test/khaaroot_hivemind/proc/respond(status, revision, mob/actor, target_ref)
	actor ||= member
	var/datum/tgui/ui = allocate(/datum/tgui, actor, hive, "KhaarootHivemind")
	ui.status = UI_INTERACTIVE
	return hive.ui_act("respond_objective", list("status" = status, "revision" = revision, "ref" = target_ref), ui, hive.ui_state(actor))

/// A forged target, repeated answer, or stale task must not change another member or append events.
/datum/unit_test/khaaroot_hivemind/task_replies/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	if(!(assign_task("Охранять источник")))
		TEST_FAIL("The source could not assign a task")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	var/first_revision = antag.objective_revision
	var/event_count = length(hive.events)
	respond("completed", first_revision)
	if(antag.objective_status != "assigned")
		TEST_FAIL("A member completed a task before accepting it")
		return
	if(length(hive.events) != event_count)
		TEST_FAIL("A rejected transition created a journal entry")
		return
	respond("blocked", first_revision)
	if(antag.objective_status != "assigned")
		TEST_FAIL("Cancelling the blocked-task dialog changed the task")
		return
	if(length(hive.events) != event_count)
		TEST_FAIL("Cancelling the dialog created a journal entry")
		return

	var/mob/living/carbon/human/other = create_person()
	if(!(hive.infect(other, source)))
		TEST_FAIL("Could not infect the second member")
		return
	var/datum/antagonist/khaaroot_thrall/other_antag = hive.get_thrall_antag(other.mind)
	if(!(hive.set_thrall_objective(other.mind, "Другая задача", source, other_antag.objective_revision, other_antag)))
		TEST_FAIL("Could not assign the second task")
		return
	if(!(!hive.set_thrall_objective(other.mind, "Поддельный приказ", member, other_antag.objective_revision, other_antag)))
		TEST_FAIL("A member assigned a task using the source mutation boundary")
		return
	respond("accepted", first_revision, member, REF(other.mind))
	if(antag.objective_status != "accepted")
		TEST_FAIL("A valid self response was not applied")
		return
	if(other_antag.objective_status != "assigned")
		TEST_FAIL("A forged ref changed another member's task")
		return
	event_count = length(hive.events)
	respond("accepted", first_revision)
	if(length(hive.events) != event_count)
		TEST_FAIL("A repeated response created a duplicate journal entry")
		return
	respond("completed", first_revision)
	if(antag.objective_status != "completed")
		TEST_FAIL("An accepted task could not be completed")
		return
	respond("accepted", first_revision)
	if(antag.objective_status != "completed")
		TEST_FAIL("A completed task was reopened without a new assignment")
		return

	if(!(assign_task("Новая задача")))
		TEST_FAIL("The source could not replace a completed task")
		return
	if(antag.objective_revision != first_revision + 1)
		TEST_FAIL("Replacing the task did not invalidate old responses")
		return
	if(antag.objective_status != "assigned")
		TEST_FAIL("A new task retained its old completion status")
		return
	event_count = length(hive.events)
	respond("accepted", first_revision)
	if(antag.objective_status != "assigned")
		TEST_FAIL("An outdated response accepted the replacement task")
		return
	if(length(hive.events) != event_count)
		TEST_FAIL("An outdated response created a journal entry")
		return

/// Revalidate consciousness and the exact antag membership when a delayed text response returns.
/datum/unit_test/khaaroot_hivemind/invalidated_reply/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	if(!(assign_task("Доложить")))
		TEST_FAIL("Could not assign a task")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	var/revision = antag.objective_revision
	member.SetUnconscious(5 SECONDS)
	if(!(!hive.respond_to_objective(member, "blocked", revision, "Причина", antag)))
		TEST_FAIL("An unconscious member submitted a delayed response")
		return
	member.SetUnconscious(0)
	if(!(hive.respond_to_objective(member, "blocked", revision, "Нужна помощь", antag)))
		TEST_FAIL("A conscious member could not report an obstacle")
		return
	if(antag.objective_reply != "Нужна помощь")
		TEST_FAIL("The member's reason was not retained")
		return
	respond("accepted", revision)
	if(antag.objective_status != "accepted")
		TEST_FAIL("A blocked task could not be resumed")
		return
	if(antag.objective_reply != "")
		TEST_FAIL("Resuming a task retained an outdated obstacle reason")
		return
	if(!(hive.respond_to_objective(member, "blocked", revision, "Новая помеха", antag)))
		TEST_FAIL("An accepted task could not be marked blocked")
		return
	if(!(assign_task("Заменённая задача")))
		TEST_FAIL("Could not replace a blocked task")
		return
	if(antag.objective_reply != "")
		TEST_FAIL("A new task retained the previous obstacle reason")
		return
	if(!(!hive.respond_to_objective(member, "blocked", revision, "Старый ответ", antag)))
		TEST_FAIL("A delayed response changed the replacement task")
		return

	hive.remove_thrall(member.mind)
	if(!(hive.infect(member, source)))
		TEST_FAIL("Could not re-infect the former member")
		return
	if(!(assign_task("Задача нового участника")))
		TEST_FAIL("Could not assign the replacement membership's task")
		return
	var/datum/antagonist/khaaroot_thrall/replacement = hive.get_thrall_antag(member.mind)
	if(!(!hive.respond_to_objective(member, "blocked", replacement.objective_revision, "Ответ прошлого членства", antag)))
		TEST_FAIL("A dialog from removed membership changed a new membership")
		return
	if(replacement.objective_status != "assigned")
		TEST_FAIL("Re-infection accepted an old membership's response")
		return

/// A member sees only itself and cannot forge source actions; outsiders see no private data.
/datum/unit_test/khaaroot_hivemind/ui_permissions/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	if(!(assign_task("Личная задача")))
		TEST_FAIL("Could not assign a task")
		return
	var/mob/living/carbon/human/other = create_person()
	if(!(hive.infect(other, source)))
		TEST_FAIL("Could not infect the second member")
		return
	var/list/data = hive.ui_data(member)
	var/list/visible_members = data["thralls"]
	if(data["can_manage"] != FALSE)
		TEST_FAIL("An ordinary member received source permission")
		return
	if(length(visible_members) != 1)
		TEST_FAIL("An ordinary member received the hive roster")
		return
	var/list/self_data = visible_members[1]
	if(self_data["ref"] != REF(member.mind))
		TEST_FAIL("The self view contains another member")
		return
	if(length(data["events"]) != 0)
		TEST_FAIL("An ordinary member received the private journal")
		return
	if(data["thrall_count"] != 1)
		TEST_FAIL("The self view leaked the hive population")
		return
	var/datum/tgui/ui = allocate(/datum/tgui, member, hive, "KhaarootHivemind")
	ui.status = UI_INTERACTIVE
	var/event_count = length(hive.events)
	for(var/action in list("set_objective", "send_command", "kill_thrall"))
		hive.ui_act(action, list("ref" = REF(other.mind)), ui, hive.ui_state(member))
	if(other.stat != STABLE)
		TEST_FAIL("A member forged a remote execution")
		return
	if(length(hive.events) != event_count)
		TEST_FAIL("A forged source action changed hive state")
		return
	var/mob/living/carbon/human/outsider = create_person()
	data = hive.ui_data(outsider)
	if(length(data["thralls"]) != 0)
		TEST_FAIL("An outsider received the hive roster")
		return
	if(length(data["events"]) != 0)
		TEST_FAIL("An outsider received the journal")
		return
	if(hive.ui_status(outsider, hive.ui_state(outsider)) != UI_CLOSE)
		TEST_FAIL("An outsider retained access to the panel")
		return

/// Real damage emits one alert per critical/dead transition, with another critical alert after recovery.
/datum/unit_test/khaaroot_hivemind/health_events/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	var/event_count = length(hive.events)
	member.adjust_oxy_loss(110, forced = TRUE)
	if(length(hive.events) != event_count + 1)
		TEST_FAIL("Entering critical health did not append exactly one event")
		return
	member.updatehealth()
	member.updatehealth()
	if(length(hive.events) != event_count + 1)
		TEST_FAIL("Repeated health updates duplicated the critical event")
		return
	member.adjust_oxy_loss(-110, forced = TRUE)
	member.adjust_oxy_loss(110, forced = TRUE)
	if(length(hive.events) != event_count + 2)
		TEST_FAIL("A new critical episode after recovery was not reported")
		return
	member.death(FALSE)
	if(length(hive.events) != event_count + 3)
		TEST_FAIL("Death did not append exactly one event")
		return
	member.updatehealth()
	SEND_SIGNAL(member, COMSIG_LIVING_DEATH, FALSE)
	if(length(hive.events) != event_count + 3)
		TEST_FAIL("Health and repeated death signals duplicated the death event")
		return

/// A task follows the mind, while old bodies and removed members stop contributing events/actions.
/datum/unit_test/khaaroot_hivemind/transfer_and_removal/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	if(!(assign_task("Сохранённая задача")))
		TEST_FAIL("Could not assign a task")
		return
	var/datum/mind/member_mind = member.mind
	var/mob/living/carbon/human/old_body = member
	member = allocate(/mob/living/carbon/human/consistent)
	member_mind.transfer_to(member)
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member_mind)
	if(antag.thrall_objective != "Сохранённая задача")
		TEST_FAIL("Mind transfer lost the task")
		return
	if(!(!HAS_TRAIT(old_body, TRAIT_FEARLESS)))
		TEST_FAIL("The old body retained the member trait")
		return
	var/datum/action/cooldown/khaaroot_hivemind_panel/panel = locate() in member.actions
	if(isnull(panel))
		TEST_FAIL("The new body did not receive the member panel")
		return
	if(!(!(locate(/datum/action/cooldown/khaaroot_hivemind_panel) in old_body.actions)))
		TEST_FAIL("The old body retained the panel")
		return
	var/event_count = length(hive.events)
	old_body.adjust_oxy_loss(110, forced = TRUE)
	if(length(hive.events) != event_count)
		TEST_FAIL("The abandoned body still reports health events")
		return
	if(!(!hive.respond_to_objective(old_body, "accepted", antag.objective_revision, "", antag)))
		TEST_FAIL("A stale body submitted a response after mind transfer")
		return
	member.adjust_oxy_loss(110, forced = TRUE)
	if(length(hive.events) != event_count + 1)
		TEST_FAIL("The current body did not report critical health")
		return
	member_mind.remove_antag_datum(/datum/antagonist/khaaroot_thrall)
	if(length(hive.thralls) != 0)
		TEST_FAIL("External antag removal left stale hive membership")
		return
	if(!(QDELETED(panel)))
		TEST_FAIL("External antag removal retained the member panel action")
		return
	event_count = length(hive.events)
	member.death(FALSE)
	if(length(hive.events) != event_count)
		TEST_FAIL("A removed member still reports death events")
		return

/// Body loss is represented without destroying membership; the journal stays capped and contains values only.
/datum/unit_test/khaaroot_hivemind/body_loss_and_journal/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	if(!(assign_task("Дождаться восстановления")))
		TEST_FAIL("Could not assign a task")
		return
	var/datum/mind/member_mind = member.mind
	qdel(member)
	var/list/data = hive.ui_data(source)
	var/list/visible_members = data["thralls"]
	if(length(visible_members) != 1)
		TEST_FAIL("Reading UI deleted a member whose body was lost")
		return
	var/list/member_data = visible_members[1]
	if(member_data["has_mob"] != FALSE)
		TEST_FAIL("A deleted body is still shown as present")
		return
	member = allocate(/mob/living/carbon/human/consistent)
	member_mind.transfer_to(member)
	if(isnull(hive.get_thrall_antag(member_mind)))
		TEST_FAIL("A bodyless member could not return to the hive")
		return
	if(hive.get_thrall_objective(member_mind) != "Дождаться восстановления")
		TEST_FAIL("Body loss discarded the assigned task")
		return
	for(var/index in 1 to 60)
		if(!(assign_task("Задача [index]")))
			TEST_FAIL("Could not append a task event")
			return
	if(length(hive.events) != 50)
		TEST_FAIL("The journal exceeded its retention bound")
		return
	var/list/newest = hive.events[1]
	var/list/oldest = hive.events[50]
	if(!(newest["id"] > oldest["id"]))
		TEST_FAIL("The journal is not newest first")
		return
	for(var/list/event as anything in hive.events)
		for(var/field in event)
			if(!(istext(event[field]) || isnum(event[field])))
				TEST_FAIL("A journal entry retained a datum/list reference")
				return

/// Removing the source role or the controller revokes source actions and all member subscriptions.
/datum/unit_test/khaaroot_hivemind/controller_cleanup/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	if(!(assign_task("Исходная задача")))
		TEST_FAIL("Could not assign a task")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	var/datum/action/cooldown/khaaroot_hivemind_panel/source_panel = locate() in source.actions
	var/datum/action/cooldown/khaaroot_hivemind_panel/member_panel = locate() in member.actions
	if(isnull(source_panel))
		TEST_FAIL("The source fixture did not receive its panel")
		return
	if(isnull(member_panel))
		TEST_FAIL("The member fixture did not receive its panel")
		return
	if(hive.get_infector_mob() != source)
		TEST_FAIL("The active source was not resolved as the private notification recipient")
		return
	source.mind.remove_antag_datum(/datum/antagonist/khaaroot_source)
	var/event_count = length(hive.events)
	member.adjust_oxy_loss(110, forced = TRUE)
	if(length(hive.events) != event_count + 1)
		TEST_FAIL("Revoking the source role disabled the hive's critical-state journal")
		return
	if(!isnull(hive.get_infector_mob()))
		TEST_FAIL("A former source remained eligible for private hive notifications")
		return
	if(!(!hive.set_thrall_objective(member.mind, "Устаревший ввод", source, antag.objective_revision, antag)))
		TEST_FAIL("A source that lost its role still assigned a delayed task")
		return
	if(!(QDELETED(source_panel)))
		TEST_FAIL("Removing the source role retained its panel action")
		return
	qdel(hive)
	if(!(QDELETED(member_panel)))
		TEST_FAIL("Deleting the hive retained the member panel")
		return
	if(!(!HAS_TRAIT(member, TRAIT_FEARLESS)))
		TEST_FAIL("Deleting the hive retained the member trait")
		return
	if(!isnull(member.mind.has_antag_datum(/datum/antagonist/khaaroot_thrall)))
		TEST_FAIL("Deleting the hive retained its antagonist datum")
		return

/// Remote execution finishes even if its immediate damage killed the target before the timer fires.
/datum/unit_test/khaaroot_hivemind/execution_cleanup/Run()
	if(!(create_hive()))
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/mind/member_mind = member.mind
	if(!(hive.kill_thrall(member_mind)))
		TEST_FAIL("Could not start remote execution")
		return
	var/deadline = world.time + 5 SECONDS
	UNTIL(!hive.get_thrall_antag(member_mind) || world.time >= deadline)
	if(member.stat != DEAD)
		TEST_FAIL("Remote execution did not kill its target")
		return
	if(!isnull(hive.get_thrall_antag(member_mind)))
		TEST_FAIL("A target killed before the timer fired remained in the hive")
		return

/** Real recovery closes existing trauma without preventing new bleeding, and expires after a modest heal budget. */
/datum/unit_test/khaaroot_hivemind/recovery_clot_and_heal/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/action/cooldown/khaaroot_mutation/recover/recover = locate() in member.actions
	if(!recover)
		TEST_FAIL("Conversion did not grant the shared recovery action")
		return
	ADD_TRAIT(member, TRAIT_NOHUNGER, TRAIT_SOURCE_UNIT_TESTS) // Isolate the skill's blood restoration from nutritional regeneration.
	member.take_overall_damage(brute = 30, burn = 30)
	member.set_blood_volume(500)
	var/obj/item/bodypart/arm = member.get_bodypart(BODY_ZONE_R_ARM)
	var/obj/item/bodypart/leg = member.get_bodypart(BODY_ZONE_L_LEG)
	var/datum/wound/slash/flesh/critical/cut = new
	var/datum/wound/blunt/bone/severe/fracture = new
	if(!cut.apply_wound(arm) || !fracture.apply_wound(leg))
		TEST_FAIL("Could not create real bleeding and fracture wounds")
		return
	member.reagents.remove_reagent(/datum/reagent/determination, INFINITY) // Isolate recovery from the wound's independent second-wind healing.
	arm.setBleedStacks(2)
	if(member.get_bleed_rate() <= 0 || !recover.Trigger(member))
		TEST_FAIL("The wounded current member could not start recovery")
		return
	var/datum/status_effect/khaaroot_recovery/recovery = member.has_status_effect(/datum/status_effect/khaaroot_recovery)
	if(!recovery || member.get_bleed_rate() != 0 || arm.generic_bleedstacks > 0)
		TEST_FAIL("Recovery did not close the complete critical-slash demotion chain and generic bleeding")
		return
	if(QDELETED(fracture) || fracture.victim != member)
		TEST_FAIL("Stopping traumatic bleeding also removed an unrelated fracture")
		return
	var/brute_before = member.get_brute_loss()
	var/burn_before = member.get_fire_loss()
	var/blood_before = member.get_blood_volume()
	var/deadline = world.time + 4 SECONDS
	while(member.get_brute_loss() >= brute_before && world.time < deadline)
		sleep(world.tick_lag)
	if(member.get_brute_loss() >= brute_before || member.get_fire_loss() >= burn_before || member.get_blood_volume() <= blood_before)
		TEST_FAIL("The real status scheduler did not gradually heal damage and restore blood")
		return
	recover.ResetCooldown()
	var/remaining_duration = recovery.duration
	if(recover.Trigger(member) || member.has_status_effect(/datum/status_effect/khaaroot_recovery) != recovery || recovery.duration != remaining_duration)
		TEST_FAIL("Repeated recovery stacked or refreshed an already active effect")
		return
	var/datum/wound/pierce/bleed/moderate/new_wound = new
	if(!new_wound.apply_wound(arm) || member.get_bleed_rate() <= 0)
		TEST_FAIL("A new injury could not bleed while recovery was active")
		return
	qdel(new_wound) // End the independent injury before measuring the complete skill budget.
	member.reagents.remove_reagent(/datum/reagent/determination, INFINITY)
	deadline = world.time + 32 SECONDS
	while(!QDELETED(recovery) && world.time < deadline)
		sleep(world.tick_lag)
	if(!QDELETED(recovery))
		TEST_FAIL("Recovery did not expire through the real status scheduler")
		return
	if(brute_before - member.get_brute_loss() != 15 || burn_before - member.get_fire_loss() != 15 || member.get_blood_volume() - blood_before != 30)
		TEST_FAIL("The complete recovery did not respect its 15 brute, 15 burn, and 30 blood budget")
		return

/** The source can use the same recovery, including its bounded blood restoration. */
/datum/unit_test/khaaroot_hivemind/recovery_source_and_blood_cap/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/action/cooldown/khaaroot_mutation/recover/recover = locate() in source.actions
	if(!recover)
		TEST_FAIL("The source did not receive the shared recovery action")
		return
	ADD_TRAIT(source, TRAIT_NOHUNGER, TRAIT_SOURCE_UNIT_TESTS)
	source.take_overall_damage(brute = 10)
	source.set_blood_volume(BLOOD_VOLUME_NORMAL - 0.5)
	if(!recover.Trigger(source))
		TEST_FAIL("The current source could not activate recovery")
		return
	var/deadline = world.time + 4 SECONDS
	while(source.get_blood_volume() < BLOOD_VOLUME_NORMAL && world.time < deadline)
		sleep(world.tick_lag)
	if(source.get_blood_volume() != BLOOD_VOLUME_NORMAL)
		TEST_FAIL("Recovery did not restore blood up to the native normal-volume cap")
		return
	var/datum/status_effect/khaaroot_recovery/recovery = source.has_status_effect(/datum/status_effect/khaaroot_recovery)
	source.mind.remove_antag_datum(/datum/antagonist/khaaroot_source)
	if(!QDELETED(recover) || !QDELETED(recovery))
		TEST_FAIL("Removing the source role left its body-bound recovery active")
		return

/** A moving or removed actor cannot finish an interrupted real channel and receive a late heal. */
/datum/unit_test/khaaroot_hivemind/recovery_channel_invalidated/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/action/cooldown/khaaroot_mutation/recover/recover = locate() in member.actions
	member.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	addtimer(CALLBACK(member, TYPE_PROC_REF(/atom/movable, forceMove), get_step(member, EAST)), 0.4 SECONDS)
	if(recover.Trigger(member) || member.has_status_effect(/datum/status_effect/khaaroot_recovery) || recover.next_use_time > world.time)
		TEST_FAIL("An interrupted recovery channel healed or consumed the completed-use cooldown")
		return
	addtimer(CALLBACK(hive, TYPE_PROC_REF(/datum/khaaroot_hivemind, remove_thrall), member.mind, TRUE), 0.4 SECONDS)
	var/recovered = recover.Trigger(member)
	if(member.mind.has_antag_datum(/datum/antagonist/khaaroot_thrall))
		TEST_FAIL("The removal fixture did not run during the real recovery channel")
		return
	if(recovered || !QDELETED(recover) || member.has_status_effect(/datum/status_effect/khaaroot_recovery))
		TEST_FAIL("Recovery completed after its exact role was removed during channeling")
		return

/** Active recovery survives unconsciousness, but death and body transfer end the exact body's effect. */
/datum/unit_test/khaaroot_hivemind/recovery_lifecycle/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	member.take_overall_damage(brute = 30)
	var/datum/action/cooldown/khaaroot_mutation/recover/recover = locate() in member.actions
	if(!recover.Trigger(member))
		TEST_FAIL("Could not start recovery before unconsciousness")
		return
	var/datum/status_effect/khaaroot_recovery/recovery = member.has_status_effect(/datum/status_effect/khaaroot_recovery)
	var/brute_before = member.get_brute_loss()
	member.Unconscious(5 SECONDS)
	var/deadline = world.time + 4 SECONDS
	while(member.get_brute_loss() >= brute_before && world.time < deadline)
		sleep(world.tick_lag)
	if(QDELETED(recovery) || member.get_brute_loss() >= brute_before)
		TEST_FAIL("Already active recovery stopped when its current owner became unconscious")
		return
	var/mob/living/carbon/human/new_body = create_person()
	member.mind.transfer_to(new_body)
	if(!QDELETED(recovery) || !QDELETED(recover) || new_body.has_status_effect(/datum/status_effect/khaaroot_recovery))
		TEST_FAIL("Body transfer retained or transferred the old body's active recovery")
		return
	var/datum/action/cooldown/khaaroot_mutation/recover/new_recover = locate() in new_body.actions
	if(!new_recover || !new_recover.Trigger(new_body))
		TEST_FAIL("The current replacement body could not use its newly bound recovery action")
		return
	var/datum/status_effect/khaaroot_recovery/new_recovery = new_body.has_status_effect(/datum/status_effect/khaaroot_recovery)
	new_body.death()
	if(!QDELETED(new_recovery))
		TEST_FAIL("A dead body retained active recovery")
		return

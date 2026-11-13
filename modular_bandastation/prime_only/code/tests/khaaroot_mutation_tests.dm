/** Core mutation regressions using the existing real-body hive fixture. */
/datum/unit_test/khaaroot_hivemind/mutation_bone_toggle/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/action/cooldown/khaaroot_mutation/bone_spike/spike = locate() in member.actions
	if(!spike)
		TEST_FAIL("Conversion did not grant the common bone spike")
		return
	if(spike.Trigger(source) || spike.is_revealed())
		TEST_FAIL("A different actor activated the member's mutation")
		return
	var/obj/item/pen/pen = allocate(/obj/item/pen)
	member.put_in_active_hand(pen)
	if(spike.Trigger(member) || member.get_active_held_item() != pen || spike.is_revealed())
		TEST_FAIL("Revealing the spike displaced an occupied active hand")
		return
	member.dropItemToGround(pen, force = TRUE)
	if(!spike.Trigger(member) || !istype(member.get_active_held_item(), /obj/item/khaaroot_mutation_arm/bone_spike))
		TEST_FAIL("A free hand did not reveal and hold the bone spike")
		return
	var/obj/item/khaaroot_mutation_arm/bone_spike/first_spike = spike.held_item
	spike.StartCooldown(10 SECONDS)
	if(!spike.Trigger(member) || !QDELETED(first_spike) || member.get_active_held_item())
		TEST_FAIL("The revealed spike could not retract safely during cooldown")
		return
	spike.ResetCooldown()
	if(!spike.Trigger(member))
		TEST_FAIL("The spike could not reveal after retracting")
		return
	var/obj/item/khaaroot_mutation_arm/bone_spike/second_spike = spike.held_item
	second_spike.attack_self(member)
	if(spike.is_revealed() || !QDELETED(second_spike) || member.get_active_held_item())
		TEST_FAIL("Self-use did not retract the mutation item")
		return
	if(!spike.Trigger(member))
		TEST_FAIL("The spike could not reveal before limb removal")
		return
	var/obj/item/khaaroot_mutation_arm/bone_spike/third_spike = spike.held_item
	var/obj/item/bodypart/arm = member.has_hand_for_held_index(member.active_hand_index)
	arm.drop_limb()
	if(!QDELETED(third_spike) || spike.is_revealed())
		TEST_FAIL("Losing the mutated hand left a visible mutation item")
		return

/** A delayed reveal must not take a hand filled after activation or survive role removal. */
/datum/unit_test/khaaroot_hivemind/mutation_reveal_invalidated/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	// Consistent humans have zero-duration do_afters in unit tests; this case must cross the real delay.
	member.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	var/datum/action/cooldown/khaaroot_mutation/bone_spike/spike = locate() in member.actions
	if(!spike)
		TEST_FAIL("Conversion did not grant the common bone spike")
		return
	var/obj/item/pen/pen = allocate(/obj/item/pen)
	addtimer(CALLBACK(member, TYPE_PROC_REF(/mob, put_in_active_hand), pen), 0.2 SECONDS)
	if(spike.Trigger(member) || member.get_active_held_item() != pen || spike.is_revealed())
		TEST_FAIL("The delayed reveal overwrote a newly occupied hand")
		return
	member.dropItemToGround(pen, force = TRUE)
	addtimer(CALLBACK(hive, TYPE_PROC_REF(/datum/khaaroot_hivemind, remove_thrall), member.mind, TRUE), 0.2 SECONDS)
	if(spike.Trigger(member) || !QDELETED(spike) || (locate(/obj/item/khaaroot_mutation_arm) in member.contents))
		TEST_FAIL("A reveal completed after its membership was removed")
		return

/** Specialization belongs to an exact membership and follows its mind across compatible bodies. */
/datum/unit_test/khaaroot_hivemind/mutation_membership_transfer/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	var/datum/khaaroot_mutations/mutations = antag.mutations
	if(!mutations)
		TEST_FAIL("Conversion did not create a mutation controller")
		return
	if(mutations.set_specialization(source, "gland") || mutations.set_specialization(member, "forged"))
		TEST_FAIL("A foreign actor or unknown specialization was accepted")
		return
	if(!mutations.set_specialization(member, "gland") || mutations.set_specialization(member, "molt"))
		TEST_FAIL("Specialization was unavailable or could be replaced")
		return
	var/datum/action/cooldown/khaaroot_mutation/bone_spike/old_spike = locate() in member.actions
	if(!old_spike.Trigger(member))
		TEST_FAIL("Could not reveal the spike before body transfer")
		return
	var/obj/item/khaaroot_mutation_arm/old_item = old_spike.held_item
	var/mob/living/carbon/human/old_body = member
	var/datum/mind/member_mind = member.mind
	var/mob/living/basic/pet/dog/corgi/incompatible_body = allocate(/mob/living/basic/pet/dog/corgi)
	member_mind.transfer_to(incompatible_body)
	if(!QDELETED(old_spike) || !QDELETED(old_item) || (locate(/datum/action/cooldown/khaaroot_mutation) in incompatible_body.actions))
		TEST_FAIL("Transfer retained old mutations or granted them to a nonhuman body")
		return
	if(mutations.can_use(old_body) || mutations.can_use(incompatible_body))
		TEST_FAIL("A stale or incompatible body retained mutation permission")
		return
	member = allocate(/mob/living/carbon/human/consistent)
	member_mind.transfer_to(member)
	var/datum/action/cooldown/khaaroot_mutation/bone_spike/new_spike = locate() in member.actions
	if(antag.mutations != mutations || mutations.specialization != "gland" || !new_spike || new_spike.is_revealed() || !(locate(/datum/action/cooldown/khaaroot_mutation/gland) in member.actions))
		TEST_FAIL("Returning to a human body lost the specialization or did not begin concealed")
		return
	hive.remove_thrall(member_mind, silent = TRUE)
	if(!QDELETED(mutations) || !QDELETED(new_spike))
		TEST_FAIL("Removing the membership retained its mutation controller or actions")
		return
	if(!hive.infect(member, source))
		TEST_FAIL("Could not create a replacement membership")
		return
	var/datum/antagonist/khaaroot_thrall/replacement = hive.get_thrall_antag(member_mind)
	if(replacement.mutations == mutations || replacement.mutations.specialization || mutations.set_specialization(member, "molt"))
		TEST_FAIL("A replacement membership reused the previous selection or accepted its stale controller")
		return

/** The source receives every mutation, with current-owner identity independent of consciousness. */
/datum/unit_test/khaaroot_hivemind/mutation_source_permissions_and_transfer/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_source/source_role = source.mind.has_antag_datum(/datum/antagonist/khaaroot_source)
	var/datum/khaaroot_mutations/mutations = source_role?.mutations
	if(!mutations || !mutations.is_current_owner(source))
		TEST_FAIL("The source did not receive its own exact-role mutation controller")
		return
	var/list/required_actions = list(
		/datum/action/cooldown/khaaroot_mutation/bone_spike,
		/datum/action/cooldown/khaaroot_mutation/recover,
		/datum/action/cooldown/khaaroot_mutation/tendril,
		/datum/action/cooldown/khaaroot_mutation/gland,
		/datum/action/cooldown/khaaroot_mutation/molt,
	)
	for(var/action_type in required_actions)
		var/datum/action/cooldown/khaaroot_mutation/ability = locate(action_type) in source.actions
		if(!ability || ability.get_mutations() != mutations)
			TEST_FAIL("The source is missing its own [action_type] action")
			return
	if((locate(/datum/action/cooldown/khaaroot_mutation/specialize) in source.actions) || mutations.set_specialization(source, "gland"))
		TEST_FAIL("The source received or accepted a thrall specialization choice")
		return
	if(!(locate(/datum/action/cooldown/khaaroot_mutation/recover) in member.actions))
		TEST_FAIL("The thrall did not receive the common recovery action")
		return
	var/mob/living/carbon/human/nonmember = create_person()
	if(mutations.is_current_owner(nonmember) || mutations.can_use(nonmember) || (locate(/datum/action/cooldown/khaaroot_mutation) in nonmember.actions))
		TEST_FAIL("An unrelated human received source mutations or their permission")
		return
	source.Unconscious(3 SECONDS)
	if(!IS_UNCONSCIOUS(source) || !mutations.is_current_owner(source) || mutations.can_use(source))
		TEST_FAIL("Unconsciousness invalidated role identity or allowed a new mutation activation")
		return
	source.SetUnconscious(0)
	var/datum/action/cooldown/khaaroot_mutation/bone_spike/spike = locate() in source.actions
	var/datum/action/cooldown/khaaroot_mutation/gland/gland = locate() in source.actions
	if(!spike.Trigger(source) || !gland.Trigger(source))
		TEST_FAIL("The source could not reveal its arm and chest mutations")
		return
	var/obj/item/khaaroot_mutation_arm/old_item = spike.held_item
	var/list/old_actions = mutations.actions.Copy()
	var/mob/living/carbon/human/old_body = source
	var/datum/mind/source_mind = source.mind
	source = allocate(/mob/living/carbon/human/consistent)
	source_mind.transfer_to(source)
	if(source_role.mutations != mutations || !mutations.can_use(source) || mutations.is_current_owner(old_body) || !QDELETED(old_item) || (locate(/datum/action/cooldown/khaaroot_mutation) in old_body.actions))
		TEST_FAIL("Source transfer lost ownership or retained mutations on the abandoned body")
		return
	for(var/datum/action/cooldown/khaaroot_mutation/old_action as anything in old_actions)
		if(!QDELETED(old_action))
			TEST_FAIL("Source transfer retained an old-body mutation action")
			return
	for(var/action_type in required_actions)
		var/datum/action/cooldown/khaaroot_mutation/ability = locate(action_type) in source.actions
		if(!ability || ability.is_revealed())
			TEST_FAIL("The source's new body did not receive a concealed [action_type] action")
			return

/** Body deletion and exact source-role replacement must destroy all old mutation effects and actions. */
/datum/unit_test/khaaroot_hivemind/mutation_source_body_and_role_cleanup/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/mind/source_mind = source.mind
	var/datum/antagonist/khaaroot_source/source_role = source_mind.has_antag_datum(/datum/antagonist/khaaroot_source)
	var/datum/khaaroot_mutations/mutations = source_role?.mutations
	var/datum/action/cooldown/khaaroot_mutation/bone_spike/spike = locate() in source.actions
	if(!mutations || !spike?.Trigger(source))
		TEST_FAIL("The source could not reveal its blade before body deletion")
		return
	var/obj/item/khaaroot_mutation_arm/old_item = spike.held_item
	var/list/old_actions = mutations.actions.Copy()
	qdel(source)
	if(!QDELETED(old_item) || mutations.get_owner() || length(mutations.actions))
		TEST_FAIL("Deleting the source body left its mutation item or bound actions")
		return
	for(var/datum/action/cooldown/khaaroot_mutation/old_action as anything in old_actions)
		if(!QDELETED(old_action))
			TEST_FAIL("Deleting the source body retained an owned mutation action")
			return
	source = allocate(/mob/living/carbon/human/consistent)
	source_mind.transfer_to(source)
	spike = locate() in source.actions
	if(source_role.mutations != mutations || !spike?.Trigger(source))
		TEST_FAIL("The source membership could not restore concealed mutations after body loss")
		return
	old_item = spike.held_item
	old_actions = mutations.actions.Copy()
	source_mind.remove_antag_datum(/datum/antagonist/khaaroot_source)
	if(!QDELETED(mutations) || !QDELETED(old_item) || mutations.is_current_owner(source) || (locate(/datum/action/cooldown/khaaroot_mutation) in source.actions))
		TEST_FAIL("Removing the exact source role retained mutation ownership or its visible blade")
		return
	for(var/datum/action/cooldown/khaaroot_mutation/old_action as anything in old_actions)
		if(!QDELETED(old_action))
			TEST_FAIL("Removing the source role retained one of its mutation actions")
			return
	var/datum/antagonist/khaaroot_source/replacement = source_mind.add_antag_datum(/datum/antagonist/khaaroot_source, hive.team)
	if(!replacement?.mutations || replacement.mutations == mutations || !replacement.mutations.is_current_owner(source) || mutations.can_use(source))
		TEST_FAIL("Replacing the source role reused or authorized its stale mutation controller")
		return

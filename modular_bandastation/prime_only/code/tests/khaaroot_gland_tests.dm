/// Native projectile collisions must corrode worn clothing and hurt exposed flesh only while the gland is open.
/datum/unit_test/khaaroot_hivemind/gland_corrosion/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "gland"))
		TEST_FAIL("Could not select the gland specialization")
		return
	var/datum/action/cooldown/khaaroot_mutation/gland/gland = locate() in member.actions
	member.forceMove(run_loc_floor_bottom_left)
	source.forceMove(get_step(run_loc_floor_bottom_left, NORTH))
	var/mob/living/carbon/human/victim = create_person()
	victim.forceMove(get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	victim.equip_to_slot_or_del(uniform, ITEM_SLOT_ICLOTHING)
	if(!gland.Trigger(member) || !gland.is_revealed())
		TEST_FAIL("The gland did not open through its real action")
		return
	var/datum/action/cooldown/khaaroot_mutation/gland_spit/spit_action = gland.spit_action
	if(!spit_action.Trigger(member, target = victim))
		TEST_FAIL("The open gland could not fire at an adjacent human")
		return
	var/deadline = world.time + 3 SECONDS
	while(!uniform.GetComponent(/datum/component/acid) && world.time < deadline)
		sleep(world.tick_lag)
	if(!uniform.GetComponent(/datum/component/acid))
		TEST_FAIL("A real gland projectile did not apply native corrosion to the worn uniform")
		return
	if(victim.get_brute_loss() + victim.get_fire_loss() <= 0)
		TEST_FAIL("The same native acid collision did not damage the victim's exposed skin")
		return
	gland.Trigger(member)
	if(gland.is_revealed() || (spit_action in member.actions) || member.click_intercept == spit_action)
		TEST_FAIL("Concealing the gland left its overlay or targeting action active")
		return
	if(spit_action.Trigger(member, target = victim))
		TEST_FAIL("A concealed gland fired a second projectile")
		return
	if(!gland.Trigger(member) || spit_action.next_use_time <= world.time)
		TEST_FAIL("Concealing and revealing the gland reset its spit cooldown")
		return

/// Native acid-proof objects survive the spit, and concealment cancels an in-flight shot.
/datum/unit_test/khaaroot_hivemind/gland_proof_and_cleanup/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "gland"))
		TEST_FAIL("Could not select the gland specialization")
		return
	var/datum/action/cooldown/khaaroot_mutation/gland/gland = locate() in member.actions
	member.forceMove(run_loc_floor_bottom_left)
	source.forceMove(get_step(run_loc_floor_bottom_left, NORTH))
	var/obj/item/clothing/suit/bio_suit/protected_suit = allocate(/obj/item/clothing/suit/bio_suit, get_step(run_loc_floor_bottom_left, EAST))
	var/original_integrity = protected_suit.get_integrity()
	if(!gland.Trigger(member) || !gland.spit_action.Trigger(member, target = protected_suit))
		TEST_FAIL("Could not fire the revealed gland at an acid-proof suit")
		return
	var/deadline = world.time + 3 SECONDS
	while(gland.spit_action.pending_spit && world.time < deadline)
		sleep(world.tick_lag)
	var/datum/component/acid/acid = protected_suit.GetComponent(/datum/component/acid)
	if(!acid)
		TEST_FAIL("The acid-proof target was never reached by the real projectile")
		return
	acid.process(1)
	if(QDELETED(protected_suit) || protected_suit.get_integrity() != original_integrity)
		TEST_FAIL("Gland acid bypassed the native ACID_PROOF contract")
		return
	var/obj/item/crowbar/unprotected_item = allocate(/obj/item/crowbar, get_step(get_step(get_step(run_loc_floor_bottom_left, EAST), EAST), EAST))
	gland.spit_action.ResetCooldown()
	if(!gland.spit_action.Trigger(member, target = unprotected_item))
		TEST_FAIL("Could not fire the second gland projectile")
		return
	var/obj/projectile/khaaroot_gland_spit/pending_spit = gland.spit_action.pending_spit
	gland.conceal()
	if(!QDELETED(pending_spit) || unprotected_item.GetComponent(/datum/component/acid))
		TEST_FAIL("Concealing the gland did not cancel its pending projectile")
		return
	gland.Trigger(member)
	var/datum/action/cooldown/khaaroot_mutation/gland_spit/spit_action = gland.spit_action
	member.mind.remove_antag_datum(/datum/antagonist/khaaroot_thrall)
	if(!QDELETED(gland) || !QDELETED(spit_action) || (spit_action in member.actions))
		TEST_FAIL("Removing membership left the gland's owned subaction alive")
		return

/// A delayed chest reveal cannot attach its overlay or subaction after membership removal.
/datum/unit_test/khaaroot_hivemind/gland_reveal_invalidated/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "gland"))
		TEST_FAIL("Could not select the gland specialization")
		return
	var/datum/action/cooldown/khaaroot_mutation/gland/gland = locate() in member.actions
	// Consistent humans normally skip do_after delays; this test must cross the real asynchronous boundary.
	member.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	addtimer(CALLBACK(hive, TYPE_PROC_REF(/datum/khaaroot_hivemind, remove_thrall), member.mind, TRUE), 0.2 SECONDS)
	var/reveal_succeeded = gland.Trigger(member)
	if(member.mind.has_antag_datum(/datum/antagonist/khaaroot_thrall))
		TEST_FAIL("The scheduled membership removal did not occur inside the real gland reveal delay")
		return
	if(reveal_succeeded || !QDELETED(gland) || (locate(/datum/action/cooldown/khaaroot_mutation/gland_spit) in member.actions))
		TEST_FAIL("A delayed gland reveal completed after its exact membership was removed")
		return

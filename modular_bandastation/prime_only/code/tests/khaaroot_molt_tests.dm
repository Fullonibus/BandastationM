/// Molting breaks a genuine aggressive grab without replacing the body, mind, or inventory.
/datum/unit_test/khaaroot_hivemind/molt_escape/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "molt"))
		TEST_FAIL("Could not select the molt specialization")
		return
	var/datum/action/cooldown/khaaroot_mutation/molt/molt = locate() in member.actions
	var/turf/start_turf = run_loc_floor_bottom_left
	member.forceMove(start_turf)
	source.forceMove(get_step(start_turf, NORTH))
	var/obj/item/crowbar/held_item = allocate(/obj/item/crowbar)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/storage/backpack/backpack = allocate(/obj/item/storage/backpack)
	var/obj/item/pen/stored_item = allocate(/obj/item/pen, backpack)
	member.put_in_active_hand(held_item)
	member.equip_to_slot_or_del(uniform, ITEM_SLOT_ICLOTHING)
	member.equip_to_slot_or_del(backpack, ITEM_SLOT_BACK)
	var/datum/mind/original_mind = member.mind
	if(!source.start_pulling(member, state = GRAB_AGGRESSIVE, supress_message = TRUE))
		TEST_FAIL("Could not establish a real pull")
		return
	source.setGrabState(GRAB_AGGRESSIVE)
	// Native aggressive grabs already drop ordinary held items before the mutation is used.
	var/atom/held_item_location = held_item.loc
	member.setDir(EAST)
	if(!molt.Trigger(member))
		TEST_FAIL("A conscious thrall could not molt out of an aggressive grab")
		return
	if(member.pulledby || source.pulling || source.grab_state != GRAB_PASSIVE)
		TEST_FAIL("Molting left the original pull relationship or aggressive grab active")
		return
	if(member.mind != original_mind || original_mind.current != member || held_item.loc != held_item_location || member.w_uniform != uniform || member.back != backpack || stored_item.loc != backpack)
		TEST_FAIL("Molting replaced the real body/mind or moved genuine inventory into its shell")
		return
	if(!molt.shell || molt.shell.loc != start_turf || length(molt.shell.contents))
		TEST_FAIL("Molting did not leave an empty physical shell on the previous turf")
		return
	if(member.loc != get_step(start_turf, EAST))
		TEST_FAIL("Molting did not take its permitted ordinary step onto the clear turf")
		return

/// A blocked step never teleports the body; native projectiles and fire destroy the empty shell.
/datum/unit_test/khaaroot_hivemind/molt_shell_damage/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "molt"))
		TEST_FAIL("Could not select the molt specialization")
		return
	var/datum/action/cooldown/khaaroot_mutation/molt/molt = locate() in member.actions
	member.forceMove(run_loc_floor_bottom_left)
	member.setDir(EAST)
	var/obj/structure/closet/blocker = allocate(/obj/structure/closet, get_step(run_loc_floor_bottom_left, EAST))
	if(!blocker.density || !molt.Trigger(member))
		TEST_FAIL("Could not create a molt with a blocked destination")
		return
	if(member.loc != run_loc_floor_bottom_left)
		TEST_FAIL("Molting moved the body through a dense obstruction")
		return
	var/obj/structure/khaaroot_molt_shell/first_shell = molt.shell
	var/obj/projectile/bullet/c9mm/bullet = allocate(/obj/projectile/bullet/c9mm)
	first_shell.bullet_act(bullet)
	if(!QDELETED(first_shell))
		TEST_FAIL("A real bullet did not destroy the low-integrity molt shell")
		return
	molt.ResetCooldown()
	if(!molt.Trigger(member))
		TEST_FAIL("Could not create a replacement shell after the first was destroyed")
		return
	var/obj/structure/khaaroot_molt_shell/second_shell = molt.shell
	second_shell.fire_act(1000, 100)
	if(!QDELETED(second_shell))
		TEST_FAIL("Native fire exposure did not destroy the unprotected shell")
		return

/// The shell expires through its real timer and is also cleaned up on body transfer.
/datum/unit_test/khaaroot_hivemind/molt_shell_lifecycle/Run()
	if(!create_hive())
		TEST_FAIL("Could not create the infected fixture")
		return
	var/datum/antagonist/khaaroot_thrall/antag = hive.get_thrall_antag(member.mind)
	if(!antag.mutations.set_specialization(member, "molt"))
		TEST_FAIL("Could not select the molt specialization")
		return
	var/datum/action/cooldown/khaaroot_mutation/molt/molt = locate() in member.actions
	molt.shell_lifetime = 0.2 SECONDS
	if(!molt.Trigger(member))
		TEST_FAIL("Could not create the expiring shell")
		return
	var/obj/structure/khaaroot_molt_shell/expired_shell = molt.shell
	var/deadline = world.time + 2 SECONDS
	while(!QDELETED(expired_shell) && world.time < deadline)
		sleep(world.tick_lag)
	if(!QDELETED(expired_shell))
		TEST_FAIL("The molt shell did not expire through its native timer")
		return
	molt.ResetCooldown()
	molt.shell_lifetime = 20 SECONDS
	if(!molt.Trigger(member))
		TEST_FAIL("Could not create the body-bound shell")
		return
	var/obj/structure/khaaroot_molt_shell/abandoned_shell = molt.shell
	var/mob/living/carbon/human/new_body = create_person()
	member.mind.transfer_to(new_body)
	if(!QDELETED(molt) || !QDELETED(abandoned_shell))
		TEST_FAIL("Body transfer left the old body's molt action or shell alive")
		return

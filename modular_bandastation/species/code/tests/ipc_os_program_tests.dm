/// The approved repair interval, energy modifiers and program removal share the real installed state.
/datum/unit_test/ipc_os_legal_programs/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/obj/item/organ/brain/ipc/core = ipc.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/datum/ipc_os/os = core.operating_system
	TEST_ASSERT(os.install("power_save"), "Could not install PowerSave.")
	TEST_ASSERT(os.install("defrag"), "Could not install Defrag.")
	var/datum/ipc_os_program/power_save = os.programs["power_save"]
	var/datum/ipc_os_program/defrag/defrag = os.programs["defrag"]
	TEST_ASSERT(power_save.start(), "PowerSave refused a valid IPC.")
	TEST_ASSERT_EQUAL(os.power_multiplier(), 0.7, "PowerSave changed the wrong baseline multiplier.")
	TEST_ASSERT(defrag.start(), "Defrag refused a valid IPC.")
	TEST_ASSERT_EQUAL(os.power_multiplier(), 0.7 * 1.35, "Defrag and PowerSave do not compose multiplicatively.")
	var/obj/item/bodypart/chest = ipc.get_bodypart(BODY_ZONE_CHEST)
	chest.receive_damage(brute = 10, burn = 8, wound_bonus = CANT_WOUND)
	var/brute_before = ipc.get_brute_loss()
	var/burn_before = ipc.get_fire_loss()
	defrag.tick(24)
	TEST_ASSERT_EQUAL(ipc.get_brute_loss(), brute_before, "Defrag healed before 25 running seconds.")
	defrag.tick(1)
	TEST_ASSERT_EQUAL(ipc.get_brute_loss(), brute_before - 2, "Defrag did not heal exactly 2 brute.")
	TEST_ASSERT_EQUAL(ipc.get_fire_loss(), burn_before, "Defrag healed burns.")
	os.uninstall("defrag")
	TEST_ASSERT(!defrag.running, "Uninstalled Defrag remains running.")
	TEST_ASSERT_EQUAL(os.power_multiplier(), 0.7, "Defrag left its power penalty.")
	os.uninstall("power_save")
	TEST_ASSERT_EQUAL(os.power_multiplier(), 1, "PowerSave left its discount.")

/// PowerSave toggles both costs together and composes with OverClock without a feedback loop.
/datum/unit_test/ipc_os_power_save_movement/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.mock_client = new /datum/client_interface()
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.install("power_save")
	var/datum/ipc_os_program/power_save/power_save = os.programs["power_save"]
	TEST_ASSERT(!power_save.running, "PowerSave activated without the player's toggle.")
	ipc.set_move_intent(MOVE_INTENT_WALK)
	var/walk_delay = ipc.cached_multiplicative_slowdown
	ipc.set_move_intent(MOVE_INTENT_RUN)
	var/run_delay = ipc.cached_multiplicative_slowdown
	TEST_ASSERT(power_save.start(), "PowerSave refused to start.")
	TEST_ASSERT(abs(ipc.cached_multiplicative_slowdown - run_delay / 0.85) < 0.001, "PowerSave did not slow running by 15%.")
	ipc.set_move_intent(MOVE_INTENT_WALK)
	TEST_ASSERT(abs(ipc.cached_multiplicative_slowdown - walk_delay / 0.85) < 0.001, "PowerSave did not slow walking by 15%.")
	power_save.stop()
	TEST_ASSERT_EQUAL(ipc.cached_multiplicative_slowdown, walk_delay, "Stopping PowerSave retained its slowdown.")
	TEST_ASSERT_EQUAL(os.power_multiplier(), 1, "Stopped PowerSave retained its energy discount.")
	ipc.set_move_intent(MOVE_INTENT_RUN)
	os.unlock(TRUE)
	os.install("overclock")
	var/datum/ipc_os_program/overclock/overclock = os.programs["overclock"]
	for(var/power_save_first in list(TRUE, FALSE))
		if(power_save_first)
			power_save.start()
			overclock.start()
		else
			overclock.start()
			power_save.start()
		TEST_ASSERT(abs(ipc.cached_multiplicative_slowdown - run_delay / (0.85 * 1.25)) < 0.001, "PowerSave and OverClock percentages depended on activation order.")
		TEST_ASSERT_EQUAL(os.power_multiplier(), 0.7, "Restarted PowerSave did not restore its discount.")
		power_save.stop()
		TEST_ASSERT(abs(ipc.cached_multiplicative_slowdown - run_delay / 1.25) < 0.001, "Stopping PowerSave damaged the active OverClock modifier.")
		overclock.stop()
	power_save.start()
	os.uninstall("power_save")
	TEST_ASSERT_EQUAL(ipc.cached_multiplicative_slowdown, run_delay, "Uninstalled PowerSave retained its movement penalty.")
	TEST_ASSERT(!ipc.has_movespeed_modifier(/datum/movespeed_modifier/ipc_os_power_save), "PowerSave retained its modifier after uninstall.")

/// One real embedded PDA registers one contact, owns no ID/cell and cleans up on removal.
/datum/unit_test/ipc_os_pda_lifecycle/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/obj/item/organ/brain/ipc/core = ipc.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/datum/ipc_os/os = core.operating_system
	os.install("pda")
	var/datum/ipc_os_program/pda/pda = os.programs["pda"]
	TEST_ASSERT(pda.start(), "Embedded PDA failed to start.")
	var/obj/item/modular_computer/pda/ipc_os/device = pda.device
	TEST_ASSERT_NULL(device.stored_id, "Embedded PDA created an ID.")
	TEST_ASSERT_NULL(device.internal_cell, "Embedded PDA created a second charge balance.")
	TEST_ASSERT_EQUAL(length(device.stored_files), 5, "Embedded PDA did not install its three apps, Hub and file manager.")
	var/datum/computer_file/program/messenger/messenger = locate() in device.stored_files
	TEST_ASSERT(REF(messenger) in GLOB.pda_messengers, "Embedded PDA was not registered as a contact.")
	pda.stop()
	TEST_ASSERT(!(REF(messenger) in GLOB.pda_messengers), "Stopped PDA left its contact registered.")
	TEST_ASSERT_EQUAL(device.loc, core, "Stopped PDA was left in the chassis.")
	TEST_ASSERT(pda.start(), "Embedded PDA could not restart.")
	TEST_ASSERT_EQUAL(pda.device, device, "Restart duplicated the embedded PDA.")
	os.uninstall("pda")
	TEST_ASSERT_NULL(pda.device, "Uninstalled PDA retained its device.")
	TEST_ASSERT(!(REF(messenger) in GLOB.pda_messengers), "Uninstalled PDA left a contact registered.")

/// Additional repair drain scales with elapsed time and active PowerSave reduces it to one third.
/datum/unit_test/ipc_os_defrag_hidden_drain/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	ipc.mock_client = new /datum/client_interface()
	var/datum/ipc_os/os = ipc.get_ipc_os()
	os.install("defrag")
	os.install("power_save")
	var/datum/ipc_os_program/defrag/defrag = os.programs["defrag"]
	var/datum/ipc_os_program/power_save = os.programs["power_save"]
	TEST_ASSERT(defrag.start(), "Could not start the hidden drain fixture.")
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	defrag.tick(20)
	TEST_ASSERT(abs(ipc.nutrition - NUTRITION_LEVEL_FULL * 0.97) < 0.001, "Defrag did not drain 3% in twenty seconds with inactive PowerSave.")
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	for(var/tick in 1 to 20)
		defrag.tick(1)
	TEST_ASSERT(abs(ipc.nutrition - NUTRITION_LEVEL_FULL * 0.97) < 0.001, "Defrag drain depends on processing tick size.")
	TEST_ASSERT(power_save.start(), "Could not activate PowerSave for the hidden drain fixture.")
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	defrag.tick(20)
	TEST_ASSERT(abs(ipc.nutrition - NUTRITION_LEVEL_FULL * 0.99) < 0.001, "Active PowerSave did not reduce hidden drain to 1%.")
	power_save.stop()
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	defrag.tick(20)
	TEST_ASSERT(abs(ipc.nutrition - NUTRITION_LEVEL_FULL * 0.97) < 0.001, "Stopping PowerSave retained its hidden discount.")
	defrag.stop()
	ipc.set_nutrition(NUTRITION_LEVEL_FULL, forced = TRUE)
	os.on_life(ipc, 15)
	TEST_ASSERT_EQUAL(ipc.nutrition, NUTRITION_LEVEL_FULL, "Stopped Defrag still drained charge through the OS life handler.")
	TEST_ASSERT(defrag.start(), "Could not restart Defrag for the exhausted battery fixture.")
	ipc.set_nutrition(1, forced = TRUE)
	defrag.tick(20)
	TEST_ASSERT_EQUAL(ipc.nutrition, 0, "Hidden drain did not clamp to the available charge.")
	TEST_ASSERT(!defrag.running, "Defrag kept healing after exhausting its battery.")

/// SignalBoost must operate a native receiver, and release its sender on shutdown.
/datum/unit_test/ipc_os_signaler
	/// Received assembly pulses, measured at the native receiver boundary.
	var/received = 0

/datum/unit_test/ipc_os_signaler/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	var/obj/item/organ/brain/ipc/core = ipc.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/datum/ipc_os/os = core.operating_system
	os.install("signal_boost")
	var/datum/ipc_os_program/signal_boost/program = os.programs["signal_boost"]
	TEST_ASSERT(program.start(), "SignalBoost refused to start.")
	var/obj/item/assembly/signaler/receiver = allocate(/obj/item/assembly/signaler)
	receiver.set_frequency(program.frequency)
	receiver.code = program.code
	var/obj/item/assembly_holder/holder = allocate(/obj/item/assembly_holder)
	var/obj/item/assembly/timer/output = allocate(/obj/item/assembly/timer)
	ipc.put_in_hands(receiver)
	holder.attach(receiver, ipc)
	ipc.put_in_hands(output)
	holder.attach(output, ipc)
	RegisterSignal(output, COMSIG_ASSEMBLY_PULSED, PROC_REF(on_pulse))
	program.signaler.code = receiver.code + 1
	program.signaler.signal()
	TEST_ASSERT_EQUAL(received, 0, "Native receiver accepted the wrong code.")
	program.signaler.code = receiver.code
	program.signaler.signal()
	TEST_ASSERT_EQUAL(received, 1, "SignalBoost did not reach the native signaler receiver.")
	var/obj/item/assembly/signaler/sender = program.signaler
	os.uninstall("signal_boost")
	TEST_ASSERT(QDELETED(sender), "SignalBoost left a native sender after uninstall.")
	TEST_ASSERT_NULL(program.signaler, "SignalBoost retained its sender reference.")
	UnregisterSignal(output, COMSIG_ASSEMBLY_PULSED)

/datum/unit_test/ipc_os_signaler/proc/on_pulse()
	SIGNAL_HANDLER
	received++

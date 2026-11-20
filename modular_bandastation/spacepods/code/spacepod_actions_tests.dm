/// Exercise the action datums actually attached to the HUD, rather than their target procs.
/datum/unit_test/spacepod_hud_actions/Run()
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(/obj/vehicle/sealed/spacepod/sec)
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/passenger = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The pilot could not board for the HUD action test.")
	TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "The passenger could not board for the HUD action test.")
	var/datum/action/vehicle/sealed/spacepod/lights/lights = locate() in pilot.actions
	var/datum/action/vehicle/sealed/spacepod/internals/internals = locate() in pilot.actions
	var/datum/action/vehicle/sealed/spacepod/brakes/brakes = locate() in pilot.actions
	var/datum/action/vehicle/sealed/spacepod/camera_zoom/camera_zoom = locate() in pilot.actions
	var/datum/action/vehicle/sealed/spacepod/eject/pilot_exit = locate() in pilot.actions
	var/datum/action/vehicle/sealed/spacepod/eject/passenger_exit = locate() in passenger.actions
	TEST_ASSERT_NOTNULL(lights, "Boarding did not grant the actual pilot light action.")
	TEST_ASSERT_NOTNULL(internals, "Boarding did not grant the actual pilot air action.")
	TEST_ASSERT_NOTNULL(brakes, "Boarding did not grant the actual pilot brake action.")
	TEST_ASSERT_NOTNULL(camera_zoom, "Boarding did not grant the pilot's camera zoom action.")
	TEST_ASSERT("mech_zoom_on" in icon_states(camera_zoom.button_icon), "The enabled camera zoom HUD icon does not exist.")
	TEST_ASSERT_NOTNULL(pilot_exit, "Boarding did not grant the actual pilot exit action.")
	TEST_ASSERT_NOTNULL(passenger_exit, "Boarding did not grant the actual passenger exit action.")
	for(var/datum/action/vehicle/sealed/spacepod/action in pilot.actions)
		var/atom/movable/screen/movable/action_button/button = allocate(__IMPLIED_TYPE__)
		action.build_button_icon(button, ALL, TRUE)
		TEST_ASSERT(button.icon_state && (button.icon_state in icon_states(button.icon)), "[action.type] rendered a missing icon state and would display the ERROR placeholder.")
	TEST_ASSERT(!(locate(/datum/action/vehicle/sealed/spacepod/internals) in passenger.actions), "A passenger received the cabin air button.")
	TEST_ASSERT(!(locate(/datum/action/vehicle/sealed/spacepod/brakes) in passenger.actions), "A passenger received the brake button.")
	TEST_ASSERT(!(locate(/datum/action/vehicle/sealed/spacepod/camera_zoom) in passenger.actions), "A passenger received the camera zoom button.")
	TEST_ASSERT(!camera_zoom.Trigger(pilot), "A pilot without a client activated camera zoom.")
	brakes.Trigger(pilot)
	TEST_ASSERT(pod.flight.brakes, "Pressing the real brake action did not enable stronger braking.")
	var/enabled_brake_icon = brakes.button_icon_state
	TEST_ASSERT(enabled_brake_icon in icon_states(brakes.button_icon), "The enabled brake HUD icon does not exist.")
	var/initial_lights = pod.lights
	TEST_ASSERT(lights.IsAvailable(), "The real light action is unavailable to a conscious pilot.")
	lights.Trigger(pilot)
	TEST_ASSERT(pod.lights != initial_lights, "Pressing the real light action did not switch the light.")
	TEST_ASSERT(lights.button_icon_state in icon_states(lights.button_icon), "The toggled light HUD icon does not exist.")
	var/initial_internals = pod.use_internal_tank
	internals.Trigger(pilot)
	TEST_ASSERT(pod.use_internal_tank != initial_internals, "Pressing the real air action did not switch the air source.")
	internals.Trigger(pilot)
	TEST_ASSERT_EQUAL(pod.use_internal_tank, initial_internals, "Pressing the real air action twice did not restore cabin air.")
	passenger_exit.Trigger(passenger)
	TEST_ASSERT(passenger.loc != pod, "Pressing the passenger exit button did not exit the pod.")
	TEST_ASSERT(QDELETED(passenger_exit), "An exited passenger retained a live pod action.")
	pilot_exit.Trigger(pilot)
	TEST_ASSERT(pilot.loc != pod, "Pressing the pilot exit button did not exit the pod.")
	TEST_ASSERT(QDELETED(lights) && QDELETED(internals) && QDELETED(brakes) && QDELETED(pilot_exit), "An exited pilot retained live pod actions.")
	TEST_ASSERT(QDELETED(camera_zoom), "An exited pilot retained the camera zoom action.")
	var/mob/living/carbon/human/replacement = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(pod.mob_enter(replacement, silent = TRUE), "The replacement pilot could not board for the brake HUD test.")
	var/datum/action/vehicle/sealed/spacepod/brakes/replacement_brakes = locate() in replacement.actions
	TEST_ASSERT_NOTNULL(replacement_brakes, "Boarding did not grant the replacement pilot a brake action.")
	TEST_ASSERT(pod.flight.brakes, "Changing pilots unexpectedly cleared the stronger brake setting.")
	TEST_ASSERT_EQUAL(replacement_brakes.button_icon_state, enabled_brake_icon, "The replacement pilot's brake icon does not show the already enabled brakes.")

/// Controls in the shared monitor can only affect the pod from its pilot's seat.
/datum/unit_test/spacepod_monitor_controls/Run()
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__)
	var/turf/boarding_turf = get_step(pod, SOUTH)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, boarding_turf)
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, boarding_turf)
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE) && pod.mob_enter(passenger, silent = TRUE), "Could not board both occupants.")
	var/datum/tgui/pilot_ui = allocate(/datum/tgui, pilot, pod, "SpacepodStatus")
	var/datum/tgui/passenger_ui = allocate(/datum/tgui, passenger, pod, "SpacepodStatus")
	var/list/passenger_selection = list("passenger" = REF(passenger))
	TEST_ASSERT(!pod.ui_act("turbo", list(), passenger_ui, null), "A passenger could control turbo.")
	TEST_ASSERT(!pod.ui_act("eject_passenger", passenger_selection, passenger_ui, null), "A passenger could access pilot ejection controls.")
	TEST_ASSERT(pod.ui_act("turbo", list(), pilot_ui, null) && pod.flight.turbo, "The pilot could not toggle turbo in the monitor.")
	TEST_ASSERT(!pod.ui_act("eject_passenger", list("passenger" = REF(pilot)), pilot_ui, null), "Passenger ejection accepted the pilot's reference.")
	TEST_ASSERT(pod.ui_act("eject_passenger", passenger_selection, pilot_ui, null), "The pilot could not eject the current passenger.")
	TEST_ASSERT(!pod.is_occupant(passenger) && passenger.loc != pod && pilot.loc == pod, "Ejection did not remove only the chosen passenger.")
	TEST_ASSERT(!pod.ui_act("eject_passenger", passenger_selection, pilot_ui, null), "A stale passenger reference was accepted.")
	TEST_ASSERT(pod.mob_exit(pilot, silent = TRUE), "The pilot failed to exit.")
	TEST_ASSERT(!pod.ui_act("turbo", list(), pilot_ui, null) && pod.flight.turbo, "A former pilot could still control turbo.")

/// Keep the real preferences tree without writing player saves.
/datum/preferences/spacepod_key_test
	load_and_save = FALSE

/// Reboarding recreates the HUD action and restores the player's own binding.
/datum/unit_test/spacepod_action_key/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
	var/datum/client_interface/viewer = allocate(__IMPLIED_TYPE__)
	viewer.prefs = allocate(/datum/preferences/spacepod_key_test, viewer)
	pilot.mock_client = viewer
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Could not board for the hotkey test.")
	var/datum/action/vehicle/sealed/spacepod/brakes/brake_action = locate() in pilot.actions
	brake_action.set_key("ShiftK")
	TEST_ASSERT(pod.mob_exit(pilot, silent = TRUE) && QDELETED(brake_action), "Leaving did not destroy the old action.")
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Could not reboard for the hotkey test.")
	brake_action = locate() in pilot.actions
	TEST_ASSERT_EQUAL(brake_action.full_key, "ShiftK", "The new HUD action lost the saved hotkey.")
	brake_action.set_key(null)
	TEST_ASSERT(pod.mob_exit(pilot, silent = TRUE) && pod.mob_enter(pilot, silent = TRUE), "Could not reboard after clearing the binding.")
	brake_action = locate() in pilot.actions
	TEST_ASSERT_NULL(brake_action.full_key, "The cleared key reappeared after reboarding.")

/// Dragging a pod onto oneself unloads its passenger only when its hatch is accessible.
/datum/unit_test/spacepod_external_ejection/Run()
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__)
	var/turf/boarding_turf = get_step(pod, SOUTH)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, boarding_turf)
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, boarding_turf)
	var/mob/living/carbon/human/consistent/rescuer = allocate(__IMPLIED_TYPE__, boarding_turf)
	rescuer.mock_client = allocate(/datum/client_interface)
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE) && pod.mob_enter(passenger, silent = TRUE), "Could not board both occupants.")
	var/obj/item/crowbar/crowbar = allocate(__IMPLIED_TYPE__, pod)
	passenger.set_combat_mode(FALSE)
	TEST_ASSERT(passenger.put_in_active_hand(crowbar), "The passenger could not handle an inventory item.")
	click_wrapper(passenger, pod)
	TEST_ASSERT(!pod.hatch_open, "The passenger could open the outside maintenance hatch from inside.")
	pod.unlocked = FALSE
	var/mob/previous_usr = usr
	usr = rescuer
	pod.MouseDrop(rescuer)
	usr = previous_usr
	TEST_ASSERT_EQUAL(passenger.loc, pod, "An outsider could unload a passenger through a locked door.")
	pod.unlocked = TRUE
	usr = rescuer
	pod.MouseDrop(rescuer)
	usr = previous_usr
	TEST_ASSERT(!pod.is_occupant(passenger) && passenger.loc != pod && pilot.loc == pod, "Native drag did not eject only the passenger.")

/// Replace only the radial UI boundary; native MOD click routing remains intact.
/obj/item/mod/control/pre_equipped/engineering/spacepod_radial_test
	/// Number of radial menu requests received by the UI boundary.
	var/radial_requests = 0

/obj/item/mod/control/pre_equipped/engineering/spacepod_radial_test/quick_module(mob/user, anchor_override = null)
	radial_requests++

/// The MOD hotkey cannot open its radial in a pod, and resumes working after exit.
/datum/unit_test/spacepod_mod_radial/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
	var/obj/item/mod/control/pre_equipped/engineering/spacepod_radial_test/mod = allocate(__IMPLIED_TYPE__)
	STOP_PROCESSING(SSobj, mod)
	TEST_ASSERT(user.equip_to_slot_if_possible(mod, ITEM_SLOT_BACK), "Could not equip the real MOD radial fixture.")
	var/list/modifiers = list(CTRL_CLICK = TRUE, MIDDLE_CLICK = TRUE)
	TEST_ASSERT(SEND_SIGNAL(user, COMSIG_MOB_CLICKON, pod, modifiers) & COMSIG_MOB_CANCEL_CLICKON, "The real MOD did not consume its hotkey outside the pod.")
	TEST_ASSERT_EQUAL(mod.radial_requests, 1, "The outside MOD hotkey did not reach the radial UI.")
	TEST_ASSERT(pod.mob_enter(user, silent = TRUE), "The MOD wearer could not board the pod.")
	TEST_ASSERT(SEND_SIGNAL(user, COMSIG_MOB_CLICKON, pod, modifiers) & COMSIG_MOB_CANCEL_CLICKON, "The blocked MOD hotkey fell through to another click action.")
	TEST_ASSERT_EQUAL(mod.radial_requests, 1, "The MOD hotkey opened a radial menu inside the pod.")
	TEST_ASSERT(pod.mob_exit(user, silent = TRUE), "The MOD wearer could not leave the pod.")
	SEND_SIGNAL(user, COMSIG_MOB_CLICKON, pod, modifiers)
	TEST_ASSERT_EQUAL(mod.radial_requests, 2, "Leaving the pod did not restore the MOD hotkey.")

/// Capture real tether projectiles without replacing the module's activation or firing path.
/datum/unit_test/spacepod_mod_tether
	/// Native projectile fire events observed during this fixture.
	var/shots = 0

/datum/unit_test/spacepod_mod_tether/proc/on_projectile(datum/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	allocated |= projectile
	shots++

/datum/unit_test/spacepod_mod_tether/Run()
	var/obj/vehicle/sealed/spacepod/sec/pod = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, get_step(pod, SOUTH))
	var/obj/item/mod/control/pre_equipped/engineering/mod = allocate(__IMPLIED_TYPE__)
	STOP_PROCESSING(SSobj, mod)
	TEST_ASSERT(user.equip_to_slot_if_possible(mod, ITEM_SLOT_BACK), "Could not equip the real tether fixture.")
	mod.quick_activation()
	var/obj/item/mod/module/tether/tether = locate() in mod.modules
	TEST_ASSERT_NOTNULL(tether, "The engineering MOD has no tether module.")
	TEST_ASSERT(tether.activate(user), "The powered tether could not be selected before boarding.")
	RegisterSignal(user, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE, PROC_REF(on_projectile))
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE) && pod.mob_enter(user, silent = TRUE), "The MOD wearer could not board the passenger seat.")
	var/charge_before = mod.get_charge()
	var/atom/target = locate(pod.x + 3, pod.y + 2, pod.z)
	TEST_ASSERT(!tether.on_select_use(target), "A preselected MOD tether fired from inside the pod.")
	TEST_ASSERT_EQUAL(shots, 0, "The blocked tether created a real projectile.")
	TEST_ASSERT_EQUAL(mod.get_charge(), charge_before, "The blocked tether consumed MOD charge.")
	TEST_ASSERT(COOLDOWN_FINISHED(tether, cooldown_timer), "The blocked tether started its cooldown.")
	TEST_ASSERT_EQUAL(mod.selected_module, tether, "Boarding discarded the selected MOD module.")
	TEST_ASSERT(pod.mob_exit(user, silent = TRUE), "The MOD passenger could not leave the pod.")
	TEST_ASSERT(tether.on_select_use(target), "Leaving the pod did not restore real tether firing.")
	TEST_ASSERT_EQUAL(shots, 1, "The restored tether did not fire its actual projectile.")
	TEST_ASSERT(mod.get_charge() < charge_before, "The restored tether fired without consuming power.")
	UnregisterSignal(user, COMSIG_PROJECTILE_FIRER_BEFORE_FIRE)

/// Real projectiles must leave the hull and damage a target in front of the muzzle.
/datum/unit_test/spacepod_weapon_hits/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(/obj/vehicle/sealed/spacepod/civilian, origin)
	var/obj/item/spacepod_equipment/weaponry/laser/weapon = allocate(/obj/item/spacepod_equipment/weaponry/laser)
	TEST_ASSERT(pod.add_equipment(null, weapon, weapon.slot), "Laser installation failed for the projectile impact test.")
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The pilot could not board for the projectile impact test.")
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, locate(origin.x, origin.y + 3, origin.z))
	pod.setDir(NORTH)
	var/initial_damage = target.get_fire_loss()
	var/hull_before = pod.get_integrity()
	var/pilot_damage = pilot.get_fire_loss()
	TEST_ASSERT(!(SEND_SIGNAL(pilot, COMSIG_MOB_CLICKON, target, list(LEFT_CLICK = TRUE, SHIFT_CLICK = TRUE)) & COMSIG_MOB_CANCEL_CLICKON), "Shift-click was intercepted as a shot.")
	click_wrapper(pilot, target)
	sleep(1 SECONDS)
	TEST_ASSERT(target.get_fire_loss() > initial_damage, "The actual laser projectiles did not damage a target beyond the hull.")
	TEST_ASSERT_EQUAL(pod.get_integrity(), hull_before, "The pod shot its own hull.")
	TEST_ASSERT_EQUAL(pilot.get_fire_loss(), pilot_damage, "The pod shot its own pilot.")

/// Capture native firing origins: sprite direction changes must not jump the rotating barrels.
/datum/unit_test/spacepod_vacuum/weapon_muzzles
	/// Pixel coordinates captured before native projectile movement starts.
	var/list/muzzle_samples = list()

/datum/unit_test/spacepod_vacuum/weapon_muzzles/proc/on_projectile(obj/item/spacepod_equipment/weaponry/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	allocated += projectile
	muzzle_samples += list(list(projectile.x * ICON_SIZE_X + projectile.pixel_x, projectile.y * ICON_SIZE_Y + projectile.pixel_y))

/datum/unit_test/spacepod_vacuum/weapon_muzzles/Run()
	var/obj/vehicle/sealed/spacepod/pod = create_flight_pod()
	TEST_ASSERT_NOTNULL(pod, "Could not board the vacuum pod for the muzzle continuity test.")
	var/obj/item/spacepod_equipment/weaponry/mining_laser_basic/weapon = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(pod.add_equipment(null, weapon, weapon.slot), "Could not install the real weapon for the muzzle continuity test.")
	RegisterSignal(weapon, COMSIG_PROJECTILE_BEFORE_FIRE, PROC_REF(on_projectile))
	pod.setDir(NORTH)
	pod.flight.heading = 44.9
	var/fired_before = pod.fireWeapon(pod.pilot)
	var/list/before_turn = muzzle_samples.Copy()
	muzzle_samples.Cut()
	COOLDOWN_RESET(weapon, weapon_cooldown)
	pod.setDir(EAST)
	pod.flight.heading = 45.1
	var/fired_after = pod.fireWeapon(pod.pilot)
	var/list/after_turn = muzzle_samples.Copy()
	muzzle_samples.Cut()
	COOLDOWN_RESET(weapon, weapon_cooldown)
	pod.pixel_x += 9
	pod.pixel_y -= 7
	var/fired_shifted = pod.fireWeapon(pod.pilot)
	UnregisterSignal(weapon, COMSIG_PROJECTILE_BEFORE_FIRE)
	TEST_ASSERT(fired_before && fired_after && fired_shifted, "An installed, powered pod weapon rejected a muzzle test volley.")
	TEST_ASSERT_EQUAL(length(before_turn), 2, "The initial volley did not emit both native projectiles.")
	TEST_ASSERT_EQUAL(length(after_turn), 2, "The turned volley did not emit both native projectiles.")
	TEST_ASSERT_EQUAL(length(muzzle_samples), 2, "The translated volley did not emit both native projectiles.")
	for(var/barrel in 1 to 2)
		var/list/before = before_turn[barrel]
		var/list/after = after_turn[barrel]
		var/list/shifted = muzzle_samples[barrel]
		TEST_ASSERT((after[1] - before[1]) ** 2 + (after[2] - before[2]) ** 2 < 1, "Barrel [barrel] jumped during a small turn: ([before[1]], [before[2]]) -> ([after[1]], [after[2]]).")
		TEST_ASSERT(abs(shifted[1] - after[1] - 9) < 0.001 && abs(shifted[2] - after[2] + 7) < 0.001, "Barrel [barrel] ignored the hull translation: ([after[1]], [after[2]]) -> ([shifted[1]], [shifted[2]]), expected (+9, -7).")

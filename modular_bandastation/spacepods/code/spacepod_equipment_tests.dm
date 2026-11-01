/// Preset installation must use the same slot and ownership bookkeeping as manual installation.
/datum/unit_test/spacepod_equipment_slots/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
	var/obj/item/spacepod_equipment/weaponry/laser/weapon = allocate(/obj/item/spacepod_equipment/weaponry/laser)
	var/obj/item/spacepod_equipment/weaponry/laser/replacement = allocate(/obj/item/spacepod_equipment/weaponry/laser)
	TEST_ASSERT(!pod.add_equipment(null, null, "weapon_system"), "A missing module was accepted.")
	TEST_ASSERT(!pod.add_equipment(null, weapon, "cargo_system"), "A weapon was accepted into the cargo slot.")
	TEST_ASSERT(pod.add_equipment(null, weapon, weapon.slot), "Preset weapon installation failed.")
	TEST_ASSERT_EQUAL(weapon.loc, pod, "Installed weapon was not moved into the pod.")
	TEST_ASSERT_EQUAL(weapon.my_atom, pod, "Installed weapon did not retain its owning pod.")
	TEST_ASSERT_EQUAL(pod.weapon_system, weapon, "Installed weapon did not occupy its slot.")
	TEST_ASSERT(!pod.add_equipment(null, replacement, replacement.slot), "A second weapon replaced an occupied slot.")
	TEST_ASSERT(!pod.add_equipment(null, weapon, weapon.slot), "An installed module was installed twice.")
	TEST_ASSERT_EQUAL(length(pod.installed_modules), 1, "Rejected installations changed the installed module list.")
	TEST_ASSERT(pod.remove_equipment(null, weapon, weapon.slot), "Preset weapon removal failed.")
	TEST_ASSERT_NULL(pod.weapon_system, "Removed weapon still occupies its slot.")
	TEST_ASSERT_NULL(weapon.my_atom, "Removed weapon still owns its old pod.")
	TEST_ASSERT_EQUAL(length(pod.installed_modules), 0, "Removed weapon remained in the installed module list.")
	TEST_ASSERT_EQUAL(weapon.loc, get_turf(pod), "Removed weapon was not dropped outside the pod.")

/// Removing the extra seat must never leave two occupants in a one-seat pod.
/datum/unit_test/spacepod_equipment_passenger_seat/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
	var/obj/item/spacepod_equipment/sec_cargo/chair/chair = allocate(/obj/item/spacepod_equipment/sec_cargo/chair)
	TEST_ASSERT(pod.add_equipment(null, chair, chair.slot), "Passenger seat installation failed.")
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/passenger = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Pilot could not board the pod.")
	TEST_ASSERT(pod.mob_enter(passenger, silent = TRUE), "Passenger could not board with a seat installed.")
	TEST_ASSERT(!pod.remove_equipment(null, chair, chair.slot), "Passenger seat was removed while two people were aboard.")
	TEST_ASSERT_EQUAL(pod.sec_cargo_system, chair, "Rejected seat removal cleared the installed seat.")
	TEST_ASSERT_EQUAL(pod.max_occupants, 2, "Rejected seat removal reduced capacity.")
	pod.mob_exit(passenger, silent = TRUE)
	TEST_ASSERT(pod.remove_equipment(null, chair, chair.slot), "Empty passenger seat could not be removed.")
	TEST_ASSERT_EQUAL(pod.max_occupants, 1, "Seat removal did not restore the original capacity.")
	TEST_ASSERT(pod.is_occupant(pilot), "Seat removal ejected the remaining pilot.")

/// Independent qdel of any module must release its slot and derived pod state.
/datum/unit_test/spacepod_equipment_deletion/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
	var/list/module_types = list(
		/obj/item/spacepod_equipment/weaponry/laser,
		/obj/item/spacepod_equipment/misc/tracker,
		/obj/item/spacepod_equipment/cargo/crate,
		/obj/item/spacepod_equipment/sec_cargo/chair,
		/obj/item/spacepod_equipment/lock/keyed,
		/obj/item/spacepod_equipment/locators/basic_pod_locator,
	)
	for(var/module_type in module_types)
		var/obj/item/spacepod_equipment/module = allocate(module_type)
		var/module_slot = module.slot
		TEST_ASSERT(pod.add_equipment(null, module, module_slot), "[module_type] failed preset installation.")
		qdel(module)
		TEST_ASSERT_NULL(pod.vars[module_slot], "Deleting [module_type] left its pod slot occupied.")
		TEST_ASSERT(!(module in pod.installed_modules), "Deleted [module_type] remained in the installed module list.")
		if(module_type == /obj/item/spacepod_equipment/misc/tracker)
			TEST_ASSERT(!(module in GLOB.pod_trackers), "Deleted tracking module remained globally registered.")
	TEST_ASSERT_EQUAL(pod.max_passengers, 0, "Deleting the passenger seat left extra passenger capacity.")
	TEST_ASSERT_EQUAL(pod.max_occupants, 1, "Deleting modules changed the base pod capacity.")

/// Removing a cargo module or deleting its owner must unload the actual crate and its contents.
/datum/unit_test/spacepod_equipment_cargo_survival/Run()
	for(var/removal in list("remove_module", "delete_module", "delete_pod"))
		var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
		var/turf/drop_turf = get_turf(pod)
		var/obj/item/spacepod_equipment/cargo/crate/cargo = allocate(/obj/item/spacepod_equipment/cargo/crate)
		TEST_ASSERT(pod.add_equipment(null, cargo, cargo.slot), "Cargo module installation failed for [removal].")
		var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, cargo)
		var/obj/item/flashlight/cargo_item = allocate(/obj/item/flashlight, crate)
		cargo.storage = crate
		switch(removal)
			if("remove_module")
				TEST_ASSERT(pod.remove_equipment(null, cargo, cargo.slot), "Loaded cargo module could not be removed.")
				TEST_ASSERT_NULL(cargo.storage, "Removed cargo module retained ownership of its unloaded crate.")
			if("delete_module")
				qdel(cargo)
			if("delete_pod")
				qdel(pod)
		TEST_ASSERT(!QDELETED(crate), "[removal] deleted the loaded crate.")
		TEST_ASSERT_EQUAL(crate.loc, drop_turf, "[removal] did not unload the crate onto the station turf.")
		TEST_ASSERT(!QDELETED(cargo_item), "[removal] destroyed an item inside the loaded crate.")
		TEST_ASSERT_EQUAL(cargo_item.loc, crate, "[removal] separated the crate from its contents.")

/// Successful pilot movement collects only ore, across the entire destination footprint.
/datum/unit_test/spacepod_equipment_ore_collection
	var/obj/item/spacepod_equipment/cargo/interrupted_cargo
	var/collection_interrupted = FALSE

/datum/unit_test/spacepod_equipment_ore_collection/Destroy()
	interrupted_cargo = null
	return ..()

/datum/unit_test/spacepod_equipment_ore_collection/proc/on_ore_moved(obj/item/stack/ore/source)
	SIGNAL_HANDLER
	if(!interrupted_cargo?.storage || source.loc != interrupted_cargo.storage)
		return
	// A synchronous movement callback can remove the box before the next ore is visited.
	collection_interrupted = interrupted_cargo.unload()

/datum/unit_test/spacepod_equipment_ore_collection/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/destination = get_step(origin, EAST)
	var/list/footprint = block(destination, locate(destination.x + 1, destination.y + 1, destination.z))
	var/list/ore_types = list(/obj/item/stack/ore/iron, /obj/item/stack/ore/plasma, /obj/item/stack/ore/gold, /obj/item/stack/ore/silver)
	for(var/scenario in list("loaded_ore", "empty_ore", "loaded_crate", "interrupted_ore"))
		var/obj/vehicle/sealed/spacepod/pod = allocate(__IMPLIED_TYPE__, origin)
		pod.setDir(NORTH)
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "The pilot could not board for ore collection [scenario].")
		var/obj/item/spacepod_equipment/cargo/cargo = allocate(scenario == "loaded_crate" ? /obj/item/spacepod_equipment/cargo/crate : /obj/item/spacepod_equipment/cargo/ore, pod)
		TEST_ASSERT(pod.add_equipment(null, cargo, cargo.slot), "The cargo module could not be installed for [scenario].")
		var/obj/stored_container
		if(scenario != "empty_ore")
			stored_container = allocate(scenario == "loaded_crate" ? /obj/structure/closet/crate : /obj/structure/ore_box, cargo)
			cargo.storage = stored_container
		var/list/ores = list()
		var/list/junk = list()
		var/tile_index = 0
		for(var/turf/tile as anything in footprint)
			tile_index++
			var/obj/item/stack/ore/ore = allocate(ore_types[tile_index], tile, tile_index)
			ores[ore] = tile
			var/obj/item/flashlight/item = allocate(__IMPLIED_TYPE__, tile)
			junk[item] = tile
			if(scenario == "interrupted_ore")
				RegisterSignal(ore, COMSIG_MOVABLE_MOVED, PROC_REF(on_ore_moved))
		collection_interrupted = FALSE
		interrupted_cargo = scenario == "interrupted_ore" ? cargo : null
		var/initial_charge = pod.battery.charge
		TEST_ASSERT(pod.relaymove(pilot, EAST), "Real pilot movement failed for ore collection [scenario].")
		STOP_PROCESSING(SSnewtonian_movement, pod.flight)
		pod.flight.process(0.05)
		TEST_ASSERT_EQUAL(pod.loc, destination, "Ore collection [scenario] did not move exactly one tile east.")
		TEST_ASSERT_EQUAL(length(pod.locs - footprint), 0, "Ore collection [scenario] used the wrong destination footprint.")
		TEST_ASSERT(pod.battery.charge < initial_charge, "Ore collection [scenario] used thrust without paying for it.")
		var/collected = 0
		tile_index = 0
		for(var/obj/item/stack/ore/ore as anything in ores)
			tile_index++
			UnregisterSignal(ore, COMSIG_MOVABLE_MOVED)
			TEST_ASSERT(!QDELETED(ore), "Ore collection [scenario] deleted an original ore stack.")
			TEST_ASSERT_EQUAL(ore.get_amount(), tile_index, "Ore collection [scenario] changed a stack's amount.")
			if(ore.loc == stored_container)
				collected++
			else
				TEST_ASSERT_EQUAL(ore.loc, ores[ore], "Ore collection [scenario] misplaced an uncollected ore stack.")
		for(var/obj/item/item as anything in junk)
			TEST_ASSERT_EQUAL(item.loc, junk[item], "Ore collection [scenario] collected a non-ore item.")
		TEST_ASSERT_EQUAL(collected, scenario == "loaded_ore" ? 4 : scenario == "interrupted_ore" ? 1 : 0, "Ore collection [scenario] collected the wrong number of footprint stacks.")
		if(scenario == "interrupted_ore")
			TEST_ASSERT(collection_interrupted, "The first ore did not exercise synchronous cargo removal.")
			TEST_ASSERT_NULL(cargo.storage, "Collection resumed after a movement callback removed its storage.")
			TEST_ASSERT_EQUAL(stored_container.loc, destination, "The interrupted collection did not unload the original box.")
		else
			TEST_ASSERT_EQUAL(cargo.storage, stored_container, "Ore collection [scenario] changed its storage ownership.")
		interrupted_cargo = null
		qdel(pod)
		qdel(pilot)
		QDEL_LIST(ores)
		QDEL_LIST(junk)
		qdel(stored_container)

/// Native movable teardown deletes contents, so auxiliary storage must explicitly release its loot.
/datum/unit_test/spacepod_equipment_loot_survival/Run()
	for(var/removal in list("delete_module", "delete_pod"))
		var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
		var/turf/drop_turf = get_turf(pod)
		var/obj/item/spacepod_equipment/sec_cargo/loot_box/cargo = allocate(/obj/item/spacepod_equipment/sec_cargo/loot_box)
		TEST_ASSERT(pod.add_equipment(null, cargo, cargo.slot), "Auxiliary cargo installation failed for [removal].")
		var/obj/item/flashlight/loot = allocate(/obj/item/flashlight)
		TEST_ASSERT(cargo.atom_storage.attempt_insert(loot, null, messages = FALSE), "Auxiliary cargo refused a normal flashlight.")
		TEST_ASSERT_EQUAL(loot.loc, cargo, "Auxiliary cargo did not physically contain its loot.")
		if(removal == "delete_module")
			qdel(cargo)
		else
			qdel(pod)
		TEST_ASSERT(!QDELETED(loot), "[removal] destroyed an item inside auxiliary cargo.")
		TEST_ASSERT_EQUAL(loot.loc, drop_turf, "[removal] failed to release auxiliary cargo onto the station turf.")

/// Key cutting must be permanent and only matching keys may toggle the installed lock.
/datum/unit_test/spacepod_equipment_keys/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/spacepod_equipment/lock/keyed/lock = allocate(/obj/item/spacepod_equipment/lock/keyed)
	var/obj/item/spacepod_equipment/lock/keyed/other_lock = allocate(/obj/item/spacepod_equipment/lock/keyed)
	var/obj/item/spacepod_equipment/key/key = allocate(/obj/item/spacepod_equipment/key)
	var/obj/item/spacepod_equipment/key/blank = allocate(/obj/item/spacepod_equipment/key)
	TEST_ASSERT_EQUAL(lock.item_interaction(user, key, list()), ITEM_INTERACT_SUCCESS, "A blank pod key could not be cut.")
	TEST_ASSERT_EQUAL(key.id, lock.id, "The cut key does not match its lock.")
	TEST_ASSERT_EQUAL(other_lock.item_interaction(user, key, list()), ITEM_INTERACT_BLOCKING, "An existing key was recut for a different lock.")
	TEST_ASSERT_EQUAL(key.id, lock.id, "Rejected recutting changed the key's lock ID.")
	TEST_ASSERT(pod.add_equipment(null, lock, lock.slot), "Keyed lock installation failed.")
	pod.equipment_interaction(user, blank, list())
	TEST_ASSERT(pod.unlocked, "An uncut key locked the pod.")
	pod.equipment_interaction(user, key, list())
	TEST_ASSERT(!pod.unlocked, "A matching key could not lock the pod.")
	pod.equipment_interaction(user, key, list())
	TEST_ASSERT(pod.unlocked, "A matching key could not unlock the pod.")
	TEST_ASSERT(pod.remove_equipment(null, lock, lock.slot), "Unlocked keyed lock could not be removed.")
	TEST_ASSERT(pod.add_equipment(null, other_lock, other_lock.slot), "Replacement lock installation failed.")
	pod.equipment_interaction(user, key, list())
	TEST_ASSERT(pod.unlocked, "A key for a different lock changed the pod's lock state.")

/// Rejected firing must not emit real projectiles or consume power; accepted firing must do both.
/datum/unit_test/spacepod_weapon_controls
	var/shots_fired = 0

/datum/unit_test/spacepod_weapon_controls/proc/on_projectile(obj/item/spacepod_equipment/weaponry/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	shots_fired++

/datum/unit_test/spacepod_weapon_controls/Run()
	var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
	var/obj/item/spacepod_equipment/weaponry/mining_laser_basic/weapon = allocate(/obj/item/spacepod_equipment/weaponry/mining_laser_basic)
	TEST_ASSERT(pod.add_equipment(null, weapon, weapon.slot), "Mining weapon installation failed.")
	var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/outsider = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Pilot could not board the armed pod.")
	TEST_ASSERT(pod.can_control(pilot), "The actual pilot cannot operate the pod console.")
	RegisterSignal(weapon, COMSIG_PROJECTILE_BEFORE_FIRE, PROC_REF(on_projectile))
	var/initial_charge = pod.battery.charge
	TEST_ASSERT(!weapon.fire_weapons(outsider), "An outsider fired pod weapons through the module directly.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge, "Rejected outsider fire consumed power.")
	pod.battery.charge = 0
	TEST_ASSERT(!pod.fireWeapon(pilot), "The pilot fired weapons with an empty battery.")
	TEST_ASSERT_EQUAL(pod.battery.charge, 0, "Rejected empty-battery fire changed the battery charge.")
	pod.battery.charge = initial_charge
	ADD_TRAIT(pilot, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	var/pacifist_fired = pod.fireWeapon(pilot)
	REMOVE_TRAIT(pilot, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!pacifist_fired, "A pacifist fired the harmful mining weapon.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge, "Rejected pacifist fire consumed power.")
	pod.hatch_open = TRUE
	var/open_hatch_fired = pod.fireWeapon(pilot)
	pod.hatch_open = FALSE
	TEST_ASSERT(!open_hatch_fired, "The pilot fired with the technical hatch open.")
	TEST_ASSERT_EQUAL(shots_fired, 0, "Rejected firing emitted real projectiles.")
	TEST_ASSERT(pod.fireWeapon(pilot), "The pilot could not fire an installed, charged weapon.")
	TEST_ASSERT_EQUAL(shots_fired, 2, "A normal mining volley did not emit its two real projectiles.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge - weapon.shot_cost * SPACEPOD_ENERGY_UNIT, "A successful volley consumed the wrong amount of power.")
	var/charge_after_volley = pod.battery.charge
	TEST_ASSERT(!pod.fireWeapon(pilot), "Weapon cooldown allowed a second immediate volley.")
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_after_volley, "Rejected cooldown fire consumed more power.")
	TEST_ASSERT_EQUAL(shots_fired, 2, "Rejected cooldown fire emitted extra projectiles.")
	UnregisterSignal(weapon, COMSIG_PROJECTILE_BEFORE_FIRE)

/// Real bursts yield between volleys and must stop when the pilot exits or the module is removed.
/datum/unit_test/spacepod_weapon_burst_cancellation
	var/shots_fired = 0
	var/cancellation

/datum/unit_test/spacepod_weapon_burst_cancellation/proc/on_projectile(obj/item/spacepod_equipment/weaponry/source, obj/projectile/projectile)
	SIGNAL_HANDLER
	shots_fired++
	if(shots_fired != 2)
		return
	var/obj/vehicle/sealed/spacepod/pod = source.my_atom
	if(cancellation == "pilot_exit")
		pod.mob_exit(pod.pilot, silent = TRUE)
	else
		pod.uninstall_equipment(source, source.slot)

/datum/unit_test/spacepod_weapon_burst_cancellation/Run()
	for(var/cancellation_type in list("pilot_exit", "module_removal"))
		var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
		var/obj/item/spacepod_equipment/weaponry/burst_taser/weapon = allocate(/obj/item/spacepod_equipment/weaponry/burst_taser)
		TEST_ASSERT(pod.add_equipment(null, weapon, weapon.slot), "Burst weapon installation failed.")
		var/mob/living/carbon/human/pilot = allocate(/mob/living/carbon/human/consistent)
		TEST_ASSERT(pod.mob_enter(pilot, silent = TRUE), "Pilot could not board for the burst test.")
		cancellation = cancellation_type
		shots_fired = 0
		RegisterSignal(weapon, COMSIG_PROJECTILE_BEFORE_FIRE, PROC_REF(on_projectile))
		var/fired = weapon.fire_weapons(pilot)
		UnregisterSignal(weapon, COMSIG_PROJECTILE_BEFORE_FIRE)
		TEST_ASSERT(fired, "The real burst never started for [cancellation_type].")
		TEST_ASSERT_EQUAL(shots_fired, 2, "The burst continued after [cancellation_type].")
		if(cancellation_type == "pilot_exit")
			TEST_ASSERT(!pod.is_occupant(pilot), "Burst cancellation did not actually remove the pilot.")
		else
			TEST_ASSERT_NULL(pod.weapon_system, "Burst cancellation did not actually remove the weapon.")

/// UI refreshes must not leak beacon coordinates after access is absent or revoked.
/datum/unit_test/spacepod_tracking_access/Run()
	var/obj/machinery/computer/podtracker/console = allocate(/obj/machinery/computer/podtracker)
	var/obj/item/spacepod_equipment/misc/tracker/beacon = allocate(/obj/item/spacepod_equipment/misc/tracker)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/list/denied_data = console.ui_data(user)
	TEST_ASSERT_EQUAL(length(denied_data["pods"]), 0, "Tracking console leaked coordinates to a person without access.")
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(ACCESS_ENGINE_EQUIP), FORCE_ADD_ALL)
	user.put_in_hands(card)
	TEST_ASSERT(console.allowed(user), "An engineering equipment ID did not authorize the tracking console.")
	var/list/authorized_data = console.ui_data(user)
	TEST_ASSERT(length(authorized_data["pods"]) > 0, "An authorized engineer could not see a real tracking beacon.")
	card.clear_access()
	var/list/revoked_data = console.ui_data(user)
	TEST_ASSERT_EQUAL(length(revoked_data["pods"]), 0, "Tracking console leaked coordinates after ID access was revoked.")
	qdel(beacon)

/// Tracking must follow the pod while installed and the physical beacon after removal.
/datum/unit_test/spacepod_tracking_coordinates/proc/find_beacon(list/data, beacon_name)
	for(var/list/row as anything in data["pods"])
		if(row["name"] == beacon_name)
			return row
	return null

/datum/unit_test/spacepod_tracking_coordinates/Run()
	var/obj/machinery/computer/podtracker/console = allocate(/obj/machinery/computer/podtracker)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	card.set_access(list(ACCESS_ENGINE_EQUIP), FORCE_ADD_ALL)
	user.put_in_hands(card)
	var/obj/item/spacepod_equipment/misc/tracker/beacon = allocate(/obj/item/spacepod_equipment/misc/tracker)
	beacon.name = "detached spacepod regression beacon"
	var/list/detached = find_beacon(console.ui_data(user), beacon.name)
	TEST_ASSERT_NOTNULL(detached, "A loose tracking beacon was missing from the console.")
	TEST_ASSERT_EQUAL(detached["x"], beacon.x, "A loose beacon reported the wrong X coordinate.")
	TEST_ASSERT_EQUAL(detached["z"], beacon.z, "A loose beacon reported the wrong Z coordinate.")
	TEST_ASSERT_NULL(detached["integrity"], "A loose beacon reported fictitious hull integrity.")
	var/obj/vehicle/sealed/spacepod/pod = allocate(/obj/vehicle/sealed/spacepod)
	pod.name = "attached spacepod regression beacon"
	TEST_ASSERT(pod.add_equipment(null, beacon, beacon.slot), "Tracking beacon installation failed.")
	var/turf/destination = get_step(run_loc_floor_bottom_left, EAST)
	pod.forceMove(destination)
	var/list/attached = find_beacon(console.ui_data(user), pod.name)
	TEST_ASSERT_NOTNULL(attached, "An installed beacon did not report its owning pod.")
	TEST_ASSERT_EQUAL(attached["x"], destination.x, "An installed beacon did not follow the pod's X coordinate.")
	TEST_ASSERT_EQUAL(attached["y"], destination.y, "An installed beacon did not follow the pod's Y coordinate.")
	TEST_ASSERT_EQUAL(attached["z"], destination.z, "An installed beacon did not follow the pod's Z coordinate.")
	TEST_ASSERT_NOTNULL(attached["integrity"], "An installed beacon omitted the real hull state.")
	TEST_ASSERT(pod.remove_equipment(null, beacon, beacon.slot), "Tracking beacon removal failed.")
	beacon.forceMove(run_loc_floor_bottom_left)
	var/list/removed = find_beacon(console.ui_data(user), beacon.name)
	TEST_ASSERT_NOTNULL(removed, "A removed tracking beacon disappeared from the console.")
	TEST_ASSERT_EQUAL(removed["x"], beacon.x, "A removed beacon kept reporting its old pod position.")
	TEST_ASSERT_NULL(removed["charge"], "A removed beacon kept reporting its old pod battery.")

/// A fresh techweb must let the dedicated fab produce a starter hull and research its utility modules normally.
/datum/unit_test/spacepod_research_production/Run()
	var/datum/techweb/research = allocate(/datum/techweb)
	TEST_ASSERT(research.researched_nodes[/datum/techweb_node/spacepod_assembly], "A fresh techweb did not unlock starter pod assembly.")
	var/obj/machinery/mecha_part_fabricator/spacepod/fabricator = allocate(__IMPLIED_TYPE__)
	fabricator.connect_techweb(research)
	var/list/starter_designs = list(
		/datum/design/spacepod_main,
		/datum/design/spacepod_fp,
		/datum/design/spacepod_ap,
		/datum/design/spacepod_fs,
		/datum/design/spacepod_as,
		/datum/design/spacepod_core,
		/datum/design/spacepod_armor,
		/datum/design/spacepod_tracking_board,
		/datum/design/spacepod_key,
		/datum/design/spacepod_lock,
		/datum/design/spacepod_paint,
	)
	for(var/design_path in starter_designs)
		TEST_ASSERT(research.researched_designs[design_path], "Starter assembly cannot produce [design_path].")
		TEST_ASSERT(design_path in fabricator.cached_designs, "The dedicated pod fabricator did not offer starter design [design_path].")
		var/datum/design/design = SSresearch.techweb_designs[design_path]
		var/atom/movable/result = design.create_result(run_loc_floor_bottom_left)
		allocated += result
		TEST_ASSERT(istype(result, design.build_path), "Native production of [design_path] did not create its advertised part.")
	research.adjust_points(TECHWEB_POINT_TYPE_GENERIC, TECHWEB_TIER_1_POINTS * 10)
	TEST_ASSERT(!research.research_node(/datum/techweb_node/spacepod_equipment, get_that_dosh = FALSE), "Pod utility research bypassed its native mech-equipment prerequisite.")
	TEST_ASSERT(research.research_node(/datum/techweb_node/mech_equipment, get_that_dosh = FALSE), "The existing mech-equipment prerequisite is unreachable from starter research.")
	TEST_ASSERT(research.research_node(/datum/techweb_node/spacepod_equipment, get_that_dosh = FALSE), "Pod utility research remained unreachable after its prerequisite was researched.")
	fabricator.update_menu_tech()
	for(var/design_path in list(/datum/design/spacepod_tracker, /datum/design/spacepod_ore, /datum/design/spacepod_crate, /datum/design/spacepod_mining, /datum/design/spacepod_locator))
		TEST_ASSERT(research.researched_designs[design_path], "Utility research did not unlock [design_path].")
		TEST_ASSERT(design_path in fabricator.cached_designs, "The dedicated pod fabricator did not offer researched utility design [design_path].")
		var/datum/design/design = SSresearch.techweb_designs[design_path]
		var/atom/movable/result = design.create_result(run_loc_floor_bottom_left)
		allocated += result
		TEST_ASSERT(istype(result, design.build_path), "Native production of [design_path] did not create its advertised module.")
	fabricator.connect_techweb(null)

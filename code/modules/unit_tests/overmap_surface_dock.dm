/** Lay a distinct real floor and retain its original layer, area and gas for native departure checks. */
/datum/unit_test/overmap_standard_dock/proc/prepare_surface_pad(turf/anchor, pad_width, pad_height, area/pad_area, carrier_floor = FALSE, turf_type = /turf/open/floor/iron/white, turf/skipped)
	var/list/records = list()
	for(var/turf/tile as anything in block(anchor, locate(anchor.x + pad_width, anchor.y + pad_height - 1, anchor.z)))
		if(tile == skipped)
			continue
		if(carrier_floor)
			tile = tile.place_on_top(/turf/open/floor/plating, CHANGETURF_NO_AREA_CHANGE)
		tile = tile.ChangeTurf(turf_type, flags = CHANGETURF_NO_AREA_CHANGE)
		tile.change_area(get_area(tile), pad_area)
		TEST_ASSERT_EQUAL(get_area(tile), pad_area, "The floor fixture must migrate into its explicitly created area")
		var/turf/open/floor/floor = tile
		var/datum/gas_mixture/removed = floor.air.remove_ratio(1)
		qdel(removed)
		floor.air.temperature = 280
		floor.archive()
		floor.air_update_turf(TRUE, FALSE)
		var/datum/gas_mixture/saved_air = allocate(/datum/gas_mixture)
		saved_air.copy_from(floor.air)
		var/list/saved_bases = islist(tile.baseturfs) ? tile.baseturfs.Copy() : list(tile.baseturfs)
		records[tile] = list(tile.type, saved_bases, pad_area, saved_air)
	return records

/** Balance the actual open fixture decks so only the preservation contract changes their gas. */
/datum/unit_test/overmap_standard_dock/proc/balance_surface_test_air(list/turfs)
	for(var/turf/open/floor/tile in turfs)
		var/datum/gas_mixture/removed = tile.air.remove_ratio(1)
		qdel(removed)
		tile.air.temperature = 280
		tile.archive()
		tile.air_update_turf(TRUE, FALSE)

/** Give a representative underlay a mapped appearance and both supported forms of real decal attachment. */
/datum/unit_test/overmap_standard_dock/proc/stamp_surface_test_floor(turf/floor, list/record, label = "surface")
	floor.color = "#7395b7"
	floor.setDir(WEST)
	floor.AddElement(/datum/element/decal, 'icons/turf/decals.dmi', "warningline", EAST, FLOAT_PLANE, TURF_DECAL_LAYER, 200, "#ef7a45", null, FALSE, "[label] directional test")
	floor.AddElement(/datum/element/decal, 'icons/turf/decals.dmi', "warningline", NONE, FLOAT_PLANE, TURF_DECAL_LAYER, 180, "#6ca658", null, FALSE, "[label] fixed test")
	record += list(floor.color, floor.dir, collect_surface_test_decals(floor))

/** Capture public decal state without using the implementation's own underlay snapshot. */
/datum/unit_test/overmap_standard_dock/proc/collect_surface_test_decals(turf/floor)
	var/list/datum/element/decal/attached = list()
	SEND_SIGNAL(floor, COMSIG_ATOM_GET_DECALS, attached)
	var/list/result = list()
	for(var/datum/element/decal/decal as anything in attached)
		result[decal.description] = list(!!decal.directional, decal.pic.dir, decal.pic.color, decal.pic.alpha, decal.base_icon_state)
	return result

/** Compare a restored pad with its actual pre-arrival substrate rather than the new turf's initial values. */
/datum/unit_test/overmap_standard_dock/proc/assert_surface_restored(turf/tile, list/record, rotation = 0)
	TEST_ASSERT_EQUAL(tile.type, record[1], "Departure must restore the original solid floor type")
	var/list/current_bases = islist(tile.baseturfs) ? tile.baseturfs : list(tile.baseturfs)
	TEST_ASSERT_EQUAL(jointext(current_bases, ","), jointext(record[2], ","), "Departure must restore the exact original baseturf stack")
	TEST_ASSERT_EQUAL(get_area(tile), record[3], "Departure must return the floor to its original area")
	var/turf/open/floor/floor = tile
	var/datum/gas_mixture/saved_air = record[4]
	TEST_ASSERT_EQUAL(floor.air.total_moles(), saved_air.total_moles(), "Departure must preserve the actual floor air instead of creating its initial atmosphere")
	TEST_ASSERT_EQUAL(floor.air.temperature, saved_air.temperature, "Departure must restore the original floor gas temperature")
	if(length(record) > 4)
		TEST_ASSERT_EQUAL(floor.color, record[5], "Departure must restore the underlay's mapped color")
		TEST_ASSERT_EQUAL(floor.dir, angle2dir(dir2angle(record[6]) + rotation), "Departure must restore the underlay's own rotated direction")
		var/list/expected_decals = record[7]
		var/list/current_decals = collect_surface_test_decals(floor)
		TEST_ASSERT_EQUAL(length(current_decals), length(expected_decals), "Departure must restore both original decal attachments exactly once")
		for(var/description in expected_decals)
			var/list/expected = expected_decals[description]
			var/list/current = current_decals[description]
			TEST_ASSERT_NOTNULL(current, "The restored floor must retain each original decal description")
			var/expected_direction = expected[1] ? angle2dir(dir2angle(expected[2]) + rotation) : expected[2]
			TEST_ASSERT_EQUAL(current[1], expected[1], "The decal must retain its directional attachment flag")
			TEST_ASSERT_EQUAL(current[2], expected_direction, "Only a directional decal must rotate with its carrier")
			TEST_ASSERT_EQUAL(current[3], expected[3], "A restored decal must keep its color")
			TEST_ASSERT_EQUAL(current[4], expected[4], "A restored decal must keep its alpha")
			TEST_ASSERT_EQUAL(current[5], expected[5], "A restored decal must keep its icon state")
	return TRUE

/** Standard docking over a stationary floor keeps its real substrate when the guest and passage leave. */
/datum/unit_test/overmap_surface_dock
	parent_type = /datum/unit_test/overmap_standard_dock
	abstract_type = /datum/unit_test/overmap_surface_dock
	/// Original pad and path cells, keyed by their persistent coordinates.
	var/list/surface_records

/datum/unit_test/overmap_surface_dock/New()
	..()
	var/area/stationtrauma_space_site/pad_area = new /area/stationtrauma_space_site/unit_test_standard_dock
	allocated += pad_area
	surface_records = prepare_surface_pad(get_turf(bay), 7, 15, pad_area)
	var/turf/marked_pad = locate(bay.x + 1, bay.y + 1, bay.z)
	stamp_surface_test_floor(marked_pad, surface_records[marked_pad])
	var/turf/marked_path = locate(bay.x + 7, bay.y + 3, bay.z)
	stamp_surface_test_floor(marked_path, surface_records[marked_path])

/** The native hull and the folded passage must reveal the original floor without moving loose occupants. */
/datum/unit_test/overmap_surface_dock/stationary_round_trip
	/// The one-shot native preflight obstruction.
	var/obj/item/departure_blocker
	/// Connected passage inspected inside native preflight after the real fold.
	var/datum/stationtrauma_dock_gangway/departure_passage
	/// Whether the actual animated departure reached its folded native boundary.
	var/folded_before_preflight = FALSE
	/// Completion of the one real asynchronous blocked departure.
	var/blocked_departure_finished = FALSE
	/// Return value from the blocked departure.
	var/blocked_departure_result

/datum/unit_test/overmap_surface_dock/stationary_round_trip/Run()
	balance_surface_test_air(ship.return_turfs() + block(locate(bay.x + 8, bay.y, bay.z), locate(bay.x + 9, bay.y + 14, bay.z)))
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, locate(ship.x + 3, ship.y + 8, ship.z))
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, ship)
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The surface guest must have real propulsion")
	TEST_ASSERT(navigation.select_site(site.id), "The standard berth must remain selectable on a solid pad")
	TEST_ASSERT(navigation.dock(instant = TRUE), "A normal S hull must dock through native movement onto the solid floor. Status: [navigation.status]")
	var/turf/path = locate(bay.x + 7, bay.y + 3, bay.z)
	var/mob/living/carbon/human/consistent/traveller = allocate(/mob/living/carbon/human/consistent, path)
	ADD_TRAIT(traveller, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(traveller, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(traveller, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	var/obj/item/loose_item = allocate(/obj/item, path)
	station_objects += list(traveller, loose_item)
	departure_passage = hatch.gangway
	var/obj/docking_port/stationary/moored_berth = ship.get_docked()
	ship.preflight_action = CALLBACK(src, PROC_REF(block_surface_departure), get_turf(navigation.flight_berth))
	INVOKE_ASYNC(src, PROC_REF(attempt_surface_departure))
	var/deadline = world.time + 30 SECONDS
	UNTIL((locate(/obj/effect/constructing_effect/stationtrauma_gangway) in path) || blocked_departure_finished || world.time >= deadline)
	TEST_ASSERT((locate(/obj/effect/constructing_effect/stationtrauma_gangway) in path), "Animated retraction must display its real construction effect on a reused floor")
	TEST_ASSERT_EQUAL(path.type, /turf/open/floor/iron/white, "The real substrate must remain walkable while its passage retracts")
	TEST_ASSERT_EQUAL(ship.get_docked(), moored_berth, "The hull must remain moored during the floor passage's construction effect")
	deadline = world.time + 8 SECONDS
	UNTIL(blocked_departure_finished || world.time >= deadline)
	TEST_ASSERT(blocked_departure_finished && !blocked_departure_result, "A late native obstruction must cancel the real animated departure")
	TEST_ASSERT_NOTNULL(departure_blocker, "The one-shot blocker must be created during genuine native preflight")
	TEST_ASSERT(folded_before_preflight, "Native preflight must observe the already folded passage")
	TEST_ASSERT_EQUAL(ship.get_docked(), moored_berth, "Rollback must keep the native hull moored")
	TEST_ASSERT_EQUAL(navigation.docked, site, "Rollback must retain the occupied docking site")
	TEST_ASSERT_EQUAL(get_turf(traveller), path, "Rollback must leave the traveller on the same real floor")
	TEST_ASSERT_EQUAL(get_turf(loose_item), path, "Rollback must leave the loose item on the same real floor")
	TEST_ASSERT(length(departure_passage.floors) && !departure_passage.breached, "Rollback must reconnect the same physical floor passage")
	if(!assert_surface_restored(path, surface_records[path]))
		return
	QDEL_NULL(departure_blocker)
	TEST_ASSERT(navigation.depart(instant = TRUE), "The native guest must depart while the solid passage remains occupied. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "The guest must physically return to its own flight berth")
	TEST_ASSERT_EQUAL(get_turf(traveller), path, "Folding a solid-floor passage must retain its traveller's coordinates")
	TEST_ASSERT_EQUAL(get_turf(loose_item), path, "Folding a solid-floor passage must retain the loose item's coordinates")
	for(var/turf/tile as anything in surface_records)
		if(!assert_surface_restored(tile, surface_records[tile]))
			return

/** Run the normal approach and construction animation once, retaining its real result. */
/datum/unit_test/overmap_surface_dock/stationary_round_trip/proc/attempt_surface_departure()
	blocked_departure_result = navigation.depart()
	blocked_departure_finished = TRUE

/** Obstruct the independent flight berth only after the solid-floor passage has folded. */
/datum/unit_test/overmap_surface_dock/stationary_round_trip/proc/block_surface_departure(turf/target)
	folded_before_preflight = length(departure_passage.folded_path) && !length(departure_passage.floors)
	departure_blocker = allocate(/obj/item, target)

/** A roof berth accepts a direct arrival and releases the hull without either gangway endpoint. */
/datum/unit_test/overmap_surface_dock/hangar_round_trip

/datum/unit_test/overmap_surface_dock/hangar_round_trip/Run()
	QDEL_NULL(hatch)
	QDEL_LIST(station_objects)
	balance_surface_test_air(ship.return_turfs())
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, locate(ship.x + 3, ship.y + 8, ship.z))
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, ship)
	TEST_ASSERT(navigation.set_engines_running(TRUE), "The hangar hull must have real propulsion for takeoff")
	TEST_ASSERT(navigation.select_site(site.id), "The pad must be selectable")
	TEST_ASSERT(!navigation.dock(instant = TRUE), "The same pad in standard S mode must still require docking endpoints")

	bay.hangar = TRUE
	var/turf/pad_anchor = get_turf(bay)
	var/datum/space_level/lower_deck = test_levels[1]
	var/turf/lower_anchor = locate(pad_anchor.x, pad_anchor.y, lower_deck.z_value)
	bay.forceMove(lower_anchor)
	var/accepted_without_link = navigation.can_dock(site, navigation.control_revision)
	// Only the fixture deck's upward linkage changes while the same landing order is checked.
	lower_deck.traits[ZTRAIT_UP] = TRUE
	SSmapping.generate_linkages_for_z_level(lower_deck.z_value)
	var/has_link = GET_TURF_ABOVE(lower_anchor) == pad_anchor
	var/accepted_with_link = navigation.can_dock(site, navigation.control_revision)
	lower_deck.traits -= ZTRAIT_UP
	SSmapping.generate_linkages_for_z_level(lower_deck.z_value)
	bay.forceMove(pad_anchor)
	TEST_ASSERT(has_link && accepted_without_link && !accepted_with_link, "The same berth must be refused once another deck is linked above it")

	var/turf/marked_pad = locate(bay.x + 1, bay.y + 1, bay.z)
	TEST_ASSERT(navigation.dock(instant = TRUE), "The ship must land on clear solid ground without a wall or docking hatch. Status: [navigation.status]")
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = bay.active_berth
	TEST_ASSERT_NOTNULL(berth, "The hangar must reserve a native berth")
	TEST_ASSERT_EQUAL(ship.get_docked(), berth, "The ship must physically occupy the reserved berth")
	TEST_ASSERT(ship.has_docking_layer(marked_pad), "The landed hull must cover the original pad floor")
	TEST_ASSERT(!length(berth.routes) && !length(berth.gangways), "A landing must neither reserve nor build a gangway")
	TEST_ASSERT(!(locate(/obj/effect/temp_visual/stationtrauma_hangar_glow) in marked_pad), "Pad glow must never be added to a landed hull tile")
	var/turf/cutout = locate(bay.x + 2, bay.y + 14, bay.z)
	TEST_ASSERT((locate(/obj/effect/temp_visual/stationtrauma_hangar_glow) in cutout), "Exposed floor within the bounds of an irregular hull must still glow")

	TEST_ASSERT(navigation.depart(instant = TRUE), "A hatchless ship must take off normally. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "The hull must physically return to its flight berth")
	TEST_ASSERT_NULL(bay.active_berth, "Takeoff must release the hangar berth")
	TEST_ASSERT((locate(/obj/effect/temp_visual/stationtrauma_hangar_glow) in marked_pad), "Takeoff must light the newly exposed floor")
	assert_surface_restored(marked_pad, surface_records[marked_pad])

/** A real M controller commissions a clear solid pad and rejects a loose object on the same floor. */
/datum/unit_test/overmap_surface_dock/medium_registration
	parent_type = /datum/unit_test/overmap_standard_dock/runtime_controller

/datum/unit_test/overmap_surface_dock/medium_registration/Run()
	var/level = bay.z
	var/anchor_x = max(bay.x + 12, TRANSITIONEDGE + 1)
	var/anchor_y = TRANSITIONEDGE + 1
	var/turf/anchor = locate(anchor_x, anchor_y, level)
	prepare_vacuum(anchor, locate(anchor_x + 22, anchor_y + 24, level), get_area(bay))
	var/area/station_area = get_area(locate(bay.x + 9, bay.y, level))
	var/datum/stationtrauma_overmap_sector/space/home/home = prepare_controller_sector(level)
	var/list/records = prepare_surface_pad(anchor, 19, 25, station_area)
	for(var/row in anchor_y to anchor_y + 24)
		var/turf/wall_floor = lay_controller_floor(locate(anchor_x + 20, row, level), station_area)
		var/obj/machinery/door/airlock/stationtrauma_docking/wall/segment = allocate(/obj/machinery/door/airlock/stationtrauma_docking/wall, wall_floor)
		segment.setDir(WEST)
		station_objects += segment
		lay_controller_floor(locate(anchor_x + 21, row, level), station_area)
	var/turf/control_floor = lay_controller_floor(locate(anchor_x + 22, anchor_y, level), station_area)
	first_controller = allocate(/obj/machinery/computer/stationtrauma_dock_controller/medium, control_floor)
	first_controller.setDir(NORTH)
	var/turf/blocked_floor = locate(anchor_x + 5, anchor_y + 5, level)
	var/obj/item/blocker = allocate(/obj/item, blocked_floor)
	TEST_ASSERT_NOTNULL(first_controller.publish_slot(), "A loose item on solid ground must prevent runtime M publication")
	TEST_ASSERT_NULL(first_controller.owned_slot, "Failed floor admission must not leave a runtime marker")
	TEST_ASSERT_EQUAL(get_turf(blocker), blocked_floor, "Rejected floor publication must leave the blocking item intact")
	if(!assert_surface_restored(blocked_floor, records[blocked_floor]))
		return
	qdel(blocker)
	TEST_ASSERT_NULL(first_controller.publish_slot(), "The identical M floor pad must publish once its obstruction is removed")
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/slot = first_controller.owned_slot
	TEST_ASSERT_NOTNULL(slot, "A clear solid M pad must create its real runtime marker")
	TEST_ASSERT(slot.width == 19 && slot.height == 25 && slot.accepted_ship_class == "medium", "Floor publication must retain the actual M standard")
	TEST_ASSERT_EQUAL(home.sites[slot.site_id], slot.published_site, "The solid M destination must enter the live station registry")

/** A floor does not grant a station berth permission to overwrite an unrelated native hull. */
/datum/unit_test/overmap_surface_dock/foreign_floor
	/// Independently registered native hull occupying part of the pad.
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/foreign_ship

/datum/unit_test/overmap_surface_dock/foreign_floor/Destroy()
	if(foreign_ship)
		qdel(foreign_ship, force = TRUE)
		foreign_ship = null
	return ..()

/datum/unit_test/overmap_surface_dock/foreign_floor/Run()
	var/area/shuttle/stationtrauma_space/foreign_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += foreign_area
	var/turf/foreign_origin = locate(bay.x + 2, bay.y + 5, bay.z)
	for(var/turf/tile as anything in block(foreign_origin, locate(foreign_origin.x + 1, foreign_origin.y + 2, foreign_origin.z)))
		tile.change_area(get_area(tile), foreign_area)
	foreign_ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, foreign_origin, list(foreign_area))
	foreign_ship.calculate_docking_port_information()
	foreign_ship.register()
	var/turf/foreign_floor = locate(foreign_origin.x + 1, foreign_origin.y + 1, foreign_origin.z)
	TEST_ASSERT_EQUAL(SSshuttle.get_containing_shuttle(foreign_floor), foreign_ship, "The obstruction must be a real owned hull floor without a marker on the tested cell")
	TEST_ASSERT(!stationtrauma_standard_dock_clear_space(foreign_floor), "Floor admission must reject another mobile hull's ownership")
	var/turf/departure = get_turf(ship)
	TEST_ASSERT(navigation.select_site(site.id), "The mapped berth remains selectable before its occupied floor is checked")
	TEST_ASSERT(!navigation.dock(instant = TRUE), "A real arrival must reject the foreign floor within the hull projection")
	TEST_ASSERT_EQUAL(get_turf(ship), departure, "A rejected floor overlap must leave the guest at its original flight berth")
	TEST_ASSERT_EQUAL(get_area(foreign_floor), foreign_area, "Rejection must preserve the foreign floor's owner")

/** Guest, carrier floor and external landing floor retain distinct native boundaries and concealed surfaces. */
/datum/unit_test/overmap_surface_dock/carrier_layers
	parent_type = /datum/unit_test/overmap_carrier
	/// The real guest departure reached native preflight only after its temporary overlay was folded.
	var/guest_fold_observed = FALSE

/datum/unit_test/overmap_surface_dock/carrier_layers/Run()
	var/area/host_area = get_area(host_ship)
	var/turf/source_gap = locate(bay.x + 7, bay.y + 3, bay.z)
	var/list/parent_records = prepare_surface_pad(get_turf(bay), 7, 15, host_area, carrier_floor = TRUE, skipped = source_gap)
	var/turf/parent_probe = locate(bay.x + 1, bay.y + 1, bay.z)
	stamp_surface_test_floor(parent_probe, parent_records[parent_probe], "carrier")
	TEST_ASSERT(isshuttleturf(parent_probe), "The newly constructed parent deck must have a real native boundary before navigation refreshes it")
	balance_surface_test_air(ship.return_turfs() + host_ship.return_turfs())
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest() && navigation.dock(instant = TRUE), "The guest must perform real native docking above the carrier's own solid deck")
	TEST_ASSERT(host_ship.has_docking_layer(parent_probe), "Real docking must recognize the newly built parent floor without a test-only registry refresh")
	var/datum/stationtrauma_dock_gangway/gangway = hatch.gangway
	var/deadline = world.time + 5 SECONDS
	UNTIL(!gangway.busy || world.time >= deadline)
	TEST_ASSERT(!gangway.busy, "The carried solid-floor passage must finish its real arrival operation")
	TEST_ASSERT(istype(gangway.floors[1], /turf/open/floor/plating/stationtrauma_dock_gangway), "The one vacuum gap must deploy a real temporary bridge beside the solid carrier pad")
	var/turf/source_host = get_turf(host_ship)
	var/turf/source_guest = get_turf(ship)
	var/source_direction = host_ship.dir
	var/obj/docking_port/stationary/target = position_carrier_target()
	var/list/projected = project_assembly(target)
	var/area/stationtrauma_space_site/ground_area = new /area/stationtrauma_space_site/unit_test_standard_dock
	allocated += ground_area
	var/list/ground_records = prepare_surface_pad(locate(4, 4, target.z), 14, 10, ground_area, turf_type = /turf/open/floor/wood)
	var/turf/ground_probe = projected[parent_probe]
	stamp_surface_test_floor(ground_probe, ground_records[ground_probe], "ground")
	host_ship.preflight_action = CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/overmap_carrier, block_compound_target), projected[get_turf(hatch)])
	TEST_ASSERT(!host_navigation.relocate(target), "A late blocker on solid destination ground must cancel the whole compound arrival")
	TEST_ASSERT_NOTNULL(late_blocker, "The blocked solid-ground arrival must reach genuine native preflight")
	TEST_ASSERT_EQUAL(get_turf(host_ship), source_host, "A blocked surface relocation must retain the carrier")
	TEST_ASSERT_EQUAL(get_turf(ship), source_guest, "A blocked surface relocation must retain the moored child")
	if(!assert_surface_restored(ground_probe, ground_records[ground_probe]))
		return
	QDEL_NULL(late_blocker)
	TEST_ASSERT(host_navigation.relocate(target), "The entire layered assembly must really rotate onto the clear external floor. Status: [host_navigation.status]")
	TEST_ASSERT_EQUAL(ship.dir, EAST, "The carried guest must complete the native quarter-turn")
	var/turf/moved_parent_probe = projected[parent_probe]
	var/turf/moved_gap = projected[source_gap]
	var/obj/docking_port/stationary/moored_berth = ship.get_docked()
	var/turf/moored_position = get_turf(ship)
	ship.preflight_action = CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/overmap_surface_dock/carrier_layers, block_guest_departure), get_turf(navigation.flight_berth))
	TEST_ASSERT(!navigation.depart(), "A late guest flight obstruction must cancel the real departure after the carried temporary passage folds")
	TEST_ASSERT_NOTNULL(late_blocker, "The guest obstruction must be introduced during genuine native preflight")
	TEST_ASSERT(guest_fold_observed, "The failed native attempt must actually observe the folded temporary passage")
	TEST_ASSERT_EQUAL(ship.get_docked(), moored_berth, "The cancelled guest departure must retain its actual native berth")
	TEST_ASSERT_EQUAL(get_turf(ship), moored_position, "The cancelled guest departure must leave the child physically moored")
	TEST_ASSERT(hatch.gangway && !hatch.gangway.breached && (moved_gap in hatch.gangway.floors), "Rollback must reconnect the carried passage without breaching it")
	TEST_ASSERT(istype(moved_gap, /turf/open/floor/plating/stationtrauma_dock_gangway), "Rollback must rebuild the original temporary overlay instead of adopting the external wood floor")
	QDEL_NULL(late_blocker)
	TEST_ASSERT(navigation.depart(instant = TRUE), "The guest must independently depart without taking the parent deck or its external substrate. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Only the guest must return to its original flight berth")
	TEST_ASSERT_EQUAL(get_turf(host_ship), get_turf(target), "The parent must remain on the external solid platform")
	if(!assert_surface_restored(moved_gap, ground_records[moved_gap]))
		return
	for(var/turf/original as anything in parent_records)
		var/turf/moved = projected[original]
		var/list/original_record = parent_records[original]
		var/list/expected = original_record.Copy()
		var/list/old_bases = expected[2]
		var/list/ground = ground_records[moved]
		var/list/ground_bases = ground[2]
		var/list/rebased_bases = ground_bases.Copy()
		rebased_bases += ground[1]
		rebased_bases += old_bases.Copy(old_bases.Find(/turf/baseturf_skipover/shuttle))
		expected[2] = rebased_bases
		if(!assert_surface_restored(moved, expected, rotation = 90))
			return
	TEST_ASSERT(host_ship.has_docking_layer(moved_parent_probe), "The exposed parent deck must retain its own boundary after the child's departure")
	var/turf/guest_home = get_turf(ship)
	TEST_ASSERT(isnull(guest_home.depth_to_find_baseturf(/turf/open/floor/iron/white)) && isnull(guest_home.depth_to_find_baseturf(/turf/open/floor/wood)), "The guest must not import either the parent deck or external landing floor into its home stack")
	target.forceMove(source_host)
	target.setDir(source_direction)
	TEST_ASSERT(host_navigation.relocate(target), "The parent must subsequently lift off the external floor through its own native boundary")
	for(var/turf/tile as anything in ground_records)
		if(!assert_surface_restored(tile, ground_records[tile]))
			return
	if(!assert_surface_restored(parent_probe, parent_records[parent_probe]))
		return
	TEST_ASSERT(isspaceturf(source_gap), "The folded temporary bridge must not import the external landing floor when its carrier returns to space")

/** Block the real flight target after normal departure has already exposed the external floor below the temporary bridge. */
/datum/unit_test/overmap_surface_dock/carrier_layers/proc/block_guest_departure(turf/target)
	var/datum/stationtrauma_dock_gangway/passage = hatch.gangway
	guest_fold_observed = passage && length(passage.folded_path) && !length(passage.floors)
	block_compound_target(target)

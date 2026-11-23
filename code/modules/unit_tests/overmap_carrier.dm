/** A real standard berth carried by a separate native hull, with private flight levels for both ships. */
/datum/unit_test/overmap_carrier
	parent_type = /datum/unit_test/overmap_standard_dock
	abstract_type = /datum/unit_test/overmap_carrier
	/// Carrier hull surrounding the inherited guest's destination.
	var/obj/docking_port/mobile/stationtrauma_space/unit_test_docking/host_ship
	/// Carrier navigation; processing is advanced explicitly by the test.
	var/datum/stationtrauma_overmap/space/host_navigation
	/// Shared non-station sector, so carrier traffic cannot rely on the home-sector special case.
	var/datum/stationtrauma_overmap_sector/space/carrier_sector
	/// Reusable empty level receiving the whole rotated assembly.
	var/static/datum/space_level/relocation_level
	/// Powered command console physically aboard the carrier.
	var/obj/machinery/computer/stationtrauma_station_traffic/traffic
	/// Adjacent command operator using a real access card.
	var/mob/living/carbon/human/consistent/operator
	/// Item inserted after the genuine native preflight has yielded.
	var/obj/item/late_blocker

/datum/unit_test/overmap_carrier/New()
	..()
	if(!relocation_level)
		relocation_level = SSmapping.add_new_zlevel("Carrier relocation test", list(ZTRAIT_AWAY = TRUE))
	TEST_ASSERT(world.maxx >= 19 && world.maxy >= 19, "The carrier fixture needs room for a rotated fifteen-tile hull")
	prepare_vacuum(locate(3, 3, relocation_level.z_value), locate(19, 19, relocation_level.z_value), navigation.exterior)
	var/area/shuttle/stationtrauma_space/host_area = new /area/shuttle/stationtrauma_space/unit_test_docking
	allocated += host_area
	// The pad's vacuum belongs to the carrier; guest hull areas remain separate after arrival.
	for(var/turf/tile as anything in block(locate(bay.x, bay.y, bay.z), locate(bay.x + 9, bay.y + 14, bay.z)))
		tile.change_area(get_area(tile), host_area)
	host_ship = allocate(/obj/docking_port/mobile/stationtrauma_space/unit_test_docking, locate(bay.x + 9, bay.y, bay.z), list(host_area))
	host_ship.ship_class = "medium"
	host_ship.calculate_docking_port_information()
	host_ship.register()
	for(var/turf/tile as anything in host_ship.return_turfs())
		host_ship.underlying_areas_by_turf[tile] = navigation.exterior
	host_navigation = allocate(/datum/stationtrauma_overmap/space, host_ship)
	host_ship.overmap = host_navigation
	STOP_PROCESSING(SSfastprocess, host_navigation)
	host_navigation.exterior = navigation.exterior
	host_navigation.preparing = FALSE
	// Movement is the contract here; balanced vacuum prevents unrelated decompression from moving the actors.
	empty_hull_air(ship)
	empty_hull_air(host_ship)
	start_engine(ship, locate(ship.x + 3, ship.y + 8, ship.z))
	start_engine(host_ship, locate(bay.x + 9, bay.y + 11, bay.z))
	carrier_sector = allocate(/datum/stationtrauma_overmap_sector/space)
	carrier_sector.id = "unit_test_carrier_origin"
	carrier_sector.ready = TRUE
	navigation.sites.Cut()
	TEST_ASSERT(carrier_sector.register(ship.shuttle_id, navigation), "The guest must register in the carrier's sector")
	TEST_ASSERT(carrier_sector.register(host_ship.shuttle_id, host_navigation), "The carrier must register independently")
	bay.site_id = "unit_test_carrier_slot"
	bay.host_ship_id = host_ship.shuttle_id
	TEST_ASSERT(host_navigation.register_carrier_dock(bay), "The synthetic carrier must register its test berth")
	site = carrier_sector.sites[bay.site_id]
	TEST_ASSERT_NOTNULL(site, "The mapped host ID must publish the carrier's standard berth")
	TEST_ASSERT_EQUAL(bay.host, host_navigation, "The mapped slot must bind to the intended live carrier")
	TEST_ASSERT_EQUAL(site.host, host_navigation, "The hosted destination must retain its carrier")
	traffic = allocate(/obj/machinery/computer/stationtrauma_station_traffic, locate(bay.x + 9, bay.y + 6, bay.z))
	operator = allocate(/mob/living/carbon/human/consistent, locate(bay.x + 9, bay.y + 7, bay.z))
	protect_vacuum_actor(operator)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(operator.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The carrier operator must wear a uniform for its ID slot")
	var/obj/item/card/id/advanced/command_card = allocate(/obj/item/card/id/advanced)
	command_card.set_access(list(ACCESS_COMMAND), FORCE_ADD_ALL)
	TEST_ASSERT(operator.equip_to_slot_if_possible(command_card, ITEM_SLOT_ID), "The carrier operator must wear command credentials through native takeoff")

/datum/unit_test/overmap_carrier/Destroy()
	QDEL_NULL(navigation)
	if(ship)
		qdel(ship, force = TRUE)
		ship = null
	QDEL_NULL(host_navigation)
	if(host_ship)
		qdel(host_ship, force = TRUE)
		host_ship = null
	QDEL_NULL(carrier_sector)
	traffic = null
	operator = null
	late_blocker = null
	return ..()

/** Fit an ordinary native engine instead of bypassing departure's propulsion checks. */
/datum/unit_test/overmap_carrier/proc/start_engine(obj/docking_port/mobile/stationtrauma_space/vessel, turf/tile)
	var/obj/machinery/power/shuttle_engine/engine = allocate(/obj/machinery/power/shuttle_engine, tile)
	engine.anchored = TRUE
	engine.engine_state = initial(engine.engine_state)
	engine.connect_to_shuttle(TRUE, vessel)
	TEST_ASSERT(vessel.overmap.set_engines_running(TRUE), "The real engine must enable the fixture's helm")

/** Remove the actual gas from both hulls so their open test decks cannot produce a decompression gust. */
/datum/unit_test/overmap_carrier/proc/empty_hull_air(obj/docking_port/mobile/stationtrauma_space/vessel)
	for(var/area/hull_area as anything in vessel.shuttle_areas)
		for(var/list/deck_turfs as anything in hull_area.get_zlevel_turf_lists())
			for(var/turf/open/floor/tile in deck_turfs)
				if(!vessel.contains_deck(tile.z))
					continue
				var/datum/gas_mixture/air = tile.return_air()
				var/datum/gas_mixture/removed = air.remove_ratio(1)
				qdel(removed)
				tile.air_update_turf(FALSE, FALSE)

/** Isolate vacuum exposure while retaining normal human interaction, access, collision and native movement. */
/datum/unit_test/overmap_carrier/proc/protect_vacuum_actor(mob/living/carbon/human/consistent/person)
	ADD_TRAIT(person, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(person, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(person, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)

/** Send a pilot request and approve it through the command console physically on the carrier. */
/datum/unit_test/overmap_carrier/proc/approve_guest(stale_token)
	TEST_ASSERT(navigation.select_site(site.docking_target.id), "A detected carrier berth must be selectable")
	TEST_ASSERT(navigation.request_station_docking(site.docking_target.id), "A pilot must be able to request the carrier berth")
	var/datum/stationtrauma_station_docking_request/request = navigation.get_station_docking_request()
	TEST_ASSERT_NOTNULL(request, "The non-station sector must own the pilot's request")
	// Standing crew recover from the ordinary native takeoff stun before operating the console again.
	var/deadline = world.time + 2 SECONDS
	UNTIL(!operator.IsParalyzed() || world.time >= deadline)
	TEST_ASSERT(traffic.can_operate(operator), "The powered carrier console must accept its recovered command operator")
	TEST_ASSERT_EQUAL(traffic.traffic_sector(), host_navigation.sector, "Carrier traffic must resolve its own live sector")
	if(!isnull(stale_token))
		TEST_ASSERT(!traffic.respond_to_request(operator, ship.shuttle_id, stale_token, TRUE, site.id), "A console action retained from the previous sector must not approve the new request")
		TEST_ASSERT(!request.assigned_berth && !site.docking_owner, "The stale response must leave the replacement request pending and its berth unreserved")
	TEST_ASSERT(traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, site.id), "The carrier's controller must approve its own berth")
	return navigation.has_station_clearance(site)

/** Let native index pairing determine the expected transformed coordinate, without assuming an anchor convention. */
/datum/unit_test/overmap_carrier/proc/project_assembly(obj/docking_port/stationary/target)
	var/list/source = host_ship.return_ordered_turfs(host_ship.x, host_ship.y, host_ship.z, host_ship.dir)
	var/list/destination = host_ship.return_ordered_turfs(target.x, target.y, target.z, target.dir)
	var/list/result = list()
	for(var/index in 1 to length(source))
		result[source[index]] = destination[index]
	return result

/** Move the empty flight marker so the real carrier return path performs a quarter-turn on a separate level. */
/datum/unit_test/overmap_carrier/proc/position_carrier_target()
	var/list/bounds = host_ship.return_coords(0, 0, EAST)
	var/target_x = 4 - min(bounds[1], bounds[3])
	var/target_y = 4 - min(bounds[2], bounds[4])
	host_navigation.flight_berth.forceMove(locate(target_x, target_y, relocation_level.z_value))
	host_navigation.flight_berth.setDir(EAST)
	return host_navigation.flight_berth

/** Introduce a collision after preflight so the final compound validation must veto the entire move. */
/datum/unit_test/overmap_carrier/proc/block_compound_target(turf/target)
	late_blocker = allocate(/obj/item, target)

/** Detection, command clearance and native transport preserve a moored guest through rotation and independent release. */
/datum/unit_test/overmap_carrier/round_trip/Run()
	TEST_ASSERT(!navigation.knows_site(site), "A mapped carrier ID must not reveal its berth before detection")
	TEST_ASSERT(!navigation.select_site(site.docking_target.id), "A forged unknown carrier destination must not be selectable")
	navigation.selected_destination = site.docking_target.id
	TEST_ASSERT(!navigation.request_station_docking(site.docking_target.id), "A forged destination ID must not bypass carrier detection")
	navigation.selected_destination = null
	host_navigation.pos_x = 12
	host_navigation.pos_y = 16
	host_navigation.sync_carrier()
	TEST_ASSERT(navigation.scan_sector(), "The real active sensor must scan nearby registered hulls")
	TEST_ASSERT(navigation.knows_site(site), "A fresh carrier observation must reveal its hosted berth")
	var/list/observation = navigation.ship_observations[host_ship.shuttle_id]
	TEST_ASSERT_NOTNULL(observation, "The active scan must record the host itself")
	host_navigation.pos_x += 400
	host_navigation.sync_carrier()
	var/list/remembered_position = navigation.site_position(site)
	TEST_ASSERT_EQUAL(remembered_position[1], 12, "A hosted destination must use its last observed easting")
	TEST_ASSERT_EQUAL(remembered_position[2], 16, "A hosted destination must use its last observed northing")
	TEST_ASSERT_EQUAL(navigation.distance_to(site), 20, "Distance must not disclose unobserved live carrier movement")
	TEST_ASSERT(navigation.select_site(site.docking_target.id), "A remembered live contact must remain selectable")
	TEST_ASSERT_EQUAL(navigation.ordered_course, delta_to_angle(12, 16), "Selection must aim at the recorded contact instead of the live carrier position")
	var/obj/machinery/computer/stationtrauma_space_navigation/helm = allocate(/obj/machinery/computer/stationtrauma_space_navigation, get_turf(ship))
	helm.vessel = ship
	var/list/helm_data = helm.ui_data(null)
	TEST_ASSERT_EQUAL(helm_data["distance"], 20, "The pilot display must use the same sensor snapshot as course selection")
	var/turf/pre_request_position = get_turf(ship)
	TEST_ASSERT(approve_guest(), "A remembered contact must permit a request before reaching the carrier")
	TEST_ASSERT(!navigation.dock(instant = TRUE), "A near sensor snapshot must not permit native docking to the now distant live carrier")
	TEST_ASSERT_EQUAL(get_turf(ship), pre_request_position, "A live-range rejection must retain the guest's physical position")
	TEST_ASSERT_NULL(bay.active_berth, "A distant carrier must not allocate an arrival marker for the rejected approach")
	TEST_ASSERT(navigation.cancel_station_docking(), "The pilot must be able to cancel the unused distant-carrier approval")
	observation["seen"] = world.time - 2 MINUTES
	TEST_ASSERT(!navigation.knows_site(site), "A charted berth must become unavailable when its host observation expires")
	TEST_ASSERT(!navigation.request_station_docking(site.docking_target.id), "A still-selected expired contact must not accept a docking request")
	helm_data = helm.ui_data(null)
	TEST_ASSERT_NULL(helm_data["landing"], "An expired selection must hide its destination metadata")
	TEST_ASSERT_NULL(helm_data["eta"], "An expired selection must hide the destination ETA")
	TEST_ASSERT_EQUAL(helm_data["distance"], 0, "An expired selection must hide its destination distance")
	TEST_ASSERT_EQUAL(length(helm_data["routes"]), 0, "The pilot chart must hide the expired carrier berth")
	var/list/clearance_data = helm_data["station_docking"]
	TEST_ASSERT(!clearance_data["canRequest"] && !helm_data["can_dock"], "Expired controls must not permit requests or native docking")
	host_navigation.pos_x = 12
	host_navigation.sync_carrier()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest(), "A fresh observation and the carrier's command approval must authorize the guest")
	TEST_ASSERT(navigation.dock(instant = TRUE), "The approved guest must perform real native docking. Status: [navigation.status]")
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = bay.active_berth
	TEST_ASSERT_NOTNULL(berth, "The carrier slot must retain the guest's native arrival berth")
	TEST_ASSERT_EQUAL(navigation.carrier_host(), host_navigation, "A moored guest must resolve its carrier")
	TEST_ASSERT_EQUAL(length(berth.gangways), 1, "The genuine arrival must deploy the aligned passage")
	var/datum/stationtrauma_dock_gangway/gangway = berth.gangways[1]
	var/deadline = world.time + 5 SECONDS
	UNTIL(!gangway.busy || world.time >= deadline)
	TEST_ASSERT(!gangway.busy, "The fitted bridge must finish its arrival interlock before transport")
	var/turf/bridge = gangway.floors[1]
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = gangway.wall
	var/mob/living/carbon/human/consistent/traveller = allocate(/mob/living/carbon/human/consistent, bridge)
	protect_vacuum_actor(traveller)
	var/obj/item/loose_item = allocate(/obj/item, bridge)
	var/obj/item/cabin_item = allocate(/obj/item, get_step(hatch, WEST))
	var/host_area_count = length(host_ship.shuttle_areas)
	var/guest_area_count = length(ship.shuttle_areas)
	host_navigation.helm_engaged = TRUE
	host_navigation.throttle = 50
	host_navigation.last_update = world.time - 1 SECONDS
	var/previous_x = host_navigation.pos_x
	host_navigation.process(1)
	TEST_ASSERT_NOTEQUAL(host_navigation.pos_x, previous_x, "The host must actually advance through virtual space")
	TEST_ASSERT_EQUAL(navigation.pos_x, host_navigation.pos_x, "A moored guest must follow virtual carrier movement")
	TEST_ASSERT_EQUAL(navigation.pos_y, host_navigation.pos_y, "The guest must inherit the carrier's virtual northing")
	TEST_ASSERT_EQUAL(site.pos_x, host_navigation.pos_x, "The berth must follow its moving carrier on the chart")
	host_navigation.stop()
	var/obj/docking_port/stationary/target = position_carrier_target()
	var/list/projected = project_assembly(target)
	var/turf/old_host = get_turf(host_ship)
	var/turf/old_ship = get_turf(ship)
	var/turf/old_hatch = get_turf(hatch)
	var/turf/old_wall = get_turf(wall)
	var/turf/old_slot = get_turf(bay)
	var/turf/old_cabin = get_turf(cabin_item)
	host_ship.preflight_action = CALLBACK(src, PROC_REF(block_compound_target), projected[old_hatch])
	TEST_ASSERT(!host_navigation.relocate(target), "A late blocker under a carried child must cancel the whole native assembly")
	TEST_ASSERT_NOTNULL(late_blocker, "The obstruction must be inserted during genuine native preflight")
	TEST_ASSERT_EQUAL(get_turf(host_ship), old_host, "A rejected carrier move must leave the host in place")
	TEST_ASSERT_EQUAL(get_turf(ship), old_ship, "A rejected carrier move must leave the child in place")
	TEST_ASSERT_EQUAL(get_turf(bay), old_slot, "A rejected carrier move must retain the mapped slot")
	TEST_ASSERT_EQUAL(get_turf(traveller), bridge, "A rejected carrier move must retain bridge occupants")
	TEST_ASSERT(!gangway.breached && !isspaceturf(bridge), "Aborting must preserve the connected passage")
	TEST_ASSERT(!host_navigation.relocating && !navigation.relocating, "A failed compound move must release every relocation lock")
	QDEL_NULL(late_blocker)
	TEST_ASSERT(host_navigation.relocate(target), "The whole native assembly must relocate once the target is clear. Status: [host_navigation.status]")
	TEST_ASSERT_EQUAL(get_turf(host_ship), projected[old_host], "The host must reach its projected native coordinate")
	TEST_ASSERT_EQUAL(get_turf(ship), projected[old_ship], "The carried child's marker must move with its hull")
	TEST_ASSERT_EQUAL(get_turf(hatch), projected[old_hatch], "The carried child's hatch must reach its projected coordinate")
	TEST_ASSERT_EQUAL(get_turf(wall), projected[old_wall], "The carrier's docking wall must move with the assembly")
	TEST_ASSERT_EQUAL(get_turf(bay), projected[old_slot], "The mapped slot must move with its carrier")
	TEST_ASSERT_EQUAL(get_turf(berth), projected[old_ship], "The guest's technical native berth must follow the carried hull")
	TEST_ASSERT_EQUAL(ship.dir, EAST, "The native child marker must inherit the carrier's quarter-turn")
	TEST_ASSERT_EQUAL(bay.dir, EAST, "The carried standard marker must inherit the quarter-turn")
	TEST_ASSERT_EQUAL(hatch.dir, SOUTH, "The east-facing hatch must rotate south with the assembly")
	TEST_ASSERT_EQUAL(get_turf(traveller), projected[bridge], "A person standing on the bridge must travel with the carrier")
	TEST_ASSERT_EQUAL(get_turf(loose_item), projected[bridge], "A loose bridge item must travel with the carrier")
	TEST_ASSERT_EQUAL(get_turf(cabin_item), projected[old_cabin], "Contents of the child's separate area must travel with its hull")
	TEST_ASSERT(!gangway.breached && !isspaceturf(get_turf(traveller)), "Carrying must retain the connected bridge instead of folding it")
	TEST_ASSERT_EQUAL(length(host_ship.shuttle_areas), host_area_count, "Transport must not permanently merge the child's areas into the host")
	TEST_ASSERT_EQUAL(length(ship.shuttle_areas), guest_area_count, "Transport must preserve the child's own area registry")
	TEST_ASSERT_EQUAL(SSshuttle.get_containing_shuttle(cabin_item), ship, "Equipment in the child must still resolve the child after compound movement")
	var/turf/carried_bridge = get_turf(traveller)
	var/turf/host_position = get_turf(host_ship)
	TEST_ASSERT(gangway.clear_tile(get_turf(hatch), hatch) && gangway.clear_tile(get_turf(wall), wall), "Native transport must leave both endpoint doorways clear before normal closure")
	TEST_ASSERT(navigation.depart(instant = TRUE), "A carried guest must still depart through the normal native path. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "Departure must return the child to its independent flight berth")
	TEST_ASSERT_EQUAL(get_turf(host_ship), host_position, "The guest's departure must leave its carrier in place")
	TEST_ASSERT_EQUAL(get_turf(traveller), carried_bridge, "Normal retraction must leave the bridge traveller at the same coordinates")
	TEST_ASSERT_EQUAL(get_turf(loose_item), carried_bridge, "Normal retraction must leave the loose bridge item at the same coordinates")
	TEST_ASSERT(isspaceturf(carried_bridge), "The departed guest's bridge must retract to vacuum")
	TEST_ASSERT_NULL(navigation.carrier_host(), "An independently departed child must release its carrier relation")
	// Recover the EVA occupants after checking their unchanged coordinates, freeing the vacuum approach for the return.
	traveller.forceMove(get_turf(operator))
	loose_item.forceMove(get_turf(operator))
	navigation.stop()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest(), "The departed guest must request a fresh approval from the relocated carrier")
	TEST_ASSERT(navigation.dock(instant = TRUE), "The child must be able to dock again at the rotated carrier berth. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(navigation.carrier_host(), host_navigation, "Returning must restore the real carrier relation")
	TEST_ASSERT_EQUAL(ship.get_docked(), bay.active_berth, "Returning must use the relocated native berth")

/** A carrier's command console cannot enumerate or approve a foreign berth in the same star system. */
/datum/unit_test/overmap_carrier/traffic_scope
	/// Independent fixed berth, explicitly force-deleted like the fixture's other native ports.
	var/obj/docking_port/stationary/stationtrauma_space_station/foreign_berth

/datum/unit_test/overmap_carrier/traffic_scope/Destroy()
	if(foreign_berth)
		qdel(foreign_berth, force = TRUE)
		foreign_berth = null
	return ..()

/datum/unit_test/overmap_carrier/traffic_scope/Run()
	foreign_berth = allocate(/obj/docking_port/stationary/stationtrauma_space_station, locate(4, 4, relocation_level.z_value))
	foreign_berth.width = ship.width
	foreign_berth.height = ship.height
	var/datum/stationtrauma_overmap_site/space/foreign_site = allocate(/datum/stationtrauma_overmap_site/space)
	foreign_site.id = "unit_test_foreign_carrier_berth"
	foreign_site.name = "Foreign berth"
	foreign_site.physical_docking = TRUE
	foreign_site.berth = foreign_berth
	foreign_site.discovered = TRUE
	carrier_sector.sites[foreign_site.id] = foreign_site
	carrier_sector.register_docking_berth(foreign_site, "traffic:foreign", "Foreign installation")
	TEST_ASSERT(navigation.select_site(foreign_site.docking_target.id), "The independent foreign berth must be selectable for this scope check")
	TEST_ASSERT(navigation.request_station_docking(foreign_site.docking_target.id), "The pilot must submit a genuine request for the foreign berth")
	var/datum/stationtrauma_station_docking_request/request = navigation.get_station_docking_request()
	TEST_ASSERT_NOTNULL(request, "The foreign request must exist in the same live sector")
	var/list/data = traffic.ui_data(operator)
	TEST_ASSERT_EQUAL(length(data["docks"]), 1, "The carrier console must list only its own berth")
	TEST_ASSERT_EQUAL(length(data["requests"]), 0, "The carrier console must hide requests addressed to foreign berths")
	TEST_ASSERT(!traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, site.id), "A forged console response must not approve a foreign berth")
	TEST_ASSERT_NULL(foreign_site.docking_owner, "A rejected foreign response must not reserve that berth")
	TEST_ASSERT(navigation.cancel_station_docking(), "The unrelated pilot request must remain independently cancellable")

	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(navigation.select_site(site.docking_target.id), "The pilot can select the detected carrier")
	TEST_ASSERT(navigation.request_station_docking(site.docking_target.id), "The carrier console must receive a request for its own target")
	request = navigation.get_station_docking_request()
	TEST_ASSERT(!traffic.respond_to_request(operator, ship.shuttle_id, request.token, TRUE, foreign_site.id), "The carrier dispatcher must not assign a foreign berth to its own request")
	TEST_ASSERT(!request.assigned_berth && !site.docking_owner && !foreign_site.docking_owner, "The rejected assignment must leave the request and both berths untouched")

/** A charged native drive transfers the carrier's moored tree and its destination to the next real sector registry. */
/datum/unit_test/overmap_carrier/sector_transfer
	/// Temporary destination registry, removed from the subsystem before fixture teardown.
	var/datum/stationtrauma_overmap_sector/space/destination_sector

/datum/unit_test/overmap_carrier/sector_transfer/Destroy()
	if(carrier_sector && SSstationtrauma_space_voyage.sectors[carrier_sector.id] == carrier_sector)
		SSstationtrauma_space_voyage.sectors -= carrier_sector.id
	if(destination_sector && SSstationtrauma_space_voyage.sectors[destination_sector.id] == destination_sector)
		SSstationtrauma_space_voyage.sectors -= destination_sector.id
	destination_sector = null
	return ..()

/datum/unit_test/overmap_carrier/sector_transfer/Run()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest(), "The transfer fixture must grant the first real docking request")
	var/datum/stationtrauma_station_docking_request/origin_request = navigation.get_station_docking_request()
	var/origin_token = origin_request.token
	var/datum/stationtrauma_overmap_site/space/docking_target/origin_target = site.docking_target
	TEST_ASSERT(navigation.dock(instant = TRUE), "The transfer fixture must start with a genuinely moored guest")
	var/deadline = world.time + 5 SECONDS
	UNTIL(!host_navigation.carrier_busy() || world.time >= deadline)
	TEST_ASSERT(!host_navigation.carrier_busy(), "A fully moored guest must leave its carrier ready to fly")
	destination_sector = allocate(/datum/stationtrauma_overmap_sector/space)
	destination_sector.id = "unit_test_carrier_destination"
	destination_sector.ready = TRUE
	destination_sector.entry_x = 870
	destination_sector.entry_y = 420
	SSstationtrauma_space_voyage.sectors[carrier_sector.id] = carrier_sector
	SSstationtrauma_space_voyage.sectors[destination_sector.id] = destination_sector
	carrier_sector.jump_routes = list(destination_sector.id)
	var/obj/machinery/stationtrauma_bluespace_drive/drive = allocate(/obj/machinery/stationtrauma_bluespace_drive, locate(host_ship.x, host_ship.y + 2, host_ship.z))
	drive.charges = 1
	drive.connect_to_shuttle(TRUE, host_ship)
	var/turf/physical_host = get_turf(host_ship)
	var/turf/physical_guest = get_turf(ship)
	var/turf/physical_slot = get_turf(bay)
	TEST_ASSERT(host_navigation.request_jump(destination_sector.id), "A carrier with a fully moored child and a charged native drive must begin its normal jump")
	// The four-minute timer is unchanged; invoke its real validated completion without delaying the regression suite.
	deltimer(host_navigation.jump_timer)
	TEST_ASSERT(host_navigation.finish_jump(destination_sector.id, host_navigation.control_revision), "The genuine jump completion must transfer the moored assembly")
	TEST_ASSERT_NULL(host_navigation.jump_target, "Completed transfer must cancel the owned jump state")
	TEST_ASSERT_EQUAL(host_navigation.sector, destination_sector, "The carrier must enter the destination's actual registry")
	TEST_ASSERT_EQUAL(navigation.sector, destination_sector, "The moored guest must enter the same destination registry")
	TEST_ASSERT_NULL(carrier_sector.ships[host_ship.shuttle_id], "The old sector must release the carrier")
	TEST_ASSERT_NULL(carrier_sector.ships[ship.shuttle_id], "The old sector must release the carried child")
	TEST_ASSERT_NULL(carrier_sector.sites[site.id], "The old chart must release the moving berth")
	TEST_ASSERT_EQUAL(destination_sector.sites[site.id], site, "The carried berth must retain its identity in the new sector")
	TEST_ASSERT_NULL(carrier_sector.sites[origin_target.id], "The old chart must release the carrier destination")
	TEST_ASSERT_EQUAL(destination_sector.sites[origin_target.id], origin_target, "The carrier destination must transfer with its berths")
	TEST_ASSERT_EQUAL(site.docking_target, origin_target, "The carried berth must remain attached to the same carrier destination")
	TEST_ASSERT_EQUAL(destination_sector.ships[ship.shuttle_id], navigation, "The child's independent registration must survive transfer")
	TEST_ASSERT_EQUAL(site.docking_owner, navigation, "A sector transfer must retain physical berth occupancy")
	TEST_ASSERT_EQUAL(get_turf(host_ship), physical_host, "A virtual sector jump must leave the host's physical hull in place")
	TEST_ASSERT_EQUAL(get_turf(ship), physical_guest, "A virtual sector jump must preserve the carried child's physical hull")
	TEST_ASSERT_EQUAL(get_turf(bay), physical_slot, "A virtual sector jump must preserve the native berth")
	TEST_ASSERT_EQUAL(navigation.pos_x, destination_sector.entry_x, "The carried child must inherit the arrival easting")
	TEST_ASSERT_EQUAL(navigation.pos_y, destination_sector.entry_y, "The carried child must inherit the arrival northing")
	TEST_ASSERT_EQUAL(drive.charges, 0, "One compound jump must spend one carrier drive charge")
	TEST_ASSERT_EQUAL(traffic.traffic_sector(), destination_sector, "The same physical traffic console must follow its carrier's new sector")
	TEST_ASSERT(navigation.depart(instant = TRUE), "The carried child must still be able to depart after the sector transfer")
	navigation.stop()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest(origin_token) && navigation.dock(instant = TRUE), "The child must be able to request and physically return in the new sector")

/** Remove a real carrier owner while preserving the guest's occupied native berth for either cleanup path. */
/datum/unit_test/overmap_carrier/proc/orphan_guest()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest() && navigation.dock(instant = TRUE), "The orphan fixture must start with a genuinely moored guest")
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = bay.active_berth
	var/datum/stationtrauma_dock_gangway/gangway = berth.gangways[1]
	var/deadline = world.time + 5 SECONDS
	UNTIL(!gangway.busy || world.time >= deadline)
	TEST_ASSERT(!gangway.busy, "The arrival interlock must finish before owner deletion")
	QDEL_NULL(host_navigation)
	TEST_ASSERT(site.failed && !site.host, "A deleted owner must withdraw and invalidate its published destination")
	TEST_ASSERT_EQUAL(navigation.docked, site, "Owner deletion must retain the guest's physical mooring state")
	TEST_ASSERT_EQUAL(bay.active_berth, berth, "Owner deletion must preserve the occupied technical berth")
	TEST_ASSERT(!gangway.breached, "Deleting navigation alone must not tear down a physically intact bridge")
	return berth

/** An invalidated orphan destination still permits its physically moored guest to depart safely. */
/datum/unit_test/overmap_carrier/owner_deleted_departure/Run()
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = orphan_guest()
	TEST_ASSERT_NOTNULL(berth, "The orphan departure needs its retained native berth")
	var/turf/host_position = get_turf(host_ship)
	TEST_ASSERT(navigation.depart(instant = TRUE), "A failed orphan destination must still allow independent native departure. Status: [navigation.status]")
	TEST_ASSERT_EQUAL(ship.get_docked(), navigation.flight_berth, "The orphaned guest must return to its own flight berth")
	TEST_ASSERT_EQUAL(get_turf(host_ship), host_position, "An orphan departure must leave the carrier hull untouched")
	TEST_ASSERT_NULL(bay.active_berth, "An orphan departure must release the technical berth")
	TEST_ASSERT(QDELETED(berth), "The unused orphan arrival marker must be deleted")

/** Deleting the remaining guest navigator releases an orphan technical berth and both endpoint links. */
/datum/unit_test/overmap_carrier/owner_deleted_guest_cleanup/Run()
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = orphan_guest()
	TEST_ASSERT_NOTNULL(berth, "The orphan cleanup needs its retained native berth")
	var/datum/stationtrauma_dock_gangway/gangway = berth.gangways[1]
	var/obj/machinery/door/airlock/stationtrauma_docking/wall/wall = gangway.wall
	var/turf/bridge = gangway.floors[1]
	QDEL_NULL(navigation)
	TEST_ASSERT_NULL(bay.active_berth, "Deleting the orphan guest navigator must release its technical berth")
	TEST_ASSERT(QDELETED(berth) && QDELETED(gangway), "Orphan cleanup must delete the owned berth and passage datums")
	TEST_ASSERT_NULL(hatch.gangway, "Orphan cleanup must unlink the surviving ship endpoint")
	TEST_ASSERT_NULL(wall.gangway, "Orphan cleanup must unlink the surviving wall endpoint")
	TEST_ASSERT(isspaceturf(bridge), "Orphan cleanup must restore the temporary bridge to vacuum")

/** An outer berth's reserved passage must not intersect a child's real projected hull in the carrier assembly. */
/datum/unit_test/overmap_carrier/blocked_receiving_route
	/// Real compound movement admission, explicitly finished even if an assertion fails.
	var/datum/stationtrauma_carrier_movement/compound
	/// Receiving slot supplies the actual destination bounds for the compound validator.
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/receiving_slot
	/// Receiving native anchor owns the route supplied to the production validator.
	var/obj/docking_port/stationary/stationtrauma_space_site/standard/receiving_berth

/datum/unit_test/overmap_carrier/blocked_receiving_route/Destroy()
	QDEL_NULL(compound)
	if(receiving_berth)
		qdel(receiving_berth, force = TRUE)
		receiving_berth = null
	if(receiving_slot)
		qdel(receiving_slot, force = TRUE)
		receiving_slot = null
	return ..()

/datum/unit_test/overmap_carrier/blocked_receiving_route/Run()
	navigation.observe_ships(navigation.sensor_range)
	TEST_ASSERT(approve_guest() && navigation.dock(instant = TRUE), "The receiving-route fixture must start with a genuinely moored guest")
	var/datum/stationtrauma_dock_gangway/gangway = hatch.gangway
	var/deadline = world.time + 5 SECONDS
	UNTIL(!gangway.busy || world.time >= deadline)
	TEST_ASSERT(!gangway.busy, "The guest's actual passage must finish its arrival before compound admission")
	var/obj/docking_port/stationary/target = position_carrier_target()
	receiving_slot = allocate(/obj/docking_port/stationary/stationtrauma_space_station/standard_m, locate(1, 1, target.z))
	receiving_berth = allocate(/obj/docking_port/stationary/stationtrauma_space_site/standard, get_turf(target))
	receiving_berth.setDir(target.dir)
	receiving_berth.slot = receiving_slot
	var/datum/stationtrauma_dock_route/route = new
	receiving_berth.routes += route
	compound = new(host_navigation, receiving_berth)
	TEST_ASSERT(compound.lock_members(), "The production movement context must lock the real carrier and moored child")
	route.path = list(compound.project(get_turf(hatch)))
	TEST_ASSERT(!compound.build(), "An outer reserved passage crossing the carried child's projected hatch must reject the compound approach")
	TEST_ASSERT_EQUAL(compound.owners[get_turf(hatch)], navigation, "The intersected cell must belong to the real child rather than the carrier's own hull")
	route.path = list(locate(3, 3, target.z))
	TEST_ASSERT(compound.validate(), "The identical assembly and receiving bounds must be admitted when only the route intersection is removed")
	compound.finish()

/datum/stationtrauma_overmap/space
	/// Physical movement shared by a carrier and every moored descendant.
	var/datum/stationtrauma_carrier_movement/carrier_relocation

/** A locked participant retains independent hull ownership throughout the compound move. */
/datum/stationtrauma_carrier_member
	/// Physical anchor captured before enumeration can yield.
	var/turf/origin
	/// Native orientation at the start of the attempt.
	var/direction
	/// Travel direction rotated independently from the native anchor.
	var/preferred_direction
	/// The caller may already be preparing a normal arrival or departure.
	var/was_preparing
	/// Substrate entries before the carrier temporarily supplies a combined map.
	var/list/underlying
	/// Logical mooring must remain unchanged through preflight.
	var/datum/stationtrauma_overmap_site/space/docked
	/// Helm changes invalidate a prepared movement.
	var/revision
	/// Hosted markers present when the participant was locked.
	var/list/docks
	/// Owned areas remain separate from every other participant.
	var/list/areas
	/// Width, height and anchor offsets used for the original enumeration.
	var/list/dimensions

/datum/stationtrauma_carrier_member/Destroy()
	origin = null
	underlying = null
	docked = null
	docks = null
	areas = null
	dimensions = null
	return ..()

/** One native preflight and takeoff for a connected carrier assembly. */
/datum/stationtrauma_carrier_movement
	/// Only this participant invokes the native movement pipeline.
	var/datum/stationtrauma_overmap/space/root
	/// Destination admitted by the root's ordinary native and overmap checks.
	var/obj/docking_port/stationary/target
	/// Existing arrival clearance or departure interlock commit.
	var/datum/callback/before_takeoff
	/// Frozen source anchor used after the root itself has moved.
	var/turf/origin
	/// Frozen destination anchor, revalidated before commit.
	var/turf/target_origin
	/// Root native orientation before movement.
	var/direction
	/// Root native orientation at the destination.
	var/target_direction
	/// The same angle that native movement applies to hull contents.
	var/rotation
	/// Navigation keys associated with independent ownership snapshots.
	var/list/members = list()
	/// Unique physical cells paired with destination by native index order.
	var/list/source = list()
	/// One transformed cell for each source cell.
	var/list/destination = list()
	/// Hull navigation owning each source cell, excluding freestanding bridges.
	var/list/owners = list()
	/// Area identity captured for every source cell.
	var/list/original_areas = list()
	/// Local admission set supplied to area callbacks, never assigned to a hull.
	var/list/movement_areas = list()
	/// Physical anchors that need explicit transport even when standing in vacuum.
	var/list/port_positions = list()
	/// Ports suppress native rotation and receive this saved orientation explicitly.
	var/list/port_directions = list()
	/// Reserved routes retain their datum while their turf references change.
	var/list/route_paths = list()
	/// Existing passages whose floors, gas, seals and occupants travel intact.
	var/list/gangways = list()
	/// Baseturf stacks restored if preflight rejects the attempt.
	var/list/bridge_baseturfs = list()
	/// Only these bridges received a temporary native transport layer.
	var/list/added_skipovers = list()
	/// Latejoin markers must follow both carrier and guest areas.
	var/list/crew_spawns = list()
	/// Native takeoff has transferred the physical cells.
	var/committed = FALSE
	/// Compound ordering is exposed only after construction has produced the complete lists.
	var/native_enumeration = FALSE
	/// Expected movement signals are held until native cleanup completes.
	var/suspended = FALSE
	/// Cleanup is shared by normal completion, exceptions and deletion.
	var/finished = FALSE

/datum/stationtrauma_carrier_movement/New(datum/stationtrauma_overmap/space/carrier, obj/docking_port/stationary/new_target, datum/callback/commit_callback)
	root = carrier
	target = new_target
	before_takeoff = commit_callback
	origin = get_turf(carrier.vessel)
	target_origin = get_turf(target)
	direction = carrier.vessel.dir
	target_direction = target.dir
	rotation = dir2angle(target.dir) - dir2angle(direction)

/** Use the root's native cardinal transform for every hull, port and passage cell. */
/datum/stationtrauma_carrier_movement/proc/project(turf/tile)
	if(!tile || tile.z != origin.z)
		return null
	var/list/current = stationtrauma_port_rotation(direction)
	var/list/rotated = stationtrauma_port_rotation(target_direction)
	var/relative_x = tile.x - origin.x
	var/relative_y = tile.y - origin.y
	var/local_x = relative_x * current[1] + relative_y * current[2]
	var/local_y = relative_y * current[1] - relative_x * current[2]
	return locate(target_origin.x + local_x * rotated[1] - local_y * rotated[2], target_origin.y + local_x * rotated[2] + local_y * rotated[1], target_origin.z)

/** Freeze participants before any native preflight or enumeration can yield. */
/datum/stationtrauma_carrier_movement/proc/lock_members()
	if(root.carrier_busy())
		return FALSE
	var/list/tree = root.carrier_tree()
	for(var/datum/stationtrauma_overmap/space/navigation as anything in tree)
		if(QDELETED(navigation.vessel) || navigation.vessel.orbital_only || length(navigation.vessel.owned_z_levels) > 1 \
			|| navigation.relocating || navigation.carrier_relocation || (navigation != root && navigation.carrier_busy()))
			return FALSE
	for(var/datum/stationtrauma_overmap/space/navigation as anything in tree)
		navigation.vessel.initialize_docking_layers()
		var/datum/stationtrauma_carrier_member/member = new
		member.origin = get_turf(navigation.vessel)
		member.direction = navigation.vessel.dir
		member.preferred_direction = navigation.vessel.preferred_direction
		member.was_preparing = navigation.preparing
		member.underlying = navigation.vessel.underlying_areas_by_turf.Copy()
		member.docked = navigation.docked
		member.revision = navigation.control_revision
		member.docks = navigation.carrier_docks.Copy()
		member.areas = navigation.vessel.shuttle_areas.Copy()
		member.dimensions = list(navigation.vessel.width, navigation.vessel.height, navigation.vessel.dwidth, navigation.vessel.dheight)
		members[navigation] = member
		navigation.preparing = TRUE
		navigation.relocating = TRUE
		navigation.carrier_relocation = src
	return length(members) > 0

/datum/stationtrauma_carrier_movement/proc/add_tile(turf/tile, datum/stationtrauma_overmap/space/owner)
	if(original_areas[tile])
		return !owner || !owners[tile] || owners[tile] == owner
	var/turf/projected = project(tile)
	if(!projected)
		return FALSE
	source += tile
	destination += projected
	original_areas[tile] = get_area(tile)
	if(owner)
		owners[tile] = owner
	if(tile in SSjob.latejoin_trackers)
		crew_spawns[tile] = projected
	return TRUE

/datum/stationtrauma_carrier_movement/proc/add_port(obj/docking_port/port)
	if(QDELETED(port) || !project(get_turf(port)))
		return FALSE
	port_positions[port] = get_turf(port)
	port_directions[port] = port.dir
	return TRUE

/** Include actual owned hull cells and bridges, never unrelated contents of empty slot space. */
/datum/stationtrauma_carrier_movement/proc/build()
	if(!(direction in GLOB.cardinals) || !(target_direction in GLOB.cardinals))
		return FALSE
	for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
		var/obj/docking_port/mobile/stationtrauma_space/ship = navigation.vessel
		for(var/area/hull_area as anything in ship.shuttle_areas)
			movement_areas[hull_area] = TRUE
		for(var/turf/tile as anything in ship.return_ordered_turfs(ship.x, ship.y, ship.z, ship.dir))
			CHECK_TICK
			if(ship.shuttle_areas[get_area(tile)] && !add_tile(tile, navigation))
				return FALSE
		if(!add_port(ship))
			return FALSE
		for(var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot in navigation.carrier_docks)
			if(slot.host != navigation || !add_port(slot))
				return FALSE
			var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = slot.active_berth
			if(!berth)
				continue
			if(!add_port(berth) || !(berth.ship.overmap in members))
				return FALSE
			for(var/datum/stationtrauma_dock_route/route as anything in berth.routes)
				var/list/path = list()
				for(var/turf/tile as anything in route.path)
					var/turf/projected = project(tile)
					if(!projected)
						return FALSE
					path += projected
				route_paths[route] = path
			for(var/datum/stationtrauma_dock_gangway/gangway as anything in berth.gangways)
				if(QDELETED(gangway) || gangway.busy || gangway.breached)
					return FALSE
				gangways |= gangway
				for(var/turf/tile as anything in gangway.floors)
					if(!add_tile(tile))
						return FALSE
					bridge_baseturfs[tile] = islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs
	return validate()

/** Reject changes during preflight and native self-overlap before modifying any physical cell. */
/datum/stationtrauma_carrier_movement/proc/validate()
	if(QDELETED(root) || QDELETED(root.vessel) || QDELETED(target) || get_turf(target) != target_origin || target.dir != target_direction)
		return FALSE
	var/list/current_tree = root.carrier_tree()
	if(length(current_tree) != length(members))
		return FALSE
	var/list/receiving_bounds
	var/list/receiving_paths = list()
	if(istype(target, /obj/docking_port/stationary/stationtrauma_space_site/standard))
		var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = target
		if(QDELETED(berth.slot))
			return FALSE
		receiving_bounds = berth.slot.return_coords()
		for(var/datum/stationtrauma_dock_route/route as anything in berth.routes)
			for(var/turf/tile as anything in route.path)
				receiving_paths[tile] = TRUE
	for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
		var/datum/stationtrauma_carrier_member/member = members[navigation]
		if(QDELETED(navigation) || QDELETED(navigation.vessel) || !(navigation in current_tree) || navigation.carrier_relocation != src \
			|| get_turf(navigation.vessel) != member.origin || navigation.vessel.dir != member.direction || navigation.docked != member.docked || navigation.control_revision != member.revision)
			return FALSE
		if(length(navigation.carrier_docks) != length(member.docks))
			return FALSE
		var/obj/docking_port/mobile/stationtrauma_space/ship = navigation.vessel
		if(ship.orbital_only || length(ship.owned_z_levels) > 1 || ship.width != member.dimensions[1] || ship.height != member.dimensions[2] \
			|| ship.dwidth != member.dimensions[3] || ship.dheight != member.dimensions[4] || length(ship.shuttle_areas) != length(member.areas))
			return FALSE
		for(var/area/hull_area as anything in member.areas)
			if(!ship.shuttle_areas[hull_area])
				return FALSE
		for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in member.docks)
			if(QDELETED(slot) || !(slot in navigation.carrier_docks) || slot.host != navigation)
				return FALSE
			var/datum/stationtrauma_overmap/space/claimant = slot.carrier_site?.docking_owner
			if(claimant && claimant.docked != slot.carrier_site)
				return FALSE
	for(var/obj/docking_port/port as anything in port_positions)
		if(QDELETED(port) || get_turf(port) != port_positions[port] || port.dir != port_directions[port] || !clear_destination(project(get_turf(port))))
			return FALSE
	for(var/turf/tile as anything in source)
		if(get_area(tile) != original_areas[tile])
			return FALSE
		var/physical_source = !!bridge_baseturfs[tile]
		if(!physical_source)
			for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
				if(navigation.vessel.has_docking_layer(tile))
					physical_source = TRUE
					break
		if(!physical_source)
			continue
		var/turf/projected = project(tile)
		if(!clear_destination(projected) || receiving_paths[projected])
			return FALSE
		if(receiving_bounds && (projected.x < min(receiving_bounds[1], receiving_bounds[3]) || projected.x > max(receiving_bounds[1], receiving_bounds[3]) \
			|| projected.y < min(receiving_bounds[2], receiving_bounds[4]) || projected.y > max(receiving_bounds[2], receiving_bounds[4])))
			return FALSE
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		if(QDELETED(gangway) || gangway.busy || gangway.breached)
			return FALSE
	return TRUE

/datum/stationtrauma_carrier_movement/proc/clear_destination(turf/tile)
	if(!tile || !isopenturf(tile) || tile.density || original_areas[tile])
		return FALSE
	if(istype(target, /obj/docking_port/stationary/stationtrauma_space_site/standard))
		var/obj/docking_port/stationary/stationtrauma_space_site/standard/berth = target
		return (!berth.slot?.hangar || isfloorturf(tile)) && stationtrauma_standard_dock_clear_space(tile, berth.slot?.host)
	if(SSshuttle.get_containing_shuttle(tile))
		return FALSE
	for(var/atom/movable/occupant as anything in tile)
		if(isliving(occupant) || (isobj(occupant) && !iseffect(occupant) && !istype(occupant, /obj/docking_port)))
			return FALSE
	return TRUE

/** Native transfer needs the outer substrate beneath every transported participant. */
/datum/stationtrauma_carrier_movement/proc/prepare_underlying()
	native_enumeration = TRUE
	var/datum/stationtrauma_carrier_member/root_member = members[root]
	var/list/combined = list()
	for(var/turf/tile as anything in source)
		if(root_member.underlying[tile])
			combined[tile] = root_member.underlying[tile]
	for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
		var/datum/stationtrauma_carrier_member/member = members[navigation]
		for(var/turf/tile as anything in member.underlying)
			if(!original_areas[tile])
				continue
			var/area/below = member.underlying[tile]
			if(!combined[tile] && !movement_areas[below])
				combined[tile] = below
	root.vessel.underlying_areas_by_turf = combined
	for(var/turf/tile as anything in bridge_baseturfs)
		if(!istype(tile, /turf/open/floor/plating/stationtrauma_dock_gangway))
			continue
		var/owned_layer = FALSE
		for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
			if(navigation.vessel.has_docking_layer(tile))
				owned_layer = TRUE
				break
		if(!owned_layer)
			var/index = islist(tile.baseturfs) ? length(tile.baseturfs) + 1 : 2
			tile.insert_baseturf(index, /turf/baseturf_skipover/shuttle)
			added_skipovers[tile] = index

/** The final callback cannot yield between validation and takeoff. */
/datum/stationtrauma_carrier_movement/proc/commit()
	if(!validate() || (before_takeoff && !before_takeoff.Invoke()))
		return FALSE
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		gangway.begin_carrier_move()
	suspended = TRUE
	return TRUE

/** Synchronize all physical anchors before native cleanup can yield. */
/datum/stationtrauma_carrier_movement/proc/after_takeoff()
	committed = TRUE
	for(var/obj/docking_port/port as anything in port_positions)
		port.abstract_move(project(port_positions[port]))
		port.setDir(angle2dir(dir2angle(port_directions[port]) + rotation))
	for(var/datum/stationtrauma_dock_route/route as anything in route_paths)
		route.path = route_paths[route]
	for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
		var/list/moved_floors = list()
		for(var/turf/old_floor as anything in gangway.floors)
			var/turf/open/floor/new_floor = project(old_floor)
			if(istype(new_floor, /turf/open/floor/plating/stationtrauma_dock_gangway))
				var/turf/open/floor/plating/stationtrauma_dock_gangway/temporary = new_floor
				temporary.gangway = gangway
			moved_floors += new_floor
		gangway.floors = moved_floors
	var/list/combined = root.vessel.underlying_areas_by_turf
	for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
		var/datum/stationtrauma_carrier_member/member = members[navigation]
		if(navigation != root)
			var/list/moved_underlying = list()
			for(var/turf/tile as anything in member.underlying)
				if(!original_areas[tile])
					continue
				var/area/below = member.underlying[tile]
				var/turf/new_tile = project(tile)
				moved_underlying[new_tile] = movement_areas[below] ? below : combined[new_tile]
			navigation.vessel.underlying_areas_by_turf = moved_underlying
		navigation.vessel.preferred_direction = angle2dir(dir2angle(member.preferred_direction) + rotation)
	for(var/turf/tile as anything in crew_spawns)
		SSjob.latejoin_trackers -= tile
		SSjob.latejoin_trackers |= crew_spawns[tile]

/** Remove temporary baseturf markers and restore watchers before releasing any navigation lock. */
/datum/stationtrauma_carrier_movement/proc/finish()
	if(finished)
		return
	finished = TRUE
	native_enumeration = FALSE
	for(var/turf/tile as anything in bridge_baseturfs)
		if(!committed)
			tile.baseturfs = bridge_baseturfs[tile]
	if(suspended)
		for(var/datum/stationtrauma_dock_gangway/gangway as anything in gangways)
			if(!QDELETED(gangway))
				gangway.finish_carrier_move()
	for(var/datum/stationtrauma_overmap/space/navigation as anything in members)
		var/datum/stationtrauma_carrier_member/member = members[navigation]
		if(QDELETED(navigation))
			continue
		if(!committed && !QDELETED(navigation.vessel))
			navigation.vessel.underlying_areas_by_turf = member.underlying
		navigation.carrier_relocation = null
		navigation.relocating = FALSE
		navigation.preparing = member.was_preparing
		if(committed)
			navigation.update_parallax()

/datum/stationtrauma_carrier_movement/Destroy()
	finish()
	QDEL_LIST_ASSOC_VAL(members)
	root = null
	target = null
	before_takeoff = null
	origin = null
	target_origin = null
	source = null
	destination = null
	owners = null
	original_areas = null
	movement_areas = null
	port_positions = null
	port_directions = null
	route_paths = null
	gangways = null
	bridge_baseturfs = null
	added_skipovers = null
	crew_spawns = null
	return ..()

/** Compound enumeration is scoped to the root's current native operation. */
/obj/docking_port/mobile/stationtrauma_space/return_ordered_turfs(_x, _y, _z, _dir)
	var/datum/stationtrauma_carrier_movement/movement = overmap?.carrier_relocation
	if(movement?.root.vessel == src && movement.native_enumeration)
		if(_x == movement.origin.x && _y == movement.origin.y && _z == movement.origin.z && _dir == movement.direction)
			return movement.source.Copy()
		if(_x == movement.target.x && _y == movement.target.y && _z == movement.target.z && _dir == movement.target.dir)
			return movement.destination.Copy()
	return ..()

/obj/docking_port/mobile/stationtrauma_space/preflight_check(list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, rotation)
	var/datum/stationtrauma_docking_layers/layers = overmap?.docking_relocation
	if(layers)
		return layers.preflight(old_turfs, new_turfs, areas_to_move, underlying_areas, rotation)
	return ..()

/obj/docking_port/mobile/stationtrauma_space/takeoff(list/old_turfs, list/new_turfs, list/moved_atoms, rotation, movement_direction, obj/docking_port/stationary/old_dock, area/fallback_area, list/shuttle_depths)
	var/datum/stationtrauma_docking_layers/layers = overmap?.docking_relocation
	layers?.capture()
	. = ..()
	layers?.after_copy()
	var/datum/stationtrauma_carrier_movement/movement = overmap?.carrier_relocation
	if(movement?.root.vessel == src)
		movement.after_takeoff()

/** Retain one native move, independent ownership and the existing movement callback contract. */
/datum/stationtrauma_overmap/space/proc/relocate_carrier(obj/docking_port/stationary/target, datum/callback/before_takeoff)
	if(relocating || QDELETED(vessel) || vessel.orbital_only || QDELETED(target) || (ship_docking && target != flight_berth && target != ship_docking.anchor))
		return FALSE
	if(vessel.get_docked() == target)
		return TRUE
	var/datum/stationtrauma_carrier_movement/movement = new(src, target, before_takeoff)
	var/success = FALSE
	var/exception/movement_failure
	try
		if(movement.lock_members() && movement.build())
			movement.prepare_underlying()
			var/result = vessel.initiate_docking(target, before_takeoff = CALLBACK(movement, TYPE_PROC_REF(/datum/stationtrauma_carrier_movement, commit)))
			success = result == DOCKING_SUCCESS && vessel.get_docked() == target
	catch(var/exception/failure)
		movement_failure = failure
	movement.finish()
	qdel(movement)
	if(movement_failure)
		throw movement_failure
	if(!success)
		status = "Манёвр носителя отменён: состав изменился, площадка перекрыта или пересекает исходную позицию"
	return success

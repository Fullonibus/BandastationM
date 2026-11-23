/** Own passages across a full-width, multi-deck seam; each gate shows the far side with the native border mirage. */
/datum/stationtrauma_map_connection
	/// Vessel supplying the physical footprint.
	var/obj/docking_port/mobile/vessel
	/// Number of contiguous physical decks connected together.
	var/decks
	/// Vessel-facing side of the seam.
	var/direction = NORTH
	/// One publication flag controls every prepared passage.
	var/active = FALSE
	/// Geometry invalidation interrupts paused preparation.
	var/revision = 0
	/// Geometry revision captured before building the inactive connection.
	var/prepared_revision = 0
	/// Owned gates; real actors never belong to this list.
	var/list/passages = list()
	/// Environment adapters specialize eligibility.
	var/passage_type = /datum/component/stationtrauma_map_passage
	/// Destination level of the first deck, recorded while preparing.
	var/site_level
	/// Level, side and receiving level of every border led round the open seam, so closing clears exactly those.
	var/list/linked_edges

/// Every live connection, for resolving what a viewer sees through an open seam.
GLOBAL_LIST_EMPTY(stationtrauma_map_connections)

/datum/stationtrauma_map_connection/New(obj/docking_port/mobile/owner, deck_count = 1, facing = NORTH)
	if(!istype(owner) || !ISINTEGER(deck_count) || deck_count < 1 || !(facing in GLOB.cardinals))
		CRASH("A map connection requires a native vessel and a positive integer deck count")
	vessel = owner
	decks = deck_count
	direction = facing
	RegisterSignal(vessel, COMSIG_QDELETING, PROC_REF(owner_deleted))
	GLOB.stationtrauma_map_connections += src

/datum/stationtrauma_map_connection/Destroy()
	GLOB.stationtrauma_map_connections -= src
	disconnect()
	UnregisterSignal(vessel, COMSIG_QDELETING)
	vessel = null
	return ..()

/** Release the connection when its physical hull is deleted. */
/datum/stationtrauma_map_connection/proc/owner_deleted()
	SIGNAL_HANDLER
	qdel(src)

/** Remove a deleted gate and invalidate pending preparation. */
/datum/stationtrauma_map_connection/proc/member_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	if(source in passages)
		revision++
	passages -= source

/** A physical map cannot be connected until its atom initialization has finished. */
/datum/stationtrauma_map_connection/proc/is_loading()
	return SSatoms.initialized == INITIALIZATION_INNEW_MAPLOAD

/** Delete owned passages. */
/datum/stationtrauma_map_connection/proc/disconnect()
	active = FALSE
	revision++
	unlink_edges()
	var/list/old_passages = passages
	passages = list()
	QDEL_LIST(old_passages)

/** Close every gate immediately, then spread subscription destruction over server ticks. */
/datum/stationtrauma_map_connection/proc/disconnect_cooperatively(datum/stationtrauma_work_budget/budget)
	active = FALSE
	revision++
	unlink_edges()
	var/list/old_passages = passages
	passages = list()
	for(var/datum/component/stationtrauma_map_passage/passage as anything in old_passages)
		budget.yield()
		if(!QDELETED(passage))
			qdel(passage)

/** Validate topology only; each transfer rechecks occupied landings and native projectile cover. */
/datum/stationtrauma_map_connection/proc/gate_available(turf/open/tile, allow_owned = FALSE)
	if(!isspaceturf(tile) || tile.destination_z)
		return FALSE
	var/datum/component/stationtrauma_map_passage/passage = tile.GetComponent(/datum/component/stationtrauma_map_passage)
	if(passage && (!allow_owned || passage.connection != src))
		return FALSE
	return TRUE

/** Prepare inactive gates cooperatively; publish only a complete corridor. */
/datum/stationtrauma_map_connection/proc/connect(obj/docking_port/stationary/berth, datum/stationtrauma_work_budget/budget, activate = TRUE, ship_clearance = 0, site_clearance = 0)
	if(QDELETED(vessel) || !berth || berth.z == vessel.z || is_loading() || passages.len)
		return FALSE
	budget ||= new
	prepared_revision = revision
	var/ready = FALSE
	try
		ready = prepare(berth, budget, ship_clearance, site_clearance)
		if(ready && activate)
			ready = activate(budget)
	catch(var/exception/failure)
		disconnect_cooperatively(budget)
		throw failure
	if(!ready)
		disconnect_cooperatively(budget)
	return ready

/** Return the hull's seam coordinate, or null when its gate and landing cannot fit inside the transition border. */
/datum/stationtrauma_map_connection/proc/get_ship_edge(list/bounds, clearance, facing)
	var/horizontal = !!(facing & (EAST|WEST))
	var/positive = facing == NORTH || facing == EAST
	var/low = horizontal ? min(bounds[1], bounds[3]) : min(bounds[2], bounds[4])
	var/high = horizontal ? max(bounds[1], bounds[3]) : max(bounds[2], bounds[4])
	var/edge = positive ? high + 1 + clearance : low - 1 - clearance
	var/axis_limit = horizontal ? world.maxx : world.maxy
	if(edge <= TRANSITIONEDGE + 1 || edge >= axis_limit - TRANSITIONEDGE)
		return null
	return edge

/** Build inactive passages cooperatively. */
/datum/stationtrauma_map_connection/proc/prepare(obj/docking_port/stationary/berth, datum/stationtrauma_work_budget/budget, ship_clearance, site_clearance)
	var/clearance = max(30, maxviewdist())
	ship_clearance ||= clearance
	site_clearance ||= clearance
	if(!ISINTEGER(ship_clearance) || ship_clearance < 1 || !ISINTEGER(site_clearance) || site_clearance < 1)
		return FALSE
	var/list/bounds = vessel.return_coords()
	var/ship_edge = get_ship_edge(bounds, ship_clearance, direction)
	if(isnull(ship_edge))
		return FALSE
	var/horizontal = !!(direction & (EAST|WEST))
	var/positive = direction == NORTH || direction == EAST
	var/site_edge = (horizontal ? berth.x : berth.y) + (positive ? -site_clearance : site_clearance)
	var/axis_limit = horizontal ? world.maxx : world.maxy
	var/extent = horizontal ? world.maxy : world.maxx
	if(site_edge <= TRANSITIONEDGE + 1 || site_edge >= axis_limit - TRANSITIONEDGE)
		return FALSE
	site_level = berth.z
	for(var/deck in 0 to decks - 1)
		for(var/column in 1 to extent)
			// The border bands at both ends of the seam lead round the map instead.
			if(column <= TRANSITIONEDGE + 1 || column >= extent - TRANSITIONEDGE)
				continue
			budget.yield()
			if(QDELETED(src) || QDELETED(vessel) || QDELETED(berth) || prepared_revision != revision)
				return FALSE
			var/turf/open/ship_gate = locate(horizontal ? ship_edge : column, horizontal ? column : ship_edge, vessel.z + deck)
			var/turf/open/site_gate = locate(horizontal ? site_edge : column, horizontal ? column : site_edge, berth.z + deck)
			var/turf/open/ship_landing = get_step(ship_gate, REVERSE_DIR(direction))
			var/turf/open/site_landing = get_step(site_gate, direction)
			for(var/turf/open/tile as anything in list(ship_gate, site_gate, ship_landing, site_landing))
				if(!gate_available(tile))
					return FALSE
			for(var/datum/component/stationtrauma_map_passage/passage as anything in list(ship_gate.AddComponent(passage_type, site_landing, direction, src), site_gate.AddComponent(passage_type, ship_landing, REVERSE_DIR(direction), src)))
				passages += passage
				RegisterSignal(passage, COMSIG_QDELETING, PROC_REF(member_deleted))
	return TRUE

/** Recheck live gates, then open both directions in one non-yielding publication. */
/datum/stationtrauma_map_connection/proc/activate(datum/stationtrauma_work_budget/budget, datum/callback/arrival_check)
	if(QDELETED(src) || QDELETED(vessel) || !passages.len || prepared_revision != revision)
		return FALSE
	for(var/datum/component/stationtrauma_map_passage/passage as anything in passages)
		budget?.yield()
		if(QDELETED(src) || QDELETED(vessel) || QDELETED(passage) || !gate_available(passage.parent, TRUE) || !gate_available(passage.landing, TRUE))
			return FALSE
	if(prepared_revision != revision)
		return FALSE
	if(arrival_check && !arrival_check.Invoke())
		return FALSE
	active = TRUE
	for(var/datum/component/stationtrauma_map_passage/passage as anything in passages)
		passage.show_mirage()
	INVOKE_ASYNC(src, PROC_REF(link_edges), revision)
	return TRUE

/**
 * Leave no border round the open seam: the sides along it loop on their own level, and flying off the far side
 * of the destination arrives at the far side of the hull, and back. The far sides beyond the seam stay plain; nobody reaches them.
 */
/datum/stationtrauma_map_connection/proc/link_edges(expected)
	var/datum/stationtrauma_work_budget/budget = new
	var/list/plan = list()
	for(var/deck in 0 to decks - 1)
		var/ship_z = vessel.z + deck
		var/site_z = site_level + deck
		for(var/side in list(turn(direction, 90), turn(direction, -90)))
			plan += list(list(ship_z, side, ship_z), list(site_z, side, site_z))
		plan += list(list(site_z, direction, ship_z), list(ship_z, REVERSE_DIR(direction), site_z))
	linked_edges = list()
	for(var/list/edge as anything in plan)
		// A border already leading somewhere (native cross-linked space, a looping open-space level) is not ours to change.
		var/turf/open/probe = get_edge_target_turf(locate(round(world.maxx / 2), round(world.maxy / 2), edge[1]), edge[2])
		if(istype(probe) && probe.destination_z)
			continue
		budget.yield()
		if(revision != expected)
			return
		linked_edges += list(edge)
		stationtrauma_set_edge(edge[1], edge[2], edge[3])

/** Restore the plain borders of every edge this seam led round. */
/datum/stationtrauma_map_connection/proc/unlink_edges()
	var/list/edges = linked_edges
	linked_edges = null
	// shortcut: synchronous so a quick re-dock cannot race the clearing; spread it over ticks if undocking ever shows in profiles.
	for(var/list/edge as anything in edges)
		stationtrauma_set_edge(edge[1], edge[2], null)

/**
 * Point the border band of one side of a level at the opposite side of `target_z`, with the native border mirage, as cross-linked space does.
 *
 * Arguments:
 * * z - Level whose border changes
 * * side - Cardinal side of that level
 * * target_z - Receiving level, or null for a plain border
 * * mirage - Whether the border shows the receiving side
 */
/proc/stationtrauma_set_edge(z, side, target_z, mirage = TRUE)
	var/inner_max_x = world.maxx - TRANSITIONEDGE
	var/inner_max_y = world.maxy - TRANSITIONEDGE
	var/list/band
	var/arrival_x = 0
	var/arrival_y = 0
	switch(side)
		if(NORTH)
			band = block(1, inner_max_y, z, world.maxx, world.maxy, z)
			arrival_y = TRANSITIONEDGE + 2
		if(SOUTH)
			band = block(1, 1, z, world.maxx, 1 + TRANSITIONEDGE, z)
			arrival_y = inner_max_y - 1
		if(EAST)
			band = block(inner_max_x, 1 + TRANSITIONEDGE, z, world.maxx, inner_max_y, z)
			arrival_x = TRANSITIONEDGE + 2
		if(WEST)
			band = block(1, 1 + TRANSITIONEDGE, z, 1 + TRANSITIONEDGE, inner_max_y, z)
			arrival_x = inner_max_x - 1
	var/range = (maxviewdist() - 1) / 2
	for(var/turf/open/tile in band)
		// The mirage sits on the innermost row of the band, facing out.
		var/innermost = side == NORTH ? tile.y == inner_max_y : side == SOUTH ? tile.y == 1 + TRANSITIONEDGE : side == EAST ? tile.x == inner_max_x : tile.x == 1 + TRANSITIONEDGE
		if(innermost && tile.destination_z)
			tile.RemoveElement(/datum/element/mirage_border)
		tile.destination_x = target_z ? (arrival_x || tile.x) : null
		tile.destination_y = target_z ? (arrival_y || tile.y) : null
		tile.destination_z = target_z
		if(innermost && target_z && mirage)
			tile.AddElement(/datum/element/mirage_border, locate(tile.destination_x, tile.destination_y, target_z), side, range)

/**
 * The turf on the viewer's level where `target`, seen through an open seam, appears; null when it is not seen through one.
 *
 * The mirage shows real far-side atoms, so a click hands over their own coordinates; whatever aims at coordinates needs this image instead.
 */
/proc/stationtrauma_seam_image_turf(atom/viewer, atom/target)
	var/turf/here = get_turf(viewer)
	var/turf/there = get_turf(target)
	if(!here || !there || here.z == there.z)
		return null
	for(var/datum/stationtrauma_map_connection/connection as anything in GLOB.stationtrauma_map_connections)
		if(!connection.active)
			continue
		for(var/datum/component/stationtrauma_map_passage/passage as anything in connection.passages)
			var/turf/gate = passage.parent
			// Every gate of one seam side shares the same offset, so the first gate from this level to that one decides.
			if(gate.z == here.z && passage.landing.z == there.z)
				return locate(there.x + gate.x - passage.landing.x, there.y + gate.y - passage.landing.y, here.z)
	return null

/obj/projectile/aim_projectile(atom/target, atom/source, list/modifiers = null, deviation = 0)
	var/turf/image = stationtrauma_seam_image_turf(source, target)
	if(!image)
		return ..()
	// Aim along the image the shooter sees, then keep the real far-side target for the direct hit.
	. = ..(image, source, modifiers, deviation)
	if(.)
		original = target

/atom/base_ranged_item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	// Guns keep the real target; their shot aims at the image itself. Other tools aim at coordinates, which only the image turf gives.
	if(!isgun(tool))
		var/turf/image = stationtrauma_seam_image_turf(user, src)
		if(image)
			return image.base_ranged_item_interaction(user, tool, modifiers)
	return ..()

/// Turfs carry VIS_INHERIT_ID, so a click on any far tile in the mirage lands on this invisible holder at the seam. Hand it to the tile under the cursor on the viewer's own level instead.
/atom/movable/mirage_holder/Click(location, control, params)
	var/list/modifiers = params2list(params)
	var/turf/origin = get_turf(usr.client?.eye || usr)
	if(!origin || !LAZYACCESS(modifiers, SCREEN_LOC))
		return
	var/turf/clicked = parse_caught_click_modifiers(modifiers, origin, usr.client)
	if(clicked)
		usr.ClickOn(clicked, list2params(modifiers))

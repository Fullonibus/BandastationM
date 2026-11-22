/** Standard berths may belong to a moving hull instead of a fixed station. */
/obj/docking_port/stationary/stationtrauma_space_station
	/// Explicit mapper link; the bay itself may lie in vacuum outside the owner's hull areas.
	var/host_ship_id
	/// Live owner, resolved when the named hull joins its sector.
	var/datum/stationtrauma_overmap/space/host
	/// Published destination retained across sector changes and dock renames.
	var/datum/stationtrauma_overmap_site/space/carrier_site

/datum/stationtrauma_overmap_site/space
	/// Moving owner; null for fixed stations and surface destinations.
	var/datum/stationtrauma_overmap/space/host

/datum/stationtrauma_overmap/space
	/// Owned standard markers, including empty bays whose anchors are outside the hull.
	var/list/obj/docking_port/stationary/stationtrauma_space_station/carrier_docks = list()
	/// Relative virtual heading retained while this hull is moored to its carrier.
	var/carrier_heading_offset = 0
	/// Dedicated physical levels retained while the hull or its guests visit other locations.
	var/list/flight_levels = list()

/** Use native area ownership, rather than the carrier's rectangular envelope, to find a machine's hull. */
/proc/stationtrauma_carrier_at(atom/location)
	var/obj/docking_port/mobile/stationtrauma_space/ship = SSshuttle.get_containing_shuttle(location)
	return istype(ship) && !QDELETED(ship.overmap) ? ship.overmap : null

/** Direct parent only; loose reservations and approaching ships are not cargo. */
/datum/stationtrauma_overmap/space/proc/carrier_host()
	var/datum/stationtrauma_overmap/space/owner = docked?.host
	return !QDELETED(owner) && docked.docking_owner == src ? owner : null

/** A bounded traversal of the actual mooring tree, retaining each hull's own areas and flight berth. */
/datum/stationtrauma_overmap/space/proc/carrier_tree()
	var/list/assembly = list(src)
	for(var/index = 1, index <= length(assembly), index++)
		var/datum/stationtrauma_overmap/space/owner = assembly[index]
		for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in owner.carrier_docks)
			var/datum/stationtrauma_overmap/space/guest = slot.carrier_site?.docking_owner
			if(!QDELETED(guest) && guest.carrier_host() == owner)
				assembly |= guest
	return assembly

/** Reject a physical carrier move or jump while any participant is in another manoeuvre. */
/datum/stationtrauma_overmap/space/proc/carrier_busy()
	for(var/datum/stationtrauma_overmap/space/member as anything in carrier_tree())
		var/shared_move = carrier_relocation && member.carrier_relocation == carrier_relocation
		if(member != src && !shared_move && (member.preparing || member.relocating || member.approach_started || member.jump_target || member.ship_docking))
			return TRUE
		for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in member.carrier_docks)
			var/datum/stationtrauma_overmap/space/claimant = slot.carrier_site?.docking_owner
			if(!QDELETED(claimant) && claimant.docked != slot.carrier_site)
				return TRUE
			var/obj/docking_port/stationary/stationtrauma_space_station/standard/standard_slot = slot
			if(istype(standard_slot))
				if(standard_slot.active_berth?.retraction_prepared)
					return TRUE
				for(var/datum/stationtrauma_dock_gangway/gangway as anything in standard_slot.active_berth?.gangways)
					if(gangway.busy && !shared_move)
						return TRUE
	return FALSE

/** Publish only the explicitly named bays; map loading must never turn them into fixed station destinations. */
/datum/stationtrauma_overmap/space/proc/register_carrier_docks()
	var/success = TRUE
	for(var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot in SSshuttle.stationary_docking_ports)
		if(slot.host_ship_id == vessel.shuttle_id && !register_carrier_dock(slot))
			success = FALSE
	return success

/** Commission one mapped or constructed bay without allocating another navigation instance. */
/datum/stationtrauma_overmap/space/proc/register_carrier_dock(obj/docking_port/stationary/stationtrauma_space_station/standard/slot)
	if(QDELETED(slot) || !is_operational() || QDELETED(sector) || !vessel.contains_deck(slot.z) || !istext(slot.site_id) || !length(slot.site_id) || (slot.host && slot.host != src))
		return FALSE
	if(slot.host == src && slot.carrier_site && sector.sites[slot.site_id] == slot.carrier_site)
		return TRUE
	if(sector.sites[slot.site_id])
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = new
	site.id = slot.site_id
	site.name = slot.station_name || slot.name
	site.pos_x = pos_x
	site.pos_y = pos_y
	site.physical_docking = TRUE
	site.discovered = FALSE
	site.needs_scan = TRUE
	site.host = src
	site.berth = slot
	slot.host_ship_id = vessel.shuttle_id
	slot.host = src
	slot.carrier_site = site
	carrier_docks |= slot
	sector.sites[site.id] = site
	var/datum/stationtrauma_overmap_sector/space/home = sector
	home.register_docking_berth(site, "traffic:carrier:[vessel.shuttle_id]", vessel.name)
	return TRUE

/** Unpublish without deleting the site: a runtime marker or a departing guest may still own it. */
/obj/docking_port/stationary/stationtrauma_space_station/proc/unregister_carrier_dock()
	var/datum/stationtrauma_overmap_site/space/site = carrier_site
	var/datum/stationtrauma_overmap_sector/space/old_sector = host?.sector
	host?.carrier_docks.Remove(src)
	old_sector?.unregister_docking_berth(site)
	if(site && old_sector?.sites[site.id] == site)
		old_sector.sites -= site.id
	if(site)
		site.host = null
	host = null
	carrier_site = null
	return site

/obj/docking_port/stationary/stationtrauma_space_station/Destroy(force)
	if(force && carrier_site)
		var/datum/stationtrauma_overmap_site/space/site = unregister_carrier_dock()
		site.failed = TRUE
		site.berth = null
		if(QDELETED(site.docking_owner) || site.docking_owner.docked != site)
			qdel(site)
	return ..()

/** Docks and moored hulls share their owner's virtual motion, without advancing a second helm. */
/datum/stationtrauma_overmap/space/proc/sync_carrier()
	for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in carrier_docks)
		var/datum/stationtrauma_overmap_site/space/site = slot.carrier_site
		if(QDELETED(site))
			continue
		site.pos_x = pos_x
		site.pos_y = pos_y
		if(site.docking_target)
			site.docking_target.pos_x = pos_x
			site.docking_target.pos_y = pos_y
			site.docking_target.name = vessel.name
		var/datum/stationtrauma_overmap/space/guest = site.docking_owner
		if(QDELETED(guest) || guest.carrier_host() != src)
			continue
		guest.pos_x = guest.encounter_x = pos_x
		guest.pos_y = guest.encounter_y = pos_y
		guest.velocity_x = velocity_x
		guest.velocity_y = velocity_y
		guest.speed = speed
		guest.course = guest.ordered_course = WRAP(course + guest.carrier_heading_offset, 0, 360)
		guest.last_update = world.time
		guest.jump_phase = jump_phase
		guest.update_parallax()
		guest.sync_carrier()

/** The owner or an actually moored crew knows its own bays; visitors need a non-expired sensor/radio contact. */
/datum/stationtrauma_overmap/space/proc/can_use_carrier_site(datum/stationtrauma_overmap_site/space/site)
	var/datum/stationtrauma_overmap/space/owner = site?.host
	var/obj/docking_port/stationary/stationtrauma_space_station/slot = site?.berth
	if(QDELETED(owner) || QDELETED(owner.vessel) || owner.sector != sector)
		return FALSE
	if(!istype(site, /datum/stationtrauma_overmap_site/space/docking_target) && (!istype(slot) || slot.host != owner))
		return FALSE
	if(src in owner.carrier_tree())
		return TRUE
	var/list/observation = ship_observations[owner.vessel.shuttle_id]
	return islist(observation) && world.time - observation["seen"] < ST_NAV_SHIP_MEMORY

/** A chart discovery alone cannot disclose or select a ship-owned bay. */
/datum/stationtrauma_overmap/space/knows_site(datum/stationtrauma_overmap_site/site)
	var/datum/stationtrauma_overmap_site/space/destination = site
	if(istype(destination) && destination.host)
		return !QDELETED(site) && sites[site.id] == site && can_use_carrier_site(destination)
	return ..()

/** Never turn a remembered contact into a live course or distance readout. */
/datum/stationtrauma_overmap/space/site_position(datum/stationtrauma_overmap_site/site)
	var/datum/stationtrauma_overmap_site/space/destination = site
	if(istype(destination) && destination.host && !(src in destination.host.carrier_tree()))
		if(!knows_site(site))
			return null
		var/list/observation = ship_observations[destination.host.vessel.shuttle_id]
		return list(observation["x"], observation["y"])
	return ..()

/** Require a stationary live host and reject attempts to moor an ancestor inside its own descendant. */
/datum/stationtrauma_overmap/space/proc/carrier_arrival_ready(datum/stationtrauma_overmap_site/space/site)
	var/datum/stationtrauma_overmap/space/owner = site?.host
	if(!owner)
		return TRUE
	if(!can_use_carrier_site(site) || owner == src || (owner in carrier_tree()) || owner.preparing || owner.relocating || owner.jump_target || owner.ship_docking || owner.approach_started || owner.helm_engaged || owner.speed > ST_NAV_STOPPED_SPEED)
		return FALSE
	return owner.is_operational()

/** Start placements run after every owner has published its bays, independent of fleet load order. */
/datum/stationtrauma_overmap/space/proc/place_starting_dock()
	if(!vessel.starting_dock)
		return TRUE
	var/datum/stationtrauma_overmap_site/space/site = sites[vessel.starting_dock]
	if(site?.host)
		record_ship_observation(site.host.vessel.shuttle_id, site.host, "radio")
	return select_site(vessel.starting_dock) && dock(instant = TRUE, station_authorized = TRUE)

/** Withdraw arrivals on teardown; an already moored guest retains its berth until it casts off. */
/datum/stationtrauma_overmap/space/proc/release_carrier_docks()
	for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in carrier_docks.Copy())
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/runtime/runtime_slot = slot
		if(istype(runtime_slot))
			runtime_slot.retire()
			if(QDELETED(slot))
				continue
		var/datum/stationtrauma_overmap_site/space/site = slot.unregister_carrier_dock()
		if(site)
			site.failed = TRUE
			if(!QDELETED(site.docking_owner) && site.docking_owner.docked == site)
				site.docking_owner.jump_phase = NONE
			if(QDELETED(site.docking_owner) || site.docking_owner.docked != site)
				qdel(site)
	carrier_docks.Cut()

/** All hull and site keys must be available before unregistering even one participant. */
/datum/stationtrauma_overmap/space/proc/carrier_transfer_ready(datum/stationtrauma_overmap_sector/space/target)
	if(QDELETED(target) || !target.ready || target == sector || carrier_busy())
		return FALSE
	for(var/datum/stationtrauma_overmap/space/member as anything in carrier_tree())
		if(!member.is_operational() || member.sector != sector || target.ships[member.vessel.shuttle_id])
			return FALSE
		for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in member.carrier_docks)
			var/datum/stationtrauma_overmap_site/space/docking_target/destination = slot.carrier_site?.docking_target
			if(QDELETED(slot.carrier_site) || sector.sites[slot.site_id] != slot.carrier_site || target.sites[slot.site_id] \
				|| QDELETED(destination) || sector.sites[destination.id] != destination || target.sites[destination.id])
				return FALSE
	return TRUE

/** Transfer the mooring tree and its destination objects together, without yielding between sector registries. */
/datum/stationtrauma_overmap/space/proc/transfer_carrier_sector(datum/stationtrauma_overmap_sector/space/target)
	if(!carrier_transfer_ready(target))
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/origin = sector
	var/list/assembly = carrier_tree()
	var/list/berths = list()
	var/list/destinations = list()
	for(var/datum/stationtrauma_overmap/space/member as anything in assembly)
		for(var/obj/docking_port/stationary/stationtrauma_space_station/slot as anything in member.carrier_docks)
			berths += slot.carrier_site
			destinations |= slot.carrier_site.docking_target
			origin.sites -= slot.site_id
	for(var/datum/stationtrauma_overmap_site/space/docking_target/destination as anything in destinations)
		origin.clear_station_docking_site(destination)
		origin.sites -= destination.id
	for(var/datum/stationtrauma_overmap/space/member as anything in assembly)
		origin.unregister(member)
	var/success = TRUE
	for(var/datum/stationtrauma_overmap/space/member as anything in assembly)
		if(!target.register(member.vessel.shuttle_id, member))
			success = FALSE
			break
	if(!success)
		for(var/datum/stationtrauma_overmap/space/member as anything in assembly)
			if(member.sector == target)
				target.unregister(member)
			origin.register(member.vessel.shuttle_id, member)
	var/datum/stationtrauma_overmap_sector/space/owner = success ? target : origin
	for(var/datum/stationtrauma_overmap_site/space/site as anything in berths + destinations)
		owner.sites[site.id] = site
	if(!success)
		return FALSE
	for(var/datum/stationtrauma_overmap/space/member as anything in assembly)
		member.ship_observations.Cut()
		member.last_ping = null
		var/datum/stationtrauma_overmap_site/space/destination = member.docked?.docking_target || member.docked
		member.selected_destination = destination?.id
		member.prepared_site = destination
		member.clear_encounters()
	return TRUE

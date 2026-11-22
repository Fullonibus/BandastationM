#define ST_STATION_DOCKING_REQUEST_TIME (2 MINUTES)
#define ST_STATION_DOCKING_AUTO_RESPONSE_DELAY (3 SECONDS)

/datum/stationtrauma_overmap_site/space
	/// Navigation destination whose dispatchers can assign this physical berth.
	var/datum/stationtrauma_overmap_site/space/docking_target/docking_target

/// Charted station, trade outpost or carrier. Native movement always uses one of its private berth sites.
/datum/stationtrauma_overmap_site/space/docking_target
	/// Physical berths registered for this destination.
	var/list/datum/stationtrauma_overmap_site/space/berths = list()
	/// Whether this location handles requests without a dispatcher.
	var/automatic = FALSE

/datum/stationtrauma_overmap_site/space/docking_target/Destroy()
	berths.Cut()
	return ..()

/datum/stationtrauma_overmap_sector/space
	/// Pending or approved station docking requests indexed by the registered ship ID.
	var/list/station_docking_requests = list()
	/// Sequence for distinguishing stale console actions from replacement requests.
	var/station_docking_request_sequence = 0

/// Publish the navigation destination once, keeping each berth's original ID for native and service calls.
/datum/stationtrauma_overmap_sector/space/proc/register_docking_berth(datum/stationtrauma_overmap_site/space/site, target_id, target_name)
	var/datum/stationtrauma_overmap_site/space/docking_target/target = sites[target_id]
	if(!target)
		target = new
		target.id = target_id
		target.name = target_name
		target.pos_x = site.pos_x
		target.pos_y = site.pos_y
		target.host = site.host
		var/obj/docking_port/stationary/stationtrauma_space_station/port = site.berth
		target.automatic = port.auto_approve_docking
		sites[target_id] = target
	target.berths |= site
	site.docking_target = target

/// Losing one berth only invalidates its assignment. Pending requests can still use the remaining berths.
/datum/stationtrauma_overmap_sector/space/proc/unregister_docking_berth(datum/stationtrauma_overmap_site/space/site)
	clear_station_docking_site(site)
	var/datum/stationtrauma_overmap_site/space/docking_target/target = site?.docking_target
	if(QDELETED(target))
		return
	site.docking_target = null
	target.berths -= site
	if(length(target.berths))
		return
	clear_station_docking_site(target)
	sites -= target.id
	qdel(target)

/// A physical berth is assignable only while it belongs to this sector's registry.
/datum/stationtrauma_overmap_sector/space/proc/is_station_berth(datum/stationtrauma_overmap_site/space/site)
	return !QDELETED(site) && sites[site.id] == site && site.physical_docking && !site.pad_parent && !QDELETED(site.berth) \
		&& istype(site.berth, /obj/docking_port/stationary/stationtrauma_space_station)

/// Resolve the requested assignment against the live registry and reserve it before either console can act again.
/datum/stationtrauma_overmap_sector/space/proc/respond_station_docking(ship_id, token, approve, dock_id)
	if(!istext(ship_id) || !istext(token) || (approve && !istext(dock_id)))
		return FALSE
	var/datum/stationtrauma_station_docking_request/request = station_docking_requests[ship_id]
	if(QDELETED(request) || request.token != token || !request.is_current())
		return FALSE
	var/datum/stationtrauma_overmap/space/navigation = request.requester
	if(!approve)
		var/notice = request.assigned_berth ? "Разрешение на стыковку с «[request.target.name]» отозвано." : "Запрос на стыковку с «[request.target.name]» отклонён."
		qdel(request)
		navigation.navigation_notice(notice)
		return TRUE
	var/datum/stationtrauma_overmap_site/space/site = sites[dock_id]
	if(!request.can_assign(site))
		return FALSE
	site.docking_owner = navigation
	request.assigned_berth = site
	request.restart_timeout()
	navigation.navigation_notice("Назначен причал «[site.name]». Приблизьтесь, остановитесь и начните манёвр.")
	return TRUE

/// Release cleared assignments or requests for a departing destination. Native approaches own committed reservations.
/datum/stationtrauma_overmap_sector/space/proc/clear_station_docking_site(datum/stationtrauma_overmap_site/space/site)
	if(!site)
		return
	for(var/ship_id in station_docking_requests.Copy())
		var/datum/stationtrauma_station_docking_request/request = station_docking_requests[ship_id]
		if(request?.target == site || request?.assigned_berth == site)
			qdel(request)

/datum/stationtrauma_station_docking_request
	/// Sector that owns and publishes this request.
	var/datum/stationtrauma_overmap_sector/space/sector
	/// Native ship ID captured before any approval or expiry can yield.
	var/ship_id
	/// Request identity sent to consoles, independent of reusable datum references.
	var/token
	/// Navigation instance authorized to dock if this request is approved.
	var/datum/stationtrauma_overmap/space/requester
	/// Object whose dispatchers can assign a berth.
	var/datum/stationtrauma_overmap_site/space/docking_target/target
	/// Exact berth reserved for this request until cancellation or native commit.
	var/datum/stationtrauma_overmap_site/space/assigned_berth
	/// Deadline in deciseconds of world time.
	var/expires_at
	/// Stoppable timer for the automatic response or expiry.
	var/timeout_timer

/datum/stationtrauma_station_docking_request/New(datum/stationtrauma_overmap_sector/space/home, datum/stationtrauma_overmap/space/navigation, datum/stationtrauma_overmap_site/space/docking_target/destination)
	. = ..()
	sector = home
	requester = navigation
	ship_id = navigation.vessel.shuttle_id
	token = "[home.id]:[num2text(++home.station_docking_request_sequence, 8)]"
	target = destination
	restart_timeout()

/datum/stationtrauma_station_docking_request/Destroy()
	deltimer(timeout_timer)
	timeout_timer = null
	if(sector?.station_docking_requests[ship_id] == src)
		sector.station_docking_requests -= ship_id
		if(!QDELETED(assigned_berth) && assigned_berth.docking_owner == requester)
			assigned_berth.docking_owner = null
	sector = null
	requester = null
	target = null
	assigned_berth = null
	return ..()

/// Used by both consoles and the server to reject a stale request or expired clearance.
/datum/stationtrauma_station_docking_request/proc/is_current()
	return world.time < expires_at && !QDELETED(sector) && !QDELETED(requester) && !QDELETED(requester.vessel) \
		&& requester.sector == sector && requester.vessel.overmap == requester && requester.vessel.shuttle_id == ship_id \
		&& sector.ships[ship_id] == requester && sector.station_docking_requests[ship_id] == src \
		&& !QDELETED(target) && requester.selected_destination == target.id && requester.knows_site(target) \
		&& (!assigned_berth || (sector.is_station_berth(assigned_berth) && !assigned_berth.failed && assigned_berth.docking_target == target && assigned_berth.docking_owner == requester))

/// Shared by manual and automatic assignment, and by the dispatcher when listing eligible berths.
/datum/stationtrauma_station_docking_request/proc/can_assign(datum/stationtrauma_overmap_site/space/site)
	// Carrier movement is checked independently of reservations for its other berths.
	if(assigned_berth || !sector.is_station_berth(site) || site.docking_target != target || site.failed \
		|| site.docking_owner || site.shuttle_order || site.berth.get_docked() || stationtrauma_berth_unavailable(site.berth) \
		|| !requester.can_request_station_docking(target) || !requester.carrier_arrival_ready(site) || !requester.vessel.permits_docking(site))
		return FALSE
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
	if(istype(slot))
		return !slot.active_berth && slot.accepts(requester.vessel)
	return requester.vessel.check_dock(site.berth, TRUE)

/datum/stationtrauma_station_docking_request/proc/restart_timeout()
	deltimer(timeout_timer)
	expires_at = world.time + ST_STATION_DOCKING_REQUEST_TIME
	if(!assigned_berth && target.automatic)
		timeout_timer = addtimer(CALLBACK(src, PROC_REF(respond_automatically)), ST_STATION_DOCKING_AUTO_RESPONSE_DELAY, TIMER_STOPPABLE)
		return
	timeout_timer = addtimer(CALLBACK(src, PROC_REF(expire)), ST_STATION_DOCKING_REQUEST_TIME, TIMER_STOPPABLE)

/// Prefer the ship's own class to keep larger berths free for ships that need them.
/datum/stationtrauma_station_docking_request/proc/respond_automatically()
	timeout_timer = null
	if(!is_current())
		qdel(src)
		return
	var/datum/stationtrauma_overmap_site/space/chosen
	for(var/datum/stationtrauma_overmap_site/space/site as anything in target.berths)
		if(!can_assign(site))
			continue
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		if(istype(slot) && slot.accepted_ship_class == requester.vessel.ship_class)
			chosen = site
			break
		if(!chosen)
			chosen = site
	if(chosen && sector.respond_station_docking(ship_id, token, TRUE, chosen.id))
		return
	requester.navigation_notice("У «[target.name]» сейчас нет свободного подходящего причала. Повторите запрос позже.")
	qdel(src)

/datum/stationtrauma_station_docking_request/proc/expire()
	timeout_timer = null
	if(!QDELETED(sector) && sector.station_docking_requests[ship_id] == src && !QDELETED(requester) && !QDELETED(requester.vessel))
		requester.navigation_notice(assigned_berth ? "Срок разрешения на стыковку истёк." : "Срок запроса на стыковку истёк.")
	qdel(src)

/datum/stationtrauma_overmap/space/proc/station_clearance_required(datum/stationtrauma_overmap_site/space/site)
	var/datum/stationtrauma_overmap_sector/space/home = sector
	return istype(home) && (istype(site, /datum/stationtrauma_overmap_site/space/docking_target) || home.is_station_berth(site))

/datum/stationtrauma_overmap/space/proc/has_station_clearance(datum/stationtrauma_overmap_site/space/site)
	if(!station_clearance_required(site))
		return TRUE
	return assigned_station_berth(site.docking_target) == site

/// Resolve a navigator's logical selection into a physical berth while the reservation is still valid.
/datum/stationtrauma_overmap/space/proc/assigned_station_berth(datum/stationtrauma_overmap_site/space/target)
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	if(QDELETED(request) || request.target != target || !request.is_current())
		return null
	return request.assigned_berth

/// A request follows a charted object. A busy compatible berth can become free before the dispatcher answers.
/datum/stationtrauma_overmap/space/proc/can_request_station_docking(datum/stationtrauma_overmap_site/space/docking_target/target)
	var/datum/stationtrauma_overmap_sector/space/home = sector
	if(!istype(target) || !istype(home) || !knows_site(target) || target.failed || QDELETED(vessel) || vessel.overmap != src \
		|| home.ships[vessel.shuttle_id] != src || target.id != selected_destination || docked || preparing || relocating || ship_docking || jump_target)
		return FALSE
	if(target.host && (target.host in carrier_tree()))
		return FALSE
	for(var/datum/stationtrauma_overmap_site/space/site as anything in target.berths)
		if(!home.is_station_berth(site) || site.failed || !vessel.permits_docking(site))
			continue
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		if(!istype(slot) || slot.accepts(vessel))
			return TRUE
	return FALSE

/// Submit a request to the selected object's dispatcher or automatic service.
/datum/stationtrauma_overmap/space/proc/request_station_docking(target_id)
	if(!istext(target_id) || target_id != selected_destination)
		return FALSE
	var/datum/stationtrauma_overmap_site/space/docking_target/target = sites[target_id]
	if(!can_request_station_docking(target))
		return FALSE
	var/datum/stationtrauma_station_docking_request/old_request = get_station_docking_request()
	if(!QDELETED(old_request))
		if(old_request.is_current())
			return FALSE
		qdel(old_request)
	var/datum/stationtrauma_overmap_sector/space/home = sector
	var/datum/stationtrauma_station_docking_request/request = new(home, src, target)
	home.station_docking_requests[vessel.shuttle_id] = request
	return TRUE

/datum/stationtrauma_overmap/space/proc/cancel_station_docking()
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	if(QDELETED(request))
		return FALSE
	qdel(request)
	return TRUE

/// Consume the approval without releasing the reservation now owned by the physical manoeuvre.
/datum/stationtrauma_overmap/space/proc/consume_station_clearance(datum/stationtrauma_overmap_site/space/site)
	if(!station_clearance_required(site))
		return TRUE
	if(!has_station_clearance(site))
		return FALSE
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	request.assigned_berth = null
	qdel(request)
	return TRUE

/datum/stationtrauma_overmap/space/proc/get_station_docking_request()
	var/datum/stationtrauma_overmap_sector/space/home = sector
	if(!istype(home))
		return null
	var/datum/stationtrauma_station_docking_request/request = home.station_docking_requests[vessel?.shuttle_id]
	return request?.requester == src ? request : null

/datum/stationtrauma_overmap/space/proc/station_docking_data(datum/stationtrauma_overmap_site/space/docking_target/target)
	var/required = istype(target)
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	var/current = required && !QDELETED(request) && request.target == target && request.is_current()
	var/seconds_left
	if(current)
		var/remaining = !request.assigned_berth && target.automatic ? timeleft(request.timeout_timer) : request.expires_at - world.time
		seconds_left = ceil(max(0, remaining) / (1 SECONDS))
	return list(
		"required" = required,
		"state" = current ? (request.assigned_berth ? "approved" : "pending") : "none",
		"canRequest" = required && !current && can_request_station_docking(target),
		"canCancel" = current,
		"expiresIn" = seconds_left,
		"dockName" = current ? request.assigned_berth?.name : null,
		"automatic" = required && target.automatic,
	)

#undef ST_STATION_DOCKING_AUTO_RESPONSE_DELAY
#undef ST_STATION_DOCKING_REQUEST_TIME

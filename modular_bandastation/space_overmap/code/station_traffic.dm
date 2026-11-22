#define ST_STATION_DOCKING_REQUEST_TIME (2 MINUTES)
#define ST_STATION_DOCKING_AUTO_RESPONSE_DELAY (3 SECONDS)

/datum/stationtrauma_overmap_sector/space
	/// Pending or approved station docking requests indexed by the registered ship ID.
	var/list/station_docking_requests = list()
	/// Sequence for distinguishing stale console actions from replacement requests.
	var/station_docking_request_sequence = 0

/// Only physical station berths in this sector's current registry require clearance.
/datum/stationtrauma_overmap_sector/space/proc/is_station_berth(datum/stationtrauma_overmap_site/space/site)
	return !QDELETED(site) && sites[site.id] == site && site.physical_docking && !QDELETED(site.berth) \
		&& istype(site.berth, /obj/docking_port/stationary/stationtrauma_space_station)

/// Resolve an operator response against the current request, never against an arbitrary reference.
/datum/stationtrauma_overmap_sector/space/proc/respond_station_docking(ship_id, token, approve)
	if(!istext(ship_id) || !istext(token))
		return FALSE
	var/datum/stationtrauma_station_docking_request/request = station_docking_requests[ship_id]
	if(QDELETED(request) || request.token != token || !request.is_current())
		return FALSE
	var/datum/stationtrauma_overmap/space/navigation = request.requester
	var/datum/stationtrauma_overmap_site/space/site = request.site
	if(!approve)
		var/was_approved = request.approved
		qdel(request)
		navigation.navigation_notice(was_approved ? "Разрешение на стыковку с «[site.name]» отозвано." : "Запрос на стыковку с «[site.name]» отклонён.")
		return TRUE
	if(request.approved || site.docking_owner || site.berth.get_docked() || !navigation.can_request_station_docking(site) || !navigation.carrier_arrival_ready(site))
		return FALSE
	if(istype(site.berth, /obj/docking_port/stationary/stationtrauma_space_station/standard))
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		if(slot.active_berth)
			return FALSE
	else if(!navigation.vessel.check_dock(site.berth, TRUE))
		return FALSE
	site.docking_owner = navigation
	request.approved = TRUE
	request.restart_timeout()
	navigation.navigation_notice("Разрешена стыковка с «[site.name]». Приблизьтесь, остановитесь и начните манёвр.")
	return TRUE

/// Release requests when a dock leaves service. A committed approach is owned by navigation.
/datum/stationtrauma_overmap_sector/space/proc/clear_station_docking_site(datum/stationtrauma_overmap_site/space/site)
	for(var/ship_id in station_docking_requests.Copy())
		var/datum/stationtrauma_station_docking_request/request = station_docking_requests[ship_id]
		if(request?.site == site)
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
	/// Exact station destination, which may be renamed without changing the request.
	var/datum/stationtrauma_overmap_site/space/site
	/// Holds the station site's reservation until cancellation or the native docking commit.
	var/approved = FALSE
	/// Deadline in deciseconds of world time.
	var/expires_at
	/// Stoppable timer for the automatic response or the request's expiry.
	var/timeout_timer

/datum/stationtrauma_station_docking_request/New(datum/stationtrauma_overmap_sector/space/home, datum/stationtrauma_overmap/space/navigation, datum/stationtrauma_overmap_site/space/destination)
	. = ..()
	sector = home
	requester = navigation
	ship_id = navigation.vessel.shuttle_id
	token = "[home.id]:[num2text(++home.station_docking_request_sequence, 8)]"
	site = destination
	restart_timeout()

/datum/stationtrauma_station_docking_request/Destroy()
	deltimer(timeout_timer)
	timeout_timer = null
	if(sector?.station_docking_requests[ship_id] == src)
		sector.station_docking_requests -= ship_id
		if(approved && !QDELETED(site) && site.docking_owner == requester)
			site.docking_owner = null
	sector = null
	requester = null
	site = null
	return ..()

/// Used by both consoles and the server to reject a stale request or expired clearance.
/datum/stationtrauma_station_docking_request/proc/is_current()
	return world.time < expires_at && !QDELETED(sector) && !QDELETED(requester) && !QDELETED(requester.vessel) \
		&& requester.sector == sector && requester.vessel.overmap == requester && requester.vessel.shuttle_id == ship_id \
		&& sector.ships[ship_id] == requester && sector.station_docking_requests[ship_id] == src \
		&& sector.is_station_berth(site) && !site.failed && requester.selected_destination == site.id && requester.knows_site(site)

/datum/stationtrauma_station_docking_request/proc/restart_timeout()
	deltimer(timeout_timer)
	expires_at = world.time + ST_STATION_DOCKING_REQUEST_TIME
	var/obj/docking_port/stationary/stationtrauma_space_station/port = site.berth
	if(!approved && port.auto_approve_docking)
		timeout_timer = addtimer(CALLBACK(src, PROC_REF(respond_automatically)), ST_STATION_DOCKING_AUTO_RESPONSE_DELAY, TIMER_STOPPABLE)
		return
	timeout_timer = addtimer(CALLBACK(src, PROC_REF(expire)), ST_STATION_DOCKING_REQUEST_TIME, TIMER_STOPPABLE)

/// Recheck the berth when the automatic response is due, without reserving it while the request waits.
/datum/stationtrauma_station_docking_request/proc/respond_automatically()
	if(approved)
		return
	timeout_timer = null
	if(!is_current())
		qdel(src)
		return
	if(sector.respond_station_docking(ship_id, token, TRUE))
		return
	requester.navigation_notice("Стыковка с «[site.name]» сейчас недоступна. Повторите запрос позже.")
	qdel(src)

/datum/stationtrauma_station_docking_request/proc/expire()
	timeout_timer = null
	if(!QDELETED(sector) && sector.station_docking_requests[ship_id] == src && !QDELETED(requester) && !QDELETED(requester.vessel))
		requester.navigation_notice(approved ? "Срок разрешения на стыковку истёк." : "Срок запроса на стыковку истёк.")
	qdel(src)

/datum/stationtrauma_overmap/space/proc/station_clearance_required(datum/stationtrauma_overmap_site/space/site)
	var/datum/stationtrauma_overmap_sector/space/home = sector
	return istype(home) && home.is_station_berth(site)

/datum/stationtrauma_overmap/space/proc/has_station_clearance(datum/stationtrauma_overmap_site/space/site)
	if(!station_clearance_required(site))
		return TRUE
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	return !QDELETED(request) && request.site == site && request.approved && request.is_current() && site.docking_owner == src

/// Requests follow the selected destination, including while the vessel is approaching it.
/datum/stationtrauma_overmap/space/proc/can_request_station_docking(datum/stationtrauma_overmap_site/space/site)
	if(!station_clearance_required(site) || !knows_site(site) || site.failed || QDELETED(vessel) || vessel.overmap != src || sector.ships[vessel.shuttle_id] != src \
		|| site.id != selected_destination || docked || preparing || relocating || ship_docking || jump_target || site.shuttle_order || !vessel.permits_docking(site))
		return FALSE
	if(site.host && (site.host in carrier_tree()))
		return FALSE
	if(istype(site.berth, /obj/docking_port/stationary/stationtrauma_space_station/standard))
		var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = site.berth
		return slot.accepts(vessel)
	return TRUE

/// Submit a clearance request for the dispatcher or the berth's automatic response.
/datum/stationtrauma_overmap/space/proc/request_station_docking(site_id)
	if(!istext(site_id) || site_id != selected_destination)
		return FALSE
	var/datum/stationtrauma_overmap_site/space/site = sites[site_id]
	if(!can_request_station_docking(site))
		return FALSE
	var/datum/stationtrauma_station_docking_request/old_request = get_station_docking_request()
	if(!QDELETED(old_request))
		if(old_request.is_current())
			return FALSE
		qdel(old_request)
	var/datum/stationtrauma_overmap_sector/space/home = sector
	var/datum/stationtrauma_station_docking_request/request = new(home, src, site)
	home.station_docking_requests[vessel.shuttle_id] = request
	return TRUE

/datum/stationtrauma_overmap/space/proc/cancel_station_docking()
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	if(QDELETED(request))
		return FALSE
	qdel(request)
	return TRUE

/// Consume the exact approval without releasing the reservation now owned by the docking maneuver.
/datum/stationtrauma_overmap/space/proc/consume_station_clearance(datum/stationtrauma_overmap_site/space/site)
	if(!station_clearance_required(site))
		return TRUE
	if(!has_station_clearance(site))
		return FALSE
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	request.approved = FALSE
	qdel(request)
	return TRUE

/datum/stationtrauma_overmap/space/proc/get_station_docking_request()
	var/datum/stationtrauma_overmap_sector/space/home = sector
	if(!istype(home))
		return null
	var/datum/stationtrauma_station_docking_request/request = home.station_docking_requests[vessel?.shuttle_id]
	return request?.requester == src ? request : null

/datum/stationtrauma_overmap/space/proc/station_docking_data(datum/stationtrauma_overmap_site/space/site)
	var/required = station_clearance_required(site)
	var/datum/stationtrauma_station_docking_request/request = get_station_docking_request()
	var/current = required && !QDELETED(request) && request.site == site && request.is_current()
	var/seconds_left
	if(current)
		var/obj/docking_port/stationary/stationtrauma_space_station/port = site.berth
		var/remaining = !request.approved && port.auto_approve_docking ? timeleft(request.timeout_timer) : request.expires_at - world.time
		seconds_left = ceil(max(0, remaining) / (1 SECONDS))
	return list(
		"required" = required,
		"state" = current ? (request.approved ? "approved" : "pending") : "none",
		"canRequest" = required && !current && can_request_station_docking(site),
		"canCancel" = current,
		"expiresIn" = seconds_left,
	)

#undef ST_STATION_DOCKING_AUTO_RESPONSE_DELAY
#undef ST_STATION_DOCKING_REQUEST_TIME

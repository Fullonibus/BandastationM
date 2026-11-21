/// Powered operation and engineering deck of the scenario shuttle.
/area/shuttle/stationtrauma_space/droid_relay
	name = "Шаттл реле: рабочая палуба"
	requires_power = TRUE

/// The shuttle's bridge is powered by its own APC.
/area/shuttle/stationtrauma_space/droid_relay/bridge
	name = "Шаттл реле: рубка"

/// The engine mounts are open to space and move with the ship.
/area/shuttle/stationtrauma_space/droid_relay/exterior
	name = "Шаттл реле: наружная обшивка"
	requires_power = FALSE
	vacuum_by_design = TRUE

/// The only hull of this type is the round's admin-loaded relay shuttle.
/obj/docking_port/mobile/stationtrauma_space/droid_relay
	name = "НТ «Дозор»"
	shuttle_id = "overmap_droid_relay"
	area_type = /area/shuttle/stationtrauma_space/droid_relay
	ship_class = ST_SHIP_SMALL

/// Transponder registration for the scenario shuttle.
/obj/item/circuitboard/computer/stationtrauma_transponder/nt/droid_relay
	callsign = "Дозор"

/// Keep the map template alive until the hull and its relay have been published together.
/datum/map_template/stationtrauma_space/ship/droid_relay
	name = "НТ «Дозор»"
	mappath = '_maps/map_files/overmap_ships/droid_relay.dmm'

/// Load and register the scenario hull, returning its relay when it is ready to be claimed.
/datum/map_template/stationtrauma_space/ship/droid_relay/proc/load_relay(client/administrator, datum/stationtrauma_overmap_sector/space/home/sector)
	if(!check_rights_for(administrator, R_ADMIN) || QDELETED(sector) || !sector.ready || SSstationtrauma_space_voyage.sectors[sector.id] != sector)
		return null
	var/obj/docking_port/mobile/stationtrauma_space/droid_relay/vessel = load_ship()
	if(!istype(vessel) || QDELETED(vessel) || !check_rights_for(administrator, R_ADMIN))
		return null
	if(QDELETED(sector) || !sector.ready || SSstationtrauma_space_voyage.sectors[vessel.overmap_sector] != sector)
		return null
	for(var/obj/docking_port/mobile/stationtrauma_space/droid_relay/existing in SSshuttle.mobile_docking_ports)
		if(existing != vessel && !QDELETED(existing))
			return null
	if(!vessel.registered)
		vessel.register()
	// Runtime map loads miss the shuttle subsystem's startup linkup. Register may already link a reused ID.
	if(!length(vessel.engine_list))
		vessel.linkup()
	if(!sector.attach(vessel) || QDELETED(vessel) || QDELETED(sector) || !check_rights_for(administrator, R_ADMIN))
		return null
	if(!sector.ready || SSstationtrauma_space_voyage.sectors[vessel.overmap_sector] != sector)
		return null
	for(var/area/ship_area as anything in vessel.shuttle_areas)
		for(var/obj/machinery/overmap_droid_relay/relay in ship_area)
			if(!QDELETED(relay) && vessel.is_in_shuttle_bounds(relay))
				relay.connect_peripherals()
				return relay
	return null

ADMIN_VERB(load_droid_relay_shuttle, R_ADMIN, "Реле дроидов — загрузить шаттл", "Разместить отдельный шаттл реле дроидов в домашнем секторе овермапы.", ADMIN_CATEGORY_EVENTS)
	if(!check_rights_for(user, R_ADMIN))
		return
	var/datum/stationtrauma_overmap_sector/space/home/sector = SSstationtrauma_space_voyage.sectors["epsilon_eridani"]
	if(SSstationtrauma_space_voyage.loading || QDELETED(sector) || !sector.ready)
		to_chat(user, span_warning("Шаттлу нужен готовый сектор овермапы. На этой карте можно разместить реле отдельно и занять его через контекстное меню."), confidential = TRUE)
		return
	var/static/loading_relay_shuttle = FALSE
	if(loading_relay_shuttle || (locate(/obj/docking_port/mobile/stationtrauma_space/droid_relay) in SSshuttle.mobile_docking_ports))
		to_chat(user, span_warning("Шаттл реле уже загружен или загружается."), confidential = TRUE)
		return
	loading_relay_shuttle = TRUE
	var/datum/map_template/stationtrauma_space/ship/droid_relay/template
	var/obj/machinery/overmap_droid_relay/relay
	var/exception/load_failure
	try
		template = new
		relay = template.load_relay(user, sector)
	catch(var/exception/failure)
		load_failure = failure
	try
		if(!relay)
			template?.discard_loaded_ship()
	catch(var/exception/cleanup_failure)
		load_failure ||= cleanup_failure
	qdel(template)
	loading_relay_shuttle = FALSE
	if(load_failure)
		throw load_failure
	if(!check_rights_for(user, R_ADMIN))
		return
	if(QDELETED(relay))
		to_chat(user, span_warning("Не удалось загрузить шаттл реле дроидов."), confidential = TRUE)
		return
	log_admin("[key_name(user)] loaded the droid relay shuttle at [AREACOORD(relay)].")
	message_admins("[key_name_admin(user)] загрузил шаттл реле дроидов [ADMIN_VERBOSEJMP(relay)].")

ADMIN_VERB_ONLY_CONTEXT_MENU(claim_droid_relay, R_ADMIN, "Реле дроидов — занять", /obj/machinery/overmap_droid_relay)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_OBJ, VERB_ARG_SOURCE_WORLD, /obj/machinery/overmap_droid_relay)
	if(!check_rights_for(user, R_ADMIN))
		return
	if(!istype(target) || QDELETED(target) || !isturf(target.loc))
		to_chat(user, span_warning("Выбранное реле недоступно."), confidential = TRUE)
		return
	if(!isobserver(user.mob))
		to_chat(user, span_warning("Чтобы занять реле, перейдите в наблюдатели."), confidential = TRUE)
		return
	if(!target.claim(user))
		to_chat(user, span_warning("Не удалось занять реле. Оно занято или недоступно."), confidential = TRUE)
		return
	to_chat(user, span_notice("Вы заняли реле дроидов."), confidential = TRUE)

/// Local supply of sheet materials for the droid production line.
/obj/machinery/relay_resource_storage
	name = "хранилище ресурсов"
	desc = "Компактный силос для листовых материалов. Подаёт их в фабрикатор по грузовой трубе."
	icon = 'modular_bandastation/space_overmap/icons/relay_logistics.dmi'
	icon_state = "storage"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	processing_flags = NONE
	/// Map-loaded iron stock, in sheets.
	var/iron_sheets = 0
	/// Sheet capacity shared by all materials.
	var/sheet_capacity = 60
	/// Physical stock of the silo.
	var/datum/material_container/materials

/obj/machinery/relay_resource_storage/Initialize(mapload)
	. = ..()
	materials = new(src, list(/datum/material/iron = iron_sheets * SHEET_MATERIAL_AMOUNT), sheet_capacity * SHEET_MATERIAL_AMOUNT, MATCONTAINER_EXAMINE, allowed_mats = SSmaterials.flat_materials.Copy(), allowed_items = list(/obj/item/stack/sheet))

/obj/machinery/relay_resource_storage/Destroy()
	QDEL_NULL(materials)
	return ..()

/// An anchored section of the relay's cargo and control network.
/obj/structure/relay_material_conduit
	name = "грузовая труба"
	desc = "Передаёт материалы и команды между постройками реле. Закреплённые секции должны стыковаться друг с другом."
	icon = 'modular_bandastation/space_overmap/icons/relay_logistics.dmi'
	icon_state = "conduit_3"
	layer = PLUMBING_PIPE_VISIBILE_LAYER
	appearance_flags = PIXEL_SCALE | LONG_GLIDE // Couplings project into the neighboring tile.
	density = FALSE
	anchored = TRUE
	max_integrity = 150
	/// Adjacent tiles monitored for equipment placement and removal.
	var/list/turf/connector_tiles
	/// Equipment on those tiles monitored for anchoring changes.
	var/list/obj/machinery/connector_devices

/obj/structure/relay_material_conduit/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/simple_rotation, ROTATION_NEEDS_ROOM)
	update_appearance(UPDATE_ICON_STATE)
	watch_connector_tiles()

/obj/structure/relay_material_conduit/Destroy()
	for(var/turf/tile as anything in connector_tiles)
		UnregisterSignal(tile, list(COMSIG_ATOM_ABSTRACT_ENTERED, COMSIG_ATOM_ABSTRACT_EXITED, COMSIG_TURF_CHANGE))
	for(var/obj/machinery/device as anything in connector_devices)
		UnregisterSignal(device, list(COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING))
	connector_tiles = null
	connector_devices = null
	return ..()

/obj/structure/relay_material_conduit/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(old_loc != loc && !QDELETED(src))
		watch_connector_tiles()

/obj/structure/relay_material_conduit/set_anchored(anchorvalue)
	. = ..()
	if(!isnull(.))
		update_appearance(UPDATE_OVERLAYS)

/obj/structure/relay_material_conduit/setDir(newdir)
	. = ..()
	update_appearance(UPDATE_ICON)

/obj/structure/relay_material_conduit/update_icon_state()
	. = ..()
	icon_state = "conduit_[connection_mask()]"

/obj/structure/relay_material_conduit/update_overlays()
	. = ..()
	if(!anchored || !isturf(loc))
		return
	var/ports = connection_mask()
	for(var/obj/machinery/device as anything in connector_devices)
		if(QDELETED(device) || !device.anchored)
			continue
		var/direction = get_dir(src, device)
		if(!(ports & direction))
			continue
		var/mutable_appearance/coupling = mutable_appearance(icon, "coupling_[direction]")
		coupling.pixel_x = (device.x - x) * ICON_SIZE_X
		coupling.pixel_y = (device.y - y) * ICON_SIZE_Y
		. += coupling
		ports &= ~direction

/// Refresh the turf subscriptions when the pipe moves or the deck is replaced.
/obj/structure/relay_material_conduit/proc/watch_connector_tiles()
	for(var/turf/tile as anything in connector_tiles)
		UnregisterSignal(tile, list(COMSIG_ATOM_ABSTRACT_ENTERED, COMSIG_ATOM_ABSTRACT_EXITED, COMSIG_TURF_CHANGE))
	connector_tiles = list()
	if(isturf(loc))
		for(var/direction in GLOB.cardinals)
			var/turf/tile = get_step(src, direction)
			if(!tile)
				continue
			connector_tiles += tile
			RegisterSignals(tile, list(COMSIG_ATOM_ABSTRACT_ENTERED, COMSIG_ATOM_ABSTRACT_EXITED), PROC_REF(on_connector_moved))
			RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(on_connector_turf_change))
	refresh_connector_devices()

/obj/structure/relay_material_conduit/proc/on_connector_turf_change(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	post_change_callbacks += CALLBACK(src, PROC_REF(watch_connector_tiles))

/obj/structure/relay_material_conduit/proc/on_connector_moved(turf/source, atom/movable/device)
	SIGNAL_HANDLER
	if(is_relay_conduit_endpoint(device))
		refresh_connector_devices()

/// Track supported equipment even when it is unanchored so re-anchoring updates the coupling.
/obj/structure/relay_material_conduit/proc/refresh_connector_devices()
	var/list/obj/machinery/devices = list()
	for(var/turf/tile as anything in connector_tiles)
		if(tile.density || isspaceturf(tile) || isopenspaceturf(tile))
			continue
		for(var/obj/machinery/device in tile)
			if(!QDELETED(device) && is_relay_conduit_endpoint(device))
				devices += device
	for(var/obj/machinery/device as anything in connector_devices)
		if(!(device in devices))
			UnregisterSignal(device, list(COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING))
	for(var/obj/machinery/device as anything in devices)
		if(!(device in connector_devices))
			RegisterSignals(device, list(COMSIG_MOVABLE_SET_ANCHORED, COMSIG_QDELETING), PROC_REF(on_connector_state_changed))
	connector_devices = devices
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/relay_material_conduit/proc/on_connector_state_changed(obj/machinery/source)
	SIGNAL_HANDLER
	update_appearance(UPDATE_OVERLAYS)

/// Cardinal sides that can connect to neighboring segments or equipment.
/obj/structure/relay_material_conduit/proc/connection_mask()
	return (dir & (NORTH | SOUTH)) ? (NORTH | SOUTH) : (EAST | WEST)

/// A two-port corner. Its diagonal direction identifies the two exits.
/obj/structure/relay_material_conduit/corner
	name = "угол грузовой трубы"
	icon_state = "conduit_5"
	dir = NORTHEAST

/obj/structure/relay_material_conduit/corner/connection_mask()
	return dir

/// A three-port junction. Its direction identifies the stem of the tee.
/obj/structure/relay_material_conduit/junction
	name = "тройник грузовой трубы"
	icon_state = "conduit_13"
	dir = NORTH

/obj/structure/relay_material_conduit/junction/connection_mask()
	return (NORTH | SOUTH | EAST | WEST) & ~REVERSE_DIR(dir)

/obj/structure/relay_material_conduit/wrench_act(mob/living/user, obj/item/tool)
	default_unfasten_wrench(user, tool, time = 1 SECONDS)
	return ITEM_INTERACT_SUCCESS

/// Only physical, anchored sections can carry a connection between adjacent deck tiles.
/turf/proc/relay_conduit()
	if(density || isspaceturf(src) || isopenspaceturf(src))
		return null
	var/obj/structure/relay_material_conduit/section = locate() in src
	return !QDELETED(section) && section.anchored ? section : null

/// Equipment returned by pipe discovery as relay peripherals.
/proc/relay_conduit_device_types()
	var/static/list/device_types = typecacheof(list(
		/obj/machinery/relay_resource_storage,
		/obj/machinery/relay_fabricator,
		/obj/machinery/relay_transport,
		/obj/machinery/computer/stationtrauma_space_navigation/relay_board,
	))
	return device_types

/// Both the relay itself and its peripherals can receive a visible coupling.
/proc/is_relay_conduit_endpoint(atom/movable/device)
	return istype(device, /obj/machinery/overmap_droid_relay) || is_type_in_typecache(device, relay_conduit_device_types())

/// Find attached equipment in order of distance through a bounded network of matching pipe ports.
/proc/relay_conduit_devices(atom/movable/source)
	var/list/devices = list()
	if(QDELETED(source) || !source.anchored || !isturf(source.loc))
		return devices

	var/list/obj/structure/relay_material_conduit/queue = list()
	var/list/seen = list()
	for(var/direction in GLOB.cardinals)
		var/turf/tile = get_step(source, direction)
		var/obj/structure/relay_material_conduit/section = tile?.relay_conduit()
		if(section && (section.connection_mask() & REVERSE_DIR(direction)))
			queue += section
			seen[section] = TRUE

	var/list/device_types = relay_conduit_device_types()
	for(var/index = 1; index <= length(queue); index++)
		// Limit the component size, so an oversized network cannot give different results from opposite ends.
		if(length(queue) > 64)
			return list()
		var/obj/structure/relay_material_conduit/section = queue[index]
		var/mask = section.connection_mask()
		for(var/direction in GLOB.cardinals)
			if(!(mask & direction))
				continue
			var/turf/tile = get_step(section, direction)
			if(!tile || tile.density || isspaceturf(tile) || isopenspaceturf(tile))
				continue
			for(var/obj/machinery/device in tile)
				if(device != source && device.anchored && !QDELETED(device) && device_types[device.type])
					devices |= device
			var/obj/structure/relay_material_conduit/next_section = tile.relay_conduit()
			if(next_section && !seen[next_section] && (next_section.connection_mask() & REVERSE_DIR(direction)))
				queue += next_section
				seen[next_section] = TRUE
	return devices

/// Prefer the nearest functioning silo on the live pipe network.
/obj/machinery/relay_fabricator/proc/connected_storage()
	for(var/obj/machinery/relay_resource_storage/storage in relay_conduit_devices(src))
		if(!(storage.machine_stat & BROKEN))
			return storage
	return null

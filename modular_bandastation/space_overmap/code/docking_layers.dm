/obj/docking_port/mobile/stationtrauma_space
	/// Index of this hull's own native boundary, including while another hull covers it.
	var/list/docking_layer_indices = list()
	/// Floors hidden immediately below this hull's own boundary.
	var/list/docking_surfaces = list()

/datum/stationtrauma_overmap/space
	/// Layer selection and surface restoration for the current native relocation.
	var/datum/stationtrauma_docking_layers/docking_relocation

/** Record new native construction while retaining ownership records beneath damaged hull cells. */
/obj/docking_port/mobile/stationtrauma_space/proc/initialize_docking_layers()
	var/list/known_tiles = list()
	for(var/turf/known_tile as anything in docking_layer_indices)
		known_tiles[known_tile] = TRUE
	for(var/area/hull_area as anything in shuttle_areas)
		for(var/list/deck as anything in hull_area.get_zlevel_turf_lists())
			for(var/turf/tile as anything in deck)
				if(contains_deck(tile.z) && !isspaceturf(tile) && !known_tiles[tile] \
					&& !istype(tile, /turf/open/floor/plating/stationtrauma_dock_gangway))
					var/index = tile.level_to_find_baseturf(/turf/baseturf_skipover/shuttle)
					if(index)
						docking_layer_indices[tile] = index

/** The recorded marker belongs to this vessel, unlike a marker in the floor below a hull cutout. */
/obj/docking_port/mobile/stationtrauma_space/proc/has_docking_layer(turf/tile)
	var/index = docking_layer_indices[tile]
	return tile && isnum(index) && islist(tile.baseturfs) && index >= 1 && index <= length(tile.baseturfs) \
		&& tile.baseturfs[index] == /turf/baseturf_skipover/shuttle

/obj/docking_port/mobile/stationtrauma_space/shuttle_layer_depth(turf/source)
	return overmap?.docking_relocation?.source_depth(source)

/obj/docking_port/mobile/stationtrauma_space/shuttle_source_restored(turf/source)
	overmap?.docking_relocation?.restore_source(source)

/** One physical cell may contain independently owned layers from several moored vessels. */
/datum/stationtrauma_docking_layer_cell
	/// Native source and paired destination.
	var/turf/source
	var/turf/destination
	/// Source layers are immutable between validation and copy.
	var/list/source_bases
	var/source_type
	/// Native CopyOnTop begins by retaining this target stack and its visible type.
	var/list/target_prefix
	var/target_type
	/// Lowest boundary owned by the transported assembly.
	var/selected_index
	/// Each participating hull retains its own boundary above selected_index.
	var/list/indices = list()
	/// Saved underlays are rekeyed rather than copied or regenerated.
	var/list/surfaces = list()
	/// The lowest participating hull receives the newly hidden destination floor.
	var/obj/docking_port/mobile/stationtrauma_space/bottom_ship
	/// An independent temporary passage can itself be the lowest transported layer.
	var/turf/open/floor/plating/stationtrauma_dock_gangway/temporary_bridge
	/// The external floor left at the source when the assembly casts off.
	var/datum/stationtrauma_dock_surface/old_surface
	/// The new receiver floor, concealed only immediately before native takeoff.
	var/datum/stationtrauma_dock_surface/new_surface

/datum/stationtrauma_docking_layer_cell/Destroy()
	source = null
	destination = null
	source_bases = null
	target_prefix = null
	indices = null
	surfaces = null
	bottom_ship = null
	temporary_bridge = null
	QDEL_NULL(old_surface)
	QDEL_NULL(new_surface)
	return ..()

/** Scoped source boundaries preserve both an external landing floor and all internal carrier layers. */
/datum/stationtrauma_docking_layers
	/// Native pipeline owner; other members keep their own areas and metadata.
	var/obj/docking_port/mobile/stationtrauma_space/root
	var/obj/docking_port/stationary/target
	var/datum/stationtrauma_carrier_movement/carrier
	/// Participating hulls, ordered from the carrier towards its descendants.
	var/list/ships = list()
	/// Admission set used locally by native area callbacks.
	var/list/areas = list()
	/// Native source turf keys associated with one layer record each.
	var/list/cells = list()
	/// All native source cells, including intentional holes.
	var/list/source_tiles
	var/list/target_tiles
	var/rotation
	/// Original caller's final interlock, run before the last layer validation.
	var/datum/callback/before_takeoff
	/// Surface concealment has occurred and native takeoff is about to copy the cells.
	var/captured = FALSE
	/// Metadata has been transferred to the new coordinates.
	var/copied = FALSE

/datum/stationtrauma_docking_layers/New(obj/docking_port/mobile/stationtrauma_space/ship, obj/docking_port/stationary/new_target, datum/callback/commit_callback)
	root = ship
	target = new_target
	before_takeoff = commit_callback
	carrier = ship.overmap?.carrier_relocation
	rotation = dir2angle(target.dir) - dir2angle(root.dir)
	if(carrier?.root.vessel == root)
		for(var/datum/stationtrauma_overmap/space/navigation as anything in carrier.members)
			ships += navigation.vessel
	else
		ships += root
	for(var/obj/docking_port/mobile/stationtrauma_space/member as anything in ships)
		member.initialize_docking_layers()
		for(var/area/hull_area as anything in member.shuttle_areas)
			areas[hull_area] = TRUE

/** Reproduce only native's blacklist filtering when rebasing copied layer indices and hidden stacks. */
/datum/stationtrauma_docking_layers/proc/rebased_stack(list/old_stack, selected_index, list/prefix)
	var/list/copied_stack = old_stack.Copy(selected_index)
	copied_stack -= prefix & GLOB.blacklisted_automated_baseturfs
	return prefix + copied_stack

/datum/stationtrauma_docking_layers/proc/build()
	source_tiles = root.return_ordered_turfs(root.x, root.y, root.z, root.dir)
	target_tiles = root.return_ordered_turfs(target.x, target.y, target.z, target.dir)
	if(length(source_tiles) != length(target_tiles))
		return FALSE
	for(var/position in 1 to length(source_tiles))
		var/turf/source = source_tiles[position]
		var/turf/destination = target_tiles[position]
		if(!source || !destination)
			return FALSE
		var/datum/stationtrauma_docking_layer_cell/cell = new
		cell.source = source
		cell.destination = destination
		for(var/obj/docking_port/mobile/stationtrauma_space/ship as anything in ships)
			if(!ship.has_docking_layer(source))
				continue
			var/index = ship.docking_layer_indices[source]
			cell.indices[ship] = index
			cell.surfaces[ship] = ship.docking_surfaces[source]
			if(!cell.selected_index || index < cell.selected_index)
				cell.selected_index = index
				cell.bottom_ship = ship
		if(istype(source, /turf/open/floor/plating/stationtrauma_dock_gangway) && carrier?.bridge_baseturfs[source])
			cell.temporary_bridge = source
			if(!cell.selected_index)
				cell.selected_index = carrier.added_skipovers[source]
		if(!cell.selected_index)
			qdel(cell)
			if(carrier?.bridge_baseturfs[source])
				return FALSE
			continue
		if(!areas[get_area(source)] && !cell.temporary_bridge)
			qdel(cell)
			return FALSE
		cell.source_bases = source.baseturfs.Copy()
		cell.source_type = source.type
		cell.target_type = destination.type
		cell.target_prefix = list()
		cell.target_prefix += destination.baseturfs
		cell.target_prefix += destination.type
		cells[source] = cell
	return validate()

/** Never reach native's destructive overflow fallback or reuse a changed layer boundary. */
/datum/stationtrauma_docking_layers/proc/validate()
	for(var/turf/source as anything in cells)
		var/datum/stationtrauma_docking_layer_cell/cell = cells[source]
		if(source.type != cell.source_type || cell.destination.type != cell.target_type || !islist(source.baseturfs) \
			|| length(source.baseturfs) != length(cell.source_bases))
			return FALSE
		if(!areas[get_area(source)] && !cell.temporary_bridge)
			return FALSE
		for(var/obj/docking_port/mobile/stationtrauma_space/ship as anything in cell.indices)
			if(ship.docking_layer_indices[source] != cell.indices[ship] || !ship.has_docking_layer(source))
				return FALSE
		for(var/index in 1 to length(cell.source_bases))
			if(source.baseturfs[index] != cell.source_bases[index])
				return FALSE
		var/list/prefix = list()
		prefix += cell.destination.baseturfs
		prefix += cell.destination.type
		if(length(prefix) != length(cell.target_prefix))
			return FALSE
		for(var/index in 1 to length(prefix))
			if(prefix[index] != cell.target_prefix[index])
				return FALSE
		if(length(rebased_stack(cell.source_bases, cell.selected_index, prefix)) > 10)
			return FALSE
	return TRUE

/** Recheck layers after the caller's final callback and before any floor or gas is concealed. */
/datum/stationtrauma_docking_layers/proc/commit()
	return (!before_takeoff || before_takeoff.Invoke()) && validate()

/datum/stationtrauma_docking_layers/proc/source_depth(turf/source)
	var/datum/stationtrauma_docking_layer_cell/cell = cells[source]
	return cell ? length(cell.source_bases) - cell.selected_index + 1 : null

/** Only known owned layers may move; a hull hole cannot adopt the receiving floor or its contents. */
/datum/stationtrauma_docking_layers/proc/preflight(list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, native_rotation)
	for(var/index in 1 to length(old_turfs))
		CHECK_TICK
		var/turf/old_tile = old_turfs[index]
		var/turf/new_tile = new_turfs[index]
		if(!old_tile || !new_tile)
			return DOCKING_NULL_DESTINATION
		var/datum/stationtrauma_docking_layer_cell/cell = cells[old_tile]
		if(!cell)
			old_turfs[old_tile] = NONE
			continue
		var/area/old_area = get_area(old_tile)
		var/move_mode = areas[old_area] ? old_area.beforeShuttleMove(areas) : NONE
		for(var/atom/movable/moving_atom as anything in old_tile.contents)
			CHECK_TICK
			if(moving_atom.loc == old_tile)
				move_mode = moving_atom.beforeShuttleMove(new_tile, native_rotation, move_mode, root)
		move_mode = old_tile.fromShuttleMove(new_tile, move_mode)
		if(cell.temporary_bridge)
			move_mode |= MOVE_TURF | MOVE_CONTENTS
		move_mode = new_tile.toShuttleMove(old_tile, move_mode, root)
		if(move_mode & MOVE_AREA)
			var/area/below = root.underlying_areas_by_turf[old_tile]
			if(below)
				underlying_areas[below] = TRUE
			areas_to_move[old_area] = TRUE
		old_turfs[old_tile] = move_mode

/** This is called after the final non-sleeping movement callback and before the first native copy. */
/datum/stationtrauma_docking_layers/proc/capture()
	root.overmap?.planet_flight?.before_move(target)
	captured = TRUE
	for(var/turf/source as anything in cells)
		var/datum/stationtrauma_docking_layer_cell/cell = cells[source]
		if(cell.bottom_ship)
			cell.old_surface = cell.surfaces[cell.bottom_ship]
		else if(cell.temporary_bridge)
			cell.old_surface = cell.temporary_bridge.docking_surface
		if(isfloorturf(cell.destination))
			cell.new_surface = new(cell.destination)
			cell.new_surface.conceal(cell.destination)

/** Translate hidden floors with the internal assembly, replacing only the external substrate. */
/datum/stationtrauma_docking_layers/proc/rebase_surface(datum/stationtrauma_dock_surface/surface, datum/stationtrauma_docking_layer_cell/cell)
	if(QDELETED(surface))
		return
	var/list/old_bases = list()
	old_bases += surface.baseturfs
	if(length(old_bases) >= cell.selected_index)
		surface.baseturfs = rebased_stack(old_bases, cell.selected_index, cell.target_prefix)
	surface.rotate(rotation)

/** Rebase every vessel before native cleanup can yield and expose the new assembly. */
/datum/stationtrauma_docking_layers/proc/after_copy()
	copied = TRUE
	for(var/turf/source as anything in cells)
		var/datum/stationtrauma_docking_layer_cell/cell = cells[source]
		cell.destination.atom_colours = source.atom_colours?.Copy()
		var/list/source_colors = source.color
		cell.destination.color = islist(source_colors) ? source_colors.Copy() : source.color
		cell.destination.alpha = source.alpha
		for(var/obj/docking_port/mobile/stationtrauma_space/ship as anything in cell.indices)
			var/old_index = cell.indices[ship]
			var/list/partial = cell.source_bases.Copy(cell.selected_index, old_index + 1)
			partial -= cell.target_prefix & GLOB.blacklisted_automated_baseturfs
			ship.docking_layer_indices -= source
			ship.docking_layer_indices[cell.destination] = length(cell.target_prefix) + length(partial)
			ship.docking_surfaces -= source
			if(ship == cell.bottom_ship)
				if(cell.new_surface)
					ship.docking_surfaces[cell.destination] = cell.new_surface
					cell.new_surface = null
			else
				var/datum/stationtrauma_dock_surface/internal = cell.surfaces[ship]
				if(internal)
					rebase_surface(internal, cell)
					ship.docking_surfaces[cell.destination] = internal
		if(cell.temporary_bridge)
			var/turf/open/floor/plating/stationtrauma_dock_gangway/new_bridge = cell.destination
			if(cell.bottom_ship)
				new_bridge.docking_surface = cell.temporary_bridge.docking_surface
				rebase_surface(new_bridge.docking_surface, cell)
			else
				new_bridge.docking_surface = cell.new_surface
				cell.new_surface = null
			cell.temporary_bridge.docking_surface = null
			if(carrier.added_skipovers[source])
				var/list/bases = new_bridge.baseturfs.Copy()
				var/temporary_index = length(cell.target_prefix) + 1
				bases.Cut(temporary_index, temporary_index + 1)
				new_bridge.baseturfs = baseturfs_string_list(bases, new_bridge)
	for(var/turf/source as anything in source_tiles)
		if(cells[source] || !isspaceturf(source) || !areas[get_area(source)])
			continue
		var/area/below = root.underlying_areas_by_turf[source] || root.overmap.exterior
		if(!QDELETED(below))
			source.change_area(get_area(source), below)
		root.underlying_areas_by_turf -= source
	if(!carrier && get_turf(root) != get_turf(target))
		root.abstract_move(get_turf(target))

/** Restore the external substrate immediately after its old native source has been scraped. */
/datum/stationtrauma_docking_layers/proc/restore_source(turf/source)
	var/datum/stationtrauma_docking_layer_cell/cell = cells[source]
	if(!cell?.old_surface)
		return
	if(!QDELETED(cell.old_surface.surface_area) && get_area(source) != cell.old_surface.surface_area)
		source.change_area(get_area(source), cell.old_surface.surface_area)
	cell.old_surface.restore(source)
	QDEL_NULL(cell.old_surface)

/datum/stationtrauma_docking_layers/Destroy()
	if(captured && !copied)
		for(var/turf/source as anything in cells)
			var/datum/stationtrauma_docking_layer_cell/cell = cells[source]
			cell.new_surface?.restore(cell.destination)
			// Original snapshots remain owned by the unmoved vessel or passage.
			cell.old_surface = null
	QDEL_LIST_ASSOC_VAL(cells)
	root = null
	target = null
	carrier = null
	before_takeoff = null
	ships = null
	areas = null
	source_tiles = null
	target_tiles = null
	return ..()

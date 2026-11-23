/datum/map_generator/expedition_barren
	/// Planned terrain before it is materialized on the z-level.
	var/list/surface_terrain
	/// Predecessors of the dry routes leading back to the first pad.
	var/list/surface_routes
	/// Authored interiors are not used as a shortcut to another destination.
	var/list/ruin_interiors

/** The minimum walkable terrain accepted for routes, landings, and optional surface discoveries. */
/datum/map_generator/expedition_barren/proc/dry_surface_type(terrain)
	return ispath(terrain, /turf/open) && !ispath(terrain, /turf/open/lava) \
		&& !ispath(terrain, /turf/open/water) && !ispath(terrain, /turf/open/chasm) && !ispath(terrain, /turf/open/openspace)

/datum/map_generator/expedition_barren/proc/plan_surface(hull_width, hull_height, second_pad)
	if(hull_width + 6 > width || hull_height + 6 > width)
		return FALSE
	surface_terrain = new /list(width * width)
	surface_layout = new /list(width * width)
	ruin_interiors = new /list(width * width)
	plan_geography()
	var/whole_surface = !isnull(surface_open_percent)
	var/cave_grid = cave_system_grid(whole_surface ? surface_open_percent : null)
	for(var/y in 1 to width)
		budget?.yield()
		var/row = (y - 1) * width
		for(var/x in 1 to width)
			var/cell = row + x
			if(x <= 2 || y <= 2 || x > width - 2 || y > width - 2)
				surface_terrain[cell] = /turf/closed/indestructible/rock
				continue
			if(surface_terrain[cell])
				continue
			var/height = surface_noise(0, x, y, biome_zoom)
			var/mountain = !whole_surface && height > mountain_height
			var/edge = max(abs(x - width / 2), abs(y - width / 2)) / (width / 2) + surface_noise(4000000, x, y, 16) * edge_roughness
			if(edge > 1 || ((mountain || whole_surface) && cave_grid[cell] != "1"))
				surface_terrain[cell] = rock_type
				continue
			var/datum/biome/biome = biome_at(x, y, mountain)
			surface_terrain[cell] = biome.open_turf_type

	var/list/visited = new /list(width * width)
	var/list/land = list()
	for(var/cell in 1 to length(surface_terrain))
		if(visited[cell] || !dry_surface_type(surface_terrain[cell]))
			continue
		var/list/island = flood_surface(cell, visited)
		if(length(island) > length(land))
			land = island
	if(!length(land))
		return FALSE
	var/list/primary = find_pad(land, hull_width, hull_height)
	if(!primary)
		// A sharply broken surface can still have a landing cut out around a point of existing dry land.
		var/cell = pick(land)
		var/x = clamp((cell - 1) % width + 1 - round(hull_width / 2), 4, width - hull_width - 2)
		var/y = clamp(round((cell - 1) / width) + 1 - round(hull_height / 2), 4, width - hull_height - 2)
		primary = list(x, y, x + hull_width - 1, y + hull_height - 1)
	add_landing_clearing(primary)
	var/list/connected = refresh_surface_routes()
	if(second_pad)
		var/list/secondary = find_pad(connected, hull_width, hull_height, primary, round(width / 4))
		if(!secondary)
			secondary = find_pad(connected, hull_width, hull_height, primary)
		if(secondary)
			add_landing_clearing(secondary)
			refresh_surface_routes()
			protect_surface_route(pad_centre(secondary))
	return TRUE

/** Flood a natural dry component. The recorded predecessor always leads back to its entry cell. */
/datum/map_generator/expedition_barren/proc/flood_surface(start, list/previous)
	var/list/queue = list(start)
	previous[start] = start
	var/list/steps = list(-width, -1, 1, width)
	var/size = length(surface_terrain)
	for(var/index = 1; index <= length(queue); index++)
		budget?.yield()
		var/here = queue[index]
		var/column = (here - 1) % width
		for(var/step in steps)
			if((step == -1 && !column) || (step == 1 && column == width - 1))
				continue
			var/next = here + step
			if(next < 1 || next > size || previous[next] || ruin_interiors[next] || !dry_surface_type(surface_terrain[next]))
				continue
			previous[next] = here
			queue += next
	return queue

/datum/map_generator/expedition_barren/proc/pad_centre(list/rect)
	return (round((rect[2] + rect[4]) / 2) - 1) * width + round((rect[1] + rect[3]) / 2)

/datum/map_generator/expedition_barren/proc/refresh_surface_routes()
	surface_routes = new /list(width * width)
	return flood_surface(pad_centre(landing_pads[1]), surface_routes)

/** Look for sufficient unbroken ground connected to the other landing. */
/datum/map_generator/expedition_barren/proc/find_pad(list/land, hull_width, hull_height, list/other, minimum_gap = 0)
	for(var/attempt in 1 to 140)
		budget?.yield()
		var/cell = pick(land)
		var/x = (cell - 1) % width + 1 - round(hull_width / 2)
		var/y = round((cell - 1) / width) + 1 - round(hull_height / 2)
		var/right = x + hull_width - 1
		var/top = y + hull_height - 1
		if(x < 4 || y < 4 || right > width - 3 || top > width - 3)
			continue
		if(other && (x <= other[3] + 4 && right >= other[1] - 4 && y <= other[4] + 4 && top >= other[2] - 4))
			continue
		if(other && max(abs(x - other[1]), abs(y - other[2])) < minimum_gap)
			continue
		var/clear = TRUE
		for(var/ty in y - 1 to top + 1)
			for(var/tx in x - 1 to right + 1)
				var/terrain = surface_terrain[(ty - 1) * width + tx]
				if(!dry_surface_type(terrain) && !ispath(terrain, /turf/closed/mineral))
					clear = FALSE
					break
			if(!clear)
				break
		if(clear)
			return list(x, y, right, top)
	return null

/** Reserve the exact pad and one tile around it inside a softly irregular clearing. */
/datum/map_generator/expedition_barren/proc/add_landing_clearing(list/rect)
	landing_pads += list(rect)
	var/mx = (rect[1] + rect[3]) / 2
	var/my = (rect[2] + rect[4]) / 2
	var/rx = (rect[3] - rect[1]) / 2 + 6
	var/ry = (rect[4] - rect[2]) / 2 + 6
	for(var/y in max(3, round(my - ry * 1.25)) to min(width - 2, round(my + ry * 1.25)))
		budget?.yield()
		for(var/x in max(3, round(mx - rx * 1.25)) to min(width - 2, round(mx + rx * 1.25)))
			var/cell = (y - 1) * width + x
			var/terrain = surface_terrain[cell]
			if(x >= rect[1] - 1 && x <= rect[3] + 1 && y >= rect[2] - 1 && y <= rect[4] + 1)
				surface_terrain[cell] = floor_type
				surface_layout[cell] = TRUE
				continue
			if(!dry_surface_type(terrain) && !ispath(terrain, /turf/closed/mineral))
				continue
			var/distance = ((x - mx) / rx) ** 2 + ((y - my) / ry) ** 2
			if(distance <= 0.55 + 0.95 * surface_noise(5000000, x, y, 7))
				if(!dry_surface_type(terrain))
					surface_terrain[cell] = floor_type
				surface_layout[cell] = TRUE

/** Protect an existing route against later templates, flora, and hazardous spawns. */
/datum/map_generator/expedition_barren/proc/protect_surface_route(cell)
	var/parent = surface_routes[cell]
	while(parent && parent != cell)
		surface_layout[cell] = TRUE
		cell = parent
		parent = surface_routes[cell]

/datum/map_generator/expedition_barren/proc/surface_noise(salt, x, y, scale)
	return text2num(rustg_noise_get_at_coordinates("[seed + salt]", "[x / scale]", "[y / scale]"))

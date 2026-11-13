/area
	/// Null retains the native background; expedition areas choose a native layer explicitly.
	var/space_parallax_background
	/// Optional fixed orbital planet layer, independent of the moving space background.
	var/space_parallax_planet

/area/shuttle/stationtrauma_space
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/// Navigation owns a hull's motion: native docking would take the berth's still background mid-manoeuvre.
/area/shuttle/stationtrauma_space/onShuttleMove(turf/oldT, turf/newT, obj/docking_port/mobile/shuttle, area/fallback_area)
	var/motion = parallax_movedir
	. = ..()
	set_parallax_movedir(motion)

/// These hulls never use native transit, so the native "docked means still" rule does not apply.
/area/shuttle/stationtrauma_space/afterShuttleMove(new_parallax_dir)
	return ..(parallax_movedir)

/area/space/stationtrauma_space_home
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/stationtrauma_space_site
	space_parallax_background = /atom/movable/screen/parallax_layer/layer_3

/area/stationtrauma_space_site/asteroid
	space_parallax_background = /atom/movable/screen/parallax_layer/random/asteroids

/datum/space_level
	/// Explicit native background layer type; null retains native selection.
	var/space_parallax_background

/** Select an explicit native layer and notify subscribed viewers on change. */
/area/proc/set_space_parallax_background(background, planet)
	SHOULD_CALL_PARENT(TRUE)
	if(space_parallax_background == background && space_parallax_planet == planet)
		return
	space_parallax_background = background
	space_parallax_planet = planet
	SEND_SIGNAL(src, COMSIG_AREA_SPACE_PARALLAX_CHANGED)

/** Explicit area profiles take precedence over the ship level's station trait. */
/proc/stationtrauma_space_parallax(atom/viewpoint)
	var/turf/tile = get_turf(viewpoint)
	if(!tile)
		return null
	var/area/location = get_area(tile)
	if(location.space_parallax_background)
		// A hull arriving on its flight level still carries the station profile until native docking returns.
		if(location.space_parallax_background == /atom/movable/screen/parallax_layer/planet && !is_station_level(tile.z))
			return /atom/movable/screen/parallax_layer/layer_3
		return location.space_parallax_background
	var/datum/space_level/level = SSmapping.get_level(tile.z)
	if(level?.space_parallax_background)
		return level.space_parallax_background
	if(!SSmapping.current_map?.space_overmap && !length(SSstationtrauma_space_voyage.sectors))
		return null
	return is_station_level(tile.z) ? /atom/movable/screen/parallax_layer/planet : /atom/movable/screen/parallax_layer/layer_3

/atom/movable/screen/parallax_home
	/// Last selected parallax profile, used to avoid unnecessary layer rebuilds.
	var/space_background
	/// Last orbital layer type, so a biome change refreshes the planet without changing the star field.
	var/space_planet

/atom/movable/screen/parallax_home/set_perspective_area(area/new_area)
	if(perspective_area == new_area)
		return ..()
	if(perspective_area)
		UnregisterSignal(perspective_area, COMSIG_AREA_SPACE_PARALLAX_CHANGED)
	. = ..()
	RegisterSignal(new_area, COMSIG_AREA_SPACE_PARALLAX_CHANGED, PROC_REF(space_background_changed))

/** Refresh the viewer after its current area changes the native background profile. */
/atom/movable/screen/parallax_home/proc/space_background_changed(datum/source)
	SIGNAL_HANDLER
	update_parallax()

/atom/movable/screen/parallax_home/update_parallax()
	var/background = stationtrauma_space_parallax(perspective)
	var/area/location = get_area(perspective)
	var/planet = location?.space_parallax_planet
	if(background != space_background)
		space_background = background
		space_planet = planet
		// Cancel old layer timers before replacement, then let the native update restore motion.
		set_parallax_movedir(NONE, TRUE)
		regenerate_layers()
	else if(planet != space_planet)
		space_planet = planet
		// Slot three is the native planet; replace only it, preserving every moving star/gas layer.
		if(layers_to_draw >= 3 && length(parallax_layers_cached) >= 3)
			var/atom/movable/screen/parallax_layer/old_planet = parallax_layers_cached[3]
			var/timer = LAZYACCESS(parallax_animate_timers, old_planet)
			if(timer)
				deltimer(timer)
				parallax_animate_timers -= old_planet
			var/atom/movable/screen/parallax_layer/new_planet = generate_space_layer(3)
			parallax_layers_cached[3] = new_planet
			if(displaying_layers)
				vis_contents -= old_planet
				vis_contents |= new_planet
			qdel(old_planet)
	return ..()

/** Preserve native quality settings without inheriting the round-wide random asteroid/gas layer. */
/atom/movable/screen/parallax_home/generate_space_layer(index)
	var/area/location = get_area(perspective)
	var/planet = location?.space_parallax_planet
	if(index == 3 && planet)
		return new planet(null, null, src)
	var/background = stationtrauma_space_parallax(perspective)
	if(background)
		if(index == 4)
			var/layer_type = background == /atom/movable/screen/parallax_layer/planet ? /atom/movable/screen/parallax_layer/layer_3 : background
			return new layer_type(null, null, src)
		if(index == 5)
			return background == /atom/movable/screen/parallax_layer/random/asteroids ? new /atom/movable/screen/parallax_layer/layer_3(null, null, src) : null
	return ..()

/atom/movable/screen/parallax_layer/planet/on_z_change(atom/source)
	// SIGNAL_HANDLER is inherited from the original definition; redeclaring it breaks DreamChecker.
	. = ..()
	var/background = stationtrauma_space_parallax(home?.perspective)
	if(background)
		SetInvisibility(background == /atom/movable/screen/parallax_layer/planet ? INVISIBILITY_NONE : INVISIBILITY_ABSTRACT, id = type)

/datum/stationtrauma_overmap/space
	/// Last selected parallax profile, used to avoid unnecessary layer rebuilds.
	var/space_background
	/// Last orbital planet layer type published to the hull and its flight level.
	var/space_planet

/**
 * A single world drawn over the native space layers without tiling.
 *
 * Like the native station planet it shifts with the viewer's own movement, but it takes no part in the hull's motion loop.
 */
/atom/movable/screen/parallax_layer/expedition_planet
	icon = 'modular_bandastation/space_overmap/icons/planets.dmi'
	icon_state = "barren"
	blend_mode = BLEND_OVERLAY
	absolute = TRUE
	speed = 3
	layer = 30

/atom/movable/screen/parallax_layer/expedition_planet/update_o(new_view)
	return

/atom/movable/screen/parallax_layer/expedition_planet/frozen
	icon_state = "frozen"

/atom/movable/screen/parallax_layer/expedition_planet/arid
	icon_state = "arid"

/atom/movable/screen/parallax_layer/expedition_planet/lush
	icon_state = "lush"

/atom/movable/screen/parallax_layer/expedition_planet/lava
	icon_state = "lava"

/// The barren world darkened to ash by its war.
/atom/movable/screen/parallax_layer/expedition_planet/dead
	icon_state = "barren"
	color = "#8a7c6c"

/// The station's own native planet, seen from a flight level near the station.
/atom/movable/screen/parallax_layer/expedition_planet/station
	icon = 'icons/effects/parallax.dmi'
	icon_state = "planet"

/** Show the nearest charted world in the existing approach band, including descent/ascent but not the surface. */
/datum/stationtrauma_overmap/space/proc/parallax_planet()
	if(!vessel || jump_phase >= HYPERSPACE_LAUNCH)
		return null
	var/datum/stationtrauma_overmap_site/space/planet/approaching = approach_site
	if(istype(approaching) && !approaching.failed)
		if(approach_departing || vessel.z != approaching.berth?.z)
			return approaching.parallax_layer
		return null
	if(docked && vessel.z == docked.berth?.z && (docked.landing || docked.physical_docking))
		return null
	var/closest_distance = INFINITY
	var/closest_layer
	for(var/id in sites)
		var/datum/stationtrauma_overmap_site/space/site = sites[id]
		var/datum/stationtrauma_overmap_site/space/planet/planet = site
		// The station's planet stays in view from the flight level while the hull is near it.
		// Trade outposts dock physically too, but only the station itself orbits its planet.
		var/layer = istype(planet) ? planet.parallax_layer : site.physical_docking && site.berth && is_station_level(site.berth.z) ? /atom/movable/screen/parallax_layer/expedition_planet/station : null
		if(!layer || site.failed || !knows_site(site))
			continue
		// A just-relocated hull can reach the surface before dock() publishes its destination.
		if(site.berth && vessel.z == site.berth.z)
			continue
		var/distance = distance_to(site)
		if(distance <= radius + site.radius + ST_NAV_APPROACH + 5 && distance < closest_distance)
			closest_distance = distance
			closest_layer = layer
	return closest_layer

/** Choose the ship background from its dock or the current asteroid region. */
/datum/stationtrauma_overmap/space/proc/parallax_background()
	// The station background belongs to the station level: a hull already moved to its flight level sees open space.
	if(docked?.physical_docking && vessel.z == docked.berth?.z && is_station_level(vessel.z))
		return /atom/movable/screen/parallax_layer/planet
	for(var/datum/stationtrauma_overmap_zone/zone as anything in zones)
		if(zone.kind == "asteroids" && (pos_x - zone.pos_x) ** 2 + (pos_y - zone.pos_y) ** 2 <= zone.radius ** 2)
			return /atom/movable/screen/parallax_layer/random/asteroids
	return /atom/movable/screen/parallax_layer/layer_3

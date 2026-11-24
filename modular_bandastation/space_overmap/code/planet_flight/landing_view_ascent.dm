// Adapted from Voidcrew PR #588 (Jackriip), AGPL-3.0. See ../../ATTRIBUTION.md.

/**
 * # The climb, seen from aboard
 *
 * Starts the moment the hull leaves its berth for transit (L), over a picture of the ground it just stood on,
 * so nothing outside changes as it goes. Then, in step with what the people on the ground see of the ship
 * (a level lift, then off toward the bow):
 *
 * | from    | what                                                                                  |
 * |---------|---------------------------------------------------------------------------------------|
 * | L       | the ground falls away and starts to slide astern, dust blowing out from under the hull |
 * | L+1s    | the ground slides off sternward faster as the ship gathers way, haze thickening       |
 * | L+3.3s  | into the cloud: everything white                                                      |
 * | L+4.1s  | out of its top: the white thins into the sky's colour, and the sky darkens             |
 * | L+4.8s  | the planet, whole, falling away under the ship until it is the size it has from orbit |
 *
 * Made while the engines wind up, using the saved tiles beneath the hull for the first frame. When it is done the view of the planet
 * from above takes over (see /datum/landing_view/hover), or it fades out if the ship is already somewhere else.
 */

/// The view from aboard of this ship's climb out: made ready as its engines wind up, gone when the climb is over
/datum/landing_view/ascent
	/// The ship climbing out, which holds us
	var/datum/stationtrauma_overmap/space/navigation
	/// world.time the hull left the ground; null while it is still on it
	var/liftoff
	/// The way the bow points, as a step on the ground picture and on the screen
	var/bow_dir = NORTH
	var/bow_x = 0
	var/bow_y = 0
	var/screen_bow_x = 0
	var/screen_bow_y = 0

/**
 * * berth_turfs - the turfs it stands on, or stood on
 * * bow_dir - the way its bow points on the berth
 */
/datum/landing_view/ascent/New(obj/docking_port/mobile/shuttle, list/berth_turfs, datum/stationtrauma_overmap_site/space/planet/site, bow_dir, datum/stationtrauma_overmap/space/navigation)
	. = ..(shuttle, null, berth_turfs, 0)
	if(ended)
		return
	src.navigation = navigation
	src.bow_dir = bow_dir
	palette = landing_view_palette_for(site)
	bow_x = (bow_dir & EAST) ? 1 : ((bow_dir & WEST) ? -1 : 0)
	bow_y = (bow_dir & NORTH) ? 1 : ((bow_dir & SOUTH) ? -1 : 0)
	prepare_ground(navigation.vessel.docking_surfaces)
	shadow = add_picture()

/datum/landing_view/ascent/Destroy(force)
	if(navigation?.planet_ascent == src)
		navigation.planet_ascent = null
	navigation = null
	return ..()

/**
 * The hull has just left its berth for transit.
 * * hull_turfs - where it stands now
 * * planet_turfs - the berth turfs it left, in the same order
 * * rotation - clockwise degrees from its heading in transit to its heading on the berth
 */
/datum/landing_view/ascent/proc/lift_off(list/hull_turfs, list/planet_turfs, rotation)
	if(ended || liftoff)
		return
	if(!set_ground(planet_turfs) || !attach(hull_turfs, rotation))
		qdel(src)
		return
	liftoff = world.time
	// the people aboard went with the hull: what they hold goes with them
	sync_viewers()
	ground.held_back = FALSE
	close.held_back = FALSE
	light.held_back = FALSE
	// the ground's light is still on the hull's edge (see takeoff()): it gives way to the stars' as it climbs
	fade_light(1, 0, 2.6 SECONDS)
	var/screen_bow = rotation ? turn(bow_dir, rotation) : bow_dir
	screen_bow_x = (screen_bow & EAST) ? 1 : ((screen_bow & WEST) ? -1 : 0)
	screen_bow_y = (screen_bow & NORTH) ? 1 : ((screen_bow & SOUTH) ? -1 : 0)
	add_ground()
	add_clouds()
	add_planet()
	sync_viewers()
	cue('modular_bandastation/space_overmap/sound/landing/launch.ogg', 60, 3 SECONDS, 0.06)
	addtimer(CALLBACK(src, PROC_REF(finish)), ST_PLANET_ASCENT_LENGTH)

/// The climb is over. The planet is left where it is, under a ship still over it, for the view from orbit to take up.
/datum/landing_view/ascent/proc/finish()
	if(ended)
		return
	var/datum/stationtrauma_overmap/space/flight_navigation = navigation
	if(flight_navigation?.planet_ascent == src)
		flight_navigation.planet_ascent = null
		if(flight_navigation.planet_hover_site())
			qdel(src)
			flight_navigation.update_planet_hover(FALSE)
			return
	fade_away()

/// The ground it stood on, falling away and sliding off astern, and its shadow left behind on it
/datum/landing_view/ascent/proc/add_ground()
	// height gained under steady thrust, and way gathered once it starts to move off: sampled, so the motion is smooth
	for(var/step in 0 to 21)
		var/seconds = step * 0.2
		var/when = liftoff + seconds * 10
		ground.scale.mark(when, 1 / (1 + (seconds / 2.4) ** 2))
		// moving off from the first moment, slowly at first
		var/slid = 1.2 * seconds ** 2.2
		ground.slide_x.mark(when, bow_x * slid)
		ground.slide_y.mark(when, bow_y * slid)
		// the shadow stays on the ground, and falls further off to one side the higher the hull is
		var/lean = min(seconds * 2.6, 9)
		shadow.slide_x.mark(when, bow_x * slid - lean)
		shadow.slide_y.mark(when, bow_y * slid + lean)
	// gone once the sky has closed over it
	ground.alpha.mark(liftoff + 3.7 SECONDS, 255)
	ground.alpha.mark(liftoff + 3.8 SECONDS, 0)
	ground.drop_at = liftoff + 3.9 SECONDS
	chain_ground(ground, close)
	show(ground)
	show(close)
	// past the reach of those pictures there is only cloud, closing in as the ground falls away
	var/datum/landing_track/veil_alpha = veil_fade(ground.scale)
	for(var/for_light in list(FALSE, TRUE))
		var/datum/landing_view_piece/veil = add_picture()
		veil.parts = cloud_veil(for_light)
		veil.scale = ground.scale
		veil.alpha = veil_alpha
		veil.slide_x = ground.slide_x
		veil.slide_y = ground.slide_y
		veil.drop_at = liftoff + 3.9 SECONDS
		show(veil)
	// the light on it goes with it, and lets go as the haze closes over it
	light.scale = ground.scale
	light.slide_x = ground.slide_x
	light.slide_y = ground.slide_y
	light.alpha.mark(liftoff, 255)
	light.alpha.mark(liftoff + 3.7 SECONDS, 255)
	light.alpha.mark(liftoff + 3.8 SECONDS, 0)
	light.drop_at = liftoff + 3.9 SECONDS
	show(light)
	// and the open sky's light closes over it with the haze and the cloud
	var/datum/landing_track/cloud_light = new
	cloud_light.mark(liftoff + 2.2 SECONDS, 0)
	cloud_light.mark(liftoff + 3.5 SECONDS, 255, LANDING_CURVE_IN)
	add_daylight(cloud_light)

	shadow.parts = list(list(landing_view_shadow_look(berth_turfs, ground_x, ground_y), 0, 0, 1))
	shadow.scale.mark(liftoff, 1)
	shadow.scale.mark(liftoff + 1.2 SECONDS, 1.2, LANDING_CURVE_BOTH)
	shadow.scale_with = ground.scale
	shadow.alpha.mark(liftoff, 0)
	shadow.alpha.mark(liftoff + 0.3 SECONDS, 140)
	shadow.alpha.mark(liftoff + 1.4 SECONDS, 110)
	shadow.alpha.mark(liftoff + 2.8 SECONDS, 0)
	show(shadow)

	var/datum/landing_view_piece/haze = add_sky(LANDING_VIEW_LAYER_HAZE, fill = palette.sky)
	haze.alpha.mark(liftoff + 0.8 SECONDS, 0)
	haze.alpha.mark(liftoff + 2.4 SECONDS, 110)
	haze.alpha.mark(liftoff + 3.4 SECONDS, 235)
	haze.alpha.mark(liftoff + 3.8 SECONDS, 235)
	haze.alpha.mark(liftoff + 3.9 SECONDS, 0)
	show(haze)

/// Through the cloud and out of its top
/datum/landing_view/ascent/proc/add_clouds()
	var/datum/landing_view_piece/sky = add_sky(LANDING_VIEW_LAYER_SKY, fill = palette.sky)
	sky.alpha.mark(liftoff + 2.8 SECONDS, 0)
	sky.alpha.mark(liftoff + 3.6 SECONDS, 255, LANDING_CURVE_BOTH)
	// thinning as soon as the white has gone: a flat sky is a dead moment
	sky.alpha.mark(liftoff + 4.7 SECONDS, 255)
	sky.alpha.mark(liftoff + 6.4 SECONDS, 0, LANDING_CURVE_BOTH)
	show(sky)

	var/datum/landing_view_piece/inside = add_sky(LANDING_VIEW_LAYER_CLOUD + 1, fill = palette.cloud)
	inside.alpha.mark(liftoff + ST_PLANET_ASCENT_CLOUD, 0)
	inside.alpha.mark(liftoff + 3.8 SECONDS, 250, LANDING_CURVE_IN)
	inside.alpha.mark(liftoff + 4.1 SECONDS, 250)
	inside.alpha.mark(liftoff + ST_PLANET_ASCENT_ORBIT, 0, LANDING_CURVE_OUT)
	show(inside)

	// mist streaming past while the ship is inside it, so the white is never still
	var/datum/landing_view_piece/mist = add_sky(LANDING_VIEW_LAYER_CLOUD + 1.5, LANDING_VIEW_ICON, "wisps", LANDING_VIEW_ICON_SIZE)
	mist.sky.color = palette.sky
	mist.turn = 73
	mist.scale.mark(liftoff + 3.2 SECONDS, 6.5)
	mist.scale.mark(liftoff + ST_PLANET_ASCENT_ORBIT, 2.2)
	mist.alpha.mark(liftoff + 3.2 SECONDS, 0)
	mist.alpha.mark(liftoff + 3.7 SECONDS, 120)
	mist.alpha.mark(liftoff + 4.2 SECONDS, 120)
	mist.alpha.mark(liftoff + ST_PLANET_ASCENT_ORBIT, 0)
	show(mist)

/// The planet whole, falling away under the ship until it is as big as it is from orbit
/datum/landing_view/ascent/proc/add_planet()
	var/list/planet = new_planet()
	var/list/grains = planet[1]
	var/datum/landing_view_piece/whole = grains[1][1]
	var/datum/landing_track/size = whole.scale
	// not as close as a descent leaves it: this near, its texture shows its grain, and here there is no cloud over it
	size.mark(liftoff + 4.6 SECONDS, 4.2)
	size.mark(liftoff + 8.6 SECONDS, LANDING_HOVER_SIZE, LANDING_CURVE_BOTH)
	// there, solid, under the sky before the sky thins: a planet that fades in lets the stars show through it
	var/datum/landing_track/opacity = new
	opacity.mark(liftoff + 4.6 SECONDS, 0)
	opacity.mark(liftoff + 4.7 SECONDS, 255)
	chain_detail(grains, size, opacity, LANDING_PLANET_DETAIL)
	var/datum/landing_view_piece/shade = planet[2]
	shade.alpha = opacity
	show(shade)

	var/datum/landing_view_piece/air = new_air(whole)
	air.alpha.mark(liftoff + 4.6 SECONDS, 0)
	air.alpha.mark(liftoff + 4.7 SECONDS, 235)
	show(air)

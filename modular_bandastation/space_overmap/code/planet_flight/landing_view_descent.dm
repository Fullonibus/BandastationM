// Adapted from Voidcrew PR #588 (Jackriip), AGPL-3.0. See ../../ATTRIBUTION.md.

/**
 * # The descent, seen from aboard
 *
 * Timings below are in donor seconds before touchdown (T), scaled for Primera.
 *
 * | from     | what                                                                                    |
 * |----------|-----------------------------------------------------------------------------------------|
 * | start    | the planet under the ship, swelling until its rim has left the screen                   |
 * | T-9.2s   | heat: the hull's edge glows and sheds sparks, streaks fly out past it                    |
 * | T-8.4s   | the planet thins into the colour of its own sky                                          |
 * | T-6.2s   | into the planet's cloud: everything white, mist streaming past                           |
 * | T-5.2s   | out of the cloud's underside over the real ground, small and hazy, rushing up            |
 * | T-4.6s   | as the cloud thins the ground's own light takes over from the open sky's: a cave is dark |
 * | T-2.7s   | the light on the hull's edge turns from the stars' to the ground's                       |
 * | T-1.4s   | the thrusters reach the ground: dust blows out from under the hull                       |
 * | T-0.3s   | the ground is at full size; the ship hangs on its thrusters until the hull really moves |
 *
 * The ground is the real terrain around the berth, so when the hull moves onto it nothing outside changes.
 */

/// Size of the ground when it comes out of the cloud
#define DESCENT_GROUND_START 0.3

/// The view from aboard, for the length of this descent
/datum/landing_animation/var/datum/landing_view/descent/inside_view

/datum/landing_view/descent
	/// world.time the hull is expected to move
	var/touchdown

/datum/landing_view/descent/New(obj/docking_port/mobile/shuttle, list/hull_turfs, list/berth_turfs, rotation, datum/stationtrauma_overmap_site/space/planet/site)
	. = ..()
	if(ended)
		return
	palette = landing_view_palette_for(site)
	prepare_ground()

/// Switch from the orbital disk at its current scale to the donor's final atmospheric sequence.
/datum/landing_view/descent/proc/start(touchdown, planet_size)
	if(ended)
		return
	src.touchdown = touchdown
	add_planet(planet_size)
	add_heat()
	add_clouds()
	add_ground()
	sync_viewers()
	addtimer(CALLBACK(src, PROC_REF(fade_light), 0, 1, (2.2 SECONDS) * ST_PLANET_DESCENT_SCALE), max(0, before_touchdown(2.7 SECONDS) - world.time), TIMER_DELETE_ME)
	cue_at(touchdown - LANDING_ENTRY_LEAD, 'modular_bandastation/space_overmap/sound/landing/entry.ogg', 65)
	cue_at(before_touchdown(6.6 SECONDS), 'modular_bandastation/space_overmap/sound/landing/clouds.ogg', 45, 1.4 SECONDS, 0.05)
	cue_at(before_touchdown(4.6 SECONDS), 'modular_bandastation/space_overmap/sound/landing/thrusters.ogg', 50)

/datum/landing_view/descent/proc/before_touchdown(offset)
	return touchdown - offset * ST_PLANET_DESCENT_SCALE

/// The planet whole, growing under the ship, then thinning into its own sky
/datum/landing_view/descent/proc/add_planet(planet_size)
	var/now = min(world.time, before_touchdown(10 SECONDS))
	var/list/planet = new_planet()
	var/list/grains = planet[1]
	var/datum/landing_view_piece/whole = grains[1][1]
	var/datum/landing_track/size = whole.scale
	size.mark(now, planet_size || LANDING_HOVER_FAR)
	size.mark(before_touchdown(6.2 SECONDS), clamp(planet_size * 1.65, 3.3, 6.4), LANDING_CURVE_BOTH)
	var/datum/landing_track/opacity = new
	if(planet_size)
		opacity.mark(now, 255)
	else
		opacity.mark(now, 0)
		opacity.mark(now + 0.6 SECONDS, 255)
	// solid until the sky has closed over it: a planet that fades lets the stars show through it
	opacity.mark(before_touchdown(6.2 SECONDS), 255)
	opacity.mark(before_touchdown(6.1 SECONDS), 0)
	chain_detail(grains, size, opacity, LANDING_PLANET_DETAIL)
	var/datum/landing_view_piece/shade = planet[2]
	shade.alpha = opacity
	show(shade)

	var/datum/landing_view_piece/air = new_air(whole)
	if(planet_size)
		air.alpha.mark(now, 235)
	else
		air.alpha.mark(now, 0)
		air.alpha.mark(now + 0.6 SECONDS, 235)
	air.alpha.mark(before_touchdown(6.2 SECONDS), 235)
	air.alpha.mark(before_touchdown(6.1 SECONDS), 0)
	show(air)

	// inside its air: the sky's own colour over everything, until the ground shows under it
	var/datum/landing_view_piece/sky = add_sky(LANDING_VIEW_LAYER_SKY, fill = palette.sky)
	sky.alpha.mark(before_touchdown(8.4 SECONDS), 0)
	sky.alpha.mark(before_touchdown(6.2 SECONDS), 255, LANDING_CURVE_BOTH)
	sky.alpha.mark(before_touchdown(5.2 SECONDS), 255)
	sky.alpha.mark(before_touchdown(4.4 SECONDS), 0)
	show(sky)

/// Heat of entry: streaks flying out past the hull, and the hull's edge glowing
/datum/landing_view/descent/proc/add_heat()
	for(var/turned in list(0, 137))
		var/datum/landing_view_piece/streaks = add_sky(LANDING_VIEW_LAYER_HEAT + 1, LANDING_VIEW_ICON, "streaks", LANDING_VIEW_ICON_SIZE)
		streaks.sky.color = palette.heat
		streaks.turn = turned
		// they fly outward: each sheet grows, and the second follows the first so there is always one coming
		var/lead = turned ? (0.9 SECONDS) * ST_PLANET_DESCENT_SCALE : 0
		streaks.scale.mark(touchdown - LANDING_ENTRY_LEAD + lead, 1.5)
		streaks.scale.mark(touchdown - LANDING_ENTRY_END, 3.4)
		streaks.alpha.mark(touchdown - LANDING_ENTRY_LEAD + lead, 0)
		streaks.alpha.mark(before_touchdown(8.4 SECONDS) + lead, 255)
		streaks.alpha.mark(before_touchdown(6.6 SECONDS), 255)
		streaks.alpha.mark(touchdown - LANDING_ENTRY_END, 0)
		show(streaks)
	// and the glow of it over everything outside, flaring and sinking
	// laid over, not added: added to a bright sky it does not show at all
	var/datum/landing_view_piece/burn = add_sky(LANDING_VIEW_LAYER_HEAT, fill = palette.heat)
	burn.alpha.mark(touchdown - LANDING_ENTRY_LEAD, 0)
	var/flare = TRUE
	for(var/moment = before_touchdown(8.6 SECONDS), moment <= before_touchdown(6.4 SECONDS), moment += (0.4 SECONDS) * ST_PLANET_DESCENT_SCALE)
		burn.alpha.mark(moment, flare ? 115 : 65, LANDING_CURVE_BOTH)
		flare = !flare
	burn.alpha.mark(touchdown - LANDING_ENTRY_END, 0)
	show(burn)
	heat_hull(touchdown - LANDING_ENTRY_LEAD, touchdown - LANDING_ENTRY_END)

/// The one layer of cloud: the planet's own, seen from afar on the planet itself, and from inside as white
/datum/landing_view/descent/proc/add_clouds()
	var/datum/landing_view_piece/inside = add_sky(LANDING_VIEW_LAYER_CLOUD + 1, fill = palette.cloud)
	inside.alpha.mark(before_touchdown(6.2 SECONDS), 0)
	inside.alpha.mark(before_touchdown(5 SECONDS), 250, LANDING_CURVE_IN)
	inside.alpha.mark(before_touchdown(4.6 SECONDS), 250)
	inside.alpha.mark(before_touchdown(3.8 SECONDS), 0, LANDING_CURVE_OUT)
	show(inside)

	// mist streaming past while the ship is inside it, so the white is never still
	var/datum/landing_view_piece/mist = add_sky(LANDING_VIEW_LAYER_CLOUD + 1.5, LANDING_VIEW_ICON, "wisps", LANDING_VIEW_ICON_SIZE)
	mist.sky.color = palette.sky
	mist.turn = 73
	mist.scale.mark(before_touchdown(6 SECONDS), 2.2)
	mist.scale.mark(before_touchdown(4 SECONDS), 6.5)
	mist.alpha.mark(before_touchdown(6 SECONDS), 0)
	mist.alpha.mark(before_touchdown(5 SECONDS), 120)
	mist.alpha.mark(before_touchdown(4.5 SECONDS), 120)
	mist.alpha.mark(before_touchdown(4 SECONDS), 0)
	show(mist)

	// haze between the ship and the ground, clearing as it comes down
	var/datum/landing_view_piece/haze = add_sky(LANDING_VIEW_LAYER_HAZE, fill = palette.sky)
	haze.alpha.mark(before_touchdown(5.2 SECONDS), 0)
	haze.alpha.mark(before_touchdown(5 SECONDS), 170)
	haze.alpha.mark(before_touchdown(1.2 SECONDS), 0)
	show(haze)

/// The real ground, rushing up to full size, and the hull's shadow tightening on it
/datum/landing_view/descent/proc/add_ground()
	ground.scale.mark(before_touchdown(5.2 SECONDS), DESCENT_GROUND_START)
	ground.scale.mark(before_touchdown(0.3 SECONDS), 1, LANDING_CURVE_OUT)
	// handed over as soon as it is made, clear and still, so that whatever a client has to fetch for it has
	// come long before it is needed; seen once the sky has covered everything
	addtimer(CALLBACK(src, PROC_REF(reveal), ground), max(0, before_touchdown(5.4 SECONDS) - world.time), TIMER_DELETE_ME)
	// and the same ground close up, once it is near enough to tell the difference
	chain_ground(ground, close)
	close.held_back = FALSE
	show(close)

	// past the reach of those pictures there is only cloud: the ground is seen through an opening in it
	var/datum/landing_track/veil_alpha = veil_fade(ground.scale)
	for(var/for_light in list(FALSE, TRUE))
		var/datum/landing_view_piece/veil = add_picture()
		veil.parts = cloud_veil(for_light)
		veil.scale = ground.scale
		veil.alpha = veil_alpha
		veil.give_at = before_touchdown(5.4 SECONDS)
		show(veil)
	// and the light on it: the white of the cloud gives way to the ground as it is lit, dark if it is dark
	light.scale = ground.scale
	// under the cloud's own light until the cloud thins: the white stays white, and the ground comes out of it lit as it is lit
	var/datum/landing_track/cloud_light = new
	cloud_light.mark(before_touchdown(4.6 SECONDS), 255)
	cloud_light.mark(before_touchdown(3.8 SECONDS), 0, LANDING_CURVE_OUT)
	add_daylight(cloud_light)
	addtimer(CALLBACK(src, PROC_REF(reveal), light), max(0, before_touchdown(5 SECONDS) - world.time), TIMER_DELETE_ME)

	// the same shadow the people on the ground see spreading over the berth (see /datum/landing_animation)
	shadow = add_picture()
	shadow.parts = list(list(landing_view_shadow_look(berth_turfs, ground_x, ground_y), 0, 0, 1))
	shadow.scale.mark(before_touchdown(3 SECONDS), 1.35)
	shadow.scale.mark(before_touchdown(1 SECONDS), 1.15, LANDING_CURVE_BOTH)
	shadow.scale.mark(touchdown, 1, LANDING_CURVE_OUT)
	shadow.scale_with = ground.scale
	// the sun is not straight overhead: from high up the shadow lies well off to one side, and it comes in
	// under the hull as the hull comes down
	shadow.slide_x.mark(before_touchdown(5 SECONDS), -9)
	shadow.slide_x.mark(before_touchdown(0.4 SECONDS), 0, LANDING_CURVE_OUT)
	shadow.slide_y.mark(before_touchdown(5 SECONDS), 9)
	shadow.slide_y.mark(before_touchdown(0.4 SECONDS), 0, LANDING_CURVE_OUT)
	shadow.alpha.mark(before_touchdown(5 SECONDS), 0)
	shadow.alpha.mark(before_touchdown(4.4 SECONDS), 100)
	shadow.alpha.mark(before_touchdown(3 SECONDS), 110)
	shadow.alpha.mark(before_touchdown(1.2 SECONDS), 140, LANDING_CURVE_BOTH)
	// and it is under the hull by the time the hull is down: a landed ship has no rim of shadow round it,
	// and one that went out as it landed would show
	shadow.alpha.mark(before_touchdown(0.5 SECONDS), 110)
	shadow.alpha.mark(before_touchdown(0.1 SECONDS), 0, LANDING_CURVE_IN)
	show(shadow)

/// The hull has started to move onto the berth
/datum/landing_view/descent/proc/touchdown()
	return

/// The hull is down: the people aboard are looking at the real ground now
/datum/landing_view/descent/proc/landed()
	qdel(src)

#undef DESCENT_GROUND_START

// Adapted from Voidcrew PR #588 (Jackriip), AGPL-3.0. See ../../ATTRIBUTION.md.

/// Space already knows which turfs are visible, including the gaps between multiz decks. Use that
/// rendering source for both the planet and its light so the picture stops naturally at the hull and at sight.
/atom/movable/screen/plane_master/landing_view
	name = "Landing view"
	documentation = "Draws the planet, atmosphere and landing site over the visible vacuum outside the hull."
	plane = LANDING_VIEW_PLANE
	appearance_flags = PLANE_MASTER | NO_CLIENT_COLOR
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_relay_planes = list(RENDER_PLANE_UNLIT_GAME)
	offsetting_flags = BLOCKS_PLANE_OFFSETTING | OFFSET_RELAYS_MATCH_HIGHEST
	multiz_scaled = FALSE

/atom/movable/screen/plane_master/landing_view/set_home(datum/plane_master_group/home)
	. = ..()
	if(.)
		RegisterSignal(home, COMSIG_PLANE_GROUP_OFFSET_CHANGED, PROC_REF(space_mask_changed))

/atom/movable/screen/plane_master/landing_view/show_to(mob/mymob)
	. = ..()
	if(.)
		update_space_mask(home.active_offset)

/atom/movable/screen/plane_master/landing_view/proc/space_mask_changed(datum/source, old_offset, new_offset)
	SIGNAL_HANDLER
	update_space_mask(new_offset)

/atom/movable/screen/plane_master/landing_view/proc/update_space_mask(offset)
	var/atom/movable/screen/plane_master/parallax_white/space = home.get_plane(GET_NEW_PLANE(PLANE_SPACE, offset))
	if(space?.render_target)
		add_filter("landing_space", 1, alpha_mask_filter(render_source = space.render_target))

/// Ground lighting covers visible space while the scene is playing and follows the same fade as the ground.
/atom/movable/screen/plane_master/landing_view/light
	name = "Landing view light"
	documentation = "Applies the landing site's light to the picture of its terrain, using the viewer's normal night vision."
	plane = LANDING_VIEW_LIGHT_PLANE
	render_relay_planes = list(RENDER_PLANE_LIGHTING)

/atom/movable/screen/plane_master/landing_view/light/Initialize(mapload, datum/hud/hud_owner, datum/plane_master_group/home, offset)
	. = ..()
	// Light on the picture overrides space's fullbright emissive exactly where this plane has visible pixels.
	add_relay_to(GET_NEW_PLANE(RENDER_PLANE_EMISSIVE, offset), relay_layer = EMISSIVE_SPACE_LAYER + 0.5, relay_color = GLOB.em_block_color)

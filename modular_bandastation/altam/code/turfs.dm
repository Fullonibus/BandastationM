// MARK: Turfs

// MARK: Бетон
/turf/open/floor/concrete
	name = "concrete floor"
	desc = "Cold, bare concrete flooring."
	icon = 'modular_bandastation/altam/icons/turf/floors/concrete.dmi'
	damaged_dmi = 'modular_bandastation/altam/icons/turf/floors/concrete.dmi'
	icon_state = "conc"
	base_icon_state = "conc"
	smoothing_groups = list(SMOOTH_GROUP_TURF_OPEN, SMOOTH_GROUP_OPEN_FLOOR)

/turf/open/floor/concrete/broken_states()
	return list("concdam_1", "concdam_2", "concdam_3", "concdam_4")

/turf/open/floor/concrete/slab
	icon_state = "conc_slab"
	base_icon_state = "conc_slab"

/turf/open/floor/concrete/smooth_half
	icon_state = "conc_smooth_half"
	base_icon_state = "conc_smooth_half"

/turf/open/floor/concrete/smooth_edge
	icon_state = "conc_smooth_edge"
	base_icon_state = "conc_smooth_edge"

/turf/open/floor/concrete/tiles
	icon_state = "conc_tiles"
	base_icon_state = "conc_tiles"

/turf/open/floor/concrete/smooth
	icon_state = "conc_smooth_1"
	base_icon_state = "conc_smooth"

/turf/open/floor/concrete/smooth/Initialize()
	. = ..()
	icon_state = "[base_icon_state]_[rand(1,4)]"

/turf/open/floor/concrete/pavement
	name = "pavement"
	desc = "A rough, durable pavement surface."
	icon_state = "pavement"
	base_icon_state = "pavement"

/turf/open/floor/concrete/pavement/Initialize()
	. = ..()
	icon_state = "[base_icon_state]_[rand(1,4)]"

// MARK: Укрепленный бетон
/turf/open/floor/reinforced_concrete
	name = "reinforced concrete floor"
	desc = "A more durable variety of concrete."
	icon = 'modular_bandastation/altam/icons/turf/floors/hexacrete.dmi'
	damaged_dmi = 'modular_bandastation/altam/icons/turf/floors/concrete.dmi'
	icon_state = "hexacrete-0"
	base_icon_state = "hexacrete"
	smoothing_flags = SMOOTH_BITMASK | SMOOTH_BORDER
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_TURF_CONCRETE
	canSmoothWith = SMOOTH_GROUP_TURF_CONCRETE
	tiled_dirt = FALSE

// MARK: Flora

//Pine
/obj/structure/flora/tree/pine
	name = "pine tree"
	desc = "A coniferous pine tree."
	icon = 'modular_bandastation/altam/icons/obj/flora/pinetrees.dmi'
	icon_state = "pine_1"
	var/list/icon_states = list("pine_1", "pine_2", "pine_3", "pine_4")

/obj/structure/flora/tree/pine/get_seethrough_map()
	return SEE_THROUGH_MAP_DEFAULT_TWO_TALL

/obj/structure/flora/tree/pine/style_2
	icon_state = "pine_2"

/obj/structure/flora/tree/pine/style_3
	icon_state = "pine_3"

/obj/structure/flora/tree/pine/style_4
	icon_state = "pine_4"

/obj/structure/flora/tree/pine/style_random/Initialize(mapload)
	. = ..()
	icon_state = "pine_[rand(1,4)]"
	update_appearance()

/obj/structure/flora/tree/stump/pine
	icon = 'modular_bandastation/altam/icons/obj/flora/pinetrees.dmi'
	icon_state = "pine_tree_stump"

// Snowless Pine
/obj/structure/flora/tree/pine/snowless
	icon_state = "snowlesspine_1"
	icon_states = list("snowlesspine_1", "snowlesspine_2", "snowlesspine_3", "snowlesspine_4")

/obj/structure/flora/tree/pine/snowless/style_2
	icon_state = "snowlesspine_2"

/obj/structure/flora/tree/pine/snowless/style_3
	icon_state = "snowlesspine_3"

/obj/structure/flora/tree/pine/snowless/style_4
	icon_state = "snowlesspine_4"

/obj/structure/flora/tree/pine/snowless/style_random/Initialize(mapload)
	. = ..()
	icon_state = "snowlesspine_[rand(1,4)]"
	update_appearance()

//Large Pine
/obj/structure/flora/tree/large_pine
	name = "large pine tree"
	desc = "A coniferous large pine tree."
	icon = 'modular_bandastation/altam/icons/obj/flora/tall_trees.dmi'
	icon_state = "large_pine_1"
	var/list/icon_states = list("large_pine_1", "large_pine_2", "large_pine_3")

/obj/structure/flora/tree/large_pine/get_seethrough_map()
	return SEE_THROUGH_MAP_DEFAULT_TWO_TALL

/obj/structure/flora/tree/large_pine/style_2
	icon_state = "large_pine_2"

/obj/structure/flora/tree/large_pine/style_3
	icon_state = "large_pine_3"

/obj/structure/flora/tree/large_pine/style_random/Initialize(mapload)
	. = ..()
	icon_state = "large_pine_[rand(1,3)]"
	update_appearance()

/obj/structure/flora/tree/large_pine/style_snow
	icon_state = "large_pine_1_snow"

//Large Tree
/obj/structure/flora/tree/large_tree
	name = "large dead tree"
	desc = "A large dead tree."
	icon = 'modular_bandastation/altam/icons/obj/flora/tall_trees.dmi'
	icon_state = "large_tree_1"
	var/list/icon_states = list("large_tree_1", "large_tree_2", "large_tree_3")

/obj/structure/flora/tree/large_tree/get_seethrough_map()
	return SEE_THROUGH_MAP_DEFAULT_THREE_TALL

/obj/structure/flora/tree/large_tree/style_2
	icon_state = "large_tree_2"

/obj/structure/flora/tree/large_tree/style_3
	icon_state = "large_tree_3"

/obj/structure/flora/tree/large_tree/style_random/Initialize(mapload)
	. = ..()
	icon_state = "large_tree_[rand(1,3)]"
	update_appearance()

/obj/structure/flora/tree/stump/large_tree
	icon = 'modular_bandastation/altam/icons/obj/flora/tall_trees.dmi'
	icon_state = "large_tree_stump"

// Snow Large Tree
/obj/structure/flora/tree/large_tree/snow
	icon_state = "snow_large_tree_1"
	icon_states = list("snow_large_tree_1", "snow_large_tree_2", "snow_large_tree_3")

/obj/structure/flora/tree/large_tree/snow/style_2
	icon_state = "snow_large_tree_2"

/obj/structure/flora/tree/large_tree/snow/style_3
	icon_state = "snow_large_tree_3"

/obj/structure/flora/tree/large_tree/snow/style_random/Initialize(mapload)
	. = ..()
	icon_state = "snow_large_tree_[rand(1,3)]"
	update_appearance()

/obj/structure/flora/tree/stump/large_tree/snow
	icon = 'modular_bandastation/altam/icons/obj/flora/tall_trees.dmi'
	icon_state = "snow_large_tree_stump"

//Grass Sticks
/obj/structure/flora/grass_sticks
	name = "stick"
	desc = "Watch your step."
	icon = 'modular_bandastation/altam/icons/obj/flora/grass-sticks.dmi'
	icon_state = "stick_1"
	flora_flags = FLORA_HERBAL

/obj/structure/flora/grass_sticks/style_2
	icon_state = "stick_2"

/obj/structure/flora/grass_sticks/style_3
	icon_state = "stick_3"

/obj/structure/flora/grass_sticks/style_4
	icon_state = "stick_4"

/obj/structure/flora/grass_sticks/style_random/Initialize(mapload)
	. = ..()
	icon_state = "stick_[rand(1, 4)]"
	update_appearance()

//Dry Grass
/obj/structure/flora/dry_grass
	name = "dry grass"
	desc = "Dead, dry grass."
	icon = 'modular_bandastation/altam/icons/obj/flora/grass-sticks.dmi'
	icon_state = "dry_grass_1"
	flora_flags = FLORA_HERBAL

/obj/structure/flora/dry_grass/style_2
	icon_state = "dry_grass_2"

/obj/structure/flora/dry_grass/style_random/Initialize(mapload)
	. = ..()
	icon_state = "dry_grass_[rand(1, 2)]"
	update_appearance()

//Tall Grass
/obj/structure/flora/tall_grass
	name = "tall grass"
	desc = "Thick clumps of grass."
	icon = 'modular_bandastation/altam/icons/obj/flora/grass-sticks.dmi'
	icon_state = "tall_grass_1"
	flora_flags = FLORA_HERBAL

/obj/structure/flora/tall_grass/style_2
	icon_state = "tall_grass_2"

/obj/structure/flora/tall_grass/style_random/Initialize(mapload)
	. = ..()
	icon_state = "tall_grass_[rand(1, 2)]"
	update_appearance()

// Dry Log
/obj/structure/flora/dry_log
	name = "dry log"
	icon_state = "dry_log"
	desc = "A dry log. It's almost rotten."
	icon = 'modular_bandastation/altam/icons/obj/flora/grass-sticks.dmi'
	density = TRUE
	resistance_flags = FLAMMABLE
	product_types = list(/obj/item/grown/log/tree = 1)
	harvest_amount_low = 2
	harvest_amount_high = 4
	harvest_message_med = "You finish chopping the log."
	harvest_verb = "chop"
	flora_flags = FLORA_WOODEN
	can_uproot = FALSE
	delete_on_harvest = TRUE


// MARK: Storage
// Бочка с вином by FF
/obj/structure/reagent_dispensers/wine_barrel
	name = "wine barrel"
	desc = "A decorative barrel laying on its side, with supposedly wine inside."
	icon = 'modular_bandastation/altam/icons/obj/misc/misc.dmi'
	icon_state = "wine_barrel"
	density = TRUE
	anchored = TRUE
	max_integrity = 100
	reagent_id = /datum/reagent/consumable/ethanol/wine
	openable = TRUE
	tank_volume = 100

// Бочка с пивом by FF
/obj/structure/reagent_dispensers/beer_barrel
	name = "beer barrel"
	desc = "A decorative barrel laying on its side, with supposedly beer inside."
	icon = 'modular_bandastation/altam/icons/obj/misc/misc.dmi'
	icon_state = "wine_barrel"
	density = TRUE
	anchored = TRUE
	max_integrity = 100
	reagent_id = /datum/reagent/consumable/ethanol/beer
	openable = TRUE
	tank_volume = 100

// Бочка с водой by FF
/obj/structure/reagent_dispensers/water_barrel
	name = "water barrel"
	desc = "A decorative barrel laying on its side, with water inside."
	icon = 'modular_bandastation/altam/icons/obj/misc/misc.dmi'
	icon_state = "water_barrel"
	density = TRUE
	anchored = TRUE
	max_integrity = 100
	reagent_id = /datum/reagent/water
	openable = TRUE
	tank_volume = 100

// Бочка ящик by FF
/obj/structure/closet/crate/wooden/storage_barrel
	name = "storage barrel"
	desc = "This barrel can't hold liquids, it can just hold things inside of it however!"
	icon_state = "barrel"
	base_icon_state = "barrel"
	icon = 'modular_bandastation/altam/icons/obj/misc/storage.dmi'
	resistance_flags = FLAMMABLE
	material_drop = /obj/item/stack/sheet/mineral/wood
	material_drop_amount = 4
	cutting_tool = /obj/item/crowbar

// Красивый смартфридге by FF
/obj/machinery/smartfridge/wooden
	name = "debug wooden smartfridge"
	desc = "You should not be seeing this!"
	icon = 'modular_bandastation/altam/icons/obj/misc/storage.dmi'
	resistance_flags = FLAMMABLE
	base_build_path = /obj/machinery/smartfridge/wooden
	icon_state = "producebin"
	base_icon_state = "producebin"
	use_power = NO_POWER_USE
	light_power = 0
	idle_power_usage = 0
	circuit = null
	has_emissive = FALSE
	integrity_failure = 0
	can_atmos_pass = ATMOS_PASS_YES
	visible_contents = TRUE
	can_be_welded_down = FALSE
	has_emissive = FALSE
	vend_sound = null

/obj/machinery/smartfridge/wooden/Initialize(mapload)
	. = ..()
	if(type == /obj/machinery/smartfridge/wooden) // don't even let these prototypes exist
		return INITIALIZE_HINT_QDEL

/obj/machinery/smartfridge/wooden/visible_items()
	return contents.len

// formerly NO_DECONSTRUCTION
/obj/machinery/smartfridge/wooden/default_deconstruction_screwdriver(mob/user, icon_state_open, icon_state_closed, obj/item/screwdriver)
	return NONE

/obj/machinery/smartfridge/wooden/default_deconstruction_crowbar(obj/item/crowbar, ignore_panel, custom_deconstruct)
	return NONE

/obj/machinery/smartfridge/wooden/default_pry_open(obj/item/crowbar, close_after_pry, open_density, closed_density)
	return NONE

/obj/machinery/smartfridge/wooden/crowbar_act(mob/living/user, obj/item/tool)
	user.balloon_alert_to_viewers("disassembling...")
	if(!tool.use_tool(src, user, 2 SECONDS, volume = 100))
		return

	deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/smartfridge/wooden/on_deconstruction(disassembled)
	new /obj/item/stack/sheet/mineral/wood(drop_location(), 10)

/obj/machinery/smartfridge/wooden/structure_examine()
	. = span_info("The whole rack can be [EXAMINE_HINT("pried")] apart.")

/obj/machinery/smartfridge/wooden/produce_bin
	name = "produce bin"
	desc = "A wooden hamper, used to hold plant products and try to keep them safe from pests."
	icon_state = "producebin"
	base_icon_state = "producebin"
	contents_overlay_icon = "produce"
	base_build_path = /obj/machinery/smartfridge/wooden/produce_bin

/obj/machinery/smartfridge/wooden/produce_bin/accept_check(obj/item/item_to_check)
	var/static/list/accepted_items = list(
		/obj/item/food/grown,
		/obj/item/grown,
		/obj/item/graft,
	)

	return is_type_in_list(item_to_check, accepted_items)

/obj/machinery/smartfridge/wooden/seed_shelf
	name = "seed shelf"
	desc = "A wooden shelf, used to hold seeds, preventing them from germinating early."
	icon_state = "seedshelf"
	base_icon_state = "seedshelf"
	contents_overlay_icon = "seed"
	base_build_path = /obj/machinery/smartfridge/wooden/seed_shelf

/obj/machinery/smartfridge/wooden/seed_shelf/accept_check(obj/item/item_to_check)
	return istype(item_to_check, /obj/item/seeds)

/obj/machinery/smartfridge/wooden/ration_shelf
	name = "ration shelf"
	desc = "A wooden shelf, used to store food... Preferably preserved."
	icon_state = "rationshelf"
	base_icon_state = "rationshelf"
	contents_overlay_icon = "ration"
	base_build_path = /obj/machinery/smartfridge/wooden/ration_shelf

/obj/machinery/smartfridge/wooden/ration_shelf/accept_check(obj/item/item_to_check)
	return (IS_EDIBLE(item_to_check) || (istype(item_to_check,/obj/item/reagent_containers/cup/bowl) && length(item_to_check.reagents?.reagent_list)))

/obj/machinery/smartfridge/wooden/produce_display
	name = "produce display"
	desc = "A wooden table with awning, used to display produce items."
	icon_state = "producedisplay"
	base_icon_state = "producedisplay"
	contents_overlay_icon = "nonfood"
	base_build_path = /obj/machinery/smartfridge/wooden/produce_display

/obj/machinery/smartfridge/wooden/produce_display/accept_check(obj/item/item_to_check)
	var/static/list/accepted_items = list(
		/obj/item/grown,
		/obj/item/bouquet,
		/obj/item/clothing/head/costume/garland,
		/obj/item/stack/sheet/cloth,
		/obj/item/stack/sheet/durathread,
		/obj/item/stack/sheet/leather,
		/obj/item/stack/sheet/mineral/wood,
		/obj/item/stack/sheet/mineral/bamboo
	)
	var/fancy_food = istype(item_to_check, /obj/item/food/grown) && item_to_check.slot_flags != NONE // mostly things like flowers
	return fancy_food || is_type_in_list(item_to_check, accepted_items)

// Заполненные холодосы
/obj/machinery/smartfridge/wooden/produce_display/full
	initial_contents = list (
		/obj/item/stack/sheet/leather = 20,
		/obj/item/bouquet/poppy = 2,
		/obj/item/bouquet = 2,
		/obj/item/stack/sheet/cloth = 10,
		/obj/item/grown/snapcorn = 10,
		/obj/item/grown/log/tree = 10
	)

/obj/machinery/smartfridge/wooden/produce_display/full/medium
	initial_contents = list (
		/obj/item/stack/sheet/leather = 10,
		/obj/item/stack/sheet/cloth = 5,
		/obj/item/grown/snapcorn = 2,
		/obj/item/grown/log/tree = 10
	)

/obj/machinery/smartfridge/wooden/produce_display/full/low
	initial_contents = list (
		/obj/item/stack/sheet/leather = 5,
		/obj/item/stack/sheet/cloth = 5
	)

/obj/machinery/smartfridge/wooden/seed_shelf/full
	initial_contents = list (
		/obj/item/seeds/apple = 5,
		/obj/item/seeds/cabbage = 5,
		/obj/item/seeds/berry = 10,
		/obj/item/seeds/corn = 20,
		/obj/item/seeds/onion = 5,
		/obj/item/seeds/potato = 10,
		/obj/item/seeds/wheat = 20
	)

/obj/machinery/smartfridge/wooden/seed_shelf/full/medium
	initial_contents = list (
		/obj/item/seeds/apple = 2,
		/obj/item/seeds/berry = 5,
		/obj/item/seeds/corn = 5,
		/obj/item/seeds/onion = 2,
		/obj/item/seeds/potato = 5,
		/obj/item/seeds/wheat = 10
	)

/obj/machinery/smartfridge/wooden/seed_shelf/full/low
	initial_contents = list (
		/obj/item/seeds/berry = 2,
		/obj/item/seeds/corn = 5,
		/obj/item/seeds/potato = 5,
		/obj/item/seeds/wheat = 5
	)

/obj/machinery/smartfridge/wooden/produce_bin/full
	initial_contents = list (
		/obj/item/food/grown/tomato = 2,
		/obj/item/food/grown/onion = 3,
		/obj/item/food/grown/greenbeans = 2,
		/obj/item/food/grown/corn = 10,
		/obj/item/food/grown/berries = 10,
		/obj/item/food/grown/apple = 5,
		/obj/item/food/grown/wheat = 15,
		/obj/item/food/grown/potato = 10
	)

/obj/machinery/smartfridge/wooden/produce_bin/full/medium
	initial_contents = list (
		/obj/item/food/grown/tomato = 2,
		/obj/item/food/grown/corn = 5,
		/obj/item/food/grown/berries = 5,
		/obj/item/food/grown/apple = 2,
		/obj/item/food/grown/wheat = 10,
		/obj/item/food/grown/potato = 5
	)

/obj/machinery/smartfridge/wooden/produce_bin/full/low
	initial_contents = list (
		/obj/item/food/grown/corn = 2,
		/obj/item/food/grown/berries = 3,
		/obj/item/food/grown/wheat = 3,
		/obj/item/food/grown/potato = 7
	)

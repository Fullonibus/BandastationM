/obj/item/seeds/kronkus
	name = "kronkus seed pack"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "A pack of highly illegal kronkus seeds.\nPossession of these seeds carries the death penalty in 7 sectors."
	icon_state = "seed-kronkus"
	plant_icon_offset = 6
	species = "kronkus"
	plantname = "Kronkus Vine"
	product = /obj/item/food/grown/kronkus
	//shitty stats, because botany is easy
	lifespan = 60
	endurance = 40
	maturation = 6
	production = 4
	growthstages = 3
	growing_icon = 'icons/obj/service/hydroponics/growing.dmi'
	reagents_add = list(/datum/reagent/consumable/nutriment = 0.05)

/obj/item/food/grown/kronkus
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	seed = /obj/item/seeds/kronkus
	name = "kronkus vine segment"
	desc = "A piece of mature kronkus vine. It exudes a sharp and noxious odor.\n\nIt can be fermented to create a crude extract used by space-barge hobos to keep awake when the engine fumes creeps into their shacks.\n\nFurther processing is said to yield kronkaine, but infoteks regarding this subject are tightly controlled."
	icon_state = "kronkus"
	filling_color = "#37946e"
	foodtypes = VEGETABLES | TOXIC
	distill_reagent = /datum/reagent/kronkus_extract

/// Toxic intermediate made by the organic waste processor.
/datum/reagent/toxin/biomass_concentrate
	name = "Сырой концентрат биомассы"
	description = "Ядовитый полуфабрикат. Для употребления требуется обработка в раздатчике питательной пасты."
	color = "#788645"
	taste_description = "горькой жижи"
	chemical_flags = NONE
	randomized_spawns = REAGENT_SPAWN_NO_RANDOM
	toxpwr = 1

/// An emergency meal dispensed after the machine removes the toxic concentrate.
/obj/item/food/nutrient_paste
	name = "nutrient paste"
	desc = "Лоток серо-зелёной пасты. На вид съедобно. На вкус тоже, если очень хочется есть."
	icon = 'modular_bandastation/nutrient_paste/icons/nutrient_paste.dmi'
	icon_state = "portion"
	food_reagents = list(/datum/reagent/consumable/nutriment = 7)
	tastes = list("мокрого картона" = 1)
	bite_consumption = 3

/obj/item/food/nutrient_paste/make_edible()
	. = ..()
	AddComponentFrom(SOURCE_EDIBLE_INNATE, /datum/component/edible, after_eat = CALLBACK(src, PROC_REF(apply_aftertaste)))

/// One mood event per eater, refreshed on the first bite of each new portion.
/obj/item/food/nutrient_paste/proc/apply_aftertaste(mob/living/eater, mob/living/feeder, bite_count)
	if(bite_count == 1)
		eater.add_mood_event("nutrient_paste_aftertaste", /datum/mood_event/nutrient_paste_aftertaste)

/// Mild, temporary penalty from eating plain emergency paste.
/datum/mood_event/nutrient_paste_aftertaste
	description = "Во рту остался привкус мокрого картона."
	mood_change = -2
	timeout = 4 MINUTES
	event_flags = MOOD_EVENT_FOOD

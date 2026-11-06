/// Washed biofiber is ready to weave into cloth on the station's wooden loom.
/obj/item/stack/phoenix_refined_fiber
	name = "refined amber biofiber"
	singular_name = "refined amber biofiber bundle"
	desc = "Очищенное биоволокно янтарного ткача. Примените к закреплённому ткацкому станку. На один рулон биошёлка уйдут четыре единицы волокна."
	icon_state = "sheet-cotton"
	color = "#e5c982"
	w_class = WEIGHT_CLASS_SMALL
	merge_type = /obj/item/stack/phoenix_refined_fiber

/obj/item/stack/phoenix_refined_fiber/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/loomable, resulting_atom = /obj/item/stack/phoenix_biosilk, required_amount = 4)

/// Woven amber biosilk is the material for the lightweight duffel.
/obj/item/stack/phoenix_biosilk
	name = "amber biosilk"
	singular_name = "amber biosilk bolt"
	desc = "Плотная ткань из янтарного биоволокна. Из двух рулонов можно сшить янтарный вещмешок через меню создания, раздел Clothing."
	icon_state = "sheet-cloth"
	color = "#d8a55d"
	w_class = WEIGHT_CLASS_SMALL
	merge_type = /obj/item/stack/phoenix_biosilk

/// A lightweight duffel with extra room for small items.
/obj/item/storage/backpack/duffelbag/phoenix
	name = "amber biosilk duffel bag"
	desc = "Лёгкий вещмешок из янтарного биошёлка. В нём больше места для мелких вещей, и с открытой молнией он не мешает бежать."
	icon = 'modular_bandastation/phoenix/icons/phoenix_duffel.dmi'
	worn_icon = 'modular_bandastation/phoenix/icons/phoenix_duffel_worn.dmi'
	lefthand_file = 'modular_bandastation/phoenix/icons/phoenix_duffel_lefthand.dmi'
	righthand_file = 'modular_bandastation/phoenix/icons/phoenix_duffel_righthand.dmi'
	icon_state = "duffel-phoenix"
	inhand_icon_state = "duffel-phoenix"
	storage_type = /datum/storage/duffel/phoenix
	zip_slowdown = 0

/// Adds room for two more items at the standard duffel's weight limit.
/datum/storage/duffel/phoenix
	max_slots = 23

/// Sew a duffel from two bolts of woven biosilk.
/datum/crafting_recipe/phoenix_duffel
	name = "Янтарный вещмешок"
	result = /obj/item/storage/backpack/duffelbag/phoenix
	time = 5 SECONDS
	reqs = list(/obj/item/stack/phoenix_biosilk = 2)
	category = CAT_CLOTHING

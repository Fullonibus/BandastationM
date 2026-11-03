/// Sterile amber-fiber dressings specialize in controlling bleeding through the existing gauze system.
/obj/item/stack/medical/wrap/gauze/phoenix
	name = "hemostatic biobandages"
	desc = "Стерильные повязки из янтарного биоволокна. Быстрее останавливают кровотечение и выдерживают больше крови, чем обычная марля. Поддерживают переломы и ожоги как обычная медицинская марля."
	singular_name = "hemostatic biobandage"
	color = "#e5c982"
	absorption_rate = 0.25
	absorption_capacity = 10
	merge_type = /obj/item/stack/medical/wrap/gauze/phoenix

/// Preparing sterile dressings spends both the industrial fiber and a drainable antiseptic supply.
/datum/crafting_recipe/phoenix_bandages
	name = "Гемостатические биоповязки"
	result = /obj/item/stack/medical/wrap/gauze/phoenix
	result_amount = 6
	time = 5 SECONDS
	reqs = list(
		/obj/item/stack/phoenix_fiber = 2,
		/datum/reagent/space_cleaner/sterilizine = 5,
	)
	category = CAT_CHEMISTRY

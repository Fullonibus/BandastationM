/// A physical project-bound material; splitting must retain its provenance.
/obj/item/stack/phoenix_fiber
	name = "amber biofiber"
	singular_name = "amber biofiber bundle"
	desc = "Сырое биоволокно янтарного ткача. Принимается для проекта «Феникс» и закупается через карго. \
		Из двух единиц волокна и 5 ед. стерилизина можно изготовить шесть гемостатических биоповязок через меню создания, раздел Chemistry. \
		Для ткачества положите сырьё в стиральную машину, закройте дверцу и запустите цикл правым кликом."
	icon = 'icons/obj/stack_objects.dmi'
	icon_state = "sheet-cotton"
	max_amount = 50
	w_class = WEIGHT_CLASS_SMALL
	merge_type = /obj/item/stack/phoenix_fiber
	/// Identifier of the project which actually produced this material.
	var/project_id

/obj/item/stack/phoenix_fiber/Initialize(mapload, new_amount = 1, source_project_id = "")
	project_id = istext(source_project_id) ? source_project_id : ""
	return ..(mapload, new_amount, FALSE)

/obj/item/stack/phoenix_fiber/can_merge(obj/item/stack/check, inhand = FALSE)
	if(!istype(check, /obj/item/stack/phoenix_fiber))
		return FALSE
	var/obj/item/stack/phoenix_fiber/other = check
	return project_id == other.project_id && ..()

/obj/item/stack/phoenix_fiber/split_stack(amount)
	var/source_id = project_id
	var/obj/item/stack/phoenix_fiber/result = ..()
	if(result)
		result.project_id = source_id
	return result

/** Replace a physical load with the same amount of cleaned fiber in the drum. */
/obj/item/stack/phoenix_fiber/machine_wash(obj/machinery/washing_machine/washer)
	if(QDELETED(src) || loc != washer || is_cyborg || (item_flags & ABSTRACT) || (flags_1 & HOLOGRAM_1))
		return
	new /obj/item/stack/phoenix_refined_fiber(washer, amount, FALSE)
	qdel(src)

/// Nanotrasen maintains a standing purchase contract for the restored species' industrial output.
/datum/export/stack/phoenix_fiber
	cost = 150
	unit_name = "unit"
	message = "of amber biofiber"
	export_types = list(/obj/item/stack/phoenix_fiber)
	k_elasticity = 0

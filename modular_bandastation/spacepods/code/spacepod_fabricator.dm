/// Keep the native material, stock-part, queue and output machinery with a pod-only catalog.
/obj/machinery/mecha_part_fabricator/spacepod
	name = "spacepod fabricator"
	desc = "Фабрикатор деталей, брони и оборудования космических челноков."
	req_access = list()
	circuit = /obj/item/circuitboard/machine/mechfab/spacepod
	allowed_buildtypes = PODFAB

/obj/machinery/mecha_part_fabricator/spacepod/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(QDELETED(ui) || QDELETED(ui.user))
		return FALSE
	return ..()

/obj/item/circuitboard/machine/mechfab/spacepod
	name = "Spacepod Fabricator"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/mecha_part_fabricator/spacepod

/datum/design/board/spacepod_fabricator
	name = "Spacepod Fabricator Board"
	desc = "Плата инженерного фабрикатора деталей и оборудования космических челноков."
	build_type = IMPRINTER
	build_path = /obj/item/circuitboard/machine/mechfab/spacepod
	category = list(RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_FAB)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

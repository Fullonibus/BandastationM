/**
 * # Excavation designs
 *
 * The hand kit prints on any autolathe from round start (like the R&D kit). The stabiliser and the
 * spectrometer board belong to the "Xenoarchaeology" research node; the advanced depth scanner and
 * quick brush to "Advanced Excavation". Those nodes list these ids:
 *
 * - Xenoarchaeology: "xenoarch_stabiliser", "xenoarch_spectrometer"
 * - Advanced Excavation: "xenoarch_scanner_advanced", "xenoarch_brush_quick"
 */

// ===== Autolathe, from round start =====

/datum/design/xenoarch_kit
	name = "Набор для раскопок"
	desc = "Разгрузка с геологическим молотком, кистью, полевым сканером, пробоотборником и сумкой для находок."
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3, /datum/material/glass = SHEET_MATERIAL_AMOUNT, /datum/material/plastic = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/storage/belt/excavation/full
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_hammer
	name = "Геологический молоток"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/excavation/hammer
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_brush
	name = "Кисть для раскопок"
	build_type = AUTOLATHE
	materials = list(/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2, /datum/material/iron = SMALL_MATERIAL_AMOUNT)
	build_path = /obj/item/excavation/brush
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_depth_scanner
	name = "Стратиграфический сканер"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3)
	build_path = /obj/item/excavation/depth_scanner
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_core_sampler
	name = "Керновый пробоотборник"
	build_type = AUTOLATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 4)
	build_path = /obj/item/excavation/core_sampler
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_find_bag
	name = "Сумка для находок"
	build_type = AUTOLATHE
	materials = list(/datum/material/plastic = SHEET_MATERIAL_AMOUNT)
	build_path = /obj/item/storage/bag/excavation
	category = list(
		RND_CATEGORY_INITIAL,
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

// ===== Research: Xenoarchaeology =====

/datum/design/xenoarch_stabiliser
	name = "Полевой стабилизатор"
	desc = "Ручной проектор, удерживающий осыпающуюся породу, пока находку извлекают."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT, /datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT, /datum/material/silver = SMALL_MATERIAL_AMOUNT * 3)
	build_path = /obj/item/excavation/stabiliser
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/board/xenoarch_spectrometer
	name = "Плата радиоуглеродного спектрометра"
	desc = "Печатная плата радиоуглеродного спектрометра."
	build_path = /obj/item/circuitboard/machine/xenoarch_spectrometer
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

// ===== Research: Advanced Excavation =====

/datum/design/xenoarch_scanner_advanced
	name = "Продвинутый стратиграфический сканер"
	desc = "Прямо на месте определяет точную глубину находки и нужное поле породы."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2, /datum/material/uranium = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/excavation/depth_scanner/advanced
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

/datum/design/xenoarch_brush_quick
	name = "Быстрая кисть"
	desc = "Кисть для раскопок с вибрирующей головкой."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(/datum/material/plastic = SMALL_MATERIAL_AMOUNT * 2, /datum/material/iron = SMALL_MATERIAL_AMOUNT * 2, /datum/material/gold = SMALL_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/excavation/brush/quick
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_MINING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO

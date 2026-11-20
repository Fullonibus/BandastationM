// Paradise material costs are expressed as sheet counts; tg uses smaller material units.

/datum/design/basic_cell
	build_type = PROTOLATHE | AWAY_LATHE | AUTOLATHE | MECHFAB | PODFAB

/datum/design/high_cell
	build_type = PROTOLATHE | AWAY_LATHE | AUTOLATHE | MECHFAB | PODFAB

/datum/design/super_cell
	build_type = PROTOLATHE | AWAY_LATHE | MECHFAB | PODFAB

/datum/design/hyper_cell
	build_type = PROTOLATHE | AWAY_LATHE | MECHFAB | PODFAB

/datum/design/bluespace_cell
	build_type = PROTOLATHE | AWAY_LATHE | MECHFAB | PODFAB

/datum/design/spacepod_main
	name = "Space Pod Mainboard"
	build_type = PODFAB
	build_path = /obj/item/circuitboard/mecha/pod
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Детали")

/datum/design/spacepod_fp
	name = "Fore port pod frame"
	build_type = PODFAB
	build_path = /obj/item/pod_parts/pod_frame/fore_port
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Каркас")

/datum/design/spacepod_ap
	name = "Aft port pod frame"
	build_type = PODFAB
	build_path = /obj/item/pod_parts/pod_frame/aft_port
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Каркас")

/datum/design/spacepod_fs
	name = "Fore starboard pod frame"
	build_type = PODFAB
	build_path = /obj/item/pod_parts/pod_frame/fore_starboard
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Каркас")

/datum/design/spacepod_as
	name = "Aft starboard pod frame"
	build_type = PODFAB
	build_path = /obj/item/pod_parts/pod_frame/aft_starboard
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Каркас")

/datum/design/spacepod_core
	name = "Spacepod Core"
	build_type = PODFAB
	build_path = /obj/item/pod_parts/core
	construction_time = 70 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/uranium = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Детали")

/datum/design/spacepod_armor
	name = "Pod Armor (civilian)"
	build_type = PODFAB
	build_path = /obj/item/pod_parts/armor
	construction_time = 40 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 5)
	category = list("/Космические челноки/Детали")

/datum/design/spacepod_taser
	name = "Spacepod Equipment (Disabler)"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/weaponry/taser
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5)
	category = list("/Космические челноки/Оружие")

/datum/design/spacepod_btaser
	name = "Spacepod Equipment (Burst Disabler)"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/weaponry/burst_taser
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Оружие")

/datum/design/spacepod_laser
	name = "Spacepod Equipment (Laser)"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/weaponry/laser
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Оружие")

/datum/design/spacepod_solaris
	name = "Spacepod Equipment (Heavy laser)"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/weaponry/solaris
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 5, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 1, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 2)
	category = list("/Космические челноки/Оружие")

/datum/design/spacepod_mining
	name = "Spacepod Equipment (Kinetic Accelerator)"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/weaponry/mining_laser_basic
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1, /datum/material/uranium = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Шахтёрское")

/datum/design/spacepod_mining_advanced
	name = "Spacepod Equipment (Industrial Kinetic Accelerator)"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/weaponry/mining_laser
	construction_time = 20 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 1, /datum/material/diamond = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Шахтёрское")

/datum/design/spacepod_tracker
	name = "Spacepod Tracking Module"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/misc/tracker
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5)
	category = list("/Космические челноки/Модули")

/datum/design/spacepod_ore
	name = "Spacepod Ore Storage Module"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/cargo/ore
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Груз")

/datum/design/spacepod_crate
	name = "Spacepod Crate Storage Module"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/cargo/crate
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 12.5)
	category = list("/Космические челноки/Груз")

/datum/design/spacepod_seat
	name = "Spacepod Passenger Seat"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/sec_cargo/chair
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3.75, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.25)
	category = list("/Космические челноки/Груз")

/datum/design/spacepod_loot
	name = "Spacepod Loot Storage Module"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/sec_cargo/loot_box
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3.75, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.25)
	category = list("/Космические челноки/Груз")

/datum/design/spacepod_lock
	name = "Spacepod Tumbler Lock"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/lock/keyed
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.25)
	category = list("/Космические челноки/Детали")

/datum/design/spacepod_key
	name = "Spacepod Tumbler Lock Key"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/key
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.25)
	category = list("/Космические челноки/Детали")

/datum/design/spacepod_locator
	name = "Spacepod Asteroid Locator"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/locators/basic_pod_locator
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 0.5)
	category = list("/Космические челноки/Модули")

/datum/design/spacepod_locator_advanced
	name = "Advanced Spacepod Locator"
	build_type = PODFAB
	build_path = /obj/item/spacepod_equipment/locators/advanced_pod_locator
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 1, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Модули")

/datum/design/spacepod_paint
	name = "Spacepod Paint Kit"
	build_type = PODFAB
	build_path = /obj/item/pod_paint_bucket
	construction_time = 10 SECONDS
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 0.5)
	category = list("/Космические челноки/Детали")

/datum/design/spacepod_tracking_board
	name = "Spacepod Tracking Console Board"
	build_type = PODFAB
	build_path = /obj/item/circuitboard/computer/podtracker
	construction_time = 10 SECONDS
	materials = list(/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1)
	category = list("/Космические челноки/Детали")

/datum/techweb_node/spacepod_assembly
	display_name = "Сборка космических челноков"
	description = "Производство и обслуживание систем космических челноков."
	node_flags = parent_type::node_flags | TECHWEB_NODE_STARTER
	unlocked_designs = list(
		/datum/design/board/spacepod_fabricator,
		/datum/design/spacepod_main,
		/datum/design/spacepod_fp,
		/datum/design/spacepod_ap,
		/datum/design/spacepod_fs,
		/datum/design/spacepod_as,
		/datum/design/spacepod_core,
		/datum/design/spacepod_armor,
		/datum/design/spacepod_seat,
		/datum/design/spacepod_loot,
		/datum/design/spacepod_lock,
		/datum/design/spacepod_key,
		/datum/design/spacepod_paint,
		/datum/design/spacepod_tracking_board,
	)

/datum/techweb_node/spacepod_equipment
	display_name = "Оборудование космических челноков"
	description = "Производство и обслуживание систем космических челноков."
	prerequisite_nodes = list(/datum/techweb_node/spacepod_assembly, /datum/techweb_node/mech_equipment)
	unlocked_designs = list(
		/datum/design/spacepod_tracker,
		/datum/design/spacepod_ore,
		/datum/design/spacepod_crate,
		/datum/design/spacepod_mining,
		/datum/design/spacepod_locator,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
	announce_channels = list(RADIO_CHANNEL_ENGINEERING, RADIO_CHANNEL_SCIENCE)

/datum/techweb_node/spacepod_weapons
	display_name = "Вооружение космических челноков"
	description = "Производство и обслуживание систем космических челноков."
	prerequisite_nodes = list(/datum/techweb_node/spacepod_equipment, /datum/techweb_node/mech_combat)
	unlocked_designs = list(
		/datum/design/spacepod_taser,
		/datum/design/spacepod_btaser,
		/datum/design/spacepod_laser,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
	announce_channels = list(RADIO_CHANNEL_ENGINEERING, RADIO_CHANNEL_SCIENCE)

/datum/techweb_node/spacepod_advanced
	display_name = "Усовершенствованные системы челноков"
	description = "Производство и обслуживание систем космических челноков."
	prerequisite_nodes = list(/datum/techweb_node/spacepod_weapons, /datum/techweb_node/mech_energy_guns)
	unlocked_designs = list(
		/datum/design/spacepod_solaris,
		/datum/design/spacepod_mining_advanced,
		/datum/design/spacepod_locator_advanced,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)
	announce_channels = list(RADIO_CHANNEL_ENGINEERING, RADIO_CHANNEL_SCIENCE)

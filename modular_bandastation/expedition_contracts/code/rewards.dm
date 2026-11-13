// Corporate rewards: a customer's first fulfilled contract opens its hidden research node, enables its cargo pack and
// leaves a plaque at the trade hub. Nothing here is stronger than what the station already prints or orders.

/// Bulb colour of skrellian lights, as Sierra had them.
#define SKRELL_LIGHT_COLOUR "#66ccff"

/// The first contract this customer saw fulfilled pays its one-time reward; `location` is where the plaque is left.
/datum/expedition_customer/proc/first_contract_reward(atom/location)
	if(rewarded)
		return
	rewarded = TRUE
	var/list/opened = list()
	var/datum/techweb_node/node = SSresearch.techweb_nodes[reward_node]
	var/datum/techweb/science_web = locate(/datum/techweb/science) in SSresearch.techwebs
	if(node && science_web?.unhide_node(node))
		opened += "узел техсети «[node.display_name]»"
	var/datum/supply_pack/pack = SSshuttle.supply_packs[reward_pack]
	if(pack)
		pack.order_flags |= ORDER_SPECIAL_ENABLED
		opened += "набор снабжения «[pack.name]»"
	var/turf/plaque_turf = get_turf(location)
	if(plaque_turf)
		var/obj/item/plaque/plaque = new(plaque_turf)
		plaque.name = "памятная табличка [name]"
		plaque.desc = "[name] благодарит экспедиционный корпус [station_name()] за первый выполненный контракт."
		plaque.engraved = TRUE
		plaque_turf.visible_message(span_notice("[name] оставляет памятную табличку для экспедиционного корпуса."))
	GLOB.expedition_contracts.notify("[name] открывает станции [english_list(opened, "свои технологии", " и ")] и оставляет корпусу памятную табличку на торговом узле.")

// ===== Hidden research nodes =====

/// Research a corporation shares once the corps has fulfilled a contract for it.
/datum/techweb_node/expedition_contract
	abstract_type = /datum/techweb_node/expedition_contract
	node_flags = parent_type::node_flags | TECHWEB_NODE_HIDDEN
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)

/datum/techweb_node/expedition_contract/etamin
	display_name = "Протезы Etamin Industry"
	description = "Лицензия Etamin Industry на печать её стандартных протезов в экзофабрикаторе."
	prerequisite_nodes = list(/datum/techweb_node/augmentation)
	unlocked_designs = list(
		/datum/design/borg_l_arm/etamin,
		/datum/design/borg_r_arm/etamin,
		/datum/design/borg_l_leg/etamin,
		/datum/design/borg_r_leg/etamin,
	)

/datum/techweb_node/expedition_contract/tsf
	display_name = "Гражданские технологии ТСФ"
	description = "Гражданская обшивка MOD в цветах Транс-Солнечной Федерации."
	prerequisite_nodes = list(/datum/techweb_node/mod_suit)
	unlocked_designs = list(
		/datum/design/mod_plating/tsf,
	)

/datum/techweb_node/expedition_contract/skrell
	display_name = "Скрелльский быт"
	description = "Гражданская обшивка MOD в стиле Раскинта, термоиндукционный обогреватель и скрелльские светильники."
	prerequisite_nodes = list(/datum/techweb_node/mod_suit)
	unlocked_designs = list(
		/datum/design/mod_plating/raskinta,
		/datum/design/board/space_heater/skrell,
		/datum/design/skrell_light_frame,
	)

// ===== Etamin Industry: its standard limbs, the ones cargo already sells =====

/datum/design/borg_l_arm/etamin
	name = "Левая рука Etamin Industry"
	build_path = /obj/item/bodypart/arm/left/robot/etamin_industry

/datum/design/borg_r_arm/etamin
	name = "Правая рука Etamin Industry"
	build_path = /obj/item/bodypart/arm/right/robot/etamin_industry

/datum/design/borg_l_leg/etamin
	name = "Левая нога Etamin Industry"
	build_path = /obj/item/bodypart/leg/left/robot/etamin_industry

/datum/design/borg_r_leg/etamin
	name = "Правая нога Etamin Industry"
	build_path = /obj/item/bodypart/leg/right/robot/etamin_industry

// ===== MOD platings: the civilian suit in a corporation's colours =====

/// A civilian theme wearing another theme's sprites: protection, slowdown and sealing stay civilian.
/datum/mod_theme/civilian/reskin
	abstract_type = /datum/mod_theme/civilian/reskin

/datum/mod_theme/civilian/reskin/New()
	var/list/civilian = variants["civilian"]
	var/list/skin = civilian.Copy()
	skin[MOD_ICON_OVERRIDE] = 'modular_bandastation/objects/icons/obj/clothing/modsuit/mod_clothing.dmi'
	skin[MOD_WORN_ICON_OVERRIDE] = 'modular_bandastation/objects/icons/mob/clothing/modsuit/mod_clothing.dmi'
	variants = list("[default_skin]" = skin)
	return ..()

/datum/mod_theme/civilian/reskin/tsf
	name = "TSF civilian"
	desc = "Гражданский костюм в цветах морской пехоты ТСФ. Защищает не лучше обычной гражданской модели."
	extended_desc = "Лицензионная гражданская модель с обшивкой в стиле костюмов КМП Транс-Солнечной Федерации. \
		Под обшивкой — обычный гражданский костюм: без брони и без защиты от вакуума."
	default_skin = "tsf_standart"

/datum/mod_theme/civilian/reskin/raskinta
	name = "raskinta civilian"
	desc = "Гражданский костюм в черно-синих цветах Раскинта. Защищает не лучше обычной гражданской модели."
	extended_desc = "Скрелльская гражданская модель, повторяющая силуэт боевых костюмов Раскинта-Кэтиш. \
		Под обшивкой — обычный гражданский костюм: без брони и без защиты от вакуума."
	default_skin = "skrell_sdtf"

/obj/item/mod/construction/plating/tsf
	theme = /datum/mod_theme/civilian/reskin/tsf

/obj/item/mod/construction/plating/raskinta
	theme = /datum/mod_theme/civilian/reskin/raskinta

// The fork draws no plating item for these skins; the civilian one stands in.
/obj/item/mod/construction/plating/tsf/Initialize(mapload)
	. = ..()
	icon_state = "civilian-plating"

/obj/item/mod/construction/plating/raskinta/Initialize(mapload)
	. = ..()
	icon_state = "civilian-plating"

/datum/design/mod_plating/tsf
	name = "MOD TSF Civilian Plating"
	build_path = /obj/item/mod/construction/plating/tsf
	research_icon_state = "civilian-plating"

/datum/design/mod_plating/raskinta
	name = "MOD Raskinta Civilian Plating"
	build_path = /obj/item/mod/construction/plating/raskinta
	research_icon_state = "civilian-plating"

// ===== Skrellian household: an ordinary heater and light in skrellian finish =====

/obj/machinery/space_heater/skrell
	name = "термоиндукционный генератор"
	desc = "Обогреватель Krri'gli Corp на термоиндукции. Работает как обычный, только выглядит по-скрелльски."
	color = "#40e0d0"
	circuit = /obj/item/circuitboard/machine/space_heater/skrell

/obj/item/circuitboard/machine/space_heater/skrell
	name = "Thermal Induction Generator"
	build_path = /obj/machinery/space_heater/skrell

/datum/design/board/space_heater/skrell
	name = "Плата термоиндукционного генератора"
	desc = "Скрелльский обогреватель: тот же space heater в другой отделке."
	build_path = /obj/item/circuitboard/machine/space_heater/skrell

/obj/item/wallframe/light_fixture/skrell
	name = "каркас скрелльского светильника"
	desc = "Каркас светильника, который светит холодным скрелльским голубым."
	result_path = /obj/structure/light_construct/skrell

/obj/structure/light_construct/skrell
	name = "каркас скрелльского светильника"

/obj/structure/light_construct/skrell/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	if(. != ITEM_INTERACT_SUCCESS)
		return
	// shortcut: the colour lives on the built fixture; taking it apart gives back an ordinary frame.
	new_light.name = "скрелльский светильник"
	new_light.bulb_colour = SKRELL_LIGHT_COLOUR
	new_light.update(FALSE)

/datum/design/skrell_light_frame
	name = "Каркас скрелльского светильника"
	desc = "Настенный светильник с холодным голубым светом."
	build_type = PROTOLATHE
	materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2)
	build_path = /obj/item/wallframe/light_fixture/skrell
	category = list(
		RND_CATEGORY_CONSTRUCTION + RND_SUBCATEGORY_CONSTRUCTION_MOUNTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

// ===== TSF uniform: the event wardrobe without anything armoured =====

/datum/supply_pack/costumes_toys/tsf_uniform
	name = "Обмундирование ТСФ"
	desc = "Парадная одежда Транс-Солнечной Федерации без брони: накидка, пиджак, плащ и головные уборы. Доступно после контракта с ТСФ."
	cost = CARGO_CRATE_VALUE * 4
	contains = list(
		/obj/item/clothing/suit/toggle/tsf_jacket,
		/obj/item/clothing/suit/tsf_suitjacket,
		/obj/item/clothing/neck/tsf_fancy_cloak,
		/obj/item/clothing/head/hats/tsf_cap,
		/obj/item/clothing/head/hats/fedora/tsf,
		/obj/item/clothing/head/beret/tsf_marine,
	)
	order_flags = ORDER_SPECIAL
	crate_name = "ящик обмундирования ТСФ"
	crate_type = /obj/structure/closet/crate/wooden

#undef SKRELL_LIGHT_COLOUR

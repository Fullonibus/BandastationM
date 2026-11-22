/** Local demand and the price paid for each delivered unit. */
/datum/trade_hub_request
	/// Terminal description of the accepted commodity.
	var/name
	/// Type of goods accepted from the input pad.
	var/item_type
	/// First-frame item preview generated once without instantiating the requested goods.
	var/icon_base64
	/// Commodity units calculated from this hub's credit target.
	var/batch_size
	/// Number of batches in a rotating quota. Zero means the request is permanent and has no batches.
	var/batches_per_quota = 3
	/// Final credits paid per accepted unit throughout this request.
	var/unit_reward = 20
	/// Unmodified unit price stored before applying the hub's category multiplier.
	var/base_unit_reward
	/// Ordinary unit price at this hub, before any high-demand premium.
	var/regular_unit_reward
	/// Whether the hub pays a premium for this quota.
	var/high_demand = FALSE
	/// Nominal high-demand premium, before rounding the price to a whole credit.
	var/const/premium_percent = 50
	/// Category used for independent price and selection-frequency modifiers.
	var/category = "Оборудование"
	/// Relative selection weight within the replenishment group's pool.
	var/selection_weight = 1
	/// Hub's fixed price multiplier for this particular quota.
	var/price_multiplier = 1
	/// Inventory group supplied by this request.
	var/group
	/// Crates added to each offer of this group, subject to capacity.
	var/restock_amount = 2
	/// Delay after a complete batch; prototype balance value.
	var/restock_delay = 30 SECONDS
	/// Delay after the exhausted quota's final replenishment before a fresh quota; prototype balance value.
	var/renewal_delay = 2 MINUTES
	/// Units still accepted in the current quota. Null for a permanent request.
	var/remaining
	/// Units accepted for the current batch.
	var/delivered = 0
	/// Completion time, or zero if no batch is pending.
	var/ready_at = 0
	/// Cancellable callback owned by this request.
	var/restock_timer
	/// Renewal time, or zero if this request is not waiting for a fresh quota.
	var/renew_at = 0
	/// Cancellable renewal callback owned by this request.
	var/renewal_timer

/** Price a new request using the ordinary local rate to determine the size of a rotating batch. */
/datum/trade_hub_request/New(target_credits = 1000, multiplier = 1, is_high_demand = FALSE)
	. = ..()
	base_unit_reward = unit_reward
	price_multiplier = multiplier
	regular_unit_reward = max(1, round(base_unit_reward * multiplier + 0.5))
	unit_reward = regular_unit_reward
	if(batches_per_quota)
		high_demand = is_high_demand
		if(high_demand)
			unit_reward = round(regular_unit_reward * (1 + premium_percent / 100) + 0.5)
		batch_size = max(1, round(target_credits / regular_unit_reward + 0.5))
		remaining = batch_size * batches_per_quota
	if(ispath(item_type, /obj))
		var/obj/display = item_type
		icon_base64 = icon2base64(icon(initial(display.icon), icon_state = initial(display.icon_state), frame = 1))

/datum/trade_hub_request/Destroy()
	if(restock_timer)
		deltimer(restock_timer)
		restock_timer = null
	if(renewal_timer)
		deltimer(renewal_timer)
		renewal_timer = null
	return ..()

/** Every hub continuously buys back empty freight crates. */
/datum/trade_hub_request/crates
	name = "Пустые грузовые ящики"
	item_type = /obj/structure/closet/crate
	unit_reward = CARGO_CRATE_VALUE / 5
	category = "Тара"
	batches_per_quota = 0
	restock_amount = 0

/** Industrial iron shipments replenish tools. */
/datum/trade_hub_request/industrial_iron
	name = "Железные листы"
	item_type = /obj/item/stack/sheet/iron
	category = "Сырьё"
	group = "Инструменты"

/** Industrial glass shipments replenish electronics. */
/datum/trade_hub_request/industrial_glass
	name = "Стеклянные листы"
	item_type = /obj/item/stack/sheet/glass
	category = "Сырьё"
	group = "Электроника"
	restock_amount = 1

/** Manufactured rods replenish emergency supplies separately from toolmaking iron. */
/datum/trade_hub_request/industrial_extra
	name = "Металлические прутья"
	item_type = /obj/item/stack/rods
	unit_reward = 10
	category = "Сырьё"
	group = "Аварийное снабжение"

/** Medical glass shipments replenish medical equipment. */
/datum/trade_hub_request/medical_glass
	name = "Стеклянные листы"
	item_type = /obj/item/stack/sheet/glass
	category = "Сырьё"
	group = "Медоборудование"

/** Medical crop shipments replenish medication. */
/datum/trade_hub_request/medical_tomato
	name = "Томаты"
	item_type = /obj/item/food/grown/tomato
	unit_reward = 30
	category = "Продукция"
	selection_weight = 0.5
	group = "Медикаменты"
	restock_amount = 1

/** Agricultural wheat shipments replenish food supplies. */
/datum/trade_hub_request/agricultural_wheat
	name = "Пшеница"
	item_type = /obj/item/food/grown/wheat
	unit_reward = 50
	category = "Продукция"
	group = "Продукты"

/** Agricultural tomato shipments replenish livestock supplies. */
/datum/trade_hub_request/agriculture_tomato
	name = "Томаты"
	item_type = /obj/item/food/grown/tomato
	unit_reward = 30
	category = "Продукция"
	group = "Животноводство"

/** Industrial production replenishes the local tool inventory. */
/datum/trade_hub_request/industrial_power_tools
	name = "Челюсти жизни"
	item_type = /obj/item/crowbar/power
	unit_reward = 350
	group = "Инструменты"

/** Advanced surgical tools replenish medical equipment. */
/datum/trade_hub_request/medical_laser_scalpels
	name = "Лазерные скальпели"
	item_type = /obj/item/scalpel/advanced
	unit_reward = 500
	group = "Медоборудование"

/** Mutated crops support agricultural equipment imports. */
/datum/trade_hub_request/agricultural_golden_apples
	name = "Золотые яблоки"
	item_type = /obj/item/food/grown/apple/gold
	unit_reward = 150
	category = "Продукция"
	group = "Гидропоника"

/** Researched scanning modules replenish scientific supplies. */
/datum/trade_hub_request/research_phasic_scanners
	name = "Фазовые сканирующие модули"
	item_type = /obj/item/stock_parts/scanning_module/phasic
	unit_reward = 300
	category = "Компоненты"
	group = "Научные товары"

/** Manufactured shields replenish general security equipment. */
/datum/trade_hub_request/security_telescopic_shields
	name = "Телескопические щиты"
	item_type = /obj/item/shield/riot/tele
	unit_reward = 300
	group = "Снаряжение охраны"

/** Prepared celebration cakes support service supply imports. */
/datum/trade_hub_request/service_birthday_cakes
	name = "Праздничные торты"
	item_type = /obj/item/food/cake/birthday
	unit_reward = 250
	category = "Продукция"
	group = "Сервисное снабжение"

/** High-end matter bins supply corporate construction projects. */
/datum/trade_hub_request/corporate_bluespace_bins
	name = "Блюспейс-накопители материи"
	item_type = /obj/item/stock_parts/matter_bin/bluespace
	unit_reward = 110
	category = "Компоненты"
	group = "Корпоративные проекты"
	restock_amount = 1

/** High-end capacitors supply corporate construction projects. */
/datum/trade_hub_request/corporate_quadratic_capacitors
	name = "Квадратичные конденсаторы"
	item_type = /obj/item/stock_parts/capacitor/quadratic
	unit_reward = 90
	category = "Компоненты"
	group = "Корпоративные проекты"
	restock_amount = 1

/** High-end lasers supply corporate construction projects. */
/datum/trade_hub_request/corporate_quadultra_lasers
	name = "Квадроультра микролазеры"
	item_type = /obj/item/stock_parts/micro_laser/quadultra
	unit_reward = 60
	category = "Компоненты"
	group = "Корпоративные проекты"
	restock_amount = 1

/** Medical exosuit production supplies corporate construction projects. */
/datum/trade_hub_request/corporate_odysseus_torsos
	name = "Торсы «Одиссея»"
	item_type = /obj/item/mecha_parts/part/odysseus_torso
	unit_reward = 150
	selection_weight = 0.5
	group = "Корпоративные проекты"
	restock_amount = 1

/** Solid plasma sheets supply industrial cutting tools. */
/datum/trade_hub_request/industrial_plasma
	name = "Листы плазмы"
	item_type = /obj/item/stack/sheet/mineral/plasma
	unit_reward = 40
	category = "Сырьё"
	group = "Инструменты"

/** Refined gold supplies electrical contacts. */
/datum/trade_hub_request/industrial_gold
	name = "Золотые слитки"
	item_type = /obj/item/stack/sheet/mineral/gold
	unit_reward = 60
	category = "Сырьё"
	group = "Электроника"

/** Uranium sheets support emergency supply production. */
/datum/trade_hub_request/industrial_uranium
	name = "Урановые листы"
	item_type = /obj/item/stack/sheet/mineral/uranium
	unit_reward = 60
	category = "Сырьё"
	group = "Аварийное снабжение"

/** Industrial silver stocks support toolmaking. */
/datum/trade_hub_request/industrial_silver
	name = "Серебряные листы"
	item_type = /obj/item/stack/sheet/mineral/silver
	unit_reward = 50
	category = "Сырьё"
	group = "Инструменты"

/** Refined plasteel stocks support toolmaking. */
/datum/trade_hub_request/industrial_plasteel
	name = "Пласталь"
	item_type = /obj/item/stack/sheet/plasteel
	unit_reward = 80
	category = "Сырьё"
	group = "Инструменты"

/** Bulk cable supports electrical supply imports. */
/datum/trade_hub_request/industrial_cable
	name = "Кабель"
	item_type = /obj/item/stack/cable_coil
	unit_reward = 5
	category = "Сырьё"
	group = "Электроника"

/** Manufactured energy storage boards support electrical imports. */
/datum/trade_hub_request/industrial_smes_boards
	name = "Платы СМЭС"
	item_type = /obj/item/circuitboard/machine/smes
	unit_reward = 100
	category = "Компоненты"
	group = "Электроника"

/** Printed diagnostic tools support electrical imports. */
/datum/trade_hub_request/industrial_multitools
	name = "Мультитулы"
	item_type = /obj/item/multitool
	unit_reward = 50
	group = "Электроника"

/** Fabricated reinforced glass supports emergency construction. */
/datum/trade_hub_request/industrial_reinforced_glass
	name = "Армированное стекло"
	item_type = /obj/item/stack/sheet/rglass
	unit_reward = 30
	category = "Сырьё"
	group = "Аварийное снабжение"

/** Refined titanium supports emergency construction. */
/datum/trade_hub_request/industrial_titanium
	name = "Титановые листы"
	item_type = /obj/item/stack/sheet/mineral/titanium
	unit_reward = 125
	category = "Сырьё"
	group = "Аварийное снабжение"

/** Powered construction tools support emergency supplies. */
/datum/trade_hub_request/industrial_power_drills
	name = "Электродрели"
	item_type = /obj/item/screwdriver/power
	unit_reward = 200
	group = "Аварийное снабжение"

/** Manufactured health analyzers support medical equipment imports. */
/datum/trade_hub_request/medical_health_analyzers
	name = "Улучшенные анализаторы здоровья"
	item_type = /obj/item/healthanalyzer/advanced
	unit_reward = 300
	group = "Медоборудование"

/** Manufactured surgical pinches support medical equipment imports. */
/datum/trade_hub_request/medical_mechanical_pinches
	name = "Механические зажимы"
	item_type = /obj/item/retractor/advanced
	unit_reward = 300
	group = "Медоборудование"

/** Processed aloe supports medicinal supply imports. */
/datum/trade_hub_request/medical_aloe
	name = "Свежие компрессы алоэ"
	item_type = /obj/item/stack/medical/aloe/fresh
	unit_reward = 50
	category = "Продукция"
	group = "Медикаменты"
	restock_amount = 1

/** Medicinal ambrosia harvests support medication imports. */
/datum/trade_hub_request/medical_ambrosia
	name = "Амброзия обыкновенная"
	item_type = /obj/item/food/grown/ambrosia/vulgaris
	unit_reward = 60
	category = "Продукция"
	group = "Медикаменты"
	restock_amount = 1

/** Medicinal flower harvests support medication imports. */
/datum/trade_hub_request/medical_poppies
	name = "Маки"
	item_type = /obj/item/food/grown/flower/poppy
	unit_reward = 40
	category = "Продукция"
	group = "Медикаменты"
	restock_amount = 1

/** Locally printed cultivators support hydroponics imports. */
/datum/trade_hub_request/agricultural_cultivators
	name = "Культиваторы"
	item_type = /obj/item/cultivator
	unit_reward = 50
	group = "Гидропоника"

/** Locally printed secateurs support hydroponics imports. */
/datum/trade_hub_request/agricultural_secateurs
	name = "Секаторы"
	item_type = /obj/item/secateurs
	unit_reward = 75
	group = "Гидропоника"

/** Printed plant analyzers support hydroponics imports. */
/datum/trade_hub_request/agricultural_plant_analyzers
	name = "Анализаторы растений"
	item_type = /obj/item/plant_analyzer
	unit_reward = 75
	group = "Гидропоника"

/** Rice harvests support food imports. */
/datum/trade_hub_request/agricultural_rice
	name = "Рис"
	item_type = /obj/item/food/grown/rice
	unit_reward = 50
	category = "Продукция"
	group = "Продукты"

/** Corn harvests support food imports. */
/datum/trade_hub_request/agricultural_corn
	name = "Кукуруза"
	item_type = /obj/item/food/grown/corn
	unit_reward = 40
	category = "Продукция"
	group = "Продукты"

/** Potato harvests support food imports. */
/datum/trade_hub_request/agricultural_potatoes
	name = "Картофель"
	item_type = /obj/item/food/grown/potato
	unit_reward = 40
	category = "Продукция"
	group = "Продукты"

/** Animal feed crops support livestock imports. */
/datum/trade_hub_request/agricultural_cabbage
	name = "Капуста"
	item_type = /obj/item/food/grown/cabbage
	unit_reward = 40
	category = "Продукция"
	group = "Животноводство"

/** Root crop harvests support livestock imports. */
/datum/trade_hub_request/agricultural_carrots
	name = "Морковь"
	item_type = /obj/item/food/grown/carrotlike/carrot
	unit_reward = 40
	category = "Продукция"
	group = "Животноводство"

/** Pumpkin harvests support livestock imports. */
/datum/trade_hub_request/agricultural_pumpkins
	name = "Тыквы"
	item_type = /obj/item/food/grown/pumpkin
	unit_reward = 60
	category = "Продукция"
	group = "Животноводство"

/** Quantum transport electronics support research imports. */
/datum/trade_hub_request/research_quantum_boards
	name = "Платы квантовой площадки"
	item_type = /obj/item/circuitboard/machine/quantumpad
	unit_reward = 150
	category = "Компоненты"
	group = "Научные товары"

/** Researched gas analysis tools support research imports. */
/datum/trade_hub_request/research_ranged_analyzers
	name = "Дистанционные газоанализаторы"
	item_type = /obj/item/analyzer/ranged
	unit_reward = 150
	group = "Научные товары"

/** Researched surveying tools support research imports. */
/datum/trade_hub_request/research_mining_scanners
	name = "Улучшенные шахтёрские сканеры"
	item_type = /obj/item/t_scanner/adv_mining_scanner/lesser
	unit_reward = 200
	group = "Научные товары"

/** Manufactured gas analyzers support expedition supplies. */
/datum/trade_hub_request/expedition_gas_analyzers
	name = "Газоанализаторы"
	item_type = /obj/item/analyzer
	unit_reward = 50
	group = "Экспедиционное снабжение"

/** Manufactured meson glasses support expedition supplies. */
/datum/trade_hub_request/expedition_mesons
	name = "Мезонные сканеры"
	item_type = /obj/item/clothing/glasses/meson
	unit_reward = 100
	group = "Экспедиционное снабжение"

/** Manufactured positioning devices support expedition supplies. */
/datum/trade_hub_request/expedition_gps
	name = "GPS-устройства"
	item_type = /obj/item/gps
	unit_reward = 75
	group = "Экспедиционное снабжение"

/** Printed structural scanners support expedition supplies. */
/datum/trade_hub_request/expedition_t_ray_scanners
	name = "Терагерцовые сканеры"
	item_type = /obj/item/t_scanner
	unit_reward = 75
	group = "Экспедиционное снабжение"

/** Printed security barrier projectors support security equipment imports. */
/datum/trade_hub_request/security_holosign_projectors
	name = "Генераторы охранных голобарьеров"
	item_type = /obj/item/holosign_creator/security
	unit_reward = 150
	group = "Снаряжение охраны"

/** Researched identification glasses support security equipment imports. */
/datum/trade_hub_request/security_huds
	name = "Охранные HUD-очки"
	item_type = /obj/item/clothing/glasses/hud/security
	unit_reward = 100
	group = "Снаряжение охраны"

/** Printed security flashlights support equipment imports without a charge requirement. */
/datum/trade_hub_request/security_flashlights
	name = "Охранные фонари"
	item_type = /obj/item/flashlight/seclite
	unit_reward = 75
	group = "Снаряжение охраны"

/** Manufactured firing pins support weapon supply imports. */
/datum/trade_hub_request/security_firing_pins
	name = "Экспедиционные бойки"
	item_type = /obj/item/firing_pin/explorer
	unit_reward = 100
	category = "Компоненты"
	group = "Оружейные поставки"

/** Energy weapon components support weapon supply imports. */
/datum/trade_hub_request/security_advanced_capacitors
	name = "Улучшенные конденсаторы"
	item_type = /obj/item/stock_parts/capacitor/adv
	unit_reward = 60
	category = "Компоненты"
	group = "Оружейные поставки"

/** Manufactured laser components support weapon supply imports. */
/datum/trade_hub_request/security_high_power_lasers
	name = "Мощные микролазеры"
	item_type = /obj/item/stock_parts/micro_laser/high
	unit_reward = 50
	category = "Компоненты"
	group = "Оружейные поставки"

/** Manufactured servos support weapon supply imports. */
/datum/trade_hub_request/security_nano_servos
	name = "Наносервоприводы"
	item_type = /obj/item/stock_parts/servo/nano
	unit_reward = 75
	category = "Компоненты"
	group = "Оружейные поставки"

/** Prepared burgers support service supply imports. */
/datum/trade_hub_request/service_burgers
	name = "Гамбургеры"
	item_type = /obj/item/food/burger/plain
	unit_reward = 100
	category = "Продукция"
	group = "Сервисное снабжение"

/** Prepared donuts support service supply imports. */
/datum/trade_hub_request/service_donuts
	name = "Пончики"
	item_type = /obj/item/food/donut/plain
	unit_reward = 40
	category = "Продукция"
	group = "Сервисное снабжение"

/** Prepared pastries support service supply imports. */
/datum/trade_hub_request/service_pretzels
	name = "Маковые крендели"
	item_type = /obj/item/food/poppypretzel
	unit_reward = 110
	category = "Продукция"
	group = "Сервисное снабжение"

/** Baked muffins replenish service supplies. */
/datum/trade_hub_request/service_muffins
	name = "Маффины"
	item_type = /obj/item/food/muffin
	unit_reward = 60
	category = "Продукция"
	group = "Сервисное снабжение"

/** Researched AI electronics support corporate projects. */
/datum/trade_hub_request/corporate_ai_boards
	name = "Платы ядра ИИ"
	item_type = /obj/item/circuitboard/aicore
	unit_reward = 250
	category = "Компоненты"
	selection_weight = 2
	group = "Корпоративные проекты"
	restock_amount = 1

/** Medical exosuit control boards support corporate projects. */
/datum/trade_hub_request/corporate_odysseus_main_boards
	name = "Главные платы «Одиссея»"
	item_type = /obj/item/circuitboard/mecha/odysseus/main
	unit_reward = 200
	category = "Компоненты"
	selection_weight = 2
	group = "Корпоративные проекты"
	restock_amount = 1

/** Medical exosuit peripheral boards support corporate projects. */
/datum/trade_hub_request/corporate_odysseus_peripheral_boards
	name = "Периферийные платы «Одиссея»"
	item_type = /obj/item/circuitboard/mecha/odysseus/peripherals
	unit_reward = 200
	category = "Компоненты"
	selection_weight = 2
	group = "Корпоративные проекты"
	restock_amount = 1

/** Industrial hub with separate tool, electronics and emergency inventories. */
/obj/machinery/trade_hub_core/industrial
	name = "Промышленный торговый узел"
	specialization = "Промышленность"
	demand_multipliers = list("Сырьё" = 0.5)
	demand_weights = list("Сырьё" = 4)
	catalogue_groups = list(
		"Engineering" = "Инструменты",
		"Engine Construction" = "Электроника",
		"Canisters & Materials" = "Электроника",
		"Emergency" = "Аварийное снабжение",
	)
	stock = list(/datum/supply_pack/engineering/tools = 3, /datum/supply_pack/engineering/power = 1)
	groups = list(/datum/supply_pack/engineering/tools = "Инструменты", /datum/supply_pack/engineering/power = "Электроника")
	request_types = list(
		/datum/trade_hub_request/industrial_iron,
		/datum/trade_hub_request/industrial_plasma,
		/datum/trade_hub_request/industrial_silver,
		/datum/trade_hub_request/industrial_plasteel,
		/datum/trade_hub_request/industrial_power_tools,
		/datum/trade_hub_request/industrial_glass,
		/datum/trade_hub_request/industrial_gold,
		/datum/trade_hub_request/industrial_cable,
		/datum/trade_hub_request/industrial_smes_boards,
		/datum/trade_hub_request/industrial_multitools,
		/datum/trade_hub_request/industrial_extra,
		/datum/trade_hub_request/industrial_uranium,
		/datum/trade_hub_request/industrial_reinforced_glass,
		/datum/trade_hub_request/industrial_titanium,
		/datum/trade_hub_request/industrial_power_drills,
	)

/** Medical hub offers equipment and medication supplied by different commodities. */
/obj/machinery/trade_hub_core/medical
	name = "Медицинский торговый узел"
	specialization = "Медицина"
	requests_per_group = 3
	demand_multipliers = list("Сырьё" = 3, "Продукция" = 1.5)
	demand_weights = list("Сырьё" = 0.1)
	catalogue_groups = list("Medical" = "Медоборудование")
	stock = list(/datum/supply_pack/medical/defibs = 0, /datum/supply_pack/medical/iv_drip = 3, /datum/supply_pack/medical/chemical = 2)
	groups = list(/datum/supply_pack/medical/defibs = "Медоборудование", /datum/supply_pack/medical/iv_drip = "Медоборудование", /datum/supply_pack/medical/chemical = "Медикаменты")
	request_types = list(
		/datum/trade_hub_request/medical_glass,
		/datum/trade_hub_request/medical_laser_scalpels,
		/datum/trade_hub_request/medical_health_analyzers,
		/datum/trade_hub_request/medical_mechanical_pinches,
		/datum/trade_hub_request/medical_tomato,
		/datum/trade_hub_request/medical_aloe,
		/datum/trade_hub_request/medical_ambrosia,
		/datum/trade_hub_request/medical_poppies,
	)

/** Agricultural hub exchanges raw materials for food and growing equipment. */
/obj/machinery/trade_hub_core/agricultural
	name = "Аграрный торговый узел"
	specialization = "Сельское хозяйство"
	demand_multipliers = list("Продукция" = 1.2)
	demand_weights = list("Продукция" = 2)
	catalogue_groups = list("Food & Hydroponics" = "Продукты", "Livestock" = "Животноводство")
	stock = list(/datum/supply_pack/engineering/tools = 9, /datum/supply_pack/organic/food = 3, /datum/supply_pack/organic/hydroponics/supplies = 0)
	groups = list(/datum/supply_pack/engineering/tools = "Гидропоника", /datum/supply_pack/organic/food = "Продукты", /datum/supply_pack/organic/hydroponics/supplies = "Гидропоника")
	request_types = list(
		/datum/trade_hub_request/agricultural_golden_apples,
		/datum/trade_hub_request/agricultural_cultivators,
		/datum/trade_hub_request/agricultural_secateurs,
		/datum/trade_hub_request/agricultural_plant_analyzers,
		/datum/trade_hub_request/agricultural_wheat,
		/datum/trade_hub_request/agricultural_rice,
		/datum/trade_hub_request/agricultural_corn,
		/datum/trade_hub_request/agricultural_potatoes,
		/datum/trade_hub_request/agriculture_tomato,
		/datum/trade_hub_request/agricultural_cabbage,
		/datum/trade_hub_request/agricultural_carrots,
		/datum/trade_hub_request/agricultural_pumpkins,
	)

/** Research hub supplies scientific equipment and expedition contracts. */
/obj/machinery/trade_hub_core/research
	name = "Научный торговый узел"
	specialization = "Наука и экспедиции"
	requests_per_group = 3
	demand_multipliers = list("Компоненты" = 1.25, "Оборудование" = 1.1)
	demand_weights = list("Компоненты" = 2)
	default_stock = 2
	catalogue_groups = list("Science" = "Научные товары", "Outsourced" = "Экспедиционное снабжение")
	request_types = list(
		/datum/trade_hub_request/research_phasic_scanners,
		/datum/trade_hub_request/research_quantum_boards,
		/datum/trade_hub_request/research_ranged_analyzers,
		/datum/trade_hub_request/research_mining_scanners,
		/datum/trade_hub_request/expedition_gas_analyzers,
		/datum/trade_hub_request/expedition_mesons,
		/datum/trade_hub_request/expedition_gps,
		/datum/trade_hub_request/expedition_t_ray_scanners,
	)

/** Security hub supplies security equipment and armory requisitions. */
/obj/machinery/trade_hub_core/security
	name = "Охранный торговый узел"
	specialization = "Служба безопасности"
	requests_per_group = 3
	demand_multipliers = list("Компоненты" = 1.1, "Оборудование" = 1.2)
	default_stock = 2
	catalogue_groups = list("Security" = "Снаряжение охраны", "Armory" = "Оружейные поставки", "Requisitions" = "Оружейные поставки")
	request_types = list(
		/datum/trade_hub_request/security_telescopic_shields,
		/datum/trade_hub_request/security_holosign_projectors,
		/datum/trade_hub_request/security_huds,
		/datum/trade_hub_request/security_flashlights,
		/datum/trade_hub_request/security_firing_pins,
		/datum/trade_hub_request/security_advanced_capacitors,
		/datum/trade_hub_request/security_high_power_lasers,
		/datum/trade_hub_request/security_nano_servos,
	)

/** Service hub supplies station services, vending, leisure and imports. */
/obj/machinery/trade_hub_core/service
	name = "Сервисный торговый узел"
	specialization = "Сервис и снабжение"
	requests_per_group = 4
	demand_multipliers = list("Продукция" = 1.1)
	catalogue_groups = list(
		"Service" = "Сервисное снабжение",
		"Vending Restocks" = "Сервисное снабжение",
		"Miscellaneous Supplies" = "Сервисное снабжение",
		"Costumes & Toys" = "Сервисное снабжение",
		"Imports" = "Сервисное снабжение",
	)
	request_types = list(
		/datum/trade_hub_request/service_birthday_cakes,
		/datum/trade_hub_request/service_burgers,
		/datum/trade_hub_request/service_donuts,
		/datum/trade_hub_request/service_pretzels,
		/datum/trade_hub_request/service_muffins,
	)

/** Corporate hub supplies only existing station project packs with their normal unlocks. */
/obj/machinery/trade_hub_core/corporate
	name = "Торговый узел корпоративных товаров"
	specialization = "Корпоративные товары"
	requests_per_group = 4
	default_stock = 1
	batch_credit_target = 2000
	request_types = list(
		/datum/trade_hub_request/corporate_bluespace_bins,
		/datum/trade_hub_request/corporate_quadratic_capacitors,
		/datum/trade_hub_request/corporate_quadultra_lasers,
		/datum/trade_hub_request/corporate_odysseus_torsos,
		/datum/trade_hub_request/corporate_ai_boards,
		/datum/trade_hub_request/corporate_odysseus_main_boards,
		/datum/trade_hub_request/corporate_odysseus_peripheral_boards,
	)

/** Route only the shared exact station project allowlist to the corporate catalogue. */
/obj/machinery/trade_hub_core/corporate/get_pack_group(datum/supply_pack/pack)
	if(pack.type in corporate_pack_types)
		return "Корпоративные проекты"
	return null

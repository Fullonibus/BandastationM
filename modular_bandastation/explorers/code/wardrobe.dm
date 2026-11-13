/// The corps vending machine: free spare clothes, carrying gear and the field kit. Stock is sized for a full corps of seven.
/obj/machinery/vending/wardrobe/expedition_wardrobe
	name = "ExpeDrobe"
	desc = "Автомат с полевой одеждой и снаряжением экспедиционного корпуса Нанотрейзен."
	icon_state = "scidrobe"
	product_ads = "Полевая форма для любой планеты!;Ножны и разгрузка — не забудьте перед вылазкой!;Детектор, болты и набор для раскопок — без них не вылетать!"
	vend_reply = "Удачной экспедиции!"
	all_products_free = TRUE
	products = list(
		/obj/item/clothing/under/expedition = 3,
		/obj/item/clothing/under/expedition/leader = 3,
		/obj/item/clothing/under/expedition/pilot = 3,
		/obj/item/clothing/under/expedition/engineer = 3,
		/obj/item/clothing/shoes/jackboots/expedition = 4,
		/obj/item/clothing/gloves/color/black/expedition = 4,
		/obj/item/clothing/suit/toggle/expedition = 4,
		/obj/item/clothing/accessory/expedition_webbing = 7,
		/obj/item/clothing/accessory/expedition_sheath = 7,
		/obj/item/storage/belt/expedition_sheath = 7,
		/obj/item/clothing/head/helmet/expedition_pilot = 2,
		/obj/item/field_detector = 5,
		/obj/item/field_collector = 2,
		/obj/item/storage/field_bolts = 4,
		/obj/item/storage/belt/excavation/full = 3,
	)
	refill_canister = /obj/item/vending_refill/wardrobe/expedition_wardrobe

/obj/item/vending_refill/wardrobe/expedition_wardrobe
	machine_name = "ExpeDrobe"

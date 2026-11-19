/obj/item/autosurgeon/syndicate/binyat
	uses = 1
	starting_organ = /obj/item/organ/cyberimp/brain/binyat

/obj/item/autosurgeon/syndicate/razorwire
	uses = 1
	starting_organ = /obj/item/organ/cyberimp/arm/toolkit/razorwire

/obj/item/autosurgeon/syndicate/kaleido
	uses = 1
	starting_organ = /obj/item/organ/eyes/robotic/kaleido

/obj/item/autosurgeon/syndicate/mantis
	uses = 1
	starting_organ = /obj/item/organ/cyberimp/arm/toolkit/mantis

/obj/item/autosurgeon/syndicate/mantis/left
	starting_organ = /obj/item/organ/cyberimp/arm/toolkit/mantis/left

/obj/item/storage/box/syndie_kit/mantis
	name = "'Naginata' mantis blades kit"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Набор одноразовых автохирургов с парой клинков Богомола «Нагината»."

/obj/item/storage/box/syndie_kit/mantis/PopulateContents()
	new /obj/item/autosurgeon/syndicate/mantis(src)
	new /obj/item/autosurgeon/syndicate/mantis/left(src)

/datum/uplink_item/implants/binyat
	name = "Binyat Wireless Hacking System"
	desc = "Одноразовый автохирург с системой дистанционного взлома. Взламывает машинерию как емаг, вскрывает двери и отключает камеры на 30 секунд. Дальность — три клетки. Взлом занимает три секунды и наносит 5 ожогов; частое использование усиливает перегрев."
	item = /obj/item/autosurgeon/syndicate/binyat
	cost = 5

/datum/uplink_item/implants/razorwire
	name = "Razorwire Spool"
	desc = "Одноразовый автохирург с катушкой моноструны. Наносит 18 урона на расстоянии до двух клеток и выбивает предметы из рук при попадании. Броня защищает от моноструны вдвое эффективнее."
	item = /obj/item/autosurgeon/syndicate/razorwire
	cost = 8

/datum/uplink_item/implants/kaleido
	name = "Hardened Kaleido Optics Eyes"
	desc = "Одноразовый автохирург с укреплёнными глазами Kaleido Optics. Дают оптическое приближение как у бинокля, освобождая руки. Устойчивы к ЭМИ."
	item = /obj/item/autosurgeon/syndicate/kaleido
	cost = 2

/datum/uplink_item/implants/mantis
	name = "'Naginata' Mantis Blades Kit"
	desc = "Два одноразовых автохирурга с выдвижными клинками предплечий. Каждый клинок наносит 15 урона без пробивания брони. Пара наносит двойные удары, вскрывает двери и даёт 50% вероятности блока. ЭМИ повреждает руки."
	item = /obj/item/storage/box/syndie_kit/mantis
	cost = 12

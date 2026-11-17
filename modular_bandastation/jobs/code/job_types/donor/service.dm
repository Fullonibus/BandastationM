/datum/job/donor/barber
	title = "Barber"
	alternate_titles = list("Парикмахер", "Стилист", "Цирюльник", "Визажист")
	description = "Стригите и брейте посетителей, подбирайте им причёски и откройте собственную парикмахерскую."
	config_tag = "BARBER"
	display_order = JOB_DISPLAY_ORDER_DONOR_BARBER
	total_positions = 1
	spawn_positions = 1
	required_donator_level = DONATOR_TIER_1
	donor_spawn_landmark = JOB_CURATOR
	outfit = /datum/outfit/job/donor/barber
	plasmaman_outfit = /datum/outfit/plasmaman/curator
	tgui_icon = FA_ICON_CUT

/datum/outfit/job/donor/barber
	name = "Barber"
	jobtype = /datum/job/donor/barber
	id_trim = /datum/id_trim/job/donor/barber
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	head = /obj/item/clothing/head/hats/bowler
	shoes = /obj/item/clothing/shoes/laceup
	ear_right = /obj/item/radio/headset/headset_srv
	backpack_contents = list(
		/obj/item/razor = 1,
		/obj/item/lipstick/random = 1,
		/obj/item/rag = 1,
	)

/datum/id_trim/job/donor/barber
	assignment = "Парикмахер"
	job = /datum/job/donor/barber
	trim_state = "trim_barber"
	sechud_icon_state = "hudbarber"
	minimal_access = list(ACCESS_MAINT_TUNNELS, ACCESS_LIBRARY, ACCESS_SERVICE)

/datum/job/donor/waiter
	title = "Waiter"
	alternate_titles = list("Официант", "Хост сервиса")
	description = "Принимайте заказы, подавайте блюда и напитки и помогайте поварам и бармену обслуживать экипаж."
	config_tag = "WAITER"
	display_order = JOB_DISPLAY_ORDER_DONOR_WAITER
	total_positions = 2
	spawn_positions = 2
	required_donator_level = DONATOR_TIER_1
	donor_spawn_landmark = JOB_BARTENDER
	outfit = /datum/outfit/job/donor/waiter
	plasmaman_outfit = /datum/outfit/plasmaman/chef
	tgui_icon = FA_ICON_CONCIERGE_BELL

/datum/outfit/job/donor/waiter
	name = "Waiter"
	jobtype = /datum/job/donor/waiter
	id_trim = /datum/id_trim/job/donor/waiter
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	neck = /obj/item/clothing/neck/bowtie
	suit = /obj/item/clothing/suit/jacket/blazer
	shoes = /obj/item/clothing/shoes/laceup
	belt = /obj/item/modular_computer/pda/crew/cook
	ear_right = /obj/item/radio/headset/headset_srv
	l_hand = /obj/item/storage/bag/tray
	backpack_contents = list(
		/obj/item/clipboard = 1,
		/obj/item/rag = 1,
	)

/datum/id_trim/job/donor/waiter
	assignment = "Официант"
	job = /datum/job/donor/waiter
	trim_state = "trim_waiter"
	sechud_icon_state = "hudwaiter"
	minimal_access = list(
		ACCESS_MAINT_TUNNELS,
		ACCESS_SERVICE,
		ACCESS_THEATRE,
		ACCESS_HYDROPONICS,
		ACCESS_BAR,
		ACCESS_KITCHEN,
	)

/datum/job/donor/administrator
	title = "Administrator"
	alternate_titles = list("Сервис-администратор", "Сервис-управитель", "Сервис-менеджер")
	description = "Помогайте главе персонала координировать отдел обслуживания, поддерживайте работу заведений и устраивайте мероприятия для экипажа."
	config_tag = "SERVICE_ADMINISTRATOR"
	display_order = JOB_DISPLAY_ORDER_DONOR_ADMINISTRATOR
	total_positions = 1
	spawn_positions = 1
	required_donator_level = DONATOR_TIER_3
	paycheck = PAYCHECK_CREW
	donor_spawn_landmark = JOB_BARTENDER
	outfit = /datum/outfit/job/donor/administrator
	plasmaman_outfit = /datum/outfit/plasmaman/bar
	tgui_icon = FA_ICON_CLIPBOARD_LIST

/datum/outfit/job/donor/administrator
	name = "Administrator"
	jobtype = /datum/job/donor/administrator
	id_trim = /datum/id_trim/job/donor/administrator
	uniform = /obj/item/clothing/under/suit/black
	suit = /obj/item/clothing/suit/jacket/fancy
	shoes = /obj/item/clothing/shoes/laceup
	gloves = /obj/item/clothing/gloves/color/white
	glasses = /obj/item/clothing/glasses/regular
	belt = /obj/item/modular_computer/pda/crew/curator
	ear_right = /obj/item/radio/headset/headset_srv
	backpack_contents = list(
		/obj/item/clothing/under/costume/buttondown/slacks/service = 1,
		/obj/item/clipboard = 1,
		/obj/item/rag = 1,
	)

/datum/id_trim/job/donor/administrator
	assignment = "Сервис-администратор"
	job = /datum/job/donor/administrator
	trim_state = "trim_administrator"
	sechud_icon_state = "hudadministrator"
	minimal_access = list(
		ACCESS_SERVICE,
		ACCESS_THEATRE,
		ACCESS_LIBRARY,
		ACCESS_BAR,
		ACCESS_KITCHEN,
		ACCESS_HYDROPONICS,
		ACCESS_MINERAL_STOREROOM,
		ACCESS_JANITOR,
	)

/datum/job/donor/guard
	title = "Guard"
	alternate_titles = list("Охранник сервиса", "Сторож сервиса", "Вышибала")
	description = "Следите за порядком в баре и на кухне. Удаляйте нарушителей из заведения и вызывайте службу безопасности, если нужна её помощь."
	config_tag = "SERVICE_GUARD"
	display_order = JOB_DISPLAY_ORDER_DONOR_GUARD
	total_positions = 1
	spawn_positions = 1
	required_donator_level = DONATOR_TIER_3
	paycheck = PAYCHECK_CREW
	donor_spawn_landmark = JOB_BARTENDER
	outfit = /datum/outfit/job/donor/guard
	plasmaman_outfit = /datum/outfit/plasmaman/bar
	tgui_icon = FA_ICON_SHIELD_ALT

/datum/outfit/job/donor/guard
	name = "Guard"
	jobtype = /datum/job/donor/guard
	id_trim = /datum/id_trim/job/donor/guard
	uniform = /obj/item/clothing/under/costume/buttondown/slacks/service
	suit = /obj/item/clothing/suit/armor/vest/old
	head = /obj/item/clothing/head/hats/bowler
	shoes = /obj/item/clothing/shoes/jackboots
	glasses = /obj/item/clothing/glasses/sunglasses
	belt = /obj/item/modular_computer/pda/crew/bar
	ear_right = /obj/item/radio/headset/headset_srv
	backpack_contents = list(
		/obj/item/clothing/suit/jacket/leather = 1,
		/obj/item/reagent_containers/spray/pepper = 1,
	)

/datum/id_trim/job/donor/guard
	assignment = "Охранник сервиса"
	job = /datum/job/donor/guard
	trim_state = "trim_guard"
	sechud_icon_state = "hudguard"
	minimal_access = list(
		ACCESS_MAINT_TUNNELS,
		ACCESS_SERVICE,
		ACCESS_BAR,
		ACCESS_KITCHEN,
		ACCESS_HYDROPONICS,
		ACCESS_LIBRARY,
	)

/datum/job/donor/dealer
	title = "Dealer"
	alternate_titles = list("Торговец", "Независимый торговец", "Барахольщик", "Коммерсант")
	description = "Откройте торговую точку, скупайте и перепродавайте товары экипажу. Принимайте переводы через NT Pay."
	config_tag = "DEALER"
	display_order = JOB_DISPLAY_ORDER_DONOR_DEALER
	total_positions = 2
	spawn_positions = 2
	required_donator_level = DONATOR_TIER_4
	donor_spawn_landmark = JOB_CURATOR
	outfit = /datum/outfit/job/donor/dealer
	job_flags = parent_type::job_flags | JOB_ANTAG_PROTECTED
	tgui_icon = FA_ICON_STORE

/datum/outfit/job/donor/dealer
	name = "Dealer"
	jobtype = /datum/job/donor/dealer
	id_trim = /datum/id_trim/job/donor/dealer
	uniform = /obj/item/clothing/under/suit/black
	suit = /obj/item/clothing/suit/jacket/leather_trenchcoat
	head = /obj/item/clothing/head/fedora
	shoes = /obj/item/clothing/shoes/cowboy/black
	glasses = /obj/item/clothing/glasses/sunglasses
	gloves = /obj/item/clothing/gloves/color/black
	ear_right = /obj/item/radio/headset/headset_srv
	l_hand = /obj/item/cane
	duffelbag = /obj/item/storage/backpack/duffelbag/engineering
	backpack_contents = list(
		/obj/item/hand_labeler = 1,
		/obj/item/hand_labeler_refill = 1,
		/obj/item/toy/plush/hampter = 1,
		/obj/item/storage/fancy/cigarettes/cigpack_robustgold = 1,
		/obj/item/lighter/greyscale = 1,
	)

/datum/id_trim/job/donor/dealer
	assignment = "Торговец"
	job = /datum/job/donor/dealer
	trim_state = "trim_dealer"
	sechud_icon_state = "huddealer"
	minimal_access = list(ACCESS_MAINT_TUNNELS, ACCESS_LIBRARY, ACCESS_RC_ANNOUNCE, ACCESS_SERVICE)

/datum/job/donor/banker
	title = "Banker"
	alternate_titles = list("Банкир", "Независимый банкир", "Корпорат", "Бизнесмен")
	description = "Вложите стартовый капитал в своё дело. Откройте банк или мастерскую, нанимайте работников и заключайте сделки с экипажем."
	config_tag = "BANKER"
	display_order = JOB_DISPLAY_ORDER_DONOR_BANKER
	total_positions = 2
	spawn_positions = 2
	required_donator_level = DONATOR_TIER_5
	outfit = /datum/outfit/job/donor/banker
	job_flags = parent_type::job_flags | JOB_ANTAG_PROTECTED
	tgui_icon = FA_ICON_UNIVERSITY

/datum/job/donor/banker/get_roundstart_spawn_point()
	return get_latejoin_spawn_point()

/datum/outfit/job/donor/banker
	name = "Banker"
	jobtype = /datum/job/donor/banker
	id_trim = /datum/id_trim/job/donor/banker
	uniform = /obj/item/clothing/under/suit/black_really
	suit = /obj/item/clothing/suit/jacket/fancy
	glasses = /obj/item/clothing/glasses/monocle
	mask = /obj/item/cigarette/pipe
	gloves = /obj/item/clothing/gloves/color/white
	shoes = /obj/item/clothing/shoes/laceup/centcom
	head = /obj/item/clothing/head/fedora
	l_hand = /obj/item/cane
	ear_right = /obj/item/radio/headset/headset_srv
	backpack_contents = list(
		/obj/item/stack/spacecash/c1000 = 1,
		/obj/item/clipboard = 1,
		/obj/item/lighter/greyscale = 1,
		/obj/item/cigarette/cigar/havana = 6,
	)

/datum/id_trim/job/donor/banker
	assignment = "Банкир"
	job = /datum/job/donor/banker
	trim_state = "trim_banker"
	sechud_icon_state = "hudbanker"
	minimal_access = list(ACCESS_MAINT_TUNNELS, ACCESS_LIBRARY, ACCESS_EVA)

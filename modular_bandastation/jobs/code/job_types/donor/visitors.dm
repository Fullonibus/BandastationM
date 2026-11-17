/datum/job/donor/tourist_tsf
	title = "Tourist TSF"
	alternate_titles = list("Турист ТСФ", "Посетитель ТСФ")
	description = "Осмотрите станцию как гость Транс-Солнечной Федерации, познакомьтесь с экипажем и найдите занятие по душе."
	required_donator_level = DONATOR_TIER_2
	config_tag = "TOURIST_TSF"
	display_order = JOB_DISPLAY_ORDER_DONOR_TOURIST_TSF
	total_positions = 2
	spawn_positions = 2
	tgui_icon = FA_ICON_PASSPORT
	outfit = /datum/outfit/job/donor/tourist_tsf
	paycheck_department = ACCOUNT_CIV
	donor_spawn_landmark = JOB_ASSISTANT

/datum/outfit/job/donor/tourist_tsf
	name = "Tourist TSF"
	jobtype = /datum/job/donor/tourist_tsf
	id = /obj/item/card/id/advanced/tsf/donor
	id_trim = /datum/id_trim/job/donor/tourist_tsf
	uniform = /obj/item/clothing/under/suit/navy
	head = /obj/item/clothing/head/hats/tsf_cap
	backpack_contents = list(/obj/item/camera = 1)

/datum/outfit/job/donor/tourist_tsf/post_equip(mob/living/carbon/human/equipped, visuals_only = FALSE)
	. = ..()
	if(!visuals_only)
		equipped.grant_language(/datum/language/uncommon)

/obj/item/card/id/advanced/tsf/donor
	trim = null
	wildcard_slots = WILDCARD_LIMIT_GREY

/datum/id_trim/job/donor/tourist_tsf
	assignment = "Турист ТСФ"
	job = /datum/job/donor/tourist_tsf
	trim_icon = 'modular_bandastation/jobs/icons/obj/card.dmi'
	trim_state = "trim_tsf"
	department_color = COLOR_MODERATE_BLUE
	subdepartment_color = COLOR_MODERATE_BLUE
	sechud_icon_state = "hudtouristtsf"
	minimal_access = list(ACCESS_LIBRARY, ACCESS_MAINT_TUNNELS)

/datum/job/donor/tourist_ussp
	title = "Tourist USSP"
	alternate_titles = list("Турист СССП", "Посетитель СССП")
	description = "Проведите отпуск на станции как гость Союза Советских Социалистических Планет и познакомьтесь с местной жизнью."
	required_donator_level = DONATOR_TIER_2
	config_tag = "TOURIST_USSP"
	display_order = JOB_DISPLAY_ORDER_DONOR_TOURIST_USSP
	total_positions = 2
	spawn_positions = 2
	tgui_icon = FA_ICON_PASSPORT
	outfit = /datum/outfit/job/donor/tourist_ussp
	paycheck_department = ACCOUNT_CIV
	donor_spawn_landmark = JOB_ASSISTANT

/datum/outfit/job/donor/tourist_ussp
	name = "Tourist USSP"
	jobtype = /datum/job/donor/tourist_ussp
	id = /obj/item/card/id/advanced/ussp/donor
	id_trim = /datum/id_trim/job/donor/tourist_ussp
	uniform = /obj/item/clothing/under/color/maroon
	head = /obj/item/clothing/head/costume/ushanka
	backpack_contents = list(/obj/item/camera = 1)

/datum/outfit/job/donor/tourist_ussp/post_equip(mob/living/carbon/human/equipped, visuals_only = FALSE)
	. = ..()
	if(!visuals_only)
		equipped.grant_language(/datum/language/spinwarder)

/obj/item/card/id/advanced/ussp/donor
	trim = null
	wildcard_slots = WILDCARD_LIMIT_GREY

/datum/id_trim/job/donor/tourist_ussp
	assignment = "Турист СССП"
	job = /datum/job/donor/tourist_ussp
	trim_icon = 'modular_bandastation/jobs/icons/obj/card.dmi'
	trim_state = "trim_ussp"
	department_color = COLOR_MAROON
	subdepartment_color = COLOR_MAROON
	sechud_icon_state = "hudtouristussp"
	minimal_access = list(ACCESS_LIBRARY, ACCESS_MAINT_TUNNELS)

/datum/job/donor/migrant
	title = "Migrant"
	alternate_titles = list("Мигрант", "Переселенец")
	description = "Вы недавно прибыли на станцию. Подыщите работу, заведите знакомства и решите, хотите ли здесь остаться."
	required_donator_level = DONATOR_TIER_2
	config_tag = "MIGRANT"
	display_order = JOB_DISPLAY_ORDER_DONOR_MIGRANT
	total_positions = 2
	spawn_positions = 2
	tgui_icon = FA_ICON_SUITCASE_ROLLING
	outfit = /datum/outfit/job/donor/migrant
	paycheck_department = ACCOUNT_CIV
	donor_spawn_landmark = JOB_ASSISTANT

/datum/outfit/job/donor/migrant
	name = "Migrant"
	jobtype = /datum/job/donor/migrant
	id_trim = /datum/id_trim/job/donor/migrant
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/jacket/puffer
	head = /obj/item/clothing/head/beanie
	shoes = /obj/item/clothing/shoes/workboots
	backpack_contents = list(/obj/item/food/sandwich = 2)

/datum/id_trim/job/donor/migrant
	assignment = "Мигрант"
	job = /datum/job/donor/migrant
	trim_state = "trim_migrant"
	department_color = COLOR_ASSISTANT_GRAY
	subdepartment_color = COLOR_ASSISTANT_GRAY
	sechud_icon_state = "hudmigrant"
	minimal_access = list(ACCESS_LIBRARY, ACCESS_MAINT_TUNNELS)

/datum/job/donor/representative_tsf
	title = "Representative TSF"
	alternate_titles = list("Представитель ТСФ", "Дипломат ТСФ", "Публицист ТСФ")
	description = "Представляйте интересы ТСФ в переговорах с командованием станции и оформляйте достигнутые договорённости."
	required_donator_level = DONATOR_TIER_4
	config_tag = "REPRESENTATIVE_TSF"
	display_order = JOB_DISPLAY_ORDER_DONOR_REPRESENTATIVE_TSF
	total_positions = 1
	spawn_positions = 1
	departments_list = list(/datum/job_department/nanotrasen_representation)
	supervisors = "дипломатической службой ТСФ"
	tgui_icon = FA_ICON_HANDSHAKE
	outfit = /datum/outfit/job/donor/representative_tsf
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_CIV
	job_flags = parent_type::job_flags | JOB_ANTAG_PROTECTED
	donor_spawn_landmark = JOB_ASSISTANT

/datum/outfit/job/donor/representative_tsf
	parent_type = /datum/outfit/job/donor/tourist_tsf
	name = "Representative TSF"
	jobtype = /datum/job/donor/representative_tsf
	id_trim = /datum/id_trim/job/donor/representative_tsf
	uniform = /obj/item/clothing/under/rank/tsf/formal
	suit = /obj/item/clothing/suit/tsf_suitjacket
	head = /obj/item/clothing/head/beret/tsf_diplomat
	ear_right = /obj/item/radio/headset/headset_com
	shoes = /obj/item/clothing/shoes/laceup
	l_hand = /obj/item/storage/briefcase
	backpack_contents = list(/obj/item/stamp/tsf = 1)

/datum/id_trim/job/donor/representative_tsf
	parent_type = /datum/id_trim/job/donor/tourist_tsf
	assignment = "Представитель ТСФ"
	job = /datum/job/donor/representative_tsf
	sechud_icon = DEFAULT_HUDS_DMI
	sechud_icon_state = SECHUD_TSF
	minimal_access = list(ACCESS_LIBRARY, ACCESS_MAINT_TUNNELS, ACCESS_COMMAND, ACCESS_RC_ANNOUNCE, ACCESS_EVA)

/datum/job/donor/representative_ussp
	title = "Representative USSP"
	alternate_titles = list("Представитель СССП", "Дипломат СССП", "Пресс-секретарь СССП")
	description = "Представляйте интересы СССП в переговорах с командованием станции, принимайте обращения и ведите дипломатическую переписку."
	required_donator_level = DONATOR_TIER_4
	config_tag = "REPRESENTATIVE_USSP"
	display_order = JOB_DISPLAY_ORDER_DONOR_REPRESENTATIVE_USSP
	total_positions = 1
	spawn_positions = 1
	departments_list = list(/datum/job_department/nanotrasen_representation)
	supervisors = "дипломатической службой СССП"
	tgui_icon = FA_ICON_HANDSHAKE
	outfit = /datum/outfit/job/donor/representative_ussp
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_CIV
	job_flags = parent_type::job_flags | JOB_ANTAG_PROTECTED
	donor_spawn_landmark = JOB_ASSISTANT

/datum/outfit/job/donor/representative_ussp
	parent_type = /datum/outfit/job/donor/tourist_ussp
	name = "Representative USSP"
	jobtype = /datum/job/donor/representative_ussp
	id_trim = /datum/id_trim/job/donor/representative_ussp
	uniform = /obj/item/clothing/under/rank/ussp/official
	head = /obj/item/clothing/head/hats/ussp_officer
	ear_right = /obj/item/radio/headset/headset_com
	shoes = /obj/item/clothing/shoes/jackboots
	l_hand = /obj/item/storage/briefcase
	backpack_contents = list(/obj/item/stamp/ussp = 1)

/datum/id_trim/job/donor/representative_ussp
	parent_type = /datum/id_trim/job/donor/tourist_ussp
	assignment = "Представитель СССП"
	job = /datum/job/donor/representative_ussp
	sechud_icon = DEFAULT_HUDS_DMI
	sechud_icon_state = SECHUD_USSP
	minimal_access = list(ACCESS_LIBRARY, ACCESS_MAINT_TUNNELS, ACCESS_COMMAND, ACCESS_RC_ANNOUNCE, ACCESS_EVA)

/datum/job/donor/navy_junior_officer
	title = "Nanotrasen Navy Junior Officer"
	alternate_titles = list("Младший офицер Центрального командования", "Младший офицер флота Нанотрейзен")
	description = "Собирайте сведения для Центрального командования, ведите переписку и согласовывайте поручения с представителем Нанотрейзен и капитаном."
	required_donator_level = DONATOR_TIER_5
	config_tag = "NAVY_JUNIOR_OFFICER"
	display_order = JOB_DISPLAY_ORDER_DONOR_NAVY_JUNIOR_OFFICER
	total_positions = 1
	spawn_positions = 1
	departments_list = list(/datum/job_department/nanotrasen_representation)
	supervisors = JOB_NANOTRASEN_REPRESENTATIVE_RU
	tgui_icon = FA_ICON_ANCHOR
	outfit = /datum/outfit/job/donor/navy_junior_officer
	paycheck = PAYCHECK_CREW
	paycheck_department = ACCOUNT_CIV
	job_flags = parent_type::job_flags | JOB_ANTAG_PROTECTED
	donor_spawn_landmark = JOB_ASSISTANT

/datum/outfit/job/donor/navy_junior_officer
	name = "Nanotrasen Navy Junior Officer"
	jobtype = /datum/job/donor/navy_junior_officer
	id = /obj/item/card/id/advanced/nanotrasen_official/navy_junior_officer
	id_trim = /datum/id_trim/job/donor/navy_junior_officer
	uniform = /obj/item/clothing/under/rank/centcom/intern
	head = /obj/item/clothing/head/hats/intern
	shoes = /obj/item/clothing/shoes/laceup
	l_hand = /obj/item/storage/briefcase
	implants = list(/obj/item/implant/mindshield)

/obj/item/card/id/advanced/nanotrasen_official/navy_junior_officer
	wildcard_slots = WILDCARD_LIMIT_GOLD

/datum/id_trim/job/donor/navy_junior_officer
	assignment = "Младший офицер Центрального командования"
	job = /datum/job/donor/navy_junior_officer
	trim_icon = 'icons/obj/card.dmi'
	trim_state = "trim_centcom"
	department_color = COLOR_CENTCOM_BLUE
	subdepartment_color = COLOR_CENTCOM_BLUE
	sechud_icon = DEFAULT_HUDS_DMI
	sechud_icon_state = SECHUD_CENTCOM
	minimal_access = list(ACCESS_CENT_GENERAL, ACCESS_CENT_LIVING)

/datum/id_trim/job/donor/navy_junior_officer/New()
	add_captain_station_access()
	return ..()

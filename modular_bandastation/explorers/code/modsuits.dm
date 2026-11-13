/// Field suit of the expedition corps, the Exoplanet Exploration Unit voidsuit of SierraBay.
/datum/mod_theme/expedition
	name = "expedition"
	desc = "Громоздкий полевой скафандр экспедиционного корпуса с дополнительной набивкой и противорадиационной подкладкой."
	extended_desc = "Стандартный скафандр полевых операций экспедиционного корпуса Нанотрейзен. Тяжеловат, зато защищает от фауны, радиации и непогоды чужих планет."
	default_skin = "expedition"
	armor_type = /datum/armor/mod_theme_expedition
	slowdown_deployed = 0.75
	allowed_suit_storage = list(
		/obj/item/flashlight,
		/obj/item/tank/internals,
		/obj/item/gps,
		/obj/item/healthanalyzer,
		/obj/item/shovel,
	)
	variants = list(
		"expedition" = list(
			MOD_ICON_OVERRIDE = 'modular_bandastation/explorers/icons/mod.dmi',
			MOD_WORN_ICON_OVERRIDE = 'modular_bandastation/explorers/icons/mod_worn.dmi',
			/obj/item/clothing/head/mod = list(
				UNSEALED_CLOTHING = SNUG_FIT|THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE|HEADINTERNALS,
				UNSEALED_INVISIBILITY = HIDEFACIALHAIR|HIDEEARS|HIDEHAIR|HIDESNOUT,
				SEALED_INVISIBILITY = HIDEMASK|HIDEEYES|HIDEFACE,
				SEALED_COVER = HEADCOVERSMOUTH|HEADCOVERSEYES|PEPPERPROOF,
				UNSEALED_MESSAGE = HELMET_UNSEAL_MESSAGE,
				SEALED_MESSAGE = HELMET_SEAL_MESSAGE,
			),
			/obj/item/clothing/suit/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				SEALED_INVISIBILITY = HIDEJUMPSUIT,
				UNSEALED_MESSAGE = CHESTPLATE_UNSEAL_MESSAGE,
				SEALED_MESSAGE = CHESTPLATE_SEAL_MESSAGE,
			),
			/obj/item/clothing/gloves/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				CAN_OVERSLOT = TRUE,
				UNSEALED_MESSAGE = GAUNTLET_UNSEAL_MESSAGE,
				SEALED_MESSAGE = GAUNTLET_SEAL_MESSAGE,
			),
			/obj/item/clothing/shoes/mod = list(
				UNSEALED_CLOTHING = THICKMATERIAL,
				SEALED_CLOTHING = STOPSPRESSUREDAMAGE,
				CAN_OVERSLOT = TRUE,
				UNSEALED_MESSAGE = BOOT_UNSEAL_MESSAGE,
				SEALED_MESSAGE = BOOT_SEAL_MESSAGE,
			),
		),
	)

/datum/armor/mod_theme_expedition
	melee = 30
	bullet = 15
	laser = 15
	energy = 15
	bomb = 50
	bio = 100
	fire = 75
	acid = 75
	wound = 15

/// The pilot's lighter voidsuit: less armour, less weight.
/datum/mod_theme/expedition/pilot
	name = "expedition pilot"
	desc = "Лёгкий герметичный скафандр пилота экспедиционного корпуса для космоса и планет."
	extended_desc = "Скафандр пилота экспедиционного корпуса. Брони почти нет, зато в нём легко двигаться и удобно сидеть за штурвалом."
	default_skin = "expedition_pilot"
	armor_type = /datum/armor/mod_theme_expedition_pilot
	slowdown_deployed = 0.5
	complexity_max = DEFAULT_MAX_COMPLEXITY - 3

/datum/mod_theme/expedition/pilot/New()
	variants = list("expedition_pilot" = variants["expedition"])
	return ..()

/// The leader's heavy suit, the A-Unit hardsuit of SierraBay.
/datum/mod_theme/expedition/heavy
	name = "heavy expedition"
	desc = "Бронированный экзоскелет главы экспедиционного корпуса, «A-Unit»: для враждебных и голодных миров."
	extended_desc = "Бронированный блок исследования экзопланет экспедиционного корпуса, коротко «A-Unit». Дополнительная броня и силовой экзоскелет для самых враждебных миров."
	default_skin = "expedition_heavy"
	armor_type = /datum/armor/mod_theme_expedition_heavy
	slowdown_deployed = 0.5
	complexity_max = DEFAULT_MAX_COMPLEXITY + 3

/datum/mod_theme/expedition/heavy/New()
	variants = list("expedition_heavy" = variants["expedition"])
	return ..()

/datum/armor/mod_theme_expedition_pilot
	melee = 20
	bullet = 10
	laser = 10
	energy = 10
	bomb = 25
	bio = 100
	fire = 50
	acid = 50
	wound = 10

/datum/armor/mod_theme_expedition_heavy
	melee = 45
	bullet = 25
	laser = 25
	energy = 30
	bomb = 50
	bio = 100
	fire = 90
	acid = 90
	wound = 25

/// The field medic's suit: the field suit's protection, with a medical kit built for carrying the wounded.
/datum/mod_theme/expedition/medic
	name = "expedition medic"
	desc = "Полевой МОД медика экспедиционного корпуса: чуть легче полевого скафандра, с медицинскими модулями."
	extended_desc = "Скафандр полевого медика экспедиционного корпуса. Брони чуть меньше, чем у полевого, зато он рассчитан на то, чтобы вытаскивать раненых с чужих планет."
	default_skin = "expedition_medic"
	armor_type = /datum/armor/mod_theme_expedition_medic

/datum/mod_theme/expedition/medic/New()
	variants = list("expedition_medic" = variants["expedition"])
	return ..()

/datum/armor/mod_theme_expedition_medic
	melee = 25
	bullet = 10
	laser = 10
	energy = 10
	bomb = 40
	bio = 100
	fire = 60
	acid = 60
	wound = 10

/// The field engineer's suit: the field suit's protection, with engineering modules.
/datum/mod_theme/expedition/engineer
	name = "expedition engineer"
	desc = "Полевой МОД инженера экспедиционного корпуса: защита полевого скафандра и место под инженерные модули."
	extended_desc = "Скафандр полевого инженера экспедиционного корпуса. Защищает не хуже полевого и держит сварку, сканер труб и защиту от радиации."
	default_skin = "expedition_engineer"

/datum/mod_theme/expedition/engineer/New()
	variants = list("expedition_engineer" = variants["expedition"])
	return ..()

/obj/item/mod/control/pre_equipped/expedition
	theme = /datum/mod_theme/expedition
	applied_modules = list(
		/obj/item/mod/module/storage,
		/obj/item/mod/module/flashlight,
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/rad_protection,
		/obj/item/mod/module/gps,
	)
	default_pins = list(
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/flashlight,
	)

/obj/item/mod/control/pre_equipped/expedition_pilot
	theme = /datum/mod_theme/expedition/pilot
	applied_modules = list(
		/obj/item/mod/module/storage,
		/obj/item/mod/module/flashlight,
		/obj/item/mod/module/magboot,
	)
	default_pins = list(
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/flashlight,
	)

/obj/item/mod/control/pre_equipped/expedition_heavy
	theme = /datum/mod_theme/expedition/heavy
	applied_modules = list(
		/obj/item/mod/module/storage/large_capacity,
		/obj/item/mod/module/jetpack,
		/obj/item/mod/module/flashlight,
		/obj/item/mod/module/thermal_regulator,
		/obj/item/mod/module/rad_protection,
		/obj/item/mod/module/gps,
	)
	default_pins = list(
		/obj/item/mod/module/jetpack,
		/obj/item/mod/module/flashlight,
	)

/obj/item/mod/control/pre_equipped/expedition_medic
	theme = /datum/mod_theme/expedition/medic
	applied_modules = list(
		/obj/item/mod/module/storage,
		/obj/item/mod/module/flashlight,
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/health_analyzer,
		/obj/item/mod/module/quick_carry,
		/obj/item/mod/module/injector,
	)
	default_pins = list(
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/health_analyzer,
	)

/obj/item/mod/control/pre_equipped/expedition_engineer
	theme = /datum/mod_theme/expedition/engineer
	applied_modules = list(
		/obj/item/mod/module/storage,
		/obj/item/mod/module/flashlight,
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/welding,
		/obj/item/mod/module/t_ray,
		/obj/item/mod/module/rad_protection,
	)
	default_pins = list(
		/obj/item/mod/module/magboot,
		/obj/item/mod/module/t_ray,
	)

/obj/machinery/suit_storage_unit/expedition
	name = "хранилище скафандров экспедиционного корпуса"
	mask_type = /obj/item/clothing/mask/breath
	storage_type = /obj/item/tank/internals/oxygen
	mod_type = /obj/item/mod/control/pre_equipped/expedition
	locked = TRUE
	/// Access written into its airlock electronics on spawn; the unit takes its access from them.
	var/list/corps_access = list(ACCESS_EXPLORER)

/obj/machinery/suit_storage_unit/expedition/Initialize(mapload)
	. = ..()
	set_access(corps_access.Copy())

/obj/machinery/suit_storage_unit/expedition/pilot
	name = "хранилище скафандра пилота экспедиционного корпуса"
	mod_type = /obj/item/mod/control/pre_equipped/expedition_pilot

/obj/machinery/suit_storage_unit/expedition/heavy
	name = "хранилище скафандра главы экспедиционного корпуса"
	mod_type = /obj/item/mod/control/pre_equipped/expedition_heavy
	corps_access = list(ACCESS_EXPEDITION_LEADER)

/obj/machinery/suit_storage_unit/expedition/medic
	name = "хранилище скафандра полевого медика"
	mod_type = /obj/item/mod/control/pre_equipped/expedition_medic

/obj/machinery/suit_storage_unit/expedition/engineer
	name = "хранилище скафандра полевого инженера"
	mod_type = /obj/item/mod/control/pre_equipped/expedition_engineer

// MARK: Tier 0
/datum/loadout_item/inhand/fannypack
	name = "Поясная сумка (Коричневая)"
	item_path = /obj/item/storage/belt/fannypack

/datum/loadout_item/inhand/fannypack_blue
	name = "Поясная сумка (Синяя)"
	item_path = /obj/item/storage/belt/fannypack/blue

/datum/loadout_item/inhand/fannypack_red
	name = "Поясная сумка (Красная)"
	item_path = /obj/item/storage/belt/fannypack/red

/datum/loadout_item/inhand/fannypack_black
	name = "Поясная сумка (Чёрная)"
	item_path = /obj/item/storage/belt/fannypack/black

// MARK: Tier 2
/datum/loadout_item/inhand/etamin_backpack
	name = "Рюкзак Etamin Industries"
	item_path = /obj/item/storage/backpack/etamin_ind
	donator_level = DONATOR_TIER_2

#define INFO_PET_TYPE "pet_type"

/// A carrier with a choice of Pet Day animals and local pets.
/datum/loadout_item/inhand/pet_carrier
	name = "Переноска с питомцем"
	item_path = /obj/item/pet_carrier
	donator_level = DONATOR_TIER_3
	/// Display names distinguish variants that share the same in-game name.
	var/static/list/pet_choices = list(
		"Корги" = /mob/living/basic/pet/dog/corgi,
		"Мопс" = /mob/living/basic/pet/dog/pug,
		"Бультерьер" = /mob/living/basic/pet/dog/bullterrier,
		"Щенок корги" = /mob/living/basic/pet/dog/corgi/puppy,
		"Экзотический корги" = /mob/living/basic/pet/dog/corgi/exoticcorgi,
		"Тамаскан" = /mob/living/basic/pet/dog/tamaskan,
		"Овчарка" = /mob/living/basic/pet/dog/german,
		"Бретонский эпаньоль" = /mob/living/basic/pet/dog/brittany,
		"Слизнёк" = /mob/living/basic/pet/dog/corgi/puppy/slime,
		"Полосатая кошка" = /mob/living/basic/pet/cat/tabby,
		"Кошка" = /mob/living/basic/pet/cat,
		"Котёнок" = /mob/living/basic/pet/cat/kitten,
		"Белый кот" = /mob/living/basic/pet/cat/white,
		"Бирманский кот" = /mob/living/basic/pet/cat/birman,
		"Чёрный кот" = /mob/living/basic/pet/cat/black,
		"Лиса" = /mob/living/basic/pet/fox,
		"Фенек" = /mob/living/basic/pet/fox/fennec,
		"Молетаракан" = /mob/living/basic/mothroach,
		"Паук из техтоннелей" = /mob/living/basic/spider/maintenance,
		"Мышь" = /mob/living/basic/mouse,
		"Хомяк" = /mob/living/basic/mouse/hamster,
		"Попугай" = /mob/living/basic/parrot,
	)

/datum/loadout_item/inhand/pet_carrier/get_ui_buttons()
	. = ..()
	UNTYPED_LIST_ADD(., list(
		"label" = "Питомец",
		"act_key" = "select_pet",
		"button_icon" = FA_ICON_PAW,
		"button_text" = "Выбрать",
		"active_key" = INFO_PET_TYPE,
	))

/datum/loadout_item/inhand/pet_carrier/handle_loadout_action(datum/preference_middleware/loadout/manager, mob/user, action, params)
	if(action != "select_pet")
		return ..()

	var/datum/preferences/preferences = manager.preferences
	var/client/player = user.client
	if(!player || player != preferences.parent || player.get_donator_level() < donator_level)
		return FALSE
	var/list/loadout = preferences.read_preference(/datum/preference/loadout)
	var/list/item_details = loadout?[item_path]
	if(isnull(item_details))
		return FALSE

	var/saved_pet = get_pet_type(item_details)
	var/default_choice
	for(var/pet_name in pet_choices)
		if(pet_choices[pet_name] == saved_pet)
			default_choice = pet_name
			break

	var/character_slot = preferences.default_slot
	var/choice = tgui_input_list(user, "Какого питомца вы хотите взять с собой?", "Переноска с питомцем", pet_choices, default_choice)
	if(!choice || !(choice in pet_choices) || QDELETED(user) || QDELETED(manager) || QDELETED(preferences))
		return FALSE
	if(player != user.client || player != preferences.parent || player.get_donator_level() < donator_level || preferences.default_slot != character_slot)
		return FALSE
	loadout = preferences.read_preference(/datum/preference/loadout)
	item_details = loadout?[item_path]
	if(isnull(item_details))
		return FALSE

	loadout = loadout.Copy()
	loadout[item_path] = item_details.Copy()
	loadout[item_path][INFO_PET_TYPE] = "[pet_choices[choice]]"
	return preferences.update_preference(GLOB.preference_entries[/datum/preference/loadout], loadout)

/// Resolve a saved choice against the roster, using the default pet for missing or invalid data.
/datum/loadout_item/inhand/pet_carrier/proc/get_pet_type(list/item_details)
	PRIVATE_PROC(TRUE)
	var/saved_pet = item_details?[INFO_PET_TYPE]
	var/pet_type = istext(saved_pet) ? text2path(saved_pet) : null
	if(pet_type && (pet_type in assoc_to_values(pet_choices)))
		return pet_type
	return /mob/living/basic/pet/dog/corgi

/datum/loadout_item/inhand/pet_carrier/on_equip_item(obj/item/equipped_item, list/item_details, mob/living/carbon/human/equipper, datum/outfit/outfit, visuals_only = FALSE)
	if(visuals_only || isdummy(equipper))
		return ..()
	var/turf/spawn_turf = get_turf(equipper)
	if(!spawn_turf)
		return ..()

	// An outfit leaves the item in contents if its assigned hand is unavailable.
	if(!equipped_item)
		equipped_item = locate(item_path) in equipper.contents
		if(equipped_item)
			equipper.put_in_hands(equipped_item)
	. = ..(equipped_item, item_details, equipper, outfit, visuals_only)
	var/obj/item/pet_carrier/carrier = equipped_item
	if(!istype(carrier) || length(carrier.occupants))
		return

	var/pet_type = get_pet_type(item_details)
	var/mob/living/pet = new pet_type(spawn_turf)
	pet.befriend(equipper)
	carrier.add_occupant(pet)
	carrier.open = FALSE
	carrier.unload_on_open = TRUE
	carrier.update_appearance()

#undef INFO_PET_TYPE

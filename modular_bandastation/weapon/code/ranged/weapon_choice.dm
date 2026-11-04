/// One-use sidearm delivery beacon with a catalogue specific to each job.
/obj/item/choice_beacon/weapon
	name = "sidearm weapon beacon"
	desc = "Одноразовый маяк для доставки оружия по вашему выбору. Пожалуйста, используйте его только в своем офисе."

/obj/item/choice_beacon/weapon/ui_interact(mob/user, datum/tgui/ui)
	if(QDELETED(src) || uses <= 0 || !isliving(user) || !can_use_beacon(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ChoiceBeaconWeapons", name)
		ui.open()

/obj/item/choice_beacon/weapon/open_options_menu(mob/living/user)
	ui_interact(user)

/obj/item/choice_beacon/weapon/ui_static_data(mob/user)
	var/static/list/weapon_info_cache = list()
	if(isnull(weapon_info_cache[type]))
		var/list/weapons = list()
		var/list/options = generate_display_names()
		for(var/display_name in options)
			var/list/info = build_weapon_info(display_name, options[display_name])
			if(info)
				weapons += list(info)
		weapon_info_cache[type] = weapons
	return list("weapons" = weapon_info_cache[type])

/obj/item/choice_beacon/weapon/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "deliver")
		return
	var/mob/living/user = ui.user
	if(QDELETED(src) || uses <= 0 || ui.src_object != src || !istype(user) || QDELETED(user) || !can_use_beacon(user))
		return TRUE
	var/list/options = generate_display_names()
	var/choice = params["choice"]
	if(!istext(choice) || isnull(options[choice]))
		return TRUE
	SStgui.close_uis(src)
	consume_use(options[choice], user)
	return TRUE

/** Builds the catalogue entry from the actual delivered loadout, including guns inside cases. */
/obj/item/choice_beacon/weapon/proc/build_weapon_info(display_name, obj/item/choice_path)
	var/obj/item/container = new choice_path(null)
	var/obj/item/gun/weapon = istype(container, /obj/item/gun) ? container : (locate(/obj/item/gun) in container)
	if(!weapon)
		qdel(container)
		return null

	var/list/info = list(
		"name" = display_name,
		"desc" = weapon.desc,
		"image" = icon2base64(getFlatIcon(weapon)),
		"weapon_type" = "other",
	)
	var/list/modes = list()
	if(istype(weapon, /obj/item/gun/ballistic))
		var/obj/item/gun/ballistic/ballistic_gun = weapon
		info["weapon_type"] = "ballistic"
		var/obj/item/ammo_box/magazine/magazine = ballistic_gun.magazine
		if(magazine)
			info["magazine_size"] = magazine.max_ammo
		var/obj/item/ammo_casing/casing = ballistic_gun.chambered || magazine?.get_round()
		if(casing)
			var/list/mode = build_mode_info(casing, weapon)
			if(mode)
				modes += list(mode)
	else if(istype(weapon, /obj/item/gun/energy))
		var/obj/item/gun/energy/energy_gun = weapon
		info["weapon_type"] = "energy"
		// The first entry is the delivered gun's selected mode, without changing its shared ammo list.
		var/list/casings = energy_gun.ammo_type.Copy()
		var/obj/item/ammo_casing/energy/default_mode = casings[energy_gun.select]
		casings -= default_mode
		casings.Insert(1, default_mode)
		for(var/obj/item/ammo_casing/energy/casing as anything in casings)
			var/list/mode = build_mode_info(casing, weapon, energy_gun.cell?.maxcharge)
			if(mode)
				modes += list(mode)
	info["modes"] = modes

	// Deleting the container also deletes its gun, magazines, casings, and cell.
	qdel(container)
	return info

/** Returns point-blank, unarmoured damage estimates and charge cost for one initialized firing mode. */
/obj/item/choice_beacon/weapon/proc/build_mode_info(obj/item/ammo_casing/casing, obj/item/gun/weapon, maxcharge)
	var/obj/projectile/projectile = casing.projectile_type
	if(!ispath(projectile, /obj/projectile))
		return null
	var/list/mode = list(
		"ammo_name" = casing.name,
		"weak_against_armour" = !!initial(projectile.weak_against_armour),
		"armour_penetration" = initial(projectile.armour_penetration),
	)
	if(istype(casing, /obj/item/ammo_casing/energy))
		var/obj/item/ammo_casing/energy/energy_casing = casing
		mode["ammo_name"] = energy_casing.select_name || energy_casing.name
		if(maxcharge > 0 && energy_casing.e_cost > 0)
			mode["energy_cost_percent"] = round(100 * energy_casing.e_cost / maxcharge, 0.1)
			mode["shots_per_charge"] = FLOOR(maxcharge / energy_casing.e_cost, 1)

	var/pellets = max(casing.pellets, 1)
	var/total_damage = initial(projectile.damage) * weapon.projectile_damage_multiplier * pellets
	var/total_stamina = initial(projectile.stamina) * weapon.projectile_damage_multiplier * pellets
	if(initial(projectile.damage_type) == STAMINA)
		total_stamina += total_damage
		total_damage = 0
	if(total_damage > 0)
		mode["hits_to_neutralize"] = HITS_TO_CRIT(total_damage)
	if(total_stamina > 0)
		mode["hits_to_exhaust"] = HITS_TO_CRIT(total_stamina)
	return mode

/obj/item/choice_beacon/weapon/security_pistol/generate_display_names()
	var/static/list/selectable_gun_types = list(
		"Пистолет GP-9 9x25мм" = /obj/item/storage/toolbox/guncase/ntcase/pistol/gp9/sec,
		"Энергетический пистолет дизейблер" = /obj/item/gun/energy/disabler,
	)
	return selectable_gun_types

/obj/item/choice_beacon/weapon/blueshield
	name = "blueshield sidearm weapon beacon"

/obj/item/choice_beacon/weapon/blueshield/generate_display_names()
	var/static/list/selectable_gun_types = list(
		"Энергетический пистолет EG-14" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/eg_14,
		"Термально-нанитовый пистолет TNG-3" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/tng_3,
		"Пистолет GP-38 калибра .38" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/gp38,
		"PDH-A1-M 'Ladon'" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/ladon,
	)
	return selectable_gun_types

/obj/item/choice_beacon/weapon/hos
	name = "HoS sidearm weapon beacon"

/obj/item/choice_beacon/weapon/hos/generate_display_names()
	var/static/list/selectable_gun_types = list(
		"Мультифазовый энергетический пистолет X-01" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/hos_laser,
		"Лазерный пистолет X-02" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/hos_laser2,
		"Пистолет GP-45M калибра .45" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/hos_gp45,
		"PDH-A2-NR 'Osprey'" = /obj/item/storage/toolbox/guncase/ntspecial/pistol/hos_pdh,
	)
	return selectable_gun_types

/obj/structure/closet/secure_closet/hos/PopulateContents()
	. = ..()
	new /obj/item/clothing/accessory/holster(src)

/datum/outfit/job/security
	suit_store = null
	backpack_contents = list(
		/obj/item/choice_beacon/weapon/security_pistol = 1,
	)

/datum/objective_item/steal/hoslaser
	name = "персональное оружие главы службы безопасности"
	steal_hint = "Уникальное оружие главы службы безопасности или маяк для его получения. \
		Обычно находится при нём или в его шкафчике. Подойдёт любой из четырёх вариантов личного оружия."
	altitems = list(
		/obj/item/choice_beacon/weapon/hos,
		/obj/item/gun/ballistic/automatic/pistol/pdh/hos,
		/obj/item/gun/ballistic/automatic/pistol/cm70/hos,
		/obj/item/gun/ballistic/automatic/laser/pistol,
	)

/obj/item/choice_beacon/weapon/hos/add_stealing_item_objective()
	return add_item_to_steal(src, /obj/item/gun/energy/e_gun/hos)

/obj/item/gun/ballistic/automatic/pistol/pdh/hos/add_stealing_item_objective()
	return add_item_to_steal(src, /obj/item/gun/energy/e_gun/hos)

/obj/item/gun/ballistic/automatic/pistol/cm70/hos/add_stealing_item_objective()
	return add_item_to_steal(src, /obj/item/gun/energy/e_gun/hos)

/obj/item/gun/ballistic/automatic/laser/pistol/add_stealing_item_objective()
	return add_item_to_steal(src, /obj/item/gun/energy/e_gun/hos)

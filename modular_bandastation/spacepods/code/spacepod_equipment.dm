/// A removable pod system. Slot names are internal constants, never client input.
/obj/item/spacepod_equipment
	name = "spacepod equipment"
	desc = "Сменный модуль космического челнока."
	icon = 'modular_bandastation/spacepods/icons/spacepod.dmi'
	w_class = WEIGHT_CLASS_BULKY
	var/obj/vehicle/sealed/spacepod/my_atom
	var/slot
	var/occupant_mod = 0

/obj/item/spacepod_equipment/Destroy()
	if(my_atom)
		removed(null)
		my_atom.detach_equipment(src)
	return ..()

/obj/item/spacepod_equipment/proc/installed(obj/vehicle/sealed/spacepod/pod)
	my_atom = pod

/obj/item/spacepod_equipment/proc/removed(mob/user)
	return

/obj/vehicle/sealed/spacepod/proc/equipment_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/spacepod_equipment/key))
		var/obj/item/spacepod_equipment/key/key = tool
		if(!lock_system || key.id != lock_system.id)
			balloon_alert(user, "неправильный ключ!")
			return ITEM_INTERACT_BLOCKING
		lock_pod(user, external = TRUE)
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/lock_buster))
		var/obj/item/lock_buster/buster = tool
		if(!buster.on || !Adjacent(user))
			balloon_alert(user, "сначала включите инструмент!")
			return ITEM_INTERACT_BLOCKING
		var/obj/item/spacepod_equipment/lock/old_lock = lock_system
		if(!old_lock)
			unlocked = TRUE
			return ITEM_INTERACT_SUCCESS
		if(!do_after(user, 10 SECONDS * buster.toolspeed, src))
			return ITEM_INTERACT_BLOCKING
		if(QDELETED(buster) || !user.is_holding(buster) || !buster.on || lock_system != old_lock || !Adjacent(user))
			return ITEM_INTERACT_BLOCKING
		qdel(old_lock)
		unlocked = TRUE
		balloon_alert(user, "замок высверлен")
		return ITEM_INTERACT_SUCCESS
	if(istype(tool, /obj/item/spacepod_equipment))
		var/obj/item/spacepod_equipment/equipment = tool
		return add_equipment(user, equipment, equipment.slot) ? ITEM_INTERACT_SUCCESS : ITEM_INTERACT_BLOCKING
	if(istype(sec_cargo_system, /obj/item/spacepod_equipment/sec_cargo/loot_box) && IsContainedAtomAccessible(sec_cargo_system, user))
		sec_cargo_system.atom_storage.attempt_insert(tool, user)
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/vehicle/sealed/spacepod/proc/can_install_equipment(obj/item/spacepod_equipment/equipment, slot)
	var/static/list/valid_slots = list("weapon_system", "misc_system", "cargo_system", "sec_cargo_system", "lock_system", "locator_system")
	return !QDELETED(src) && !QDELETED(equipment) && (slot in valid_slots) && slot == equipment.slot && !vars[slot] && !equipment.my_atom

/// Null user is reserved for map presets and skips the manual installation delay.
/obj/vehicle/sealed/spacepod/proc/add_equipment(mob/living/user, obj/item/spacepod_equipment/equipment, slot)
	if(!can_install_equipment(equipment, slot))
		return FALSE
	if(user)
		if(!hatch_open || !unlocked || !Adjacent(user) || !user.is_holding(equipment))
			balloon_alert(user, "откройте технический люк!")
			return FALSE
		if(!do_after(user, 2 SECONDS, src))
			return FALSE
		if(!can_install_equipment(equipment, slot) || !hatch_open || !unlocked || !Adjacent(user) || !user.is_holding(equipment))
			return FALSE
	return install_equipment(equipment, slot, user)

/// Presets and non-sleeping callbacks use the same commit path without a manual delay.
/obj/vehicle/sealed/spacepod/proc/install_equipment(obj/item/spacepod_equipment/equipment, slot, mob/living/user)
	SHOULD_NOT_SLEEP(TRUE)
	if(!can_install_equipment(equipment, slot))
		return FALSE
	if(user)
		if(!user.transferItemToLoc(equipment, src))
			return FALSE
	else
		equipment.forceMove(src)
	if(!can_install_equipment(equipment, slot) || equipment.loc != src)
		return FALSE
	vars[slot] = equipment
	installed_modules += equipment
	max_passengers += equipment.occupant_mod
	max_occupants = 1 + max_passengers
	equipment.installed(src)
	if(user)
		balloon_alert(user, "модуль установлен")
	return TRUE

/obj/vehicle/sealed/spacepod/proc/remove_equipment(mob/living/user, obj/item/spacepod_equipment/equipment, slot)
	if(QDELETED(equipment) || equipment.my_atom != src || equipment.slot != slot || vars[slot] != equipment)
		return FALSE
	if(length(passengers) > max_passengers - equipment.occupant_mod)
		if(user)
			balloon_alert(user, "сначала высадите пассажира!")
		return FALSE
	if(user)
		if(!hatch_open || !unlocked || !Adjacent(user) || !do_after(user, 2 SECONDS, src))
			return FALSE
		if(QDELETED(equipment) || equipment.my_atom != src || vars[slot] != equipment || !hatch_open || !unlocked || !Adjacent(user) || length(passengers) > max_passengers - equipment.occupant_mod)
			return FALSE
	if(!uninstall_equipment(equipment, slot, user))
		return FALSE
	if(user)
		user.put_in_hands(equipment)
	return TRUE

/// Module removal during a firing signal must never enter the manual do_after path.
/obj/vehicle/sealed/spacepod/proc/uninstall_equipment(obj/item/spacepod_equipment/equipment, slot, mob/living/user)
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(src) || QDELETED(equipment) || equipment.my_atom != src || equipment.slot != slot || vars[slot] != equipment || length(passengers) > max_passengers - equipment.occupant_mod)
		return FALSE
	equipment.removed(user)
	detach_equipment(equipment)
	equipment.forceMove(drop_location())
	return TRUE

/// Clear ownership once, including when a module is deleted independently of its pod.
/obj/vehicle/sealed/spacepod/proc/detach_equipment(obj/item/spacepod_equipment/equipment)
	if(equipment.my_atom != src)
		return
	if(equipment.slot && vars[equipment.slot] == equipment)
		vars[equipment.slot] = null
	installed_modules -= equipment
	max_passengers -= equipment.occupant_mod
	max_occupants = 1 + max_passengers
	equipment.my_atom = null

/obj/item/spacepod_equipment/weaponry
	name = "spacepod weapon"
	slot = "weapon_system"
	var/projectile_type
	var/shot_cost = 0
	var/shots_per = 1
	var/fire_sound
	var/fire_delay = 1.5 SECONDS
	var/harmful = TRUE
	COOLDOWN_DECLARE(weapon_cooldown)

/obj/vehicle/sealed/spacepod/proc/fireWeapon(mob/living/user)
	if(!can_control(user) || hatch_open || !weapon_system)
		return FALSE
	return weapon_system.fire_weapons(user)

/obj/item/spacepod_equipment/weaponry/proc/fire_weapons(mob/living/user)
	var/obj/vehicle/sealed/spacepod/pod = my_atom
	if(!pod?.can_control(user) || pod.hatch_open || pod.weapon_system != src || !COOLDOWN_FINISHED(src, weapon_cooldown))
		return FALSE
	if(harmful && HAS_TRAIT(user, TRAIT_PACIFISM))
		to_chat(user, span_warning("Вы не хотите причинять вред живым существам!"))
		return FALSE
	if(!pod.battery?.use(shot_cost * SPACEPOD_ENERGY_UNIT))
		pod.balloon_alert(user, "недостаточно энергии!")
		return FALSE
	// Rigged cells can explode during use() and delete their owning vehicle.
	if(QDELETED(src) || QDELETED(pod) || pod.weapon_system != src || !pod.can_control(user))
		return FALSE
	COOLDOWN_START(src, weapon_cooldown, fire_delay)
	for(var/shot in 1 to shots_per)
		// Bursts yield. Never keep firing after an exit, module removal or deletion.
		if(QDELETED(src) || QDELETED(pod) || my_atom != pod || pod.weapon_system != src || !pod.can_control(user) || pod.hatch_open)
			break
		var/turf/origin = get_turf(pod)
		if(!origin)
			break
		var/firing_angle = pod.flight.heading
		var/forward_x = sin(firing_angle)
		var/forward_y = cos(firing_angle)
		var/center_x = ICON_SIZE_X + pod.pixel_x - pod.base_pixel_x
		var/center_y = ICON_SIZE_Y + pod.pixel_y - pod.base_pixel_y
		var/half_tile = ICON_SIZE_ALL / 2
		var/datum/point/left_muzzle = new(origin.x, origin.y, origin.z, center_x + half_tile * (forward_x - forward_y), center_y + half_tile * (forward_y + forward_x))
		var/datum/point/right_muzzle = new(origin.x, origin.y, origin.z, center_x + half_tile * (forward_x + forward_y), center_y + half_tile * (forward_y - forward_x))
		if(!left_muzzle.return_turf() || !right_muzzle.return_turf())
			break
		for(var/datum/point/muzzle_point as anything in list(left_muzzle, right_muzzle))
			var/turf/muzzle = muzzle_point.return_turf()
			var/obj/projectile/projectile = new projectile_type(muzzle)
			projectile.starting = muzzle
			// Keep integer pixel offsets continuous on both sides of a turf boundary.
			projectile.pixel_x = round(muzzle_point.pixel_x - half_tile, 1)
			projectile.pixel_y = round(muzzle_point.pixel_y - half_tile, 1)
			projectile.firer = pod
			projectile.fired_from = src
			projectile.impacted[WEAKREF(pod)] = TRUE
			for(var/mob/rider as anything in pod.occupants)
				projectile.impacted[WEAKREF(rider)] = TRUE
			projectile.fire(firing_angle)
		playsound(pod, fire_sound, 50, TRUE)
		log_combat(user, pod, "fired pod weapons", src)
		if(shot < shots_per)
			sleep(0.2 SECONDS)
	return TRUE

/obj/item/spacepod_equipment/weaponry/taser
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5)
	name = "disabler system"
	desc = "Двухствольная система дизейблеров для челнока."
	icon_state = "weapon_taser"
	projectile_type = /obj/projectile/beam/disabler
	shot_cost = 800
	shots_per = 2
	fire_sound = 'sound/items/weapons/taser2.ogg'
	harmful = FALSE

/obj/item/spacepod_equipment/weaponry/burst_taser
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 7.5, /datum/material/plasma = SHEET_MATERIAL_AMOUNT * 1)
	name = "burst disabler system"
	desc = "Система дизейблеров, стреляющая очередью из трёх пар импульсов."
	icon_state = "weapon_burst_taser"
	projectile_type = /obj/projectile/beam/disabler
	shot_cost = 1200
	shots_per = 3
	fire_sound = 'sound/items/weapons/taser2.ogg'
	fire_delay = 3 SECONDS
	harmful = FALSE

/obj/item/spacepod_equipment/weaponry/laser
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1)
	name = "laser system"
	desc = "Двухствольная лазерная система для челнока."
	icon_state = "weapon_laser"
	projectile_type = /obj/projectile/beam/laser
	shot_cost = 1200
	shots_per = 2
	fire_sound = 'sound/items/weapons/laser.ogg'

/obj/item/spacepod_equipment/weaponry/solaris
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 5, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 1, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 2)
	name = "solaris system"
	desc = "Тяжёлая лазерная система для челнока."
	icon_state = "weapon_laser"
	projectile_type = /obj/projectile/beam/laser/heavylaser
	shot_cost = 1800
	shots_per = 2
	fire_sound = 'sound/items/weapons/lasercannonfire.ogg'

/obj/item/spacepod_equipment/weaponry/mining_laser_basic
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1, /datum/material/uranium = SHEET_MATERIAL_AMOUNT * 1)
	name = "kinetic accelerator system"
	desc = "Двухствольная шахтёрская система кинетических ускорителей."
	icon = 'modular_bandastation/spacepods/icons/ship.dmi'
	icon_state = "pod_taser"
	projectile_type = /obj/projectile/kinetic/spacepod
	shot_cost = 300
	fire_delay = 1.4 SECONDS
	fire_sound = 'sound/items/weapons/kinetic_accel.ogg'

/obj/item/spacepod_equipment/weaponry/mining_laser
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2.5, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 1, /datum/material/diamond = SHEET_MATERIAL_AMOUNT * 1)
	name = "industrial kinetic accelerator system"
	desc = "Усиленная двухствольная система кинетических ускорителей."
	icon = 'modular_bandastation/spacepods/icons/ship.dmi'
	icon_state = "pod_m_laser"
	projectile_type = /obj/projectile/kinetic/spacepod/industrial
	shot_cost = 250
	fire_delay = 1 SECONDS
	fire_sound = 'sound/items/weapons/kinetic_accel.ogg'

// A vehicle has no kinetic gun: the handheld parent's mining callback dereferences it.
/obj/projectile/kinetic/spacepod
	range = 4
	damage = 40

/obj/projectile/kinetic/spacepod/strike_thing(atom/target)
	var/turf/target_turf = get_turf(target) || get_turf(src)
	if(ismineralturf(target_turf))
		var/turf/closed/mineral/mineral = target_turf
		mineral.gets_drilled(firer, 1)
	new /obj/effect/temp_visual/kinetic_blast(target_turf)

/obj/projectile/kinetic/spacepod/industrial
	damage = 50
	pressure_decrease = 0.5

/obj/item/spacepod_equipment/misc
	name = "spacepod utility module"
	icon = 'modular_bandastation/spacepods/icons/ship.dmi'
	slot = "misc_system"

/obj/item/spacepod_equipment/misc/tracker
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5)
	name = "spacepod tracking system"
	desc = "Передаёт координаты и состояние челнока на консоль слежения."
	icon_state = "pod_locator"

/obj/item/spacepod_equipment/misc/tracker/Initialize(mapload)
	. = ..()
	GLOB.pod_trackers += src

/obj/item/spacepod_equipment/misc/tracker/Destroy()
	GLOB.pod_trackers -= src
	return ..()

/obj/item/spacepod_equipment/cargo
	name = "spacepod cargo module"
	icon_state = "cargo_blank"
	slot = "cargo_system"
	var/obj/storage

/obj/item/spacepod_equipment/cargo/removed(mob/user)
	unload()
	return ..()

/obj/item/spacepod_equipment/cargo/Destroy()
	unload()
	return ..()

/obj/item/spacepod_equipment/cargo/proc/unload(turf/destination)
	if(QDELETED(storage))
		return FALSE
	if(!storage.forceMove(destination || get_turf(my_atom || src)))
		return FALSE
	storage = null
	return TRUE

/obj/item/spacepod_equipment/cargo/proc/passover(list/footprint)
	return

/obj/item/spacepod_equipment/cargo/ore
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1)
	name = "spacepod ore storage system"
	desc = "Вмещает рудный ящик и собирает в него руду, над которой пролетает челнок."
	icon_state = "cargo_ore"

/obj/item/spacepod_equipment/cargo/ore/passover(list/footprint)
	if(!storage)
		return
	for(var/turf/pod_turf as anything in footprint)
		for(var/obj/item/stack/ore/ore in pod_turf)
			if(storage)
				ore.forceMove(storage)

/obj/item/spacepod_equipment/cargo/crate
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 12.5)
	name = "spacepod crate storage system"
	desc = "Грузовой отсек для одного ящика."
	icon_state = "cargo_crate"

/obj/vehicle/sealed/spacepod/proc/load_cargo(mob/living/user, obj/object)
	var/obj/item/spacepod_equipment/cargo/cargo = cargo_system
	if(QDELETED(src) || QDELETED(user) || QDELETED(cargo) || QDELETED(object) || !isturf(loc) || !isturf(object.loc) || cargo.my_atom != src || cargo.loc != src || cargo.storage || !unlocked || !Adjacent(user) || !user.Adjacent(object) || object.anchored)
		return FALSE
	if(istype(cargo, /obj/item/spacepod_equipment/cargo/ore))
		if(!istype(object, /obj/structure/ore_box))
			return FALSE
	else if(istype(cargo, /obj/item/spacepod_equipment/cargo/crate))
		if(!istype(object, /obj/structure/closet/crate))
			return FALSE
	else
		return FALSE
	if(istype(object, /obj/structure/closet))
		var/obj/structure/closet/closet = object
		if(closet.opened)
			return FALSE
	if(!do_after(user, 4 SECONDS, src))
		return FALSE
	if(QDELETED(src) || QDELETED(user) || QDELETED(cargo) || cargo != cargo_system || cargo.my_atom != src || cargo.loc != src || cargo.storage || QDELETED(object) || !isturf(loc) || !isturf(object.loc) || object.anchored || !unlocked || !Adjacent(user) || !user.Adjacent(object))
		return FALSE
	if(istype(object, /obj/structure/closet))
		var/obj/structure/closet/closet = object
		if(closet.opened)
			return FALSE
	if(!object.forceMove(cargo) || QDELETED(src) || QDELETED(cargo) || cargo != cargo_system || cargo.my_atom != src || cargo.loc != src || cargo.storage || QDELETED(object) || object.loc != cargo)
		return FALSE
	cargo.storage = object
	balloon_alert(user, "груз загружен")
	return TRUE

/obj/vehicle/sealed/spacepod/proc/unload(mob/living/user)
	if(!can_control(user) && (!can_service_cargo(user) || user.get_active_held_item()))
		return FALSE
	if(QDELETED(cargo_system) || cargo_system.my_atom != src || cargo_system.loc != src)
		balloon_alert(user, "нет грузового модуля!")
		return FALSE
	if(QDELETED(cargo_system.storage))
		balloon_alert(user, "грузовой отсек пуст")
		return FALSE
	var/turf/destination = find_cargo_unload_turf()
	if(!destination)
		balloon_alert(user, "рядом нет места!")
		return FALSE
	if(!cargo_system.unload(destination))
		return FALSE
	balloon_alert(user, "груз выгружен")
	return TRUE

/// Only the cargo fittings are externally accessible; the cabin keeps its other contents sealed.
/obj/vehicle/sealed/spacepod/proc/can_service_cargo(mob/living/user)
	return !QDELETED(src) && !melting_down && isliving(user) && !QDELETED(user) && isturf(user.loc) && !user.incapacitated && !user.combat_mode && !HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) && unlocked && !hatch_open && Adjacent(user)

/obj/vehicle/sealed/spacepod/IsContainedAtomAccessible(atom/contained, atom/movable/user)
	if(istype(contained, /obj/item/spacepod_equipment/sec_cargo/loot_box) && contained == sec_cargo_system)
		return sec_cargo_system.my_atom == src && sec_cargo_system.loc == src && can_service_cargo(user)
	return ..()

/// Search only the footprint's immediate edges, without dropping cargo beneath the cabin.
/obj/vehicle/sealed/spacepod/proc/find_cargo_unload_turf()
	if(!isturf(loc))
		return null
	for(var/turf/pod_turf as anything in locs)
		for(var/direction in GLOB.cardinals)
			var/turf/candidate = get_step(pod_turf, direction)
			if(!isopenturf(candidate) || (candidate in locs) || candidate.is_blocked_turf() || !pod_turf.Adjacent(candidate))
				continue
			return candidate
	return null

/obj/item/spacepod_equipment/sec_cargo
	name = "spacepod auxiliary cargo module"
	slot = "sec_cargo_system"

/obj/item/spacepod_equipment/sec_cargo/proc/check_storage(mob/user)
	return

/obj/item/spacepod_equipment/sec_cargo/chair
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3.75, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.25)
	name = "passenger seat"
	desc = "Дополнительное пассажирское место в челноке."
	icon_state = "sec_cargo_chair"
	occupant_mod = 1

/obj/item/spacepod_equipment/sec_cargo/loot_box
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3.75, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.25)
	name = "spacepod loot storage module"
	desc = "Небольшой грузовой отсек под сиденьем челнока."
	icon_state = "sec_cargo_loot"

/obj/item/spacepod_equipment/sec_cargo/loot_box/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 7, max_specific_storage = WEIGHT_CLASS_BULKY, max_total_storage = 14)

/obj/item/spacepod_equipment/sec_cargo/loot_box/Destroy()
	// A destroyed fitting must not delete the valuables stored in it.
	atom_storage?.close_all()
	atom_storage?.remove_all()
	return ..()

/obj/item/spacepod_equipment/sec_cargo/loot_box/removed(mob/user)
	atom_storage?.close_all()
	return ..()

/obj/item/spacepod_equipment/sec_cargo/loot_box/attempt_pickup(mob/living/user, skip_grav = FALSE)
	if(my_atom)
		return TRUE
	return ..()

/obj/item/spacepod_equipment/sec_cargo/loot_box/check_storage(mob/user)
	var/obj/vehicle/sealed/spacepod/pod = my_atom
	if(QDELETED(src) || QDELETED(pod) || pod.sec_cargo_system != src || loc != pod || !atom_storage)
		return FALSE
	if(pod.can_control(user))
		var/list/items = list()
		for(var/obj/item/item in contents)
			items += item
		if(!length(items))
			pod.balloon_alert(user, "малый отсек пуст")
			return FALSE
		var/obj/item/selected = tgui_input_list(user, "Какой предмет выгрузить рядом с челноком?", "Малый грузовой отсек", items)
		if(QDELETED(src) || QDELETED(pod) || my_atom != pod)
			return FALSE
		return unload_item(user, selected)
	if(pod.can_service_cargo(user))
		return atom_storage.open_storage(user)
	return FALSE

/// The pilot's hands stay blocked: selected items go outside through the normal storage removal API.
/obj/item/spacepod_equipment/sec_cargo/loot_box/proc/unload_item(mob/living/user, obj/item/item)
	var/obj/vehicle/sealed/spacepod/pod = my_atom
	if(QDELETED(src) || QDELETED(pod) || pod.sec_cargo_system != src || loc != pod || !atom_storage || !pod.can_control(user) || QDELETED(item) || item.loc != src)
		return FALSE
	var/turf/destination = pod.find_cargo_unload_turf()
	if(!destination)
		pod.balloon_alert(user, "рядом нет места!")
		return FALSE
	if(!atom_storage.remove_single(user, item, destination))
		return FALSE
	pod.balloon_alert(user, "предмет выгружен")
	return TRUE

/obj/item/spacepod_equipment/lock
	name = "spacepod lock"
	slot = "lock_system"
	var/id

/obj/item/spacepod_equipment/lock/keyed
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.25)
	name = "spacepod tumbler lock"
	desc = "Замок челнока, для которого можно выточить отдельный ключ."
	icon_state = "lock_tumbler"
	var/static/id_source = 0

/obj/item/spacepod_equipment/lock/keyed/Initialize(mapload)
	. = ..()
	id = ++id_source

/obj/item/spacepod_equipment/lock/keyed/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/spacepod_equipment/key))
		return ..()
	var/obj/item/spacepod_equipment/key/key = tool
	if(key.id)
		balloon_alert(user, "ключ уже выточен!")
		return ITEM_INTERACT_BLOCKING
	key.id = id
	balloon_alert(user, "ключ выточен")
	return ITEM_INTERACT_SUCCESS

/obj/item/spacepod_equipment/key
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.25)
	name = "spacepod key"
	desc = "Заготовка ключа. Примените её к снятому замку челнока."
	icon_state = "podkey"
	w_class = WEIGHT_CLASS_TINY
	var/id = 0

/obj/item/lock_buster
	name = "pod lock buster"
	desc = "Инструмент для высверливания замков челноков."
	icon = 'icons/obj/devices/tool.dmi'
	icon_state = "multitool"
	var/on = FALSE

/obj/item/lock_buster/attack_self(mob/user)
	on = !on
	balloon_alert(user, on ? "включено" : "выключено")

/obj/item/spacepod_equipment/locators
	name = "spacepod locator system"
	icon = 'modular_bandastation/spacepods/icons/locator.dmi'
	icon_state = "pod_locator"
	slot = "locator_system"
	var/can_ignore_z = FALSE
	var/can_found_all = FALSE

/obj/vehicle/sealed/spacepod/proc/startScan(mob/living/user)
	if(can_control(user))
		locator_system?.scan(user)

/obj/item/spacepod_equipment/locators/proc/scan(mob/user)
	if(!my_atom?.can_control(user))
		return
	var/list/results = list()
	for(var/obj/effect/landmark/ruin/ruin as anything in GLOB.ruin_landmarks)
		if(!ruin.ruin_template || (!can_ignore_z && ruin.z != my_atom.z))
			continue
		if(!can_found_all && !ruin.ruin_template.spacepod_detectable)
			continue
		var/area_size = ruin.ruin_template.width * ruin.ruin_template.height
		var/size_text = area_size <= 500 ? "малый" : area_size <= 900 ? "средний" : area_size <= 3000 ? "большой" : "огромный"
		results += "X: [ruin.x], Y: [ruin.y], Z: [ruin.z], размер: [size_text]"
	to_chat(user, span_notice(length(results) ? "Результаты сканирования:<br>[jointext(results, "<br>")]" : "Объектов в секторе не обнаружено."))

/obj/item/spacepod_equipment/locators/basic_pod_locator
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.5, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 1, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 0.5)
	name = "spacepod asteroid locator"
	desc = "Сканер координат астероидов в текущем секторе."

/obj/item/spacepod_equipment/locators/advanced_pod_locator
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 1, /datum/material/glass = SHEET_MATERIAL_AMOUNT * 2, /datum/material/silver = SHEET_MATERIAL_AMOUNT * 1, /datum/material/gold = SHEET_MATERIAL_AMOUNT * 1)
	name = "advanced spacepod locator"
	desc = "Сканер координат космических объектов в текущем секторе."
	can_found_all = TRUE

/// The basic scanner reveals only the native asteroid ruins.
/datum/map_template/ruin
	var/spacepod_detectable = FALSE

/datum/map_template/ruin/space/asteroid1
	spacepod_detectable = TRUE

/datum/map_template/ruin/space/asteroid2
	spacepod_detectable = TRUE

/datum/map_template/ruin/space/asteroid3
	spacepod_detectable = TRUE

/datum/map_template/ruin/space/asteroid4
	spacepod_detectable = TRUE

/datum/map_template/ruin/space/asteroid5
	spacepod_detectable = TRUE

/datum/map_template/ruin/space/asteroid6
	spacepod_detectable = TRUE

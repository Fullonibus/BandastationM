/obj/item/gun/energy/laser/awaymission_aeg
	name = "Exploreverse Mk.I"
	desc = "Прототип оружия с миниатюрным реактором для исследований в крайне отдаленных секторах."
	icon = 'modular_bandastation/weapon/icons/ranged/energy.dmi'
	icon_state = "laser_gate"
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 0.75,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 0.75,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.25,
	)
	lefthand_file = 'modular_bandastation/weapon/icons/ranged/inhands/energy/lefthand.dmi'
	righthand_file = 'modular_bandastation/weapon/icons/ranged/inhands/energy/righthand.dmi'
	inhand_icon_state = "laser_gate"
	pin = /obj/item/firing_pin/explorer
	ammo_type = list(/obj/item/ammo_casing/energy/lasergun/awaymission_aeg)
	ammo_x_offset = 0
	charge_delay = 10
	selfcharge = TRUE
	can_charge = FALSE
	/// The miniature reactor blows up under EMP.
	var/has_reactor = TRUE
	var/going_boom = FALSE

/obj/projectile/beam/laser/awaymission_aeg
	name = "weak laser"
	wound_bonus = -100
	exposed_wound_bonus = -100
	damage = 15

/obj/item/ammo_casing/energy/lasergun/awaymission_aeg
	projectile_type = /obj/projectile/beam/laser/awaymission_aeg
	e_cost = LASER_SHOTS(20, STANDARD_CELL_CHARGE)

/obj/item/gun/energy/laser/awaymission_aeg/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF || going_boom || !has_reactor)
		return
	var/turf/current_turf = get_turf(src)
	going_boom = TRUE
	addtimer(CALLBACK(src, PROC_REF(boom)), 3 SECONDS)
	do_sparks(3, FALSE, current_turf)
	playsound(current_turf, 'sound/effects/alert.ogg', 35, TRUE)
	loc.visible_message(span_warning("[capitalize(declent_ru(NOMINATIVE))] начинает пищать и светиться!"), span_userdanger("[capitalize(declent_ru(NOMINATIVE))] начинает пищать и светиться!"))

/obj/item/gun/energy/laser/awaymission_aeg/proc/boom()
	explosion(src, -1, -1, 1, 2)
	qdel(src)

/obj/item/gun/energy/laser/awaymission_aeg/mk2
	name = "Exploreverse Mk.II"
	desc = "Второй прототип оружия с миниатюрным реактором и забавным рычагом для исследований в крайне отдаленных секторах. \
	\nДанная модель оснащена системой ручного восполнения энергии \"Za.E.-8 A.L'sya\", \
	позволяющей в короткие сроки восполнить необходимую электроэнергию с помощью ручного труда и конвертации личной энергии подключенного к системе зарядки. \
	\nТеперь еще более нелепый дизайн с торчащими проводами!"
	icon_state = "laser_gate_mk2"
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.25,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
	)

/obj/item/gun/energy/laser/awaymission_aeg/mk2/attack_self(mob/living/user)
	. = ..()
	if(cell.charge >= cell.maxcharge)
		user.balloon_alert(user, "полностью заряжен!")
		return FALSE

	if(user.nutrition <= NUTRITION_LEVEL_STARVING)
		user.balloon_alert(user, "недостаточно сил!")
		return FALSE

	user.balloon_alert(user, "зарядка...")
	playsound(src, 'sound/effects/sparks/sparks3.ogg', 10, 1)
	do_sparks(1, 1, src)

	if(!do_after(user, 3 SECONDS, target = src))
		return
	var/obj/item/ammo_casing/energy/ammo = ammo_type[1]
	cell.give(ammo::e_cost)
	user.adjust_nutrition(-10)

/datum/design/exploreverse_mk1
	name = "Exploreverse Mk.I"
	desc = "Энергетическое оружие с экспериментальным миниатюрным реактором."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3.5,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 0.75,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 0.75,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.25,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	transfered_materials = list(
		/obj/item/gun/energy/laser/awaymission_aeg = /obj/item/gun/energy/laser/awaymission_aeg::custom_materials,
		/obj/item/firing_pin/explorer = /obj/item/firing_pin/explorer::custom_materials,
		/obj/item/stock_parts/power_store/cell = list(),
		/obj/item/ammo_casing/energy/lasergun/awaymission_aeg = list(),
	)
	build_path = /obj/item/gun/energy/laser/awaymission_aeg
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_RANGED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_SECURITY
/datum/design/exploreverse_mk2
	name = "Exploreverse Mk.II"
	desc = "Энергетическое оружие с экспериментальным миниатюрным реактором и рычагом для ручной зарядки."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4.5,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.25,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	transfered_materials = list(
		/obj/item/gun/energy/laser/awaymission_aeg/mk2 = /obj/item/gun/energy/laser/awaymission_aeg/mk2::custom_materials,
		/obj/item/firing_pin/explorer = /obj/item/firing_pin/explorer::custom_materials,
		/obj/item/stock_parts/power_store/cell = list(),
		/obj/item/ammo_casing/energy/lasergun/awaymission_aeg = list(),
	)
	build_path = /obj/item/gun/energy/laser/awaymission_aeg/mk2
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_RANGED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/mining/New()
	. = ..()
	unlocked_designs |= /datum/design/exploreverse_mk1

/datum/techweb_node/plasma_mining/New()
	. = ..()
	unlocked_designs |= /datum/design/exploreverse_mk2

/// Third prototype in a Sierra laser carbine body: no self-charge, it fires from swappable battery magazines.
/obj/item/gun/energy/laser/awaymission_aeg/mk3
	name = "Exploreverse Mk.III"
	desc = "Третий прототип линейки Exploreverse в корпусе лазерного карабина. Самозарядки нет: питается от сменных батарей, \
		которые вставляются и извлекаются как магазин и заряжаются в оружейном зарядном устройстве."
	icon_state = "laser_gate_mk3"
	inhand_icon_state = "laser"
	lefthand_file = 'icons/mob/inhands/weapons/guns_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/guns_righthand.dmi'
	ammo_type = list(/obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3)
	cell_type = /obj/item/stock_parts/power_store/cell/exploreverse
	selfcharge = FALSE
	has_reactor = FALSE
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.5,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
	)

// Without its magazine the carbine shows the empty well and no charge strip.
/obj/item/gun/energy/laser/awaymission_aeg/mk3/update_icon_state()
	. = ..()
	icon_state = cell ? initial(icon_state) : "[initial(icon_state)]_nomag"

/obj/item/gun/energy/laser/awaymission_aeg/mk3/update_overlays()
	. = ..()
	if(!cell)
		. -= "[icon_state]_empty"

/obj/item/gun/energy/laser/awaymission_aeg/mk3/examine(mob/user)
	. = ..()
	if(!cell)
		. += span_warning("Батарея не вставлена.")
		return
	var/obj/item/ammo_casing/energy/shot = ammo_type[select]
	. += span_notice("Батарея: [round(cell.charge / shot.e_cost)] из [round(cell.maxcharge / shot.e_cost)] выстрелов.")

/obj/item/gun/energy/laser/awaymission_aeg/mk3/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/stock_parts/power_store/cell))
		return ..()
	if(!istype(tool, /obj/item/stock_parts/power_store/cell/exploreverse))
		balloon_alert(user, "не подходит!")
		return ITEM_INTERACT_BLOCKING
	var/obj/item/stock_parts/power_store/cell/old_cell = cell
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	// A loaded gun swaps magazines; the old one leaving clears `cell` through Exited().
	if(old_cell)
		user.put_in_hands(old_cell)
	cell = tool
	recharge_newshot(TRUE)
	update_appearance()
	playsound(src, 'sound/items/weapons/gun/general/magazine_insert_full.ogg', 40, TRUE)
	balloon_alert(user, old_cell ? "батарея заменена" : "батарея вставлена")
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/energy/laser/awaymission_aeg/mk3/attack_self(mob/living/user)
	. = ..()
	if(.)
		return
	if(!cell)
		balloon_alert(user, "нет батареи!")
		return
	var/obj/item/stock_parts/power_store/cell/old_cell = cell
	user.put_in_hands(old_cell)
	playsound(src, 'sound/items/weapons/gun/general/magazine_remove_full.ogg', 40, TRUE)
	balloon_alert(user, "батарея извлечена")

/// Battery magazine of the Exploreverse Mk.III: a quarter more shots than the Mk.I, charged like any other cell.
/obj/item/stock_parts/power_store/cell/exploreverse
	name = "Exploreverse Mk.III battery"
	desc = "Сменная батарея-магазин для Exploreverse Mk.III. Заряжается в оружейном зарядном устройстве."
	icon = 'modular_bandastation/weapon/icons/ranged/energy.dmi'
	icon_state = "exploreverse_battery"
	maxcharge = STANDARD_CELL_CHARGE * 1.25
	// Its own three lights replace the standard cell charge light.
	charge_light_type = null
	custom_materials = list(
		/datum/material/iron = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT * 5,
	)

/obj/item/stock_parts/power_store/cell/exploreverse/update_overlays()
	. = ..()
	if(charge >= 0.01)
		. += "[icon_state]_charge[clamp(CEILING(percent() / (100 / 3), 1), 1, 3)]"

/obj/item/stock_parts/power_store/cell/exploreverse/empty
	empty = TRUE

// The magazine charges on a weapon recharger, which also draws on the APC's cell; the cell charger takes only grid surplus.
/obj/machinery/cell_charger/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/stock_parts/power_store/cell/exploreverse))
		balloon_alert(user, "нужна оружейная зарядка!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/datum/design/exploreverse_battery
	name = "Exploreverse Mk.III Battery"
	desc = "Сменная батарея-магазин для Exploreverse Mk.III. Печатается разряженной."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT * 5,
	)
	build_path = /obj/item/stock_parts/power_store/cell/exploreverse/empty
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_RANGED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_SECURITY

/obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3
	fire_sound = 'modular_bandastation/weapon/sound/ranged/exploreverse_mk3_fire.ogg'

/datum/design/exploreverse_mk3
	name = "Exploreverse Mk.III"
	desc = "Лазерный карабин на сменных батареях-магазинах."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4.5,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.5,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
	)
	transfered_materials = list(
		/obj/item/gun/energy/laser/awaymission_aeg/mk3 = /obj/item/gun/energy/laser/awaymission_aeg/mk3::custom_materials,
		/obj/item/firing_pin/explorer = /obj/item/firing_pin/explorer::custom_materials,
		/obj/item/stock_parts/power_store/cell/exploreverse = list(),
		/obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3 = list(),
	)
	build_path = /obj/item/gun/energy/laser/awaymission_aeg/mk3
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_RANGED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/mining_adv/New()
	. = ..()
	unlocked_designs |= list(/datum/design/exploreverse_mk3, /datum/design/exploreverse_battery)

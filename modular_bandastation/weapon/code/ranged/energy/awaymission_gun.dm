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
	if(. & EMP_PROTECT_SELF || going_boom)
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

/// Third prototype: the Mk.I's reactor in a Sierra laser carbine body, with a heavy shot against large fauna.
/obj/item/gun/energy/laser/awaymission_aeg/mk3
	name = "Exploreverse Mk.III"
	desc = "Третий прототип оружия с миниатюрным реактором, в корпусе лазерного карабина. \
	\nКроме обычного луча стреляет тяжёлым зарядом против крупной фауны: он съедает четверть батареи. Переключение режимов — в руке."
	icon_state = "laser_gate_mk3"
	inhand_icon_state = "laser"
	lefthand_file = 'icons/mob/inhands/weapons/guns_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/guns_righthand.dmi'
	ammo_type = list(/obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3, /obj/item/ammo_casing/energy/lasergun/awaymission_heavy)
	// The carbine's charge strip is drawn into whole sprites, one per level, rather than overlays.
	automatic_charge_overlays = FALSE
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT * 1.5,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 0.5,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
	)

/obj/item/gun/energy/laser/awaymission_aeg/mk3/update_icon_state()
	. = ..()
	icon_state = "[initial(icon_state)]_[get_charge_ratio()]"

// After a heavy shot the reactor audibly charges up; the reload sound (1.14 s) ends as the next heavy shot is ready.
/obj/item/gun/energy/laser/awaymission_aeg/mk3/shoot_live_shot(mob/living/user, pointblank = FALSE, atom/pbtarget = null, message = TRUE)
	. = ..()
	if(istype(ammo_type[select], /obj/item/ammo_casing/energy/lasergun/awaymission_heavy))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), src, 'sound/items/weapons/kinetic_reload.ogg', 50, TRUE), fire_delay - 1.15 SECONDS)

/obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3
	fire_sound = 'modular_bandastation/weapon/sound/ranged/exploreverse_mk3_fire.ogg'

/obj/item/ammo_casing/energy/lasergun/awaymission_heavy
	projectile_type = /obj/projectile/beam/laser/heavylaser/awaymission
	e_cost = LASER_SHOTS(4, STANDARD_CELL_CHARGE)
	select_name = "тяжёлый"
	fire_sound = 'sound/items/weapons/lasercannonfire.ogg'
	// The reactor needs time to charge the next heavy shot.
	delay = 2 SECONDS

/obj/projectile/beam/laser/heavylaser/awaymission
	wound_bonus = -100
	exposed_wound_bonus = -100

/datum/design/exploreverse_mk3
	name = "Exploreverse Mk.III"
	desc = "Энергетическое оружие с экспериментальным миниатюрным реактором и тяжёлым режимом огня против крупной фауны."
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
		/obj/item/stock_parts/power_store/cell = list(),
		/obj/item/ammo_casing/energy/lasergun/awaymission_aeg/mk3 = list(),
		/obj/item/ammo_casing/energy/lasergun/awaymission_heavy = list(),
	)
	build_path = /obj/item/gun/energy/laser/awaymission_aeg/mk3
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_RANGED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/mining_adv/New()
	. = ..()
	unlocked_designs |= /datum/design/exploreverse_mk3

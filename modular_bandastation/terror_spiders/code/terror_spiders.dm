/mob/living/basic/spider/giant/terror
	abstract_type = /mob/living/basic/spider/giant/terror
	name = "паук ужаса"
	desc = "Крупный паук с острыми хелицерами."
	icon = 'modular_bandastation/terror_spiders/icons/terrorspider.dmi'
	icon_state = "terror_red"
	icon_living = "terror_red"
	icon_dead = "terror_red_dead"
	faction = list(FACTION_TERROR_SPIDER)
	initial_language_holder = /datum/language_holder/terror_spider
	gold_core_spawnable = NO_SPAWN
	unique_name = FALSE
	maxHealth = 120
	health = 120
	melee_damage_lower = 15
	melee_damage_upper = 20
	attack_sound = 'modular_bandastation/terror_spiders/sound/bite.ogg'
	death_sound = 'modular_bandastation/terror_spiders/sound/death.ogg'
	habitable_atmos = null
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	move_resist = MOVE_FORCE_STRONG
	speed = 4
	player_speed_modifier = -3
	sight = SEE_TURFS | SEE_MOBS | SEE_OBJS
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror
	/// Heavy castes cannot squeeze into ventilation.
	var/can_ventcrawl = TRUE
	var/can_wrap = TRUE
	var/can_pry_powered_airlocks = FALSE
	var/loud_hive_voice = FALSE
	var/terror_tier = 1
	/// Health restored every two seconds, before food and jelly.
	var/terror_regeneration = 2
	var/list/terror_damage_coefficients = list(BRUTE = 0.75, BURN = 1.25, STAMINA = 0, OXY = 0.2)
	var/terror_force_threshold = 0
	var/fed = 0
	var/datum/weakref/terror_queen_ref
	var/terror_degenerating = FALSE
	/// Speed modifier applied while standing on Terror Spider webbing.
	var/web_speed_modifier = /datum/movespeed_modifier/terror_web

/mob/living/basic/spider/giant/terror/Initialize(mapload)
	. = ..()
	qdel(GetComponent(/datum/component/tameable))
	if(can_ventcrawl)
		ADD_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NEGATES_GRAVITY, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_PUSHIMMUNE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOMOBSWAP, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_MEDICAL_HUD, INNATE_TRAIT)
	AddElement(/datum/element/terror_hivemind)
	RegisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(play_terror_hurt))
	if(terror_tier >= 2)
		grant_language(/datum/language/common)
	if(can_wrap)
		GRANT_ACTION(/datum/action/cooldown/mob_cooldown/wrap/terror)
	var/static/list/web_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_terror_web_changed),
		COMSIG_ATOM_EXITED = PROC_REF(on_terror_web_changed),
		COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON = PROC_REF(on_terror_web_changed),
	)
	AddElement(/datum/element/connect_loc, web_connections)
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(refresh_terror_web))
	refresh_terror_web()

/mob/living/basic/spider/giant/terror/Login()
	. = ..()
	if(.)
		RemoveElement(/datum/element/ridable, /datum/component/riding/creature/spider)

/mob/living/basic/spider/giant/terror/red
	name = "рыцарь ужаса"
	desc = "Массивный паук с алыми глазами и прочным панцирем."
	menu_description = "Штурмовик. Переключается между яростью и защитной стойкой, плетёт усиленную паутину."
	maxHealth = 220
	health = 220
	melee_damage_upper = 15
	attack_sound = 'modular_bandastation/terror_spiders/sound/bite2.ogg'
	death_sound = 'modular_bandastation/terror_spiders/sound/death1.ogg'
	armour_penetration = 25
	obj_damage = 60
	speed = 5
	player_speed_modifier = -3.2
	terror_damage_coefficients = list(BRUTE = 0.6, BURN = 1.1, STAMINA = 0, OXY = 0.2)
	can_pry_powered_airlocks = TRUE
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror_reinforced
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_knight_mode/attack,
		/datum/action/cooldown/mob_cooldown/terror_knight_mode/defense,
	)

/mob/living/basic/spider/giant/terror/gray
	name = "наблюдатель ужаса"
	desc = "Серый паук с полупрозрачным панцирем."
	menu_description = "Охотник из засады. Ненадолго становится невидимым и сильнее кусает, стоя в паутине."
	icon_state = "terror_gray"
	icon_living = "terror_gray"
	icon_dead = "terror_gray_dead"
	death_sound = 'modular_bandastation/terror_spiders/sound/death5.ogg'
	maxHealth = 100
	health = 100
	melee_damage_upper = 15
	armour_penetration = 2
	player_speed_modifier = -3.3
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror_transparent
	innate_actions = list(/datum/action/cooldown/mob_cooldown/terror_lurker_stealth)

/mob/living/basic/spider/giant/terror/green
	name = "лекарь ужаса"
	desc = "На зеленоватом панцире блестит вязкая слизь."
	menu_description = "Лечит союзников. Питаясь трупами, усиливает лечение и получает возможность откладывать яйца."
	icon_state = "terror_green"
	icon_living = "terror_green"
	icon_dead = "terror_green_dead"
	death_sound = 'modular_bandastation/terror_spiders/sound/death4.ogg'
	maxHealth = 100
	health = 100
	melee_damage_lower = 10
	melee_damage_upper = 15
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror_slimy
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/lay_eggs/terror,
		/datum/action/cooldown/mob_cooldown/terror_healing,
	)

/mob/living/basic/spider/giant/terror/reaper
	name = "жнец ужаса"
	desc = "Быстрый паук с острыми кровавыми хелицерами."
	menu_description = "Теряет здоровье со временем и восстанавливает его укусами живых людей."
	icon_state = "terror_reaper"
	icon_living = "terror_reaper"
	icon_dead = "terror_reaper_dead"
	attack_sound = 'modular_bandastation/terror_spiders/sound/bite2.ogg'
	death_sound = 'modular_bandastation/terror_spiders/sound/death3.ogg'
	maxHealth = 110
	health = 110
	melee_damage_lower = 20
	melee_damage_upper = 25
	armour_penetration = 15
	obj_damage = 50
	player_speed_modifier = -3.3
	terror_regeneration = 0
	terror_damage_coefficients = list(BRUTE = 0.85, STAMINA = 0, OXY = 0.2)
	can_pry_powered_airlocks = TRUE
	web_type = null

/mob/living/basic/spider/giant/terror/builder
	web_speed_modifier = /datum/movespeed_modifier/terror_web/drone
	name = "дрон ужаса"
	desc = "Небольшой паук, покрытый плотной паутиной."
	menu_description = "Быстро плетёт прочную герметичную паутину, в ней ускоряется и лечится. Замедляет добычу плевками."
	icon_state = "terror_drone"
	icon_living = "terror_drone"
	icon_dead = "terror_drone_dead"
	maxHealth = 100
	health = 100
	melee_damage_lower = 10
	melee_damage_upper = 15
	obj_damage = 50
	speed = 5
	terror_regeneration = 0
	can_wrap = FALSE
	can_pry_powered_airlocks = TRUE
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror/airtight/drone
	innate_actions = list(/datum/action/cooldown/mob_cooldown/projectile_attack/terror_drone_spit)

/mob/living/basic/spider/giant/terror/black
	name = "вдова ужаса"
	desc = "На чёрном брюшке видна яркая метка. С хелицер капает яд."
	menu_description = "Впрыскивает яд укусами, ставит ядовитую паутину и плюётся кислотой, оставляющей дым."
	icon_state = "terror_widow"
	icon_living = "terror_widow"
	icon_dead = "terror_widow_dead"
	death_sound = 'modular_bandastation/terror_spiders/sound/death2.ogg'
	melee_damage_lower = 10
	melee_damage_upper = 15
	player_speed_modifier = -3.1
	terror_tier = 2
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror_venom
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/venom,
		/datum/action/cooldown/mob_cooldown/projectile_attack/terror_widow_spit/smoke,
	)

/mob/living/basic/spider/giant/terror/brown
	name = "разрушитель ужаса"
	desc = "Его передние лапы похожи на тяжёлые крючья."
	menu_description = "Ломает укреплённые стены, срывает крышки вентиляции, вызывает ЭМИ и огненное кольцо."
	icon_state = "terror_brown"
	icon_living = "terror_brown"
	icon_dead = "terror_brown_dead"
	melee_damage_lower = 10
	melee_damage_upper = 15
	obj_damage = 100
	player_speed_modifier = -3.1
	web_type = null
	terror_tier = 2
	can_wrap = FALSE
	can_pry_powered_airlocks = TRUE
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_vent_breach,
		/datum/action/cooldown/mob_cooldown/terror_destroyer_shriek,
		/datum/action/cooldown/mob_cooldown/terror_destroyer_ignite,
	)

/mob/living/basic/spider/giant/terror/purple
	name = "защитник ужаса"
	desc = "Широкий панцирь этого паука хорошо защищает его в бою."
	menu_description = "Ставит защитную мембрану, плетёт непрозрачную паутину и ломает стены. \
		Если вы связаны с королевой, держитесь ближе 10 клеток от неё на том же этаже. \
		Через 3 минуты разлуки укусы ослабевают, и вы начинаете терять здоровье. Возвращение к королеве уже не остановит потерю здоровья. \
		Гибель вашей королевы тоже приводит к потере здоровья."
	icon_state = "terror_purple"
	icon_living = "terror_purple"
	icon_dead = "terror_purple_dead"
	attack_sound = 'modular_bandastation/terror_spiders/sound/bite2.ogg'
	death_sound = 'modular_bandastation/terror_spiders/sound/death6.ogg'
	maxHealth = 250
	health = 250
	melee_damage_lower = 20
	melee_damage_upper = 25
	armour_penetration = 10
	obj_damage = 70
	terror_tier = 2
	terror_damage_coefficients = list(BRUTE = 0.6, BURN = 1.1, STAMINA = 0, OXY = 0.2)
	can_wrap = FALSE
	can_ventcrawl = FALSE
	can_pry_powered_airlocks = TRUE
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror_opaque
	innate_actions = list(/datum/action/cooldown/mob_cooldown/terror_guardian_membrane)

/mob/living/basic/spider/giant/terror/white
	name = "осквернитель ужаса"
	desc = "Под бледным брюшком шевелятся крошечные яйца."
	menu_description = "Заражает жертв и плетёт паутину с яйцами. Оглушает визгом и выпускает дым двух видов."
	icon_state = "terror_white"
	icon_living = "terror_white"
	icon_dead = "terror_white_dead"
	death_sound = 'modular_bandastation/terror_spiders/sound/death2.ogg'
	maxHealth = 200
	health = 200
	melee_damage_lower = 1
	melee_damage_upper = 1
	player_speed_modifier = -3.3
	terror_tier = 3
	can_pry_powered_airlocks = TRUE
	loud_hive_voice = TRUE
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror_infested
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_smoke,
		/datum/action/cooldown/mob_cooldown/terror_parasmoke,
		/datum/action/cooldown/mob_cooldown/terror_defiler_shriek,
		/datum/action/cooldown/mob_cooldown/terror_empress_egg,
	)

/mob/living/basic/spider/giant/terror/mother
	name = "мать ужаса"
	desc = "На брюшке видны железы, выделяющие лечебный секрет для выводка."
	menu_description = "Исцеляет пауков вокруг себя, производит лечебное желе и может смотреть глазами союзников."
	icon_state = "terror_mother"
	icon_living = "terror_mother"
	icon_dead = "terror_mother_dead"
	maxHealth = 220
	health = 220
	melee_damage_lower = 10
	melee_damage_upper = 15
	terror_tier = 3
	can_wrap = FALSE
	can_ventcrawl = FALSE
	can_pry_powered_airlocks = TRUE
	loud_hive_voice = TRUE
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_vent_breach,
		/datum/action/cooldown/mob_cooldown/terror_remote_view,
		/datum/action/cooldown/mob_cooldown/terror_royal_jelly,
		/datum/action/cooldown/mob_cooldown/terror_healing/greater,
	)

/mob/living/basic/spider/giant/terror/prince
	name = "принц ужаса"
	desc = "Огромный чёрный паук в толстом панцире."
	menu_description = "Проламывает стены, валит добычу топотом и разрывает ослабленных жертв."
	icon_state = "terror_allblack"
	icon_living = "terror_allblack"
	icon_dead = "terror_allblack_dead"
	attack_sound = 'modular_bandastation/terror_spiders/sound/bite2.ogg'
	death_sound = 'modular_bandastation/terror_spiders/sound/prince_dead.ogg'
	maxHealth = 600
	health = 600
	melee_damage_lower = 35
	melee_damage_upper = 45
	armour_penetration = 20
	obj_damage = 100
	player_speed_modifier = -3.1
	can_ventcrawl = FALSE
	terror_tier = 3
	terror_regeneration = 0
	terror_force_threshold = 30
	terror_damage_coefficients = list(BRUTE = 0.3, BURN = 0.6, STAMINA = 0, OXY = 0.2)
	can_pry_powered_airlocks = TRUE
	loud_hive_voice = TRUE
	web_type = null
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_prince_slam,
		/datum/action/cooldown/mob_cooldown/terror_empress_egg,
	)

/mob/living/basic/spider/giant/terror/queen
	name = "королева ужаса"
	desc = "Исполинский паук с тяжёлым яйцевым мешком."
	menu_description = "Основывает гнездо, выводит новые касты, ослабляет врагов визгом и плюётся кислотой."
	icon_state = "terror_queen"
	icon_living = "terror_queen"
	icon_dead = "terror_queen_dead"
	death_sound = 'modular_bandastation/terror_spiders/sound/queen_death.ogg'
	maxHealth = 340
	health = 340
	melee_damage_lower = 25
	melee_damage_upper = 30
	armour_penetration = 20
	obj_damage = 100
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror/airtight
	terror_tier = 4
	can_wrap = FALSE
	can_pry_powered_airlocks = TRUE
	loud_hive_voice = TRUE
	terror_regeneration = 3
	terror_force_threshold = 18
	terror_damage_coefficients = list(BRUTE = 0.7, BURN = 1.1, STAMINA = 0, OXY = 0.2)
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_nest,
		/datum/action/cooldown/mob_cooldown/set_spider_directive,
		/datum/action/cooldown/mob_cooldown/terror_vent_breach,
		/datum/action/cooldown/mob_cooldown/terror_remote_view,
		/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/queen,
		/datum/action/cooldown/mob_cooldown/terror_royal_shriek/queen,
		/datum/action/cooldown/mob_cooldown/terror_empress_egg,
	)

/mob/living/basic/spider/giant/terror/queen/princess
	name = "принцесса ужаса"
	desc = "Молодая королева с пушистым брюшком и небольшим яйцевым мешком."
	menu_description = "Выводит пауков без гнезда. Ослабляет врагов визгом и плюётся кислотой."
	icon_state = "terror_princess1"
	icon_living = "terror_princess1"
	icon_dead = "terror_princess1_dead"
	death_sound = 'modular_bandastation/terror_spiders/sound/princess_death.ogg'
	maxHealth = 200
	health = 200
	melee_damage_lower = 15
	melee_damage_upper = 20
	obj_damage = 60
	player_speed_modifier = -3.1
	terror_tier = 3
	web_type = /datum/action/cooldown/mob_cooldown/lay_web/terror/airtight/princess
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/lay_eggs/terror/royal/princess,
		/datum/action/cooldown/mob_cooldown/set_spider_directive,
		/datum/action/cooldown/mob_cooldown/terror_vent_breach,
		/datum/action/cooldown/mob_cooldown/terror_hive_sense,
		/datum/action/cooldown/mob_cooldown/terror_remote_view,
		/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/princess,
		/datum/action/cooldown/mob_cooldown/terror_royal_shriek/princess,
		/datum/action/cooldown/mob_cooldown/terror_empress_egg,
	)

/mob/living/basic/spider/giant/terror/queen/empress
	name = "императрица ужаса"
	desc = "Гигантская матка пауков ужаса."
	menu_description = "Создаёт массовый выводок, может уничтожить улей и плюётся особо едкой кислотой."
	icon = 'modular_bandastation/terror_spiders/icons/terrorspider64.dmi'
	icon_state = "terror_empress"
	icon_living = "terror_empress"
	icon_dead = "terror_empress_dead"
	pixel_x = -16
	base_pixel_x = -16
	mob_size = MOB_SIZE_LARGE
	maxHealth = 1000
	health = 1000
	melee_damage_lower = 30
	melee_damage_upper = 60
	ai_controller = null
	terror_tier = 5
	innate_actions = list(
		/datum/action/cooldown/mob_cooldown/terror_nest,
		/datum/action/cooldown/mob_cooldown/set_spider_directive,
		/datum/action/cooldown/mob_cooldown/terror_vent_breach,
		/datum/action/cooldown/mob_cooldown/terror_remote_view,
		/datum/action/cooldown/mob_cooldown/projectile_attack/terror_royal_acid/empress,
		/datum/action/cooldown/mob_cooldown/terror_royal_shriek/queen,
		/datum/action/cooldown/mob_cooldown/terror_empress_spawn,
		/datum/action/cooldown/mob_cooldown/terror_empress_erase,
	)

/// The native cocoon handles movement and one-time consumption.
/datum/action/cooldown/mob_cooldown/wrap/terror
	name = "Спеленать"
	desc = "Завернуть предмет или труп в кокон. Питание трупами ускоряет восстановление."
	button_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	button_icon_state = "cocoon_large1"
	active_icon_state = null
	background_icon = 'modular_bandastation/terror_spiders/icons/actions.dmi'
	background_icon_state = "bg_terror"
	overlay_icon_state = null
	wrap_time = 4 SECONDS

/datum/action/cooldown/mob_cooldown/wrap/terror/Activate(atom/to_wrap)
	var/mob/living/victim = to_wrap
	if(isliving(victim) && victim.stat != DEAD)
		owner.balloon_alert(owner, "цель ещё жива!")
		return FALSE
	return ..()

/datum/action/cooldown/mob_cooldown/wrap/terror/cocoon(atom/movable/to_wrap)
	if(!QDELETED(owner))
		playsound(owner, 'modular_bandastation/terror_spiders/sound/wrap.ogg', 120, TRUE)
	return ..()

/datum/action/cooldown/mob_cooldown/wrap/terror/wrap_target(mob/living/to_wrap)
	var/mob/living/basic/spider/giant/terror/spider = owner
	if(QDELETED(spider) || spider.incapacitated || QDELETED(to_wrap) || to_wrap.anchored || !isturf(to_wrap.loc) || !spider.Adjacent(to_wrap))
		return
	if(isliving(to_wrap) && to_wrap.stat != DEAD)
		return
	var/feed = iscarbon(to_wrap) && !HAS_TRAIT(to_wrap, TRAIT_SPIDER_CONSUMED)
	..()
	if(!feed)
		return
	ADD_TRAIT(to_wrap, TRAIT_SPIDER_CONSUMED, TRAIT_GENERIC)
	spider.fed++
	spider.apply_status_effect(/datum/status_effect/terror_recovery/food)
	for(var/datum/action/cooldown/mob_cooldown/lay_eggs/terror/eggs in spider.actions)
		eggs.build_all_button_icons()

/obj/item/organ/cyberimp/arm/toolkit/mantis
	name = "'Naginata' mantis blade implant"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Скрытый клинок предплечья. Пара клинков позволяет наносить двойные удары и вскрывать двери. ЭМИ вызывает ожоги руки."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "syndie_mantis"
	items_to_create = list(/obj/item/melee/mantis_blade)
	valid_zones = list(BODY_ZONE_R_ARM = ORGAN_SLOT_RIGHT_ARM_AUG)
	hand_state = FALSE

/obj/item/organ/cyberimp/arm/toolkit/mantis/emp_act(severity)
	. = ..()
	if((. & EMP_PROTECT_SELF) || !owner)
		return
	owner.apply_damage(10 / severity, BURN, zone)

/obj/item/organ/cyberimp/arm/toolkit/mantis/left
	zone = BODY_ZONE_L_ARM
	slot = ORGAN_SLOT_LEFT_ARM_AUG
	valid_zones = list(BODY_ZONE_L_ARM = ORGAN_SLOT_LEFT_ARM_AUG)

/obj/item/melee/mantis_blade
	name = "'Naginata' mantis blade"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "Выдвижной клинок предплечья. Пара позволяет наносить двойные удары, вскрывать двери и блокировать атаки с вероятностью 50%."
	icon = 'modular_bandastation/uplink_items/icons/items.dmi'
	icon_state = "syndie_mantis"
	inhand_icon_state = "syndie_mantis"
	lefthand_file = 'modular_bandastation/uplink_items/icons/implants_lefthand.dmi'
	righthand_file = 'modular_bandastation/uplink_items/icons/implants_righthand.dmi'
	force = 15
	armour_penetration = 0
	block_chance = 50
	w_class = WEIGHT_CLASS_BULKY
	sharpness = SHARP_EDGED
	hitsound = 'sound/items/weapons/bladeslice.ogg'
	block_sound = 'sound/items/weapons/parry.ogg'
	attack_verb_continuous = list("slashes", "slices", "cuts")
	attack_verb_simple = list("slash", "slice", "cut")
	COOLDOWN_DECLARE(double_attack_cooldown)

/obj/item/melee/mantis_blade/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_TOOL_FORCE_OPEN_AIRLOCK, PROC_REF(check_prying))

/obj/item/melee/mantis_blade/attack(mob/living/victim, mob/living/user, list/modifiers, list/attack_modifiers)
	var/obj/item/melee/mantis_blade/second_blade = user.get_inactive_held_item()
	. = ..()
	if(. || HAS_TRAIT(user, TRAIT_PACIFISM) || !istype(second_blade) || second_blade == src || user.get_active_held_item() != src || !COOLDOWN_FINISHED(src, double_attack_cooldown) || !COOLDOWN_FINISHED(second_blade, double_attack_cooldown))
		return
	COOLDOWN_START(src, double_attack_cooldown, 1.5 SECONDS)
	COOLDOWN_START(second_blade, double_attack_cooldown, 1.5 SECONDS)
	addtimer(CALLBACK(second_blade, PROC_REF(second_strike), victim, user, src), 0.2 SECONDS)

/obj/item/melee/mantis_blade/proc/second_strike(mob/living/victim, mob/living/user, obj/item/melee/mantis_blade/first_blade)
	if(QDELETED(victim) || QDELETED(user) || QDELETED(first_blade) || user.incapacitated || !user.is_holding(src) || !user.is_holding(first_blade) || !user.Adjacent(victim))
		return
	attack(victim, user)

/obj/item/melee/mantis_blade/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text, final_block_chance, damage, attack_type, damage_type)
	var/obj/item/other_blade = owner.get_active_held_item()
	if(other_blade != src && istype(other_blade, /obj/item/melee/mantis_blade))
		return FALSE
	return ..()

/obj/item/melee/mantis_blade/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(user.combat_mode || !istype(interacting_with, /obj/machinery/door))
		return NONE
	if(!istype(user.get_inactive_held_item(), /obj/item/melee/mantis_blade))
		balloon_alert(user, "нужны оба клинка!")
		return ITEM_INTERACT_BLOCKING
	if(istype(interacting_with, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = interacting_with
		airlock.try_to_crowbar(src, user, forced = TRUE)
		return ITEM_INTERACT_SUCCESS
	if(istype(interacting_with, /obj/machinery/door/firedoor))
		interacting_with.crowbar_act(user, src)
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/item/melee/mantis_blade/proc/check_prying(obj/item/source, mob/living/user, obj/machinery/door/airlock/airlock)
	SIGNAL_HANDLER
	if(!user.is_holding(src) || !istype(user.get_inactive_held_item(), /obj/item/melee/mantis_blade))
		return COMPONENT_TOOL_DO_NOT_ALLOW_FORCE_OPEN

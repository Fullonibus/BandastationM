/// A Midnight skin on the elite Syndicate MODsuit plating.
/datum/mod_theme/elite/midnight
	name = "Midnight"
	desc = "An elite Syndicate MODsuit with graphite armor and a red visor."
	extended_desc = "An elite Gorlex Marauders combat MODsuit finished in graphite with red accents."
	default_skin = "midnight"
	armor_type = /datum/armor/mod_theme_elite/midnight

/datum/mod_theme/elite/midnight/New()
	inbuilt_modules = (inbuilt_modules - /obj/item/mod/module/night) + /obj/item/mod/module/night/midnight
	var/list/midnight_skin = deep_copy_list_alt(variants["elite"])
	midnight_skin[MOD_ICON_OVERRIDE] = 'modular_bandastation/prime_only/icons/object/mod_midnight.dmi'
	midnight_skin[MOD_WORN_ICON_OVERRIDE] = 'modular_bandastation/prime_only/icons/mob/mod_midnight.dmi'
	variants = list("midnight" = midnight_skin)
	return ..()

/// Reinforced Midnight plating with class V wound protection.
/datum/armor/mod_theme_elite/midnight
	melee = 70
	bullet = 70
	laser = 60
	energy = 60
	bomb = 65
	wound = 50

/// An upgraded elite Syndicate loadout with Midnight styling and a gatling fusion cell.
/obj/item/mod/control/pre_equipped/elite/midnight
	theme = /datum/mod_theme/elite/midnight
	applied_cell = /obj/item/stock_parts/power_store/cell/minigun
	req_access = null

/obj/item/mod/control/pre_equipped/elite/midnight/Initialize(mapload, new_theme, new_skin, new_core)
	applied_modules = (applied_modules - /obj/item/mod/module/emp_shield) + list(
		/obj/item/mod/module/emp_shield/advanced,
		/obj/item/mod/module/energy_shield/midnight,
		/obj/item/mod/module/magboot/advanced,
	)
	default_pins = default_pins + list(/obj/item/mod/module/energy_shield/midnight, /obj/item/mod/module/magboot/advanced)
	return ..()

/// A manual shield switch using the MOD's existing module controls.
/obj/item/mod/module/energy_shield/midnight
	module_type = MODULE_TOGGLE
	idle_power_cost = 0
	active_power_cost = DEFAULT_CHARGE_DRAIN * 0.5
	/// Absolute recharge deadlines survive removing the shield component while switched off.
	var/saved_hit_cooldown = 0
	var/saved_charge_cooldown = 0

/obj/item/mod/module/energy_shield/midnight/on_activation(mob/activator)
	. = ..()
	on_part_activation()

/obj/item/mod/module/energy_shield/midnight/on_deactivation(mob/activator, display_message = TRUE, deleting = FALSE)
	. = ..()
	on_part_deactivation(deleting)

/obj/item/mod/module/energy_shield/midnight/on_part_activation()
	if(!active || mod.GetComponent(/datum/component/shielded))
		return
	. = ..()
	var/datum/component/shielded/shield = mod.GetComponent(/datum/component/shielded)
	shield.recently_hit_cd = saved_hit_cooldown
	shield.charge_add_cd = saved_charge_cooldown

/obj/item/mod/module/energy_shield/midnight/on_part_deactivation(deleting = FALSE)
	var/datum/component/shielded/shield = mod.GetComponent(/datum/component/shielded)
	if(!shield)
		return
	saved_hit_cooldown = shield.recently_hit_cd
	saved_charge_cooldown = shield.charge_add_cd
	return ..()

/obj/item/mod/module/energy_shield/midnight/on_unequip()
	. = ..()
	if(active)
		deactivate(display_message = FALSE)

/// Uses the security night-vision HUD's red shading without changing other MODs.
/obj/item/mod/module/night/midnight
	desc = "A night vision module with red low-light shading, compatible with other MOD visor modules."

/obj/item/mod/module/night/midnight/on_activation(mob/activator)
	RegisterSignal(mod.wearer, COMSIG_LIVING_RESTORE_INITIAL_SIGHT, PROC_REF(on_initial_sight))
	. = ..()
	mod.wearer.update_sight()

/obj/item/mod/module/night/midnight/on_deactivation(mob/activator, display_message = TRUE, deleting = FALSE)
	UnregisterSignal(mod.wearer, COMSIG_LIVING_RESTORE_INITIAL_SIGHT)
	. = ..()
	mod.wearer.update_sight()

/obj/item/mod/module/night/midnight/on_unequip()
	. = ..()
	if(active)
		deactivate(display_message = FALSE)

/// Matches the existing security night-vision HUD's tint in dark areas.
/obj/item/mod/module/night/midnight/proc/on_initial_sight(mob/living/source)
	SIGNAL_HANDLER
	source.lighting_color_cutoffs = blend_cutoff_colors(source.lighting_color_cutoffs, list(40, 15, 10))

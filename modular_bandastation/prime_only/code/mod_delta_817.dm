/// Standard MODsuit equipment for Delta-817 operators.
/datum/mod_theme/apocryphal/delta_817
	name = "Delta-817 standard"
	desc = "A standard-issue MODsuit for Delta-817 operators."
	extended_desc = "An Apocryphal-based MODsuit issued as standard equipment to Delta-817 operators."
	default_skin = "apocryphal"

/datum/mod_theme/apocryphal/delta_817/New()
	// Keep the Apocryphal part configuration while using Delta-817 sprites.
	variants = deep_copy_list_alt(variants)
	variants["apocryphal"][MOD_ICON_OVERRIDE] = 'modular_bandastation/prime_only/icons/centcom/ModDelta.dmi'
	variants["apocryphal"][MOD_WORN_ICON_OVERRIDE] = 'modular_bandastation/prime_only/icons/centcom/ModDelta.dmi'
	return ..()

/obj/item/mod/control/pre_equipped/apocryphal/delta_817
	theme = /datum/mod_theme/apocryphal/delta_817

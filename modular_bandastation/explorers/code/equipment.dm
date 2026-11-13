/// Sierra field blade using the native hatchet's cutting and butchering mechanics.
/obj/item/hatchet/expedition_machete
	name = "экспедиционное мачете"
	desc = "Длинный прочный клинок с удобной рукоятью для расчистки пути в экспедициях. Обухом можно поддеть дверь или ящик, как монтировкой, только медленнее."
	icon = 'modular_bandastation/explorers/icons/machete.dmi'
	icon_state = "machete"
	inhand_icon_state = "machete"
	lefthand_file = 'modular_bandastation/explorers/icons/machete_lefthand.dmi'
	righthand_file = 'modular_bandastation/explorers/icons/machete_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	force = 20
	wound_bonus = 5
	// The heavy back of the blade pries doors and crates open, slower than a real crowbar.
	tool_behaviour = TOOL_CROWBAR
	toolspeed = 1.5

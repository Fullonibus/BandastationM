// MARK: Lamppost

/obj/structure/lamppost
	name = "lamp post"
	desc = "A tall street lamp."
	icon = 'modular_bandastation/altam/icons/obj/lamppost/lamppost.dmi'
	anchored = TRUE
	density = TRUE
	icon_state = "lamppost_1"
	base_icon_state = "lamppost_1"
	var/active = FALSE
	light_range = 0
	light_power = 0
	light_color = "#e2d225"
	pixel_y = 10
	layer = LOW_ITEM_LAYER

/obj/structure/lamppost/Initialize()
	. = ..()
	base_icon_state = icon_state

/obj/structure/lamppost/attack_hand(mob/user)
	active = !active
	update_lamp()

/obj/structure/lamppost/update_icon_state()
	. = ..()
	if(active)
		icon_state = "[base_icon_state]-on"
	else
		icon_state = base_icon_state

/obj/structure/lamppost/proc/update_lamp()
	update_icon_state()
	if(active)
		light_range = 5
		light_power = 1.5
	else
		light_range = 0
		light_power = 0
	update_light()

/obj/structure/lamppost/double
	icon_state = "lamppost_2"
	base_icon_state = "lamppost_2"

/obj/structure/lamppost/rusted
	icon_state = "lamppost_rusted_1"
	base_icon_state = "lamppost_rusted_1"

/obj/structure/lamppost/rusted/double
	icon_state = "lamppost_rusted_2"
	base_icon_state = "lamppost_rusted_2"

/obj/structure/lamppost_broken
	name = "broken lamp post"
	desc = "A broken lamp post."
	icon = 'modular_bandastation/altam/icons/obj/lamppost/lamppost.dmi'
	anchored = TRUE
	density = TRUE
	icon_state = "lamppost_broken_1"
	pixel_y = 10
	layer = LOW_ITEM_LAYER

/obj/structure/lamppost_broken/two
	icon_state = "lamppost_broken_2"

/obj/structure/lamppost_broken/three
	icon_state = "lamppost_broken_3"

/obj/structure/lamppost_broken/four
	icon_state = "lamppost_broken_4"

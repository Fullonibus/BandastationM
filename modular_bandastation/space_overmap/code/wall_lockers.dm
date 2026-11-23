/// Compact wall storage for ship corridors and rooms.
/obj/structure/closet/wall
	name = "настенный шкафчик"
	desc = "Компактный шкафчик для хранения вещей. Крепится к стене и оставляет проход свободным."
	icon = 'modular_bandastation/space_overmap/icons/wallcloset.dmi'
	icon_state = "generic"
	anchored = TRUE
	anchorable = FALSE
	density = FALSE
	wall_mounted = TRUE
	max_mob_size = MOB_SIZE_TINY
	storage_capacity = 15
	paint_jobs = FALSE
	can_install_electronics = FALSE
	divable = FALSE

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall, 32)

/obj/structure/closet/wall/Initialize(mapload)
	. = ..()
	if(mapload)
		find_and_mount_on_atom()

/obj/structure/closet/wall/mouse_drop_receive(atom/movable/dropped, mob/living/user, params)
	if(isliving(dropped))
		var/mob/living/creature = dropped
		if(creature.mob_size > max_mob_size)
			return
	return ..()

/obj/structure/closet/wall/engineering
	name = "настенный шкафчик инженера"
	icon_state = "engi"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/engineering, 32)

/obj/structure/closet/wall/engineering/atmospherics
	name = "настенный шкафчик атмосферного техника"
	icon_state = "atmos"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/engineering/atmospherics, 32)

/obj/structure/closet/wall/medical
	name = "настенный медицинский шкафчик"
	icon_state = "med"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/medical, 32)

/obj/structure/closet/wall/medical/chemistry
	name = "настенный шкафчик химика"
	icon_door = "chem"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/medical/chemistry, 32)

/obj/structure/closet/wall/science
	name = "настенный научный шкафчик"
	icon_state = "sci"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/science, 32)

/obj/structure/closet/wall/science/robotics
	name = "настенный шкафчик робототехника"
	icon_door = "robo"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/science/robotics, 32)

/obj/structure/closet/wall/security
	name = "настенный шкафчик службы безопасности"
	icon_state = "sec"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/security, 32)

/obj/structure/closet/wall/cargo
	name = "настенный шкафчик снабжения"
	icon_state = "cargo"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/cargo, 32)

/obj/structure/closet/wall/cargo/mining
	name = "настенный шкафчик шахтёра"
	icon_door = "miner"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/cargo/mining, 32)

/obj/structure/closet/wall/botany
	name = "настенный шкафчик ботаника"
	icon_state = "hydro"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/botany, 32)

/obj/structure/closet/wall/janitor
	name = "настенный шкафчик уборщика"
	icon_state = "jani"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/janitor, 32)

/obj/structure/closet/wall/emergency
	name = "настенный аварийный шкафчик"
	icon_state = "emergency"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/emergency, 32)

/obj/structure/closet/wall/emergency/PopulateContents()
	..()
	populate_emergency_supplies()

/obj/structure/closet/wall/nanotrasen
	name = "настенный шкафчик НаноТрейзен"
	icon_state = "nanotrasen"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/nanotrasen, 32)

/obj/structure/closet/wall/syndicate
	name = "настенный шкафчик Синдиката"
	icon_state = "syndicate"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/closet/wall/syndicate, 32)

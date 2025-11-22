// MARK: Decal
// Кирпичики
/obj/effect/decal/bricks
	name = "bricks"
	desc = "A pile of bricks."
	icon = 'modular_bandastation/altam/icons/effects/decals/decals.dmi'
	icon_state = "bricks1"

/obj/effect/decal/bricks/two
	icon_state = "bricks2"

/obj/effect/decal/bricks/three
	icon_state = "bricks3"

/obj/effect/decal/bricks/four
	icon_state = "bricks4"

/obj/effect/decal/bricks/five
	icon_state = "bricks5"

/obj/effect/decal/bricks/six
	icon_state = "bricks6"

/obj/effect/decal/bricks/seven
	icon_state = "bricks7"

/obj/effect/decal/bricks/eight
	icon_state = "bricks8"

/obj/effect/decal/bricks/nine
	icon_state = "bricks9"

// Сломанный пол и грязючка
/obj/structure/broken_flooring/plating/always_floorplane/dirt
	name = "dirt"
	icon = 'modular_bandastation/altam/icons/effects/decals/decals.dmi'
	icon_state = "dirt1"

/obj/structure/broken_flooring/plating/always_floorplane/dirt/side
	icon_state = "dirt2"

/obj/structure/broken_flooring/plating/always_floorplane/dirt/angle
	icon_state = "dirt3"

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/broken_flooring/plating/always_floorplane/dirt, 0)
MAPPING_DIRECTIONAL_HELPERS(/obj/structure/broken_flooring/plating/always_floorplane/dirt/side, 0)
MAPPING_DIRECTIONAL_HELPERS(/obj/structure/broken_flooring/plating/always_floorplane/dirt/angle, 0)

// Воронка
/obj/effect/decal/shell_crater
	name = "shell crater"
	desc = "A shell does not fall twice in the same place."
	icon = 'modular_bandastation/altam/icons/effects/decals/decals.dmi'
	icon_state = "shell_crater"

// Осколки
/obj/effect/decal/shards
	name = "shards"
	desc = "A pile of shards."
	icon = 'modular_bandastation/altam/icons/effects/decals/decals.dmi'
	icon_state = "shards"

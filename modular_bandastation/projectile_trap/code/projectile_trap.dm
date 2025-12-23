/obj/structure/trap/projectile_trap
	name = "projectile trap"
	icon = 'icons/obj/cigarettes.dmi'
	icon_state = "candybum"
	desc = "Джокушка"
	sparks = FALSE
	charges = 1

	var/projectile_origin_x = 0
	var/projectile_origin_y = 0
	var/projectile_origin_z = 0
	var/projectile_type = /obj/projectile/bullet/arrow
	var/projectile_fire_sound = 'sound/items/weapons/fwoosh.ogg'
	var/projectile_origin_radius = 5

/obj/structure/trap/projectile_trap/Initialize(mapload)
	. = ..()
	var/turf/origin_turf
	var/closest_dist = INFINITY

	for(var/turf/closed/S in range(projectile_origin_radius, src))
		if(S == src)
			continue
		var/turf/T = get_turf(S)
		if(!T)
			continue
		var/d = get_dist(src, S)
		if(d < closest_dist)
			closest_dist = d
			origin_turf = T

	if(origin_turf)
		projectile_origin_x = origin_turf.x
		projectile_origin_y = origin_turf.y
		projectile_origin_z = origin_turf.z

/obj/structure/trap/projectile_trap/trap_effect(mob/living/victim)
	var/turf/target = get_turf(src)
	if(!target)
		return

	if(!ispath(projectile_type, /obj/projectile))
		return

	var/turf/spawn_from = null
	// если при инициализации не найден закрытый турф в радиусе - спавним из рандомной точки в радиусе
	if(projectile_origin_x && projectile_origin_y)
		spawn_from = locate(projectile_origin_x, projectile_origin_y, projectile_origin_z || target.z)

	if(!spawn_from)
		var/list/candidates = list()
		for(var/turf/T in range(projectile_origin_radius, target))
			candidates += T
		if(candidates.len)
			spawn_from = pick(candidates)
		else
			spawn_from = target

	if(!spawn_from)
		return

	spawn_from.fire_projectile(projectile_type, target, projectile_fire_sound, src)

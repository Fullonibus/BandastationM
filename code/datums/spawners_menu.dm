/datum/spawners_menu
	var/mob/dead/observer/owner

/datum/spawners_menu/New(mob/dead/observer/new_owner)
	if(!istype(new_owner))
		qdel(src)
	owner = new_owner

/datum/spawners_menu/Destroy()
	owner = null
	return ..()

/datum/spawners_menu/ui_state(mob/user)
	return GLOB.observer_state

/datum/spawners_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SpawnersMenu")
		ui.open()

/datum/spawners_menu/ui_data(mob/user)
	var/list/data = list()
	data["spawners"] = list()
	for(var/spawner in GLOB.mob_spawners)
		var/list/this = list()
		this["name"] = spawner
		this["amount_left"] = 0
		for(var/obj/effect/mob_spawn/ghost_role/mob_spawner as anything in GLOB.mob_spawners[spawner])
			if(!spawner_is_available(mob_spawner, user))
				continue
			if(!this["amount_left"] && !this["infinite"])
				this["you_are_text"] = mob_spawner.you_are_text
				this["flavor_text"] = mob_spawner.flavour_text
				this["important_text"] = mob_spawner.important_text
			this["amount_left"] += mob_spawner.uses
			this["infinite"] += mob_spawner.infinite_use
		if(this["amount_left"] > 0 || this["infinite"])
			data["spawners"] += list(this)
	for(var/mob_type in GLOB.joinable_mobs)
		var/list/this = list()
		this["name"] = mob_type
		this["amount_left"] = 0
		for(var/mob/joinable_mob as anything in GLOB.joinable_mobs[mob_type])
			SEND_SIGNAL(joinable_mob, COMSIG_LIVING_GHOSTROLE_INFO, this)
			this["amount_left"] += 1
			this["desc"] ||= initial(joinable_mob.desc)

		if(this["amount_left"] > 0)
			data["spawners"] += list(this)
	return data

/// Whether this spawner can appear in the menu and be selected for an action.
/datum/spawners_menu/proc/spawner_is_available(obj/effect/mob_spawn/ghost_role/spawner, mob/user)
	return !QDELETED(spawner) && (spawner.uses > 0 || spawner.infinite_use) && spawner.allow_spawn(user, silent = TRUE)

/datum/spawners_menu/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(. || QDELETED(owner) || ui.user != owner)
		return

	var/group_name = params["name"]
	if(!istext(group_name))
		return

	var/list/spawnerlist = list()

	if (group_name in GLOB.mob_spawners)
		for(var/obj/effect/mob_spawn/ghost_role/current_spawner as anything in GLOB.mob_spawners[group_name])
			if(spawner_is_available(current_spawner, owner))
				spawnerlist += current_spawner
	else if (group_name in GLOB.joinable_mobs)
		spawnerlist = GLOB.joinable_mobs[group_name]

	if(!length(spawnerlist))
		return
	var/atom/mob_spawner = pick(spawnerlist)
	if(!SSpoints_of_interest.is_valid_poi(mob_spawner))
		return

	switch(action)
		if("jump")
			if(mob_spawner)
				owner.forceMove(get_turf(mob_spawner))
				return TRUE
		if("spawn")
			if(mob_spawner)
				owner.ManualFollow(mob_spawner)
				ui.close()
				mob_spawner.attack_ghost(owner)
				return TRUE

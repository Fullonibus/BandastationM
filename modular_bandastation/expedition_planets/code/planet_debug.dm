ADMIN_VERB(stationtrauma_planet_system, R_DEBUG, "Overmap - Планеты системы", "Посмотреть выпавшие планеты и заменить отдельные до высадки.", ADMIN_CATEGORY_DEBUG)
	SSstationtrauma_space_voyage.ui_interact(user.mob)

/datum/controller/subsystem/stationtrauma_space_voyage/ui_status(mob/user, datum/ui_state/state)
	return check_rights_for(user?.client, R_DEBUG) ? UI_INTERACTIVE : UI_CLOSE

/datum/controller/subsystem/stationtrauma_space_voyage/ui_interact(mob/user, datum/tgui/ui)
	if(ui_status(user) != UI_INTERACTIVE)
		ui?.close()
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OvermapPlanetDebug", "Планеты системы")
		ui.open()

/datum/controller/subsystem/stationtrauma_space_voyage/ui_static_data(mob/user)
	var/list/profiles = list()
	for(var/datum/stationtrauma_overmap_site/space/planet/profile as anything in typesof(/datum/stationtrauma_overmap_site/space/planet))
		var/generator_type = initial(profile.generator_type)
		var/datum/map_generator/expedition_barren/generator = new generator_type(1)
		var/list/options = list()
		for(var/datum/expedition_planet_modifier/modifier as anything in expedition_planet_modifiers())
			if(modifier.name && modifier.can_apply(generator))
				options += list(list("id" = "[modifier.type]", "name" = modifier.name, "group" = modifier.group))
		qdel(generator)
		profiles += list(list("id" = "[profile]", "name" = initial(profile.name), "modifiers" = options))
	return list("profiles" = profiles)

/datum/controller/subsystem/stationtrauma_space_voyage/ui_data(mob/user)
	var/list/systems = list()
	for(var/sector_id in sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = sectors[sector_id]
		if(!QDELETED(sector) && sector.ready)
			systems += list(list("id" = sector_id, "name" = sector.name, "planets" = sector.debug_planet_overview()))
	return list("systems" = systems)

/datum/controller/subsystem/stationtrauma_space_voyage/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/client/user = ui.user?.client
	if(!check_rights_for(user, R_DEBUG))
		return FALSE
	var/sector_id = params["system"]
	var/planet_id = params["planet"]
	if(!istext(sector_id) || !istext(planet_id))
		return FALSE
	var/datum/stationtrauma_overmap_sector/space/sector = sectors[sector_id]
	if(QDELETED(sector) || !sector.ready)
		return FALSE
	var/datum/stationtrauma_overmap_site/space/planet/planet = sector.sites[planet_id]
	if(!istype(planet) || QDELETED(planet) || params["ref"] != REF(planet))
		to_chat(user, span_warning("Планета изменилась. Проверь обновлённые параметры."), confidential = TRUE)
		return TRUE

	switch(action)
		if("details")
			var/datum/browser/details = new(ui.user, "overmap_planet_details", "Параметры планеты", 850, 600)
			details.set_content(planet.debug_report())
			details.open()
			return TRUE
		if("generate")
			if(planet.awaits_map() && !planet.loading_map && !planet.failed)
				debug_generate_surface(user, sector_id, planet)
			return TRUE
		if("random_replace", "replace")
			var/planet_type
			var/seed
			var/level
			var/width = 0
			var/list/modifier_types
			if(action == "random_replace")
				planet_type = pick(typesof(/datum/stationtrauma_overmap_site/space/planet))
				seed = rand(1, 1000000)
				level = planet.modifier_level
			else
				var/profile = params["profile"]
				if(!istext(profile))
					return FALSE
				planet_type = text2path(profile)
				seed = params["seed"]
				level = params["level"]
				width = params["width"]
				switch(params["mode"])
					if("manual")
						var/list/selection = params["modifiers"]
						if(!islist(selection) || length(selection) > length(expedition_planet_modifiers()))
							return FALSE
						modifier_types = list()
						for(var/entry in selection)
							if(!istext(entry))
								return FALSE
							var/modifier_type = text2path(entry)
							if(!ispath(modifier_type, /datum/expedition_planet_modifier))
								return FALSE
							modifier_types += modifier_type
					if("none")
						modifier_types = list()
					if("random")
						modifier_types = null
					else
						return FALSE
			var/datum/stationtrauma_overmap_site/space/planet/replacement = sector.debug_replace_planet(planet, planet_type, seed, level, width, modifier_types)
			if(QDELETED(replacement))
				to_chat(user, span_warning("Замена отклонена. Планета уже используется, параметры недопустимы или модификаторы конфликтуют."), confidential = TRUE)
				return TRUE
			log_admin("[key_name(user)] replaced planet [planet_id] in [sector_id]: [replacement.type], seed [replacement.seed], level [replacement.modifier_level], width [replacement.surface_width], modifiers [jointext(replacement.modifier_log, ", ")]")
			message_admins("[key_name_admin(user)] заменил планету [html_encode(replacement.name)] ([planet_id]) в [html_encode(sector.name)] до высадки.")
			return TRUE

/datum/controller/subsystem/stationtrauma_space_voyage/proc/debug_generate_surface(client/user, sector_id, datum/stationtrauma_overmap_site/space/planet/planet)
	set waitfor = FALSE
	var/planet_id = planet.id
	log_admin("[key_name(user)] requested advance surface generation of planet [planet_id] in sector [sector_id]")
	planet.load_map()
	if(QDELETED(planet))
		return
	log_admin("Advance surface generation [planet_id]: [planet.failed ? "FAILED" : "ready"], [planet.generation_seconds]s")
	if(check_rights_for(user, R_DEBUG))
		to_chat(user, planet.debug_report(), confidential = TRUE)

/** Only untouched, unloaded planets may be replaced; an active approach also protects the destination. */
/datum/stationtrauma_overmap_sector/space/proc/debug_can_replace_planet(datum/stationtrauma_overmap_site/space/planet/planet)
	if(!ready || !istype(planet) || QDELETED(planet) || sites[planet.id] != planet || planet.visited || planet.berth || planet.loading_map || planet.failed || !planet.generator || planet.docking_owner)
		return FALSE
	for(var/datum/stationtrauma_overmap_site/space/pad as anything in planet.pads)
		if(pad.docking_owner || pad.loading_map)
			return FALSE
	for(var/ship_id in ships)
		var/datum/stationtrauma_overmap/space/navigation = ships[ship_id]
		if(navigation.docked == planet || navigation.approach_site == planet || navigation.docked?.pad_parent == planet || navigation.approach_site?.pad_parent == planet \
			|| (navigation.selected_destination == planet.id && (navigation.helm_engaged || navigation.planning || navigation.preparing || navigation.relocating || navigation.arrival_pending)))
			return FALSE
	return TRUE

/** Replace an untouched chart without creating physical levels. */
/datum/stationtrauma_overmap_sector/space/proc/debug_replace_planet(datum/stationtrauma_overmap_site/space/planet/previous, planet_type, seed, level, width = 0, list/modifier_types = null)
	if(!debug_can_replace_planet(previous) || !ispath(planet_type, /datum/stationtrauma_overmap_site/space/planet) \
		|| !isnum(seed) || seed != round(seed) || seed < 1 || seed > 1000000 \
		|| !isnum(level) || level < 0 || level > 10 || !(width in list(0, 128, 176)))
		return null
	var/datum/stationtrauma_overmap_site/space/planet/planet = create_stationtrauma_planet(seed, previous.id, previous.name, planet_type, level, modifier_types)
	if(!planet)
		return null
	if(width)
		planet.generator.width = width
		planet.generator.large_slot = width >= planet.generator.large_surface_width && !!planet.generator.large_ruin_biome
		planet.surface_width = width
	if(planet.surface_width > min(world.maxx, world.maxy))
		QDEL_NULL(planet.generator)
		qdel(planet)
		return null
	planet.pos_x = previous.pos_x
	planet.pos_y = previous.pos_y
	planet.discovered = previous.discovered
	remove_pads(previous)
	sites[planet.id] = planet
	add_pads(planet, 1)
	for(var/ship_id in ships)
		var/datum/stationtrauma_overmap/space/navigation = ships[ship_id]
		if(navigation.prepared_site == previous)
			navigation.prepared_site = planet
		navigation.update_parallax()
	QDEL_NULL(previous.generator)
	qdel(previous)
	return planet

/** Current charts for the admin window. Merely opening it never generates terrain. */
/datum/stationtrauma_overmap_sector/space/proc/debug_planet_overview()
	var/list/planets = list()
	for(var/site_id in sites)
		var/datum/stationtrauma_overmap_site/space/planet/planet = sites[site_id]
		if(!istype(planet) || QDELETED(planet))
			continue
		var/datum/stationtrauma_overmap_site/space/planet/profile = planet.type
		planets += list(list(
			"id" = planet.id,
			"ref" = REF(planet),
			"name" = planet.name,
			"profile" = "[planet.type]",
			"profile_name" = initial(profile.name),
			"seed" = planet.seed,
			"level" = planet.modifier_level,
			"width" = planet.surface_width,
			"modifiers" = planet.modifier_log,
			"status" = planet.failed ? "Ошибка генерации" : planet.loading_map ? "Генерируется" : planet.awaits_map() ? "Ожидает генерации" : "Готова",
			"can_generate" = planet.awaits_map() && !planet.loading_map && !planet.failed,
			"can_replace" = debug_can_replace_planet(planet),
		))
	return planets

/** Admin-only diagnostic text; the caller checks rights, while crew surveys never use this report. */
/datum/stationtrauma_overmap_site/space/planet/proc/debug_report()
	var/state = failed ? "ОШИБКА" : loading_map ? "генерируется" : awaits_map() ? "ещё не сгенерирована" : "готова"
	var/list/lines = list(
		"<b>[html_encode(name)]</b> ([html_encode(id)]): [state]",
		"Профиль: [type]; seed: [seed]; уровень опасности/наград: [modifier_level]",
		"Поверхность: [surface_width] × [surface_width]; overmap: [pos_x], [pos_y]",
		"Среда: [html_encode(biome)]; [html_encode(atmosphere)]; [surface_temperature] K; дыхание: [breathable ? "да" : "нет"]",
		"Модификаторы: [length(modifier_log) ? html_encode(jointext(modifier_log, ", ")) : "нет"]",
		"Seed задаёт шум рельефа; полный результат также зависит от RNG и уже использованных руин раунда.",
	)
	if(!QDELETED(berth))
		var/list/levels = list(berth.z)
		if(SSmapping.level_trait(berth.z, ZTRAIT_DOWN))
			levels += berth.z - 1
		lines += "Уровни z: [jointext(levels, ", ")]; генерация: [generation_seconds] с; площадка: [ADMIN_VERBOSEJMP(berth)]"
		lines += "Руины: [length(ruin_ids) ? html_encode(jointext(ruin_ids, ", ")) : "нет"]"
		var/list/population = list()
		var/total = 0
		for(var/mob/living/creature as anything in GLOB.mob_living_list)
			if(creature.stat == DEAD || !(creature.z in levels))
				continue
			var/kind = "[creature.type]"
			population[kind] += 1
			total++
		lines += "Живых мобов сейчас (включая прибывших): [total]"
		for(var/kind in sort_list(population))
			lines += "[kind]: [population[kind]]"
	return jointext(lines, "<br>")

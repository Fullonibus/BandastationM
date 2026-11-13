ADMIN_VERB(stationtrauma_planet_system, R_DEBUG, "Overmap - Планеты системы", "Посмотреть выпавшие планеты и заменить отдельные до высадки.", ADMIN_CATEGORY_DEBUG)
	var/list/sectors = list()
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		if(sector.ready)
			sectors["[sector.name] ([sector_id])"] = sector_id
	if(!length(sectors))
		to_chat(user, span_warning("Нет готовых секторов овермапы."), confidential = TRUE)
		return
	var/sector_choice = tgui_input_list(user, "Система", "Планеты системы", sectors)
	if(!(sector_choice in sectors) || !check_rights_for(user, R_DEBUG))
		return
	var/sector_id = sectors[sector_choice]
	while(check_rights_for(user, R_DEBUG))
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		if(QDELETED(sector) || !sector.ready)
			return
		var/datum/browser/overview = new(user.mob, "overmap_planets", "Планеты системы", 1000, 650)
		overview.set_content(sector.debug_planet_overview())
		overview.open()
		var/list/planets = list()
		for(var/site_id in sector.sites)
			var/datum/stationtrauma_overmap_site/space/planet/planet = sector.sites[site_id]
			if(istype(planet))
				planets["[planet.name] ([site_id])"] = site_id
		sector = null
		if(!length(planets))
			to_chat(user, span_notice("В этой системе нет процедурных планет."), confidential = TRUE)
			return
		var/choice = tgui_input_list(user, "Обзор характеристик открыт в отдельном окне. Выбери планету для подробностей или замены.", "Планеты системы", planets)
		if(!(choice in planets) || !check_rights_for(user, R_DEBUG))
			return
		sector = SSstationtrauma_space_voyage.sectors[sector_id]
		var/datum/stationtrauma_overmap_site/space/planet/planet = sector?.sites[planets[choice]]
		if(!istype(planet) || QDELETED(planet))
			continue
		var/planet_id = planet.id
		var/datum/weakref/expected_ref = WEAKREF(planet)
		var/list/actions = list("Подробности")
		if(planet.awaits_map() && !planet.loading_map && !planet.failed)
			actions += "Сгенерировать поверхность"
		if(sector.debug_can_replace_planet(planet))
			actions += list("Случайная замена", "Настроить замену")
		planet = null
		sector = null
		var/action = tgui_input_list(user, "Действие", "Планеты системы", actions)
		if(!(action in actions) || !check_rights_for(user, R_DEBUG))
			continue
		if(action == "Настроить замену")
			user.configure_stationtrauma_planet(sector_id, planet_id, expected_ref)
			continue
		sector = SSstationtrauma_space_voyage.sectors[sector_id]
		planet = sector?.sites[planet_id]
		if(!istype(planet) || QDELETED(planet) || expected_ref.resolve() != planet)
			continue
		if(action == "Подробности")
			var/datum/browser/details = new(user.mob, "overmap_planet_details", "Параметры планеты", 850, 600)
			details.set_content(planet.debug_report())
			details.open()
			continue
		planet = null
		sector = null
		var/generate = action == "Сгенерировать поверхность"
		var/button = generate ? "Сгенерировать" : "Заменить"
		var/prompt = generate ? "Заранее построить поверхность и пещеры этой планеты без посадки корабля? После генерации замена этой планеты станет недоступна до конца раунда." : "Заменить эту планету случайным профилем и набором характеристик? Название и координаты сохранятся."
		if(tgui_alert(user, prompt, "Планеты системы", list(button, "Отмена")) != button || !check_rights_for(user, R_DEBUG))
			continue
		sector = SSstationtrauma_space_voyage.sectors[sector_id]
		planet = sector?.sites[planet_id]
		if(!istype(planet) || QDELETED(planet) || expected_ref.resolve() != planet)
			continue
		if(generate)
			if(!planet.awaits_map() || planet.loading_map || planet.failed)
				continue
			log_admin("[key_name(user)] requested advance surface generation of planet [planet_id] in sector [sector_id]")
			to_chat(user, span_notice("Генерация началась. Корабль не требуется; дождись отчёта с переходом на площадку."), confidential = TRUE)
			planet.load_map()
			if(QDELETED(planet))
				continue
			log_admin("Advance surface generation [planet_id]: [planet.failed ? "FAILED" : "ready"], [planet.generation_seconds]s")
			if(!check_rights_for(user, R_DEBUG))
				return
			var/datum/browser/details = new(user.mob, "overmap_planet_details", "Параметры планеты", 850, 600)
			details.set_content(planet.debug_report())
			details.open()
			continue
		log_admin("[key_name(user)] requested random replacement of planet [planet_id] in sector [sector_id]")
		var/datum/stationtrauma_overmap_site/space/planet/replacement = sector.debug_replace_planet(planet, pick(typesof(/datum/stationtrauma_overmap_site/space/planet)), rand(1, 1000000), planet.modifier_level)
		if(replacement)
			log_admin("Planet [planet_id] replaced: [replacement.type], seed [replacement.seed], modifiers [jointext(replacement.modifier_log, ", ")]")
		else
			to_chat(user, span_warning("Замена отклонена: планета уже используется."), confidential = TRUE)

/** Configure a replacement using only stable IDs and an expected identity across the input dialogs. */
/client/proc/configure_stationtrauma_planet(sector_id, planet_id, datum/weakref/expected_ref)
	var/client/user = src
	if(!check_rights_for(user, R_DEBUG))
		return
	var/list/profiles = list()
	for(var/datum/stationtrauma_overmap_site/space/planet/profile as anything in typesof(/datum/stationtrauma_overmap_site/space/planet))
		profiles[initial(profile.name)] = profile
	var/profile_choice = tgui_input_list(user, "Профиль среды", "Генерация планеты", profiles)
	if(!(profile_choice in profiles) || !check_rights_for(user, R_DEBUG))
		return
	var/seed = tgui_input_number(user, "Seed шума рельефа. Руины, пещеры и мобы дополнительно используют RNG раунда.", "Генерация планеты", rand(1, 1000000), 1000000, 1)
	if(isnull(seed) || !check_rights_for(user, R_DEBUG))
		return
	var/level = tgui_input_number(user, "Уровень опасности/наград (0–10). При ручном выборе бюджет модификаторов не ограничивает выбор.", "Генерация планеты", 2, 10, 0, round_value = FALSE)
	if(isnull(level) || !check_rights_for(user, R_DEBUG))
		return
	var/list/sizes = list("По профилю" = 0, "128 × 128" = 128, "176 × 176" = 176)
	var/size_choice = tgui_input_list(user, "Размер поверхности", "Генерация планеты", sizes)
	if(!(size_choice in sizes) || !check_rights_for(user, R_DEBUG))
		return
	var/list/modes = list("Вручную", "Случайно", "Без модификаторов")
	var/mode = tgui_input_list(user, "Модификаторы планеты", "Генерация планеты", modes)
	if(!(mode in modes) || !check_rights_for(user, R_DEBUG))
		return
	var/list/modifier_types
	if(mode != "Случайно")
		modifier_types = list()
	if(mode == "Вручную")
		var/datum/stationtrauma_overmap_site/space/planet/profile = profiles[profile_choice]
		var/generator_type = initial(profile.generator_type)
		var/datum/map_generator/expedition_barren/generator = new generator_type(seed)
		var/list/options = list()
		for(var/datum/expedition_planet_modifier/modifier as anything in expedition_planet_modifiers())
			if(modifier.name && modifier.can_apply(generator))
				options[modifier.name] = modifier.type
		QDEL_NULL(generator)
		var/selected = tgui_input_checkboxes(user, "Совместимые с профилем характеристики. Выбирай не больше одного варианта руды, фауны, погоды, освещения и типа логов.", "Генерация планеты", options, min_checked = 0)
		if(isnull(selected) || !check_rights_for(user, R_DEBUG))
			return
		// The native-input fallback returns a single item instead of a list.
		if(istext(selected))
			selected = list(selected)
		if(!islist(selected))
			return
		for(var/choice in selected)
			if(!(choice in options))
				return
			modifier_types += options[choice]
		mode = length(selected) ? jointext(selected, ", ") : "нет"
	var/confirmation = tgui_alert(user, "Заменить планету: [profile_choice], seed [seed], уровень [level], размер [size_choice], модификаторы: [mode]? Название и координаты сохранятся; поверхность построится при первой посадке.", "Замена планеты", list("Заменить", "Отмена"))
	if(confirmation != "Заменить" || !check_rights_for(user, R_DEBUG))
		return
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
	if(QDELETED(sector) || !sector.ready)
		return
	var/datum/stationtrauma_overmap_site/space/planet/previous = sector.sites[planet_id]
	if(!istype(previous) || QDELETED(previous) || expected_ref?.resolve() != previous)
		to_chat(user, span_warning("Эта планета уже изменена другим администратором. Открой её заново."), confidential = TRUE)
		return
	log_admin("[key_name(user)] requested replacement of [planet_id]: [profiles[profile_choice]], seed [seed], level [level], width [sizes[size_choice]], modifiers [isnull(modifier_types) ? "random" : json_encode(modifier_types)] in sector [sector.id]")
	var/datum/stationtrauma_overmap_site/space/planet/planet = sector.debug_replace_planet(previous, profiles[profile_choice], seed, level, sizes[size_choice], modifier_types)
	if(QDELETED(planet))
		to_chat(user, span_warning("Замена отклонена: планета уже используется, параметры недопустимы или модификаторы конфликтуют."), confidential = TRUE)
		return
	log_admin("Planet [planet.id] replaced: [planet.type], seed [planet.seed], modifiers [jointext(planet.modifier_log, ", ")]")
	to_chat(user, planet.debug_report(), confidential = TRUE)
	message_admins("[key_name_admin(user)] заменил планету [html_encode(planet.name)] ([planet.id]) в [html_encode(sector.name)] до высадки.")

/** Only untouched, unloaded planets may be replaced; an active approach also protects the destination. */
/datum/stationtrauma_overmap_sector/space/proc/debug_can_replace_planet(datum/stationtrauma_overmap_site/space/planet/planet)
	if(!ready || !istype(planet) || QDELETED(planet) || sites[planet.id] != planet || planet.visited || planet.berth || planet.loading_map || planet.failed || !planet.generator || planet.docking_owner)
		return FALSE
	for(var/ship_id in ships)
		var/datum/stationtrauma_overmap/space/navigation = ships[ship_id]
		if(navigation.docked == planet || navigation.approach_site == planet || navigation.dispatch_target == planet \
			|| (navigation.selected_destination == planet.id && (navigation.helm_engaged || navigation.planning || navigation.preparing || navigation.relocating || navigation.arrival_pending)))
			return FALSE
	return TRUE

/** Replace an untouched chart without creating levels; the admin caller rechecks rights and identity after its dialogs. */
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
	sites[planet.id] = planet
	for(var/ship_id in ships)
		var/datum/stationtrauma_overmap/space/navigation = ships[ship_id]
		if(navigation.prepared_site == previous)
			navigation.prepared_site = planet
		navigation.update_parallax()
	QDEL_NULL(previous.generator)
	qdel(previous)
	return planet

/** Read-only preflight overview; no terrain is generated merely by opening the window. */
/datum/stationtrauma_overmap_sector/space/proc/debug_planet_overview()
	var/list/rows = list("<h2>[html_encode(name)]</h2><p>Снимок характеристик. Поверхность строится при первой посадке или действием «Сгенерировать поверхность» заранее. Заменяются только незагруженные планеты без активного захода корабля.</p><table border='1' cellpadding='6'><tr><th>Планета</th><th>Профиль</th><th>Seed / уровень</th><th>Размер</th><th>Характеристики</th><th>Замена</th></tr>")
	for(var/site_id in sites)
		var/datum/stationtrauma_overmap_site/space/planet/planet = sites[site_id]
		if(!istype(planet))
			continue
		var/datum/stationtrauma_overmap_site/space/planet/profile = planet.type
		rows += "<tr><td>[html_encode(planet.name)]</td><td>[html_encode(initial(profile.name))]</td><td>[planet.seed] / [planet.modifier_level]</td><td>[planet.surface_width] × [planet.surface_width]</td><td>[length(planet.modifier_log) ? html_encode(jointext(planet.modifier_log, ", ")) : "нет дополнительных модификаторов"]</td><td>[debug_can_replace_planet(planet) ? "доступна" : "защищена"]</td></tr>"
	rows += "</table>"
	return jointext(rows, "")

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

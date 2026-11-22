ADMIN_VERB(stationtrauma_overmap_jump, R_DEBUG, "Overmap - Переместить корабль к объекту", "Переместить корабль к координатам объекта без стыковки.", ADMIN_CATEGORY_DEBUG)
	// Dialogs sleep, so only IDs survive them; the ship and site are looked up again after each one.
	var/list/ships = list()
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/listed_sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/id in listed_sector.ships)
			var/datum/stationtrauma_overmap/space/listed = listed_sector.ships[id]
			ships["[listed.vessel.name] ([id], [listed_sector.name])"] = list(sector_id, id)
	var/ship_choice = tgui_input_list(user, "Корабль", "Перемещение на овермапе", ships)
	if(!ship_choice || !check_rights_for(user, R_DEBUG))
		return
	var/list/ship_ids = ships[ship_choice]
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[ship_ids[1]]
	var/datum/stationtrauma_overmap/space/navigation = sector ? sector.ships[ship_ids[2]] : null
	if(QDELETED(navigation))
		return
	var/list/destinations = list()
	for(var/id in navigation.sites)
		var/datum/stationtrauma_overmap_site/space/listed_site = navigation.sites[id]
		if((listed_site.berth || listed_site.awaits_map()) && !listed_site.failed)
			destinations["[listed_site.name] ([id])"] = id
	sector = null
	navigation = null
	var/choice = tgui_input_list(user, "Объект", "Перемещение на овермапе", destinations)
	if(!choice || !check_rights_for(user, R_DEBUG))
		return
	sector = SSstationtrauma_space_voyage.sectors[ship_ids[1]]
	navigation = sector ? sector.ships[ship_ids[2]] : null
	var/datum/stationtrauma_overmap_site/space/site = navigation ? navigation.sites[destinations[choice]] : null
	if(QDELETED(navigation) || QDELETED(site))
		return
	if(navigation.preparing || navigation.relocating || navigation.planning || navigation.arrival_pending)
		to_chat(user, span_warning("Дождись завершения текущего манёвра."), confidential = TRUE)
		return
	navigation.stop()
	var/revision = navigation.control_revision
	if((navigation.docked || navigation.ship_docking) && !navigation.depart(instant = TRUE))
		to_chat(user, span_warning("Не удалось освободить стоянку: [navigation.status]"), confidential = TRUE)
		return
	if(!check_rights_for(user, R_DEBUG) || QDELETED(navigation) || navigation.control_revision != revision || !navigation.debug_reposition(site))
		return
	log_admin("[key_name(user)] moved [navigation.vessel.shuttle_id] to overmap site [site.id] ([site.pos_x], [site.pos_y]) without docking")
	to_chat(user, span_notice("[navigation.vessel.name]: координаты [site.name]. Стыковка не выполнялась."), confidential = TRUE)

/** A non-yielding debug effect; the admin verb revalidates permissions after its dialogs and departure. */
/datum/stationtrauma_overmap/space/proc/debug_reposition(datum/stationtrauma_overmap_site/space/site)
	if(!is_operational() || preparing || relocating || planning || arrival_pending || docked || ship_docking || QDELETED(site) || sites[site.id] != site || (!site.berth && !site.awaits_map()) || site.failed)
		return FALSE
	stop("Движение остановлено")
	clear_encounters()
	pos_x = encounter_x = site.pos_x
	pos_y = encounter_y = site.pos_y
	discover_site(site)
	selected_destination = site.id
	prepared_site = site
	trip_distance = travelled = 0
	update_parallax()
	return TRUE

ADMIN_VERB(stationtrauma_overmap_skip_wait, R_DEBUG, "Overmap - Завершить прыжок или вызов", "Мгновенно завершить идущий блюспейс-прыжок или вызов корабля к причалу.", ADMIN_CATEGORY_DEBUG)
	// The dialog sleeps, so resolve the selected ship or exact order again after it.
	var/list/choices = list()
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/listed_sector = SSstationtrauma_space_voyage.sectors[sector_id]
		for(var/id in listed_sector.ships)
			var/datum/stationtrauma_overmap/space/listed = listed_sector.ships[id]
			if(listed.jump_timer)
				choices["[listed.vessel.name] ([id]): прыжок"] = list("sector" = sector_id, "ship" = id)
		for(var/id in listed_sector.sites)
			var/datum/stationtrauma_overmap_site/space/site = listed_sector.sites[id]
			var/datum/stationtrauma_shuttle_order/order = site.shuttle_order
			if(order?.delivery_timer)
				choices["[site.name] ([id]): доставка"] = list("order" = WEAKREF(order))

	if(!length(choices))
		to_chat(user, span_notice("Нет кораблей в прыжке или в пути к причалу."), confidential = TRUE)
		return
	var/choice = tgui_input_list(user, "Корабль", "Завершить ожидание", choices)
	if(!choice || !check_rights_for(user, R_DEBUG))
		return
	var/list/selection = choices[choice]
	var/datum/weakref/order_ref = selection["order"]
	if(order_ref)
		var/datum/stationtrauma_shuttle_order/order = order_ref.resolve()
		if(!order?.delivery_timer)
			return
		log_admin("[key_name(user)] skipped the delivery wait to [order.site.id]")
		var/done = order.deliver()
		to_chat(user, done ? span_notice("Корабль доставлен.") : span_warning("Доставка не состоялась."), confidential = TRUE)
		return
	var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[selection["sector"]]
	var/datum/stationtrauma_overmap/space/navigation = sector?.ships[selection["ship"]]
	if(QDELETED(navigation) || !navigation.jump_timer)
		return
	log_admin("[key_name(user)] skipped the jump wait of [navigation.vessel.shuttle_id]")
	var/done = navigation.debug_skip_wait()
	to_chat(user, done ? span_notice("Ожидание завершено.") : span_warning("Не завершено: [navigation?.status]"), confidential = TRUE)

/** Debug: complete a pending jump at once through its normal completion checks. */
/datum/stationtrauma_overmap/space/proc/debug_skip_wait()
	if(!jump_timer)
		return FALSE
	deltimer(jump_timer)
	jump_timer = null
	return finish_jump(jump_target, control_revision)

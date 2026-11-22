/datum/stationtrauma_overmap_sector/space
	/// One Raven dispatch is paid for at round start. Failed delivery restores it.
	var/free_raven_dispatch = TRUE

/** Declared port profiles for the three purchasable maps. The native port still validates the loaded hull. */
/datum/stationtrauma_overmap_sector/space/proc/shuttle_offers()
	var/static/list/offers = list(
		"cargo" = list("name" = "Грузовой челнок", "price" = 5000, "class" = ST_SHIP_SMALL, "map" = "_maps/map_files/overmap_ships/cargo_s.dmm", "width" = 7, "height" = 15, "dwidth" = 3, "dheight" = 6),
		"raven" = list("name" = "Raven", "price" = 15000, "class" = ST_SHIP_MEDIUM, "map" = "_maps/map_files/overmap_ships/raven.dmm", "width" = 19, "height" = 25, "dwidth" = 0, "dheight" = 10),
		"pocketrocket" = list("name" = "Pocket Rocket", "price" = 4500, "class" = ST_SHIP_SMALL, "map" = "_maps/map_files/overmap_ships/pocketrocket.dmm", "width" = 16, "height" = 10, "dwidth" = 0, "dheight" = 2),
	)
	return offers

/datum/stationtrauma_overmap_sector/space/proc/shuttle_price(offer_id, list/offer)
	return offer_id == "raven" && free_raven_dispatch ? 0 : offer["price"]

/** Dispatch is a station service. Outposts and moving carriers have their own berths. */
/datum/stationtrauma_overmap_sector/space/proc/is_shuttle_order_dock(datum/stationtrauma_overmap_site/space/site)
	if(!ready || !is_station_berth(site) || site.host)
		return FALSE
	var/obj/docking_port/stationary/stationtrauma_space_station/port = site.berth
	return !port.host_ship_id && is_station_level(port.z)

/** A standard slot may choose the orientation. A native bay fixes it at its port anchor. */
/datum/stationtrauma_overmap_site/space/proc/fits_shuttle_offer(list/offer)
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = berth
	if(istype(slot))
		return offer["class"] == slot.accepted_ship_class && min(offer["width"], offer["height"]) <= slot.width && max(offer["width"], offer["height"]) <= slot.height
	return offer["dwidth"] <= berth.dwidth && offer["width"] - offer["dwidth"] <= berth.width - berth.dwidth \
		&& offer["dheight"] <= berth.dheight && offer["height"] - offer["dheight"] <= berth.height - berth.dheight

/datum/stationtrauma_overmap_site/space/proc/shuttle_order_dock_status(datum/stationtrauma_shuttle_order/current_order)
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = berth
	var/obj/docking_port/mobile/moored = istype(slot) ? slot.active_berth?.get_docked() : berth.get_docked()
	if(moored)
		return "occupied"
	if(docking_owner || (shuttle_order && shuttle_order != current_order) || (istype(slot) && slot.active_berth))
		return "reserved"
	if(failed || stationtrauma_berth_unavailable(berth))
		return "unavailable"
	return "free"

/** Avoid loading a hull when a standard bay's footprint is blocked. */
/datum/stationtrauma_overmap_site/space/proc/shuttle_order_dock_problem()
	var/obj/docking_port/stationary/stationtrauma_space_station/standard/slot = berth
	if(istype(slot))
		return stationtrauma_standard_dock_problem(get_turf(slot), slot.dir, slot.width, slot.height, slot)
	return null

/** Accept the exact quote the operator saw and reserve the dock before any async work. */
/datum/stationtrauma_overmap_sector/space/proc/order_shuttle(mob/user, offer_id, dock_id, expected_price)
	if(!istext(offer_id) || !istext(dock_id) || !isnum(expected_price))
		return "Выберите корабль и причал заново."
	var/list/offers = shuttle_offers()
	var/list/offer = offers[offer_id]
	var/datum/stationtrauma_overmap_site/space/site = sites[dock_id]
	if(!offer || !is_shuttle_order_dock(site))
		return "Корабль или причал недоступен. Выберите другой вариант."
	if(!site.fits_shuttle_offer(offer))
		return "Этот корабль не подходит к выбранному причалу."
	if(site.shuttle_order_dock_status() != "free")
		return "Причал больше не свободен. Выберите другой причал."
	var/price = shuttle_price(offer_id, offer)
	if(price != expected_price)
		return "Цена изменилась. Проверьте стоимость перед заказом."
	var/problem = site.shuttle_order_dock_problem()
	if(problem)
		return problem
	var/datum/bank_account/department/account = SSeconomy.get_dep_account(ACCOUNT_CAR)
	var/ship_name = offer["name"]
	if(price && (QDELETED(account) || !account.adjust_money(-price, "Заказ корабля «[ship_name]»")))
		return "В бюджете карго недостаточно средств для заказа."
	if(!price)
		free_raven_dispatch = FALSE
	var/datum/stationtrauma_shuttle_order/order = new(src, site, offer, price, account, user)
	site.shuttle_order = order
	site.berth.investigate_log("Shuttle dispatch: [key_name(user)] ordered [ship_name] to [site.id] for [price] credits from cargo.", INVESTIGATE_CARGO)
	return null

/datum/stationtrauma_shuttle_order
	/// Sector owning the delivery and its free dispatch entitlement.
	var/datum/stationtrauma_overmap_sector/space/sector
	/// Exact destination reserved by this order.
	var/datum/stationtrauma_overmap_site/space/site
	/// Static catalog record for the ordered hull.
	var/list/offer
	/// Amount withdrawn, or zero for the round-start Raven.
	var/price
	/// Account to refund if the delivery fails.
	var/datum/bank_account/department/account
	/// Operator receives the outcome even if the console was closed.
	var/datum/weakref/operator_ref
	/// Stoppable timer until delivery starts.
	var/delivery_timer
	/// World time at which the delivery timer expires.
	var/delivery_at
	/// The hull is physically docked and payment is final.
	var/delivered = FALSE

/datum/stationtrauma_shuttle_order/New(datum/stationtrauma_overmap_sector/space/owner, datum/stationtrauma_overmap_site/space/destination, list/ordered_offer, amount, datum/bank_account/department/payer, mob/operator)
	. = ..()
	sector = owner
	site = destination
	offer = ordered_offer
	price = amount
	account = payer
	operator_ref = WEAKREF(operator)
	delivery_at = world.time + ST_SHUTTLE_DELIVERY_TIME
	delivery_timer = addtimer(CALLBACK(src, PROC_REF(deliver)), ST_SHUTTLE_DELIVERY_TIME, TIMER_STOPPABLE)

/datum/stationtrauma_shuttle_order/Destroy()
	deltimer(delivery_timer)
	if(site?.shuttle_order == src)
		site.shuttle_order = null
	var/ship_name = offer["name"]
	var/mob/operator = operator_ref?.resolve()
	if(delivered)
		to_chat(operator, span_notice("«[ship_name]» пристыкован. Причал: [site.name]."))
	else if(price)
		if(!QDELETED(account))
			account.adjust_money(price, "Возврат за корабль «[ship_name]»")
		to_chat(operator, span_warning("Доставка «[ship_name]» сорвалась. Кредиты возвращены в бюджет карго."))
	else
		if(!QDELETED(sector))
			sector.free_raven_dispatch = TRUE
		to_chat(operator, span_warning("Доставка Raven сорвалась. Бесплатный вызов снова доступен."))
	sector = null
	site = null
	offer = null
	account = null
	operator_ref = null
	return ..()

/** Check the same reservation after the timer and again after the map loader yields. */
/datum/stationtrauma_shuttle_order/proc/can_deliver()
	return !QDELETED(src) && !QDELETED(sector) && sector.is_shuttle_order_dock(site) && site.shuttle_order == src \
		&& site.shuttle_order_dock_status(src) == "free" && site.fits_shuttle_offer(offer)

/datum/stationtrauma_shuttle_order/proc/deliver()
	if(!delivery_timer)
		return FALSE
	deltimer(delivery_timer)
	delivery_timer = null
	UNTIL(QDELETED(src) || !SSstationtrauma_space_voyage.loading_ship_template)
	if(QDELETED(src))
		return FALSE
	var/obj/docking_port/mobile/stationtrauma_space/vessel
	if(can_deliver() && !site.shuttle_order_dock_problem())
		SSstationtrauma_space_voyage.loading_ship_template = TRUE
		try
			vessel = load_stationtrauma_space_ship(offer["map"], attach_to_sector = TRUE, place_ship = CALLBACK(src, PROC_REF(dock_ordered_ship)))
		catch(var/exception/failure)
			stack_trace("Shuttle dispatch failed: [failure]")
		SSstationtrauma_space_voyage.loading_ship_template = FALSE
	if(QDELETED(src))
		return FALSE
	delivered = !QDELETED(vessel)
	var/success = delivered
	qdel(src)
	return success

/** Transfer the reserved berth to native navigation without yielding between owners. */
/datum/stationtrauma_shuttle_order/proc/dock_ordered_ship(obj/docking_port/mobile/stationtrauma_space/vessel)
	var/datum/stationtrauma_overmap/space/navigation = vessel.overmap
	if(!can_deliver() || QDELETED(navigation) || !navigation.select_site(site.id))
		return FALSE
	navigation.pos_x = navigation.encounter_x = site.pos_x
	navigation.pos_y = navigation.encounter_y = site.pos_y
	site.shuttle_order = null
	return navigation.dock(instant = TRUE, station_authorized = TRUE)

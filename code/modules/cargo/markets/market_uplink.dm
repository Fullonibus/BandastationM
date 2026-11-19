/obj/item/market_uplink
	name = "\improper Market Uplink"
	desc = "A market uplink. Usable with markets. You probably shouldn't have this!"
	icon = 'icons/obj/devices/blackmarket.dmi'
	icon_state = "uplink"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 0.75, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 3.6)
	// UI variables.
	/// What category is the current uplink viewing?
	var/viewing_category
	/// What market is currently being bought from by the uplink?
	var/viewing_market
	/// List of typepaths for "/datum/market"s that this uplink can access.
	var/list/accessible_markets = list(/datum/market/blackmarket)

/obj/item/market_uplink/Initialize(mapload)
	. = ..()
	// We don't want to go through this at mapload because the SSmarket isn't initialized yet.
	if(mapload)
		return

	update_viewing_category()

/// Simple internal proc for updating the viewing_category variable.
/obj/item/market_uplink/proc/update_viewing_category()
	if(accessible_markets.len)
		viewing_market = accessible_markets[1]
		var/list/categories = SSmarket.markets[viewing_market]?.categories
		if(categories?.len)
			viewing_category = categories[1]

/obj/item/market_uplink/ui_interact(mob/user, datum/tgui/ui)
	if(!viewing_category)
		update_viewing_category()

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BlackMarketUplink", name)
		ui.open()

/obj/item/market_uplink/ui_data(mob/user)
	var/list/data = list()
	var/datum/market/market = viewing_market ? SSmarket.markets[viewing_market] : null
	var/datum/bank_account/account = astype(user, /mob/living)?.get_bank_account()
	data["categories"] = market?.categories
	data["money"] = account?.account_balance || 0
	data["has_account"] = !QDELETED(account) ? TRUE : FALSE
	data["ltsrbt_built"] = !!length(SSmarket.telepads)
	data["items"] = list()
	data["viewing_category"] = viewing_category
	data["viewing_market"] = viewing_market
	var/list/market_category = market?.available_items?[viewing_category]
	for(var/id in market_category)
		var/datum/market_item/item = market_category[id]
		var/list/shipping_methods = market.get_shipping_methods(item)
		var/list/delivery_methods = list()
		for(var/method in shipping_methods)
			delivery_methods += list(list("name" = method, "price" = shipping_methods[method]))
		data["items"] += list(list(
			"id" = id,
			"name" = item.name,
			"cost" = item.get_purchase_price(account),
			"amount" = item.stock,
			"desc" = item.desc || item.name,
			"html_icon" = item.html_icon,
			"delivery_methods" = delivery_methods,
		))
	return data

/obj/item/market_uplink/ui_static_data(mob/user)
	var/list/data = list()
	data["delivery_method_description"] = SSmarket.shipping_method_descriptions
	data["markets"] = list()
	for(var/M in accessible_markets)
		var/datum/market/BM = SSmarket.markets[M]
		data["markets"] += list(list(
			"id" = M,
			"name" = BM.name
		))
	return data

/obj/item/market_uplink/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("set_category")
			var/category = params["category"]
			var/datum/market/market = SSmarket.markets[viewing_market]
			if(!istext(category) || !(category in market?.categories))
				return FALSE
			viewing_category = category
			return TRUE
		if("set_market")
			if(!istext(params["market"]))
				return FALSE
			var/market_path = text2path(params["market"])
			if(!(market_path in accessible_markets))
				return FALSE
			var/datum/market/market = SSmarket.markets[market_path]
			if(isnull(market))
				return FALSE
			viewing_market = market_path
			viewing_category = length(market.categories) ? market.categories[1] : null
			return TRUE
		if("buy")
			var/identifier = params["item"]
			var/category = params["category"]
			var/method = params["method"]
			var/quoted_total = params["total"]
			if(!istext(params["market"]) || !istext(identifier) || !istext(category) || !istext(method) || !isnum(quoted_total))
				return FALSE
			var/market_path = text2path(params["market"])
			if(!(market_path in accessible_markets))
				return FALSE
			var/datum/market/market = SSmarket.markets[market_path]
			return market?.purchase(identifier, category, method, src, ui.user, quoted_total)

/obj/item/market_uplink/blackmarket
	name = "\improper Black Market Uplink"
	contraband_type_categories = CONTRABAND_CATEGORY_UNCLASSIFIED
	desc = "An illegal black market uplink. If command wanted you to have these, they wouldn't have made it so hard to get one."
	icon = 'icons/obj/devices/blackmarket.dmi'
	icon_state = "uplink"
	//The original black market uplink
	accessible_markets = list(/datum/market/blackmarket)
	custom_premium_price = PAYCHECK_CREW * 2.5

/datum/crafting_recipe/radio_containing/blackmarket_uplink
	name = "Black Market Uplink"
	result = /obj/item/market_uplink/blackmarket
	time = 3 SECONDS
	tool_behaviors = list(TOOL_SCREWDRIVER, TOOL_WIRECUTTER, TOOL_MULTITOOL)
	reqs = list(
		/obj/item/stock_parts/micro_laser = 1,
		/obj/item/assembly/signaler = 1,
		/obj/item/stack/cable_coil = 15,
		/obj/item/radio = 1,
		/obj/item/analyzer = 1
	)
	category = CAT_EQUIPMENT

// Corporate contracts: Nanotrasen sells a certified find to a corporation. The corps brings it in, R&D catalogues
// it (the catalogue is the certificate), cargo packs it and hauls it to the corporate trade hub.

/// Mining and machinery manufacturer; buys large finds from the digs.
/datum/expedition_customer/etamin
	name = "Etamin Industry"
	nanotrasen = FALSE
	contract_types = list(/datum/expedition_contract/large_find)
	reward_node = /datum/techweb_node/expedition_contract/etamin

/// Trans-Solar Federation; buys the cores of live anomalies.
/datum/expedition_customer/tsf
	name = "Транс-Солнечная Федерация"
	nanotrasen = FALSE
	contract_types = list(/datum/expedition_contract/containment)
	reward_node = /datum/techweb_node/expedition_contract/tsf
	reward_pack = /datum/supply_pack/costumes_toys/tsf_uniform

/// The Skrellian Empire; buys field artefacts.
/datum/expedition_customer/skrell
	name = "Империя скреллов"
	nanotrasen = FALSE
	contract_types = list(/datum/expedition_contract/field_artefact)
	reward_node = /datum/techweb_node/expedition_contract/skrell

/// The certified find, packed, handed over at the corporate trade hub; the hub terminal drives it.
/datum/expedition_contract_step/deliver
	text = "упаковать сертифицированную находку в закрытый ящик (аномальную — в ящик для образцов) и сдать на корпоративном торговом узле"

/// Whether `find` must travel in a specimen crate: anything still carrying anomalous energy does.
/proc/expedition_find_is_anomalous(atom/movable/find)
	return istype(find, /obj/machinery/artifact) || istype(find, /obj/item/field_artefact) || istype(find, /obj/item/assembly/signaler/anomaly)

/**
 * Hands the order's find over on `core`'s input pad. The find must lie in a closed crate there: a specimen crate for an
 * anomalous find, any crate otherwise. Returns a message for the terminal, or null on success.
 */
/datum/expedition_contract/proc/deliver_at(obj/machinery/trade_hub_core/corporate/core, mob/user)
	if(state != EXPEDITION_CONTRACT_ACTIVE || !istype(steps[current], /datum/expedition_contract_step/deliver))
		return "Контракт не ожидает сдачи."
	var/obj/machinery/trade_hub_pad/pad = core.get_pad(/obj/machinery/trade_hub_pad/input)
	if(!pad)
		return core.get_input_reason()
	for(var/obj/structure/closet/crate/crate in get_turf(pad))
		if(crate.opened)
			continue
		for(var/atom/movable/find in crate)
			if(!(find in bound))
				continue
			if(expedition_find_is_anomalous(find) && !istype(crate, /obj/structure/closet/crate/specimen))
				return "Находка «[find.name]» аномальна: заказчик принимает её только в ящике для образцов."
			var/paid = credits()
			core.investigate_log("Trade hub [core.hub_id] took [find.type] for contract [id] of [customer.name], [paid] credits to cargo.", INVESTIGATE_CARGO)
			// The order closes and lets go of the find before it leaves, so its loss does not roll the order back.
			steps[current].add_progress(core)
			qdel(find)
			playsound(core, 'sound/machines/ping.ogg', 40, TRUE)
			return null
	return "На площадке нет закрытого ящика с находкой по этому контракту."

// The corporate hub's terminal lists contracts waiting for delivery and takes them.

/obj/machinery/computer/trade_hub/ui_data(mob/user)
	. = ..()
	var/list/contracts = list()
	if(istype(get_core(), /obj/machinery/trade_hub_core/corporate))
		for(var/id in GLOB.expedition_contracts.contracts)
			var/datum/expedition_contract/contract = GLOB.expedition_contracts.contracts[id]
			if(contract.state != EXPEDITION_CONTRACT_ACTIVE || !istype(contract.steps[contract.current], /datum/expedition_contract_step/deliver))
				continue
			contracts += list(list(
				"id" = contract.id,
				"name" = contract.name,
				"customer" = contract.customer.name,
				"target" = contract.target_name,
				"credits" = contract.credits(),
			))
	.["contracts"] = contracts

/obj/machinery/computer/trade_hub/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || action != "deliver_contract")
		return
	var/mob/user = ui.user
	var/id = istext(params["id"]) ? params["id"] : null
	var/obj/machinery/trade_hub_core/corporate/core = get_core()
	var/reason = get_trade_reason(user, core)
	if(reason || !can_interact(user))
		return transaction_result(user, action, id, FALSE, reason || "Не удаётся воспользоваться терминалом.")
	if(!istype(core))
		return transaction_result(user, action, id, FALSE, "Контракты принимает только корпоративный узел.")
	var/datum/expedition_contract/contract = id ? GLOB.expedition_contracts.contracts[id] : null
	if(!contract)
		return transaction_result(user, action, id, FALSE, "Контракт не найден.")
	if(contract.credits() > 0 && !SSeconomy.get_dep_account(ACCOUNT_CAR))
		return transaction_result(user, action, id, FALSE, "Счёт карго недоступен.")
	core.busy = TRUE
	var/failure = contract.deliver_at(core, user)
	core.busy = FALSE
	if(failure)
		return transaction_result(user, action, id, FALSE, failure)
	return transaction_result(user, action, id, TRUE, "Контракт [contract.customer.name] принят: [contract.name]. Начислено [contract.credits()] кредитов.")

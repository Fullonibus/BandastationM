/// Every order of the round and the waves that bring new ones.
GLOBAL_DATUM_INIT(expedition_contracts, /datum/expedition_contract_board, new)
/// Corps journals that receive order notifications.
GLOBAL_LIST_EMPTY(expedition_journal_programs)

/datum/expedition_contract_board
	/// Every order of the round by ID, in the order they were offered.
	var/list/datum/expedition_contract/contracts = list()
	/// Customers placing orders.
	var/list/datum/expedition_customer/customers = list()
	/// Round-local order serial.
	var/serial = 0
	/// Waves run once the round has started on a map with a charted sector.
	var/started = FALSE

/datum/expedition_contract_board/New()
	for(var/customer_type in subtypesof(/datum/expedition_customer))
		customers += new customer_type

/// The first offers, then a wave every EXPEDITION_CONTRACT_WAVE_DELAY.
/datum/expedition_contract_board/proc/start()
	if(started)
		return
	started = TRUE
	for(var/index in 1 to EXPEDITION_CONTRACTS_AT_START)
		offer()
	addtimer(CALLBACK(src, PROC_REF(wave)), EXPEDITION_CONTRACT_WAVE_DELAY, TIMER_LOOP)

/datum/expedition_contract_board/proc/wave()
	if(open_count() < EXPEDITION_CONTRACTS_MAX_OPEN)
		offer()

/// Offers and taken orders.
/datum/expedition_contract_board/proc/open_count()
	. = 0
	for(var/id in contracts)
		var/datum/expedition_contract/contract = contracts[id]
		if(!contract.parent_id && (contract.state == EXPEDITION_CONTRACT_OFFERED || contract.state == EXPEDITION_CONTRACT_ACTIVE))
			.++

/// Destinations of the charted far sectors: the home sector is a short hop, not an expedition.
/datum/expedition_contract_board/proc/destinations()
	. = list()
	for(var/sector_id in SSstationtrauma_space_voyage.sectors)
		var/datum/stationtrauma_overmap_sector/space/sector = SSstationtrauma_space_voyage.sectors[sector_id]
		if(!sector.ready || istype(sector, /datum/stationtrauma_overmap_sector/space/home))
			continue
		for(var/site_id in sector.sites)
			. += sector.sites[site_id]

/// Offers one new order to the corps. Returns it, or null if no customer has work anywhere.
/datum/expedition_contract_board/proc/offer()
	var/list/taken_targets = list()
	for(var/id in contracts)
		var/datum/expedition_contract/contract = contracts[id]
		if(!contract.parent_id && (contract.state == EXPEDITION_CONTRACT_OFFERED || contract.state == EXPEDITION_CONTRACT_ACTIVE))
			taken_targets[contract.target_id] = TRUE
	var/list/free_sites = list()
	for(var/datum/stationtrauma_overmap_site/space/site as anything in destinations())
		if(!taken_targets[site.id] && !site.failed)
			free_sites += site
	var/list/choices = list()
	for(var/datum/expedition_customer/customer as anything in customers)
		for(var/contract_type in customer.contract_types)
			choices += list(list(customer, contract_type))
	for(var/list/choice as anything in shuffle(choices))
		var/contract_type = choice[2]
		var/datum/expedition_contract/contract = new contract_type
		var/list/suitable = list()
		var/list/unvisited = list()
		for(var/datum/stationtrauma_overmap_site/space/site as anything in free_sites)
			if(!contract.can_target(site))
				continue
			suitable += site
			if(!site.visited)
				unvisited += site
		// New ground first: an order should take the corps somewhere it has not been.
		var/datum/stationtrauma_overmap_site/space/target = length(unvisited) ? pick(unvisited) : (length(suitable) ? pick(suitable) : null)
		if(!target || !contract.setup(choice[1], target))
			qdel(contract)
			continue
		contract.id = "З-[++serial]"
		contracts[contract.id] = contract
		contract.offer_timer = addtimer(CALLBACK(contract, TYPE_PROC_REF(/datum/expedition_contract, expire)), EXPEDITION_CONTRACT_OFFER_LIFETIME, TIMER_STOPPABLE)
		if(prob(EXPEDITION_SIDE_CHANCE))
			offer_side(contract, target)
		notify("Новое предложение от [contract.customer.name]: [contract.summary()][contract.side_order ? ", с побочным заданием" : ""].")
		return contract
	return null

/// Attaches a side task in `site`'s ruins to `main`, for the same customer.
/datum/expedition_contract_board/proc/offer_side(datum/expedition_contract/main, datum/stationtrauma_overmap_site/space/site)
	var/datum/expedition_contract/side/side_task = new
	if(!side_task.setup(main.customer, site))
		qdel(side_task)
		return
	side_task.id = "З-[++serial]"
	side_task.parent_id = main.id
	main.side_order = side_task
	contracts[side_task.id] = side_task

/// Whether `user` may take or turn down orders on `journal`: the corps leader, or any explorer while the corps has none.
/datum/expedition_contract_board/proc/can_decide(mob/user, datum/computer_file/program/expedition_journal/journal)
	if(journal.can_run(user, access_to_check = list(ACCESS_EXPEDITION_LEADER)))
		return TRUE
	var/datum/job/leader = SSjob.get_job_type(/datum/job/explorer/leader)
	return !leader?.current_positions

/// A journal action on order `id`; every rule is checked here, the client only asks.
/datum/expedition_contract_board/proc/act(action, id, mob/user, datum/computer_file/program/expedition_journal/journal)
	var/datum/expedition_contract/contract = istext(id) && contracts[id]
	if(!contract || !can_decide(user, journal))
		return FALSE
	switch(action)
		if("accept_contract")
			// A side task is taken with its order.
			if(contract.parent_id || !contract.accept(user))
				return FALSE
			notify("[user.real_name] принимает заказ: [contract.summary()]. Задача: [contract.steps[contract.current].text].")
			return TRUE
		if("decline_contract")
			if(!contract.decline(user))
				return FALSE
			notify("[user.real_name] отказывается от заказа: [contract.summary()].")
			return TRUE
	return FALSE

/// Rings every corps journal on a device that is somewhere in the world.
/datum/expedition_contract_board/proc/notify(text)
	for(var/datum/computer_file/program/expedition_journal/journal as anything in GLOB.expedition_journal_programs)
		// Store copies have no device, and alert_call speaks through the device's location.
		if(journal.computer?.physical?.loc)
			journal.computer.alert_call(journal, text)

/// Orders for the journal, newest first.
/datum/expedition_contract_board/proc/journal_data()
	. = list()
	for(var/index in length(contracts) to 1 step -1)
		var/datum/expedition_contract/contract = contracts[contracts[index]]
		. += list(contract.journal_data())

// Orders need the charted sectors, so they start with the round on maps that have them.
/datum/controller/subsystem/stationtrauma_space_voyage/Initialize()
	. = ..()
	if(. == SS_INIT_SUCCESS)
		SSticker.OnRoundstart(CALLBACK(GLOB.expedition_contracts, TYPE_PROC_REF(/datum/expedition_contract_board, start)))

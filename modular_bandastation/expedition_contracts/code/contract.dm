/**
 * An order for the expedition corps, after the Voidcrew mission shell: a customer, a destination and an ordered
 * list of steps of which exactly one is live while the order is taken.
 *
 * The destination is kept as its stable site ID; the site datum is never referenced, so the order holds nothing
 * that a sector could delete under it.
 */
/datum/expedition_contract
	/// Kind of work, as the corps reads it.
	var/name = "Заказ"
	/// Round-local ID.
	var/id
	/// Who placed it.
	var/datum/expedition_customer/customer
	/// EXPEDITION_CONTRACT_* state.
	var/state = EXPEDITION_CONTRACT_OFFERED
	/// Stable site ID of the destination.
	var/target_id
	/// Destination name at the time of the offer.
	var/target_name
	/// Chart position of the destination.
	var/target_x
	var/target_y
	/// Reward multiplier for the destination's danger band.
	var/danger_mult = 1
	/// Steps in order.
	var/list/datum/expedition_contract_step/steps = list()
	/// Index of the live step.
	var/current = 1
	/// Research points a Nanotrasen order pays, before the danger multiplier.
	var/research_reward = 0
	/// Credits a corporation pays cargo for the delivered find, before the danger multiplier.
	var/credit_reward = 0
	/// Name of whoever took or turned it down.
	var/decided_by
	/// Withdraws the offer if nobody takes it.
	var/offer_timer
	/// Finds this order counts as its own, brought in by its binding step; released when the order closes.
	var/list/atom/movable/bound = list()
	/// Index of the step that binds finds, which the order falls back to if they are lost.
	var/bind_step
	/// Losing the bound thing ends the order instead of sending it back a step.
	var/fails_on_loss = FALSE
	/// Side task that came with this order; it is taken, turned down and withdrawn along with it.
	var/datum/expedition_contract/side_order
	/// ID of the order a side task came with; null for an order of its own.
	var/parent_id

/datum/expedition_contract/Destroy()
	deltimer(offer_timer)
	release_bound()
	QDEL_LIST(steps)
	customer = null
	side_order = null
	return ..()

/// Whether `site` can be this order's destination.
/datum/expedition_contract/proc/can_target(datum/stationtrauma_overmap_site/space/site)
	return istype(site, /datum/stationtrauma_overmap_site/space/planet)

/// Fill in the order for `site`. Returns FALSE if it cannot be built there.
/datum/expedition_contract/proc/setup(datum/expedition_customer/new_customer, datum/stationtrauma_overmap_site/space/site)
	customer = new_customer
	target_id = site.id
	target_name = site.name
	target_x = site.pos_x
	target_y = site.pos_y
	var/datum/stationtrauma_overmap_site/space/planet/planet = site
	if(istype(planet))
		var/static/list/band_mults = list(1, 1.25, 1.5)
		danger_mult = band_mults[XENOARCH_BAND_INDEX(xenoarch_band_for_level(planet.modifier_level))]
	build_steps(site)
	// A corporation buys the find itself: once certified it goes to its trade hub.
	if(!customer.nanotrasen && length(steps))
		steps += new /datum/expedition_contract_step/deliver
	for(var/datum/expedition_contract_step/step as anything in steps)
		step.contract = src
	return length(steps) > 0

/// Add the steps for `site`, in order.
/datum/expedition_contract/proc/build_steps(datum/stationtrauma_overmap_site/space/site)
	return

/// Research points this order pays, after the danger multiplier; only Nanotrasen orders pay them.
/datum/expedition_contract/proc/research_points()
	return customer?.nanotrasen ? round(research_reward * danger_mult) : 0

/// Credits this order pays cargo, after the danger multiplier; only corporations pay them.
/datum/expedition_contract/proc/credits()
	return customer && !customer.nanotrasen ? round(credit_reward * danger_mult) : 0

/// The order as one line of the offer text.
/datum/expedition_contract/proc/summary()
	return "[name]: [target_name]"

/// Taken by `user`: its first step goes live.
/datum/expedition_contract/proc/accept(mob/user)
	if(state != EXPEDITION_CONTRACT_OFFERED)
		return FALSE
	deltimer(offer_timer)
	state = EXPEDITION_CONTRACT_ACTIVE
	decided_by = user.real_name
	steps[current].activate()
	side_order?.accept(user)
	return TRUE

/// Turned down while offered, or dropped once taken; costs nothing.
/datum/expedition_contract/proc/decline(mob/user)
	if(state != EXPEDITION_CONTRACT_OFFERED && state != EXPEDITION_CONTRACT_ACTIVE)
		return FALSE
	deltimer(offer_timer)
	if(state == EXPEDITION_CONTRACT_ACTIVE)
		steps[current].deactivate()
	// A side task is turned down with its offer; once taken it stands on its own.
	else if(side_order?.state == EXPEDITION_CONTRACT_OFFERED)
		side_order.decline(user)
	release_bound()
	state = EXPEDITION_CONTRACT_DECLINED
	decided_by = user.real_name
	return TRUE

/// Nobody took the offer in time.
/datum/expedition_contract/proc/expire()
	if(state != EXPEDITION_CONTRACT_OFFERED)
		return
	state = EXPEDITION_CONTRACT_EXPIRED
	side_order?.expire()
	GLOB.expedition_contracts.notify("Предложение снято: [summary()].")

/// The live step is done at `location`: the next one goes live, or the order is fulfilled.
/datum/expedition_contract/proc/step_completed(datum/expedition_contract_step/step, atom/location)
	if(state != EXPEDITION_CONTRACT_ACTIVE || step != steps[current])
		return
	if(current < length(steps))
		current++
		steps[current].activate()
		GLOB.expedition_contracts.notify("[summary()]: этап выполнен. Далее: [steps[current].text].")
		return
	fulfil(location)

/// Pays the reward at `location`, where the last step was done.
/datum/expedition_contract/proc/fulfil(atom/location)
	state = EXPEDITION_CONTRACT_DONE
	release_bound()
	var/points = research_points()
	if(points > 0 && location)
		new /obj/item/research_notes(get_turf(location), points, "экспедиционных исследований")
		location.visible_message(span_notice("[capitalize(location.name)] печатает исследовательские заметки по заказу [customer.name]."))
		playsound(location, 'sound/machines/printer.ogg', 40, TRUE)
	var/paid = credits()
	if(paid > 0)
		SSeconomy.get_dep_account(ACCOUNT_CAR)?.adjust_money(paid, "Контракт [customer.name]: [name]")
	if(!customer.nanotrasen)
		customer.first_contract_reward(location)
	GLOB.expedition_contracts.notify("[customer.nanotrasen ? "Заказ" : "Контракт"] выполнен: [summary()]. [customer.name] благодарит корпус[points > 0 ? "; станции начислено [points] очков исследований" : ""][paid > 0 ? "; бюджет снабжения получил [paid] кредитов" : ""].")

/// `find` now counts for this order, brought in by `step`.
/datum/expedition_contract/proc/bind(atom/movable/find, datum/expedition_contract_step/step)
	if(find in bound)
		return
	bound += find
	bind_step = steps.Find(step)
	RegisterSignal(find, COMSIG_QDELETING, PROC_REF(on_bound_lost))

/// Stops counting any find as this order's own.
/datum/expedition_contract/proc/release_bound()
	for(var/atom/movable/find as anything in bound)
		UnregisterSignal(find, COMSIG_QDELETING)
		REMOVE_TRAIT(find, TRAIT_EXPEDITION_ORDER_ITEM, EXPEDITION_ORDER_TRAIT)
	bound.Cut()

/// The thing a side task was for is gone: the task ends.
/datum/expedition_contract/proc/fail(reason)
	if(state != EXPEDITION_CONTRACT_ACTIVE)
		return
	steps[current].deactivate()
	release_bound()
	state = EXPEDITION_CONTRACT_FAILED
	GLOB.expedition_contracts.notify("[summary()]: задание провалено — [reason].")

/// A find this order counted on is gone: past its binding step, the order goes back to it.
/datum/expedition_contract/proc/on_bound_lost(atom/movable/source)
	SIGNAL_HANDLER
	bound -= source
	if(fails_on_loss)
		fail("[source.name] уничтожен")
		return
	if(state != EXPEDITION_CONTRACT_ACTIVE || length(bound) || current <= bind_step)
		return
	steps[current].deactivate()
	for(var/index in bind_step to current)
		var/datum/expedition_contract_step/step = steps[index]
		step.completed = FALSE
		step.progress = 0
	current = bind_step
	steps[current].activate()
	GLOB.expedition_contracts.notify("[summary()]: находка утрачена. Нужно снова [steps[current].text].")

/// Data for the journal.
/datum/expedition_contract/proc/journal_data()
	var/list/step_data = list()
	for(var/index in 1 to length(steps))
		var/datum/expedition_contract_step/step = steps[index]
		step_data += list(list(
			"text" = step.text,
			"progress" = step.progress,
			"required" = step.required,
			"done" = step.completed,
			"current" = state == EXPEDITION_CONTRACT_ACTIVE && index == current,
		))
	return list(
		"id" = id,
		"name" = name,
		"customer" = customer.name,
		"nanotrasen" = customer.nanotrasen,
		"state" = state,
		"target" = target_name,
		"x" = target_x,
		"y" = target_y,
		"reward" = research_points(),
		"credits" = credits(),
		"decided_by" = decided_by,
		"parent" = parent_id,
		"steps" = step_data,
	)

/**
 * One step of an order. Only the live step listens for the events that move it on; it stops listening the moment
 * it is done or the order is dropped.
 */
/datum/expedition_contract_step
	/// Order this step belongs to.
	var/datum/expedition_contract/contract
	/// What the corps has to do.
	var/text
	/// How many times the event has to happen.
	var/required = 1
	/// How many times it has.
	var/progress = 0
	/// Done.
	var/completed = FALSE
	/// Global event that moves this step on; it is heard only while the step is live.
	var/event_signal

/datum/expedition_contract_step/Destroy()
	deactivate()
	contract = null
	return ..()

/// Start listening.
/datum/expedition_contract_step/proc/activate()
	if(event_signal)
		RegisterSignal(SSdcs, event_signal, PROC_REF(on_event))

/// Stop listening.
/datum/expedition_contract_step/proc/deactivate()
	if(event_signal)
		UnregisterSignal(SSdcs, event_signal)

/datum/expedition_contract_step/proc/on_event(datum/source, datum/subject, mob/living/user, atom/location)
	SIGNAL_HANDLER
	if(!counts(subject, location))
		return
	counted(subject)
	add_progress(location)

/// Whether the event about `subject` at `location` counts for this order.
/datum/expedition_contract_step/proc/counts(datum/subject, atom/location)
	return FALSE

/// The event about `subject` was counted.
/datum/expedition_contract_step/proc/counted(datum/subject)
	return

/// One more event at `location`; completes the step when enough have happened.
/datum/expedition_contract_step/proc/add_progress(atom/location)
	if(completed)
		return
	progress++
	if(progress < required)
		GLOB.expedition_contracts.notify("[contract.summary()]: [text] — [progress]/[required].")
		return
	completed = TRUE
	deactivate()
	contract.step_completed(src, location)

/// Stable site ID of the expedition destination `thing` is on, or null off any charted destination.
/proc/expedition_site_id_at(atom/thing)
	var/turf/tile = get_turf(thing)
	if(!tile)
		return null
	for(var/obj/effect/landmark/stationtrauma_research_site/site in GLOB.landmarks_list)
		if(site.z == tile.z)
			return site.site_id
	return null

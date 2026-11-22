// Studying an anomalous find on the scan pad can let its energy loose: a living anomaly breaks out, or a field unfolds.

/// Breakout chance in percent by danger band, for each kind of study.
GLOBAL_LIST_INIT(xenoarch_breakout_chances, list(
	"artifact" = list(3, 6, 10),
	"field" = list(5, 10, 15),
	"core" = list(3, 6, 10),
))

/// Let `find` loose where it lies now: a living anomaly of its energy, or a small field of its kind around it.
/proc/xenoarch_breakout(datum/weakref/find_ref, kind, band)
	var/atom/movable/find = find_ref.resolve()
	if(!find)
		return
	find.remove_filter("xenoarch_breakout")
	var/obj/structure/closet/crate/specimen/container = find.loc
	if(istype(container) && !container.opened)
		return
	var/turf/spot = get_turf(find)
	if(!spot)
		return
	band = XENOARCH_BAND_INDEX(band)
	if(kind == "field")
		var/obj/item/field_artefact/artefact = find
		var/list/kinds = list()
		for(var/field_type in GLOB.anomaly_field_weights[band])
			var/obj/effect/anomaly_field/field = field_type
			if(initial(field.energy_kind) == artefact.energy_kind)
				kinds[field_type] = GLOB.anomaly_field_weights[band][field_type]
		var/field_type = pick_weight(length(kinds) ? kinds : GLOB.anomaly_field_weights[band])
		var/list/spots = list()
		for(var/turf/open/ground in RANGE_TURFS(2, spot))
			if(!ground.is_blocked_turf() && !(locate(/obj/effect/anomaly_field) in ground))
				spots += ground
		for(var/index in 1 to min(rand(3, 5), length(spots)))
			new field_type(pick_n_take(spots))
		spot.visible_message(span_danger("Пространство вокруг [find.declent_ru(GENITIVE)] искажается и застывает аномальным полем!"))
		log_game("Xenoarchaeology breakout: [find] unfolded [field_type] fields at [AREACOORD(spot)].")
		return
	var/anomaly_type
	if(kind == "core")
		for(var/candidate in GLOB.planetary_anomaly_weights[length(GLOB.planetary_anomaly_weights)])
			var/obj/effect/anomaly/pulsing/anomaly = candidate
			if(initial(anomaly.anomaly_core) == find.type)
				anomaly_type = candidate
				break
	else
		var/obj/machinery/artifact/artifact = find
		var/energy = artifact.main_effect?.energy_kind
		var/list/kinds = list()
		for(var/candidate in GLOB.planetary_anomaly_weights[band])
			var/obj/effect/anomaly/pulsing/anomaly = candidate
			var/obj/item/assembly/signaler/anomaly/planetary/core = initial(anomaly.anomaly_core)
			if(initial(core.energy_kind) == energy)
				kinds[candidate] = GLOB.planetary_anomaly_weights[band][candidate]
		anomaly_type = pick_weight(length(kinds) ? kinds : GLOB.planetary_anomaly_weights[band])
	if(!anomaly_type)
		return
	var/obj/effect/anomaly/pulsing/escaped = new anomaly_type(spot)
	if(QDELETED(escaped))
		return
	settle_planetary_anomaly(escaped)
	spot.visible_message(span_danger("Из [find.declent_ru(GENITIVE)] вырывается живая аномалия!"))
	log_game("Xenoarchaeology breakout: [find] released [anomaly_type] at [AREACOORD(spot)].")
	// The core turns back into the anomaly it was taken from.
	if(kind == "core")
		var/obj/item/assembly/signaler/anomaly/planetary/original_core = find
		var/obj/item/assembly/signaler/anomaly/planetary/new_core = escaped.anomaly_core
		// Neutralizing the same anomaly again must not grant another research payout.
		if(istype(new_core))
			new_core.research_paid = original_core.research_paid
		escaped.journal_record = original_core.journal_record
		qdel(original_core)

/// The weakest danger band whose wildlife includes the anomaly this core was taken from.
/proc/xenoarch_core_band(obj/item/assembly/signaler/anomaly/planetary/core)
	for(var/band in 1 to length(GLOB.planetary_anomaly_weights))
		for(var/candidate in GLOB.planetary_anomaly_weights[band])
			var/obj/effect/anomaly/pulsing/anomaly = candidate
			if(initial(anomaly.anomaly_core) == core.type)
				return band
	return XENOARCH_BAND_YELLOW

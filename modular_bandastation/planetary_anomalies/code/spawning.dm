/// Random tries for a living anomaly's spot.
#define PLANETARY_ANOMALY_ATTEMPTS 250
/// Tiles a living anomaly keeps from fields and other anomalies.
#define PLANETARY_ANOMALY_SPACING 8

/// Living anomalies by danger band, weighted: green planets get the milder ones only.
GLOBAL_LIST_INIT(planetary_anomaly_weights, list(
	list(
		/obj/effect/anomaly/pulsing/sparkler = 1,
		/obj/effect/anomaly/pulsing/veins = 1,
		/obj/effect/anomaly/pulsing/phantom = 1,
		/obj/effect/anomaly/pulsing/transfusion = 1,
		/obj/effect/anomaly/pulsing/chronograph = 1,
		/obj/effect/anomaly/pulsing/pulsar = 1,
	),
	list(
		/obj/effect/anomaly/pulsing/sparkler = 1,
		/obj/effect/anomaly/pulsing/veins = 2,
		/obj/effect/anomaly/pulsing/phantom = 2,
		/obj/effect/anomaly/pulsing/transfusion = 2,
		/obj/effect/anomaly/pulsing/chronograph = 2,
		/obj/effect/anomaly/pulsing/pulsar = 2,
		/obj/effect/anomaly/pulsing/heartbeat = 1,
		/obj/effect/anomaly/pulsing/tvstatic = 1,
		/obj/effect/anomaly/pulsing/plasmasoul = 1,
		/obj/effect/anomaly/pulsing/melter = 1,
	),
	list(
		/obj/effect/anomaly/pulsing/sparkler = 1,
		/obj/effect/anomaly/pulsing/veins = 1,
		/obj/effect/anomaly/pulsing/phantom = 1,
		/obj/effect/anomaly/pulsing/transfusion = 1,
		/obj/effect/anomaly/pulsing/chronograph = 1,
		/obj/effect/anomaly/pulsing/pulsar = 1,
		/obj/effect/anomaly/pulsing/heartbeat = 1,
		/obj/effect/anomaly/pulsing/tvstatic = 1,
		/obj/effect/anomaly/pulsing/plasmasoul = 1,
		/obj/effect/anomaly/pulsing/melter = 1,
	),
))

/**
 * On a planet with the anomalous zone modifier, places one immortal, still living anomaly per danger band
 * step on open ground away from the camp, ruins, dig sites, field clusters and each other. Returns how many.
 */
/datum/map_generator/expedition_barren/proc/place_planetary_anomalies(list/turfs, area/surface, datum/stationtrauma_overmap_site/space/planet/planet, datum/stationtrauma_work_budget/budget)
	if(!anomaly_fields || !length(turfs) || !planet)
		return 0
	var/band = XENOARCH_BAND_INDEX(xenoarch_band_for_level(planet.modifier_level))
	. = 0
	for(var/i in 1 to band)
		var/turf/spot = find_planetary_anomaly_spot(turfs, surface, budget)
		if(!spot)
			break
		var/anomaly_type = pick_weight(GLOB.planetary_anomaly_weights[band])
		var/obj/effect/anomaly/anomaly = new anomaly_type(spot)
		settle_planetary_anomaly(anomaly)
		if(istype(anomaly, /obj/effect/anomaly/pulsing/tvstatic) && prob(25))
			new /obj/effect/mob_spawn/corpse/human/legioninfested(spot)
			var/mob/living/carbon/human/body = locate() in spot
			if(body)
				var/obj/effect/anomaly/pulsing/tvstatic/tvstatic = anomaly
				tvstatic.hold_body(body)
		.++

/// Open ground clear of reserved tiles and of fields, anomalies and dig sites nearby, or null.
/datum/map_generator/expedition_barren/proc/find_planetary_anomaly_spot(list/turfs, area/surface, datum/stationtrauma_work_budget/budget)
	for(var/attempt in 1 to PLANETARY_ANOMALY_ATTEMPTS)
		budget?.yield()
		var/turf/candidate = pick(turfs)
		if(!dig_site_ground_ok(candidate, surface) || !dig_site_clear(candidate, surface))
			continue
		var/crowded = FALSE
		for(var/atom/movable/thing in range(PLANETARY_ANOMALY_SPACING, candidate))
			if(istype(thing, /obj/effect/anomaly_field) || istype(thing, /obj/effect/anomaly) || istype(thing, /obj/structure/xenoarch_stake))
				crowded = TRUE
				break
		if(!crowded)
			return candidate
	return null

#undef PLANETARY_ANOMALY_ATTEMPTS
#undef PLANETARY_ANOMALY_SPACING

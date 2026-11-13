/**
 * # Field clusters
 *
 * A pass after dig sites on planets that rolled the anomalous zone modifier: three or four clusters plus
 * one per danger band step (green 4-5, red 6-7). Each cluster is one kind of field, picked by band, except
 * that anomalous heat grows among zharkas and a sparkler sits at the heart of electras. Most
 * are a scatter with one or two artefacts; about one in three is a dense barrier to walk around or bolt
 * through, with one artefact at its heart. Kinds that grow no artefacts are bare hazards. Clusters keep off
 * the camp, its corridors, ruins, dig sites and each other.
 */

/// Fields in a scattered cluster, before running out of ground.
#define FIELD_CLUSTER_SIZE_MIN 6
#define FIELD_CLUSTER_SIZE_MAX 10
/// How far a scattered cluster spreads from its centre.
#define FIELD_CLUSTER_RADIUS 4
/// Fields in a dense barrier cluster, before running out of ground.
#define FIELD_BARRIER_SIZE_MIN 10
#define FIELD_BARRIER_SIZE_MAX 16
/// How far a barrier spreads from its centre.
#define FIELD_BARRIER_RADIUS 6
/// Chance a cluster is a barrier.
#define FIELD_BARRIER_CHANCE 35
/// Random tries for a cluster centre.
#define FIELD_CLUSTER_ATTEMPTS 250

/// Danger: invisible anomaly fields cluster on the surface, with artefacts grown in them.
/datum/expedition_planet_modifier/anomaly_zone
	name = "Аномальная зона"
	group = "anomaly_fields"
	cost = 1
	probability = 35
	anomaly_fields = TRUE

/datum/expedition_planet_modifier
	/// Whether this modifier scatters anomaly field clusters over the surface.
	var/anomaly_fields = FALSE

/datum/map_generator/expedition_barren
	/// Whether the anomalous zone modifier put field clusters on this planet.
	var/anomaly_fields = FALSE

/// Field kinds a cluster may be made of, by danger band, weighted.
GLOBAL_LIST_INIT(anomaly_field_weights, list(
	list(
		/obj/effect/anomaly_field/tramplin = 3,
		/obj/effect/anomaly_field/thermal/cooler = 2,
		/obj/effect/anomaly_field/zharka = 2,
		/obj/effect/anomaly_field/vspishka = 1,
	),
	list(
		/obj/effect/anomaly_field/electra = 3,
		/obj/effect/anomaly_field/zharka = 3,
		/obj/effect/anomaly_field/tramplin = 2,
		/obj/effect/anomaly_field/thermal/cooler = 1,
		/obj/effect/anomaly_field/vspishka = 1,
		/obj/effect/anomaly_field/rvach = 1,
	),
	list(
		/obj/effect/anomaly_field/electra = 3,
		/obj/effect/anomaly_field/rvach = 3,
		/obj/effect/anomaly_field/zharka = 3,
		/obj/effect/anomaly_field/tramplin = 2,
		/obj/effect/anomaly_field/vspishka = 2,
	),
))

/// Places the planet's field clusters on `surface`. Returns how many were placed.
/datum/map_generator/expedition_barren/proc/place_anomaly_fields(list/turfs, area/surface, datum/stationtrauma_overmap_site/space/planet/planet, datum/stationtrauma_work_budget/budget)
	if(!anomaly_fields || !length(turfs) || !planet)
		return 0
	var/band = XENOARCH_BAND_INDEX(xenoarch_band_for_level(planet.modifier_level))
	var/list/centres = list()
	for(var/i in 1 to rand(3, 4) + band)
		var/turf/centre = find_field_cluster_centre(turfs, surface, centres, budget)
		if(!centre)
			break
		if(prob(FIELD_BARRIER_CHANCE))
			build_field_cluster(centre, surface, band, FIELD_BARRIER_RADIUS, rand(FIELD_BARRIER_SIZE_MIN, FIELD_BARRIER_SIZE_MAX), 1)
		else
			build_field_cluster(centre, surface, band, FIELD_CLUSTER_RADIUS, rand(FIELD_CLUSTER_SIZE_MIN, FIELD_CLUSTER_SIZE_MAX), rand(1, 2))
		centres += centre
	return length(centres)

/// Open ground clear of reserved tiles, dig sites and other clusters, or null.
/datum/map_generator/expedition_barren/proc/find_field_cluster_centre(list/turfs, area/surface, list/centres, datum/stationtrauma_work_budget/budget)
	for(var/attempt in 1 to FIELD_CLUSTER_ATTEMPTS)
		budget?.yield()
		var/turf/candidate = pick(turfs)
		if(!dig_site_ground_ok(candidate, surface) || !dig_site_clear(candidate, surface))
			continue
		var/too_close = FALSE
		for(var/turf/taken as anything in centres)
			if(get_dist(candidate, taken) < XENOARCH_SITE_SPACING)
				too_close = TRUE
				break
		if(too_close || (locate(/obj/structure/xenoarch_stake) in range(FIELD_BARRIER_RADIUS + 3, candidate)))
			continue
		return candidate
	return null

/// Scatters `size` fields of one kind within `radius` of `centre` and grows up to `artefacts` artefacts in them, nearest the centre first.
/datum/map_generator/expedition_barren/proc/build_field_cluster(turf/centre, area/surface, band, radius, size, artefacts)
	var/field_type = pick_weight(GLOB.anomaly_field_weights[band])
	var/list/spots = list()
	for(var/turf/spot as anything in RANGE_TURFS(radius, centre))
		if(dig_site_ground_ok(spot, surface))
			spots += spot
	var/list/bearers = list()
	for(var/i in 1 to min(size, length(spots)))
		var/obj/effect/anomaly_field/field = new field_type(pick_n_take(spots))
		if(length(field.artefact_types))
			bearers += field
	if(field_type == /obj/effect/anomaly_field/zharka)
		for(var/i in 1 to min(rand(1, 2), length(spots)))
			bearers += new /obj/effect/anomaly_field/thermal/heater(pick_n_take(spots))
	else if(field_type == /obj/effect/anomaly_field/electra)
		var/obj/effect/anomaly/sparkler = new /obj/effect/anomaly/pulsing/sparkler(centre)
		settle_planetary_anomaly(sparkler)
	for(var/i in 1 to min(artefacts, length(bearers)))
		var/obj/effect/anomaly_field/nearest
		for(var/obj/effect/anomaly_field/field as anything in bearers)
			if(!nearest || get_dist(field, centre) < get_dist(nearest, centre))
				nearest = field
		bearers -= nearest
		nearest.bear_artefact(band)

#undef FIELD_CLUSTER_SIZE_MIN
#undef FIELD_CLUSTER_SIZE_MAX
#undef FIELD_CLUSTER_RADIUS
#undef FIELD_CLUSTER_ATTEMPTS
#undef FIELD_BARRIER_SIZE_MIN
#undef FIELD_BARRIER_SIZE_MAX
#undef FIELD_BARRIER_RADIUS
#undef FIELD_BARRIER_CHANCE

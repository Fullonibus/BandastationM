/**
 * # Dig site records
 *
 * Our planet surfaces are generated once and never rebuilt, so a site keeps no persistent reserve:
 * its record lives on the planet's overmap site for the round, the walls point at it weakly, and a
 * cut boulder owns its own state. Adapted from Voidcrew's planet dig reserve.
 */

/datum/stationtrauma_overmap_site/space/planet
	/// Dig sites placed on this planet's surface; owns their records for the round.
	var/list/datum/dig_site_record/dig_sites

/// The find band of a planet's danger level (its modifier budget, which grows with distance).
/proc/xenoarch_band_for_level(modifier_level)
	// Starting balance values; the level runs roughly 0-8 across a sector.
	if(modifier_level >= 4)
		return XENOARCH_BAND_RED
	if(modifier_level >= 2.5)
		return XENOARCH_BAND_YELLOW
	return XENOARCH_BAND_GREEN

/// What one dig site still holds.
/datum/dig_site_record
	/// Large finds (boulders) left in the site
	var/large_left = 0
	/// Small finds (strange rocks) left in the site
	var/small_left = 0
	/// Which kind of site it is (XENOARCH_SITE_*)
	var/site_kind = XENOARCH_SITE_HOUSE
	/// Band every find from here is stamped with
	var/band = XENOARCH_BAND_GREEN
	/// Fauna of this planet that may answer a dig, as types
	var/list/ambush_fauna

/datum/dig_site_record/New(band, site_kind)
	. = ..()
	src.band = XENOARCH_BAND_INDEX(band)
	if(site_kind)
		src.site_kind = site_kind
	var/list/large = XENOARCH_LARGE_PER_SITE
	var/list/small = XENOARCH_SMALL_PER_SITE
	large_left = large[src.band]
	small_left = small[src.band]

/// Takes one find of `kind` (XENOARCH_FIND_*) out of the count. FALSE if none were left.
/datum/dig_site_record/proc/take_find(kind)
	switch(kind)
		if(XENOARCH_FIND_LARGE)
			if(large_left <= 0)
				return FALSE
			large_left--
			return TRUE
		if(XENOARCH_FIND_SMALL)
			if(small_left <= 0)
				return FALSE
			small_left--
			return TRUE
	return FALSE

/// A boulder was cut out of the face: rolls what it holds. The boulder owns the record.
/datum/dig_site_record/proc/cut_boulder()
	var/datum/dig_boulder_record/boulder = new(band)
	boulder.site_kind = site_kind
	return boulder

/**
 * Everything about one boulder: what is inside, how deep, which field holds it, and how far the
 * crew has got. The boulder structure only draws it.
 */
/datum/dig_boulder_record
	/// Band the find is stamped with
	var/band = XENOARCH_BAND_GREEN
	/// The catalogue number on its holotag, which an artifact keeps when it comes out
	var/serial
	/// What is inside (a type path), rolled by band
	var/find_type
	/// Depth of the find's surface, in cm
	var/target_depth = XENOARCH_BOULDER_DEPTH_MIN
	/// What the plain depth scanner reads: the true depth give or take XENOARCH_SCAN_ERROR
	var/rough_depth = XENOARCH_BOULDER_DEPTH_MIN
	/// The one stabilising field that holds it (one of GLOB.xenoarch_stabilising_fields)
	var/field
	/// Radiometric age, in years, for the spectrometer report
	var/age = 0
	/// cm cut so far
	var/dug = 0
	/// 0 not sounded, 1 sounded roughly, 2 sounded exactly
	var/sounded = 0
	/// The field the crew projected on it, if any
	var/field_applied
	/// The projected field matches
	var/stabilised = FALSE
	/// A holotag (GPS) has been fixed to it
	var/tagged = FALSE
	/// Sprite variant, 1 to 4
	var/variant = 1
	/// Colour of the rock it was cut from
	var/rock_color
	/// The kind of site it came from, for the spectrometer report
	var/site_kind
	/// Opened or lost: nothing more to do with it
	var/settled = FALSE

/datum/dig_boulder_record/New(band)
	. = ..()
	src.band = XENOARCH_BAND_INDEX(band)
	serial = xenoarch_new_serial()
	find_type = xenoarch_roll_large_find(src.band)
	target_depth = rand(XENOARCH_BOULDER_DEPTH_MIN, XENOARCH_BOULDER_DEPTH_MAX)
	rough_depth = max(1, target_depth + rand(-XENOARCH_SCAN_ERROR, XENOARCH_SCAN_ERROR))
	field = pick(GLOB.xenoarch_stabilising_fields)
	age = rand(4, 900) * 1000000
	variant = rand(1, 4)

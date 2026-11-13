/// Exact debug traits bypass the random budget while rejecting conflicts before changing the generator.
/datum/unit_test/overmap_planet_debug_modifiers/Run()
	var/datum/map_generator/expedition_barren/frozen/manual = allocate(/datum/map_generator/expedition_barren/frozen, 123)
	var/list/selected = list(/datum/expedition_planet_modifier/predators, /datum/expedition_planet_modifier/caves, /datum/expedition_planet_modifier/bright_day)
	var/list/survey = manual.apply_modifiers(0, selected)
	TEST_ASSERT_NOTNULL(survey, "An exact compatible selection must work even with zero random budget.")
	TEST_ASSERT(manual.underground && manual.fauna_multiplier > 1 && manual.light_alpha > 0, "The selected cave, fauna and lighting effects must actually apply.")
	TEST_ASSERT_EQUAL(length(manual.modifier_log), 3, "No unselected trait may be rolled into an exact selection.")
	var/datum/map_generator/expedition_barren/frozen/untouched = allocate(/datum/map_generator/expedition_barren/frozen, 123)
	TEST_ASSERT_NULL(untouched.apply_modifiers(4, list(/datum/expedition_planet_modifier/caves, /datum/expedition_planet_modifier/rich_ore, /datum/expedition_planet_modifier/poor_ore)), "Conflicting ore traits must be rejected.")
	TEST_ASSERT(!untouched.underground && !length(untouched.modifier_log), "A rejected selection must not partially apply its earlier traits.")
	TEST_ASSERT_NULL(untouched.apply_modifiers(4, list(/datum/expedition_planet_modifier/nest/xeno_hive)), "An ice world must reject a jungle/dead-world hive.")
	TEST_ASSERT_NULL(untouched.apply_modifiers(4, list(/obj/item)), "Unknown modifier types must be rejected.")
	TEST_ASSERT_NULL(untouched.apply_modifiers(4, list(/datum/expedition_planet_modifier/caves, /datum/expedition_planet_modifier/caves)), "Duplicate traits must not multiply their effects.")
	var/datum/stationtrauma_overmap_site/space/planet/planet = create_stationtrauma_planet(selected_modifiers = list(), modifier_level = 3)
	TEST_ASSERT_NOTNULL(planet, "An explicit empty selection must still chart a planet.")
	allocated += planet
	allocated += planet.generator
	TEST_ASSERT_EQUAL(length(planet.modifier_log), 0, "An empty selection must not roll random traits.")
	TEST_ASSERT_EQUAL(planet.modifier_level, 3, "Diagnostics must retain the selected level.")
	TEST_ASSERT_NOTNULL(untouched.apply_modifiers(0), "Omitting the selection must preserve ordinary random generation.")

/// Replacements retain sector identity and idle ship selections, but cannot rewrite a used destination.
/datum/unit_test/overmap_docking/planet_debug_replace
	/// Private sector lends its geography to the fixture's real navigation controller.
	var/datum/stationtrauma_overmap_sector/space/sector
	/// Ruin reservations are global, so their pre-test counts must be restored.
	var/list/ruin_loads = list()

/datum/unit_test/overmap_docking/planet_debug_replace/Destroy()
	for(var/datum/map_template/ruin/template as anything in ruin_loads)
		template.loaded = ruin_loads[template]
	ruin_loads.Cut()
	if(navigation?.sector == sector)
		sector.unregister(navigation)
	for(var/site_id in sector?.sites)
		var/datum/stationtrauma_overmap_site/space/planet/planet = sector.sites[site_id]
		QDEL_NULL(planet.generator)
		if(planet.berth && planet.berth != bay)
			qdel(planet.berth, force = TRUE)
	QDEL_NULL(sector)
	return ..()

/datum/unit_test/overmap_docking/planet_debug_replace/Run()
	sector = new
	sector.ready = TRUE
	navigation.sites = list()
	TEST_ASSERT(sector.register(ship.shuttle_id, navigation), "The real ship must borrow the sector's destination list.")
	for(var/key in SSmapping.ruins_templates)
		var/datum/map_template/ruin/template = SSmapping.ruins_templates[key]
		ruin_loads[template] = template.loaded
	var/datum/stationtrauma_overmap_site/space/planet/previous = create_stationtrauma_planet(456, "debug_test", "Original planet", selected_modifiers = list())
	sector.sites[previous.id] = previous
	previous.pos_x = 777
	previous.pos_y = -888
	TEST_ASSERT(navigation.select_site(previous.id), "The existing idle selection must use the ordinary navigation entry point.")
	TEST_ASSERT_NULL(sector.debug_replace_planet(previous, /obj/item, 123, 2), "Unknown profiles must be rejected.")
	TEST_ASSERT_NULL(sector.debug_replace_planet(previous, /datum/stationtrauma_overmap_site/space/planet, 123, 2, 32), "An unsupported surface size must be rejected.")
	TEST_ASSERT_EQUAL(sector.sites[previous.id], previous, "Invalid requests must retain the original planet.")
	var/datum/map_generator/expedition_barren/old_generator = previous.generator
	var/old_maxz = world.maxz
	var/datum/stationtrauma_overmap_site/space/planet/planet = sector.debug_replace_planet(previous, /datum/stationtrauma_overmap_site/space/planet/frozen, 123, 2, 128, list(/datum/expedition_planet_modifier/caves, /datum/expedition_planet_modifier/bright_day))
	TEST_ASSERT_NOTNULL(planet, "The debug effect must return the replacement.")
	TEST_ASSERT(QDELETED(previous) && QDELETED(old_generator), "Replacement must release the old chart and its pending generator.")
	TEST_ASSERT_EQUAL(world.maxz, old_maxz, "Preflight replacement must not build or leak physical levels.")
	TEST_ASSERT_EQUAL(planet.id, "debug_test", "Destination identity must survive replacement.")
	TEST_ASSERT(planet.name == "Original planet" && planet.pos_x == 777 && planet.pos_y == -888, "Names and orbital positions must remain unchanged.")
	TEST_ASSERT_EQUAL(navigation.sites[planet.id], planet, "Registered ships must see the replacement through their shared geography.")
	TEST_ASSERT_EQUAL(navigation.prepared_site, planet, "An idle selected destination must point to the replacement rather than a deleted chart.")
	TEST_ASSERT(findtext(sector.debug_planet_overview(), "Ледяная экзопланета"), "The system overview must reflect the new profile immediately.")
	navigation.helm_engaged = TRUE
	TEST_ASSERT(!sector.debug_can_replace_planet(planet), "An actively navigated destination must be protected.")
	navigation.helm_engaged = FALSE
	planet.visited = TRUE
	TEST_ASSERT_NULL(sector.debug_replace_planet(planet, planet.type, 999, 2), "Visited destinations must never be overwritten.")
	planet.visited = FALSE
	planet.loading_map = TRUE
	TEST_ASSERT(!sector.debug_can_replace_planet(planet), "An in-progress surface load must be protected.")
	planet.loading_map = FALSE
	planet.berth = bay
	TEST_ASSERT(!sector.debug_can_replace_planet(planet), "Even an unvisited loaded surface must be protected.")
	planet.berth = null
	planet.load_map()
	TEST_ASSERT(!planet.failed && !planet.loading_map && !planet.awaits_map() && planet.berth, "The replacement must still build a real surface through the normal first-landing path.")
	TEST_ASSERT(SSmapping.level_trait(planet.berth.z, ZTRAIT_DOWN) && SSmapping.level_trait(planet.berth.z - 1, ZTRAIT_UP), "The chosen cave system must have real connected native levels.")
	TEST_ASSERT_NULL(planet.generator, "Finished generation must release its generator while retaining diagnostics.")
	var/report = planet.debug_report()
	TEST_ASSERT(findtext(report, "seed: 123") && findtext(report, "128 × 128") && findtext(report, "Пещерная система"), "The report must describe the actual generated configuration after generator cleanup.")
	TEST_ASSERT_NULL(planet.survey_data()["seed"], "An admin-only seed must not leak into the crew survey.")
	TEST_ASSERT(!sector.debug_can_replace_planet(planet), "A completed physical surface must remain protected.")

/// Cave connectors must open onto solid ground even when the surrounding biome is lava.
/datum/unit_test/overmap_planet_cave_clearing
	/// Reservation owned by this fixture, independent of the shared test room's floor bounds.
	var/datum/turf_reservation/space
	/// Preserve the reserved turfs even when a failed assertion returns early.
	var/list/original_turfs = list()

/datum/unit_test/overmap_planet_cave_clearing/Destroy()
	for(var/turf/tile as anything in original_turfs)
		var/list/original = original_turfs[tile]
		var/turf/restored = tile.ChangeTurf(original[1], original[2], CHANGETURF_IGNORE_AIR)
		restored.change_area(get_area(restored), original[3])
		if(isopenturf(restored))
			var/turf/open/open_turf = restored
			if(original[4])
				open_turf.copy_air(original[4])
			else
				open_turf.air = null
			restored.air_update_turf(TRUE, TRUE)
	original_turfs.Cut()
	QDEL_NULL(space)
	return ..()

/datum/unit_test/overmap_planet_cave_clearing/Run()
	space = SSmapping.request_turf_block_reservation(4, 1)
	TEST_ASSERT_NOTNULL(space, "The cave clearing fixture needs its own turf reservation.")
	var/turf/clearing_center = space.bottom_left_turfs[1]
	var/turf/clearing_edge = locate(clearing_center.x + 2, clearing_center.y, clearing_center.z)
	var/turf/natural_lava = locate(clearing_center.x + 3, clearing_center.y, clearing_center.z)
	var/datum/map_generator/expedition_barren/lava/generator = allocate(/datum/map_generator/expedition_barren/lava, 1)
	generator.width = 32
	generator.origin_x = clearing_center.x - 7
	generator.origin_y = clearing_center.y - 7
	generator.cave_level = TRUE
	generator.connector_points = list(list(8, 8))
	generator.cave_biome_table = /datum/biome/expedition/volcanic_lava
	// Both pocket outcomes are lava, so this fixture tests clearing safety independently of noise.
	generator.rock_type = /turf/open/lava/smooth/expedition_volcanic
	generator.mineral_chance = 0
	generator.edge_roughness = 0
	var/list/turfs = list(clearing_center, clearing_edge, natural_lava)
	for(var/turf/tile as anything in turfs)
		var/datum/gas_mixture/original_air
		if(isopenturf(tile))
			var/turf/open/open_turf = tile
			if(open_turf.air)
				original_air = allocate(/datum/gas_mixture)
				original_air.copy_from(open_turf.air)
		original_turfs[tile] = list(tile.type, islist(tile.baseturfs) ? tile.baseturfs.Copy() : tile.baseturfs, get_area(tile), original_air)

	generator.generate_terrain(turfs, get_area(clearing_center))

	TEST_ASSERT_EQUAL(clearing_center.type, /turf/open/misc/asteroid/basalt/expedition_volcanic, "The cave connector opens directly onto lava instead of solid volcanic ground.")
	TEST_ASSERT_EQUAL(clearing_edge.type, /turf/open/misc/asteroid/basalt/expedition_volcanic, "The edge of the cave connector clearing must also be solid ground.")
	TEST_ASSERT_EQUAL(natural_lava.type, /turf/open/lava/smooth/expedition_volcanic, "Making a connector clearing safe must preserve the surrounding lava biome.")

/// Profiles populate the real ground with their own fauna, without multiplying summoners into whole packs.
/datum/unit_test/overmap_planet_fauna

/datum/unit_test/overmap_planet_fauna/Run()
	var/turf/centre = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/list/cases = list(
		list(/datum/map_generator/expedition_barren/dead, /datum/biome/expedition/dead, null, 6, 10),
		list(/datum/map_generator/expedition_barren/frozen, /datum/biome/expedition/snow, /mob/living/basic/mining/legion/snow, 1, 1),
		list(/datum/map_generator/expedition_barren/frozen, /datum/biome/expedition/snow, /mob/living/basic/mining/ice_demon, 1, 1),
		list(/datum/map_generator/expedition_barren/arid, /datum/biome/expedition/sand, /mob/living/basic/mining/goliath, 1, 1),
		list(/datum/map_generator/expedition_barren/lava, /datum/biome/expedition/volcanic, /mob/living/basic/mining/legion, 1, 1),
	)
	for(var/list/entry as anything in cases)
		var/datum/map_generator/expedition_barren/generator = allocate(entry[1], 1)
		// The fixture anchor is in the profile's north district, outside its empty middle third.
		generator.origin_x = centre.x - 64
		generator.origin_y = centre.y - 96
		var/datum/biome/biome = generator.local_biome(entry[2])
		// Remove only the anchor roll and species selection from this small placement fixture.
		biome.fauna_density = 100
		if(entry[3])
			TEST_ASSERT(entry[3] in biome.fauna_types, "The profile no longer offers its expected fauna [entry[3]].")
			biome.fauna_types = list(entry[3])
		var/list/wild = list()
		wild[biome] = list(centre)
		generator.place_packs(wild)
		var/list/creatures = list()
		for(var/turf/tile in RANGE_TURFS(2, centre))
			for(var/mob/living/creature in tile)
				creatures += creature
				allocated += creature
				if(!entry[3])
					TEST_ASSERT(istype(creature, /mob/living/basic/zombie/rotten/expedition), "The dead world spawned [creature.type] instead of its plague carriers.")
		TEST_ASSERT(length(creatures) >= entry[4] && length(creatures) <= entry[5], "[generator.type] spawned [length(creatures)] mobs at a single anchor.")
		QDEL_LIST(creatures)

/// Ambient zombies occupy one compass district in larger packs, with no second budget on a later population pass.
/datum/unit_test/overmap_planet_zombie_region
	/// Private level keeps the generated packs away from other test occupants.
	var/level_z

/datum/unit_test/overmap_planet_zombie_region/Destroy()
	for(var/mob/living/creature as anything in GLOB.mob_living_list.Copy())
		if(creature.z == level_z)
			qdel(creature)
	return ..()

/datum/unit_test/overmap_planet_zombie_region/Run()
	var/datum/space_level/level = SSmapping.add_new_zlevel("Zombie region placement test", ZTRAITS_AWAY)
	level_z = level.z_value
	var/datum/map_generator/expedition_barren/dead/generator = allocate(/datum/map_generator/expedition_barren/dead, 123)
	generator.width = 176
	generator.origin_x = 20
	generator.origin_y = 20
	var/list/anchors = list()
	var/list/later_anchors = list()
	var/list/bands = list(list(14, 42), list(75, 103), list(135, 163))
	var/list/directions = list(list(SOUTHWEST, WEST, NORTHWEST), list(SOUTH, NONE, NORTH), list(SOUTHEAST, EAST, NORTHEAST))
	var/list/anchor_regions = list()
	for(var/x_band in 1 to 3)
		for(var/y_band in 1 to 3)
			if(x_band == 2 && y_band == 2)
				continue
			for(var/x in bands[x_band])
				for(var/y in bands[y_band])
					var/turf/anchor = locate(generator.origin_x + x - 1, generator.origin_y + y - 1, level_z)
					anchors += anchor
					anchor_regions[anchor] = directions[x_band][y_band]
					later_anchors += locate(anchor.x + 8, anchor.y, level_z)
	for(var/turf/anchor as anything in anchors + later_anchors)
		for(var/turf/tile in RANGE_TURFS(2, anchor))
			tile.ChangeTurf(/turf/open/misc/asteroid)
	var/datum/biome/biome = generator.local_biome(/datum/biome/expedition/dead)
	// Every district offers four equally viable anchors; only regional placement and pack limits are under test.
	biome.fauna_density = 100
	var/list/wild = list()
	wild[biome] = anchors
	generator.place_packs(wild)
	var/pack_count = 0
	var/total = 0
	var/actual_region = NONE
	for(var/turf/anchor as anything in anchors)
		var/members = 0
		for(var/turf/tile in RANGE_TURFS(2, anchor))
			for(var/mob/living/basic/zombie/rotten/expedition/creature in tile)
				members++
		if(members)
			if(!actual_region)
				actual_region = anchor_regions[anchor]
			TEST_ASSERT_EQUAL(anchor_regions[anchor], actual_region, "Actual groups must occupy one fixture district rather than different compass sectors.")
			pack_count++
			TEST_ASSERT(members >= 6 && members <= 10, "A viable ambient pack must contain six to ten actual zombies, got [members].")
			total += members
	TEST_ASSERT(pack_count >= 3 && pack_count <= 4, "The planet must have only three or four ordinary packs, got [pack_count].")
	TEST_ASSERT_EQUAL(generator.zombie_region, actual_region, "The selected region must describe where the groups actually spawned.")
	var/region = generator.zombie_region
	generator.cave_level = TRUE
	wild[biome] = later_anchors
	generator.place_packs(wild)
	var/after = 0
	for(var/mob/living/basic/zombie/rotten/expedition/creature in GLOB.mob_living_list)
		if(creature.z == level_z)
			after++
	TEST_ASSERT_EQUAL(after, total, "A later cave/population pass must not refill the planet-wide pack budget on fresh ground.")
	TEST_ASSERT_EQUAL(generator.zombie_region, region, "Later passes must retain the same geographic district.")

/// Planetary carcasses use the native bite infection, while the ordinary ruin carcass stays non-infectious.
/datum/unit_test/overmap_planet_zombie_bite

/datum/unit_test/overmap_planet_zombie_bite/Run()
	var/mob/living/basic/zombie/rotten/expedition/carrier = allocate(/mob/living/basic/zombie/rotten/expedition)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(carrier.infection_chance > 0, "The planetary carcass cannot infect through its bites.")
	TEST_ASSERT_EQUAL(/mob/living/basic/zombie/rotten::infection_chance, 0, "The ordinary ruin carcass must stay non-infectious.")
	// Make the bite deterministic; the native infection proc still checks the victim's actual armour and organs.
	carrier.infection_chance = 100
	carrier.melee_attack(victim, ignore_cooldown = TRUE)
	TEST_ASSERT_NOTNULL(victim.get_organ_slot(ORGAN_SLOT_ZOMBIE), "A successful unprotected bite did not insert the native zombie infection.")

/// Orbital artwork follows proximity and manoeuvre state without replacing the moving native space field.
/datum/unit_test/overmap_docking/orbital_parallax

/datum/unit_test/overmap_docking/orbital_parallax/Run()
	var/datum/stationtrauma_overmap_site/space/planet/planet = allocate(/datum/stationtrauma_overmap_site/space/planet)
	planet.id = "unit_test_planet"
	planet.pos_x = navigation.pos_x + 500
	planet.pos_y = navigation.pos_y
	navigation.sites[planet.id] = planet
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A distant world must not appear behind the ship")
	planet.pos_x = navigation.pos_x + 100
	TEST_ASSERT_EQUAL(navigation.parallax_planet(), planet.parallax_layer, "A nearby charted world must appear without loading its surface")
	planet.discovered = FALSE
	TEST_ASSERT_NULL(navigation.parallax_planet(), "The background must not disclose an undiscovered world")
	planet.discovered = TRUE
	planet.failed = TRUE
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A failed destination must not leave an orbital image")
	planet.failed = FALSE
	navigation.speed = 1
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, planet.parallax_layer, "The ship must publish its nearby world to the viewers' area")
	TEST_ASSERT_EQUAL(hull_area.parallax_movedir, ship.preferred_direction, "The ordinary space layers must keep scrolling beside a fixed planet")
	TEST_ASSERT_EQUAL(navigation.parallax_background(), /atom/movable/screen/parallax_layer/layer_3, "An orbital world must not replace the native star field")
	var/datum/stationtrauma_overmap_site/space/planet/frozen/ice = allocate(/datum/stationtrauma_overmap_site/space/planet/frozen)
	ice.id = "unit_test_ice"
	ice.pos_x = navigation.pos_x + 90
	ice.pos_y = navigation.pos_y
	navigation.sites[ice.id] = ice
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, ice.parallax_layer, "A different nearest biome must update even when motion and star field stay the same")
	ice.failed = TRUE
	navigation.jump_phase = HYPERSPACE_LAUNCH
	navigation.update_parallax()
	TEST_ASSERT_NULL(hull_area.space_parallax_planet, "A departing bluespace jump must remove the orbital world")
	navigation.jump_phase = NONE
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, planet.parallax_layer, "Cancelling or finishing a jump near the world must restore its image")
	planet.pos_x = navigation.pos_x + 500
	navigation.approach_site = planet
	navigation.approach_started = world.time
	TEST_ASSERT_EQUAL(navigation.parallax_planet(), planet.parallax_layer, "The current descent keeps its world throughout the approach")
	planet.berth = bay
	TEST_ASSERT_NULL(navigation.parallax_planet(), "The world must disappear when the hull reaches its physical surface level")
	navigation.approach_departing = TRUE
	TEST_ASSERT_EQUAL(navigation.parallax_planet(), planet.parallax_layer, "Ascent must restore the fixed world while space scrolls")
	navigation.approach_site = null
	navigation.approach_started = 0
	navigation.approach_departing = FALSE
	navigation.docked = planet
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A landed hull must not see its entire world in the sky")
	planet.berth = null
	planet.pos_x = navigation.pos_x + 100
	navigation.docked = site
	TEST_ASSERT_NULL(navigation.parallax_planet(), "A physical station berth must retain its own background")
	navigation.docked = null
	navigation.update_parallax()
	TEST_ASSERT_EQUAL(hull_area.space_parallax_planet, planet.parallax_layer, "Leaving the physical berth restores a nearby world")
	planet.pos_x = navigation.pos_x + 500
	navigation.update_parallax()
	TEST_ASSERT_NULL(hull_area.space_parallax_planet, "Leaving orbital range must clear the cached world")
	TEST_ASSERT_NULL(exterior.space_parallax_planet, "The empty flight level must clear the same orbital profile")

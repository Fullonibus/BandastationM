/// Makes sure turf icons actually exist. :)
/datum/unit_test/maptest_turf_icons
	var/modular_mineral_turf_file //= 'icons/turf/mining.dmi' //MODULARITY SUPPORT - insert your snowflake MAP_SWITCH icon file here if you use that define.

/datum/unit_test/maptest_turf_icons/Run()
	for(var/turf/turf_path as anything in (subtypesof(/turf) - typesof(/turf/closed/mineral, /turf/closed/indestructible/rock)))

		var/icon_state = initial(turf_path.icon_state)
		var/icon_file = initial(turf_path.icon)
		if(isnull(icon_state) || isnull(icon_file))
			continue
		if(!icon_exists(icon_file, icon_state))
			TEST_FAIL("[turf_path] using invalid icon_state - \"[icon_state]\" in icon file, '[icon_file]")

	for(var/turf/closed/mineral/turf_path as anything in typesof(/turf/closed/mineral)) //minerals use a special (read: snowflake) MAP_SWITCH definition that changes their icon based on if we're just compiling or if we're actually PLAYING the game.

		var/icon_state = initial(turf_path.icon_state)
		var/icon_file = initial(turf_path.icon)
		if(isnull(icon_state) || isnull(icon_file))
			continue
		if(!icon_exists(icon_file, icon_state))
			if(modular_mineral_turf_file && (icon_state in icon_states(modular_mineral_turf_file, 1)))
				continue
			if(!(icon_state in icon_states('icons/turf/mining.dmi', 1)))
				TEST_FAIL("[turf_path] using invalid icon_state - \"[icon_state]\" in icon file, '[icon_file]")

	var/turf/initial_turf_type = run_loc_floor_bottom_left.type

	var/list/ignored_types = list()
	//ignored_types += typesof(YOUR_DOWNSTREAM_TYPEPATH(s)_HERE) //MODULARITY SUPPORT. If you have snowflake typepaths that are blacklisted in, for example, create & destroy unit test because they require certain SS's being init, use this to blacklist them.


	for(var/turf/open/open_turf_path as anything in (subtypesof(/turf/open) - ignored_types))

		var/damaged_dmi = initial(open_turf_path.damaged_dmi)
		if(isnull(damaged_dmi))
			continue


		run_loc_floor_bottom_left.ChangeTurf(open_turf_path)
		run_loc_floor_bottom_left = get_turf(locate(/obj/effect/landmark/unit_test_bottom_left) in GLOB.landmarks_list) //in case the turf path changed the final turf in Initialize() without passing the final turf to ChangeTurf()....
		if(!isopenturf(run_loc_floor_bottom_left))
			continue
		var/turf/open/instanced_turf = run_loc_floor_bottom_left

		var/list/burnt_states = instanced_turf.burnt_states()
		for(var/state in burnt_states)
			if(!icon_exists(damaged_dmi, state))
				TEST_FAIL("[open_turf_path] has an invalid icon in burnt_states - \"[state]\", in '[damaged_dmi]'")


		var/list/broken_states = instanced_turf.broken_states()
		for(var/state in broken_states)
			if(!icon_exists(damaged_dmi, state))
				TEST_FAIL("[open_turf_path] has an invalid icon in broken_states - \"[state]\", in '[damaged_dmi]'")

	run_loc_floor_bottom_left = run_loc_floor_bottom_left.ChangeTurf(initial_turf_type) //cleanup.


/// Checks the appearance and repair of a partially dismantled wall after shuttle turf copying.
/datum/unit_test/copied_reinforced_wall/Run()
	var/source_type = run_loc_floor_bottom_left.type
	var/destination_type = run_loc_floor_top_right.type
	var/list/source_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/list/destination_baseturfs = run_loc_floor_top_right.baseturfs
	var/mob/living/carbon/human/worker = allocate(/mob/living/carbon/human/consistent, get_step(run_loc_floor_bottom_left, EAST))
	var/obj/item/wirecutters/cutters = allocate(/obj/item/wirecutters, worker)
	var/turf/closed/wall/r_wall/source_wall = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/wall/r_wall)
	source_wall.try_decon(cutters, worker)
	var/dismantled_icon_state = source_wall.icon_state

	var/turf/closed/wall/r_wall/moved_wall = run_loc_floor_top_right.CopyOnTop(source_wall)
	if(moved_wall.smoothing_flags & SMOOTH_QUEUED)
		moved_wall.smooth_icon()
	var/kept_dismantled_sprite = moved_wall.icon_state == dismantled_icon_state && icon_exists(moved_wall.icon, moved_wall.icon_state)
	moved_wall.try_decon(cutters, worker)
	var/repaired = moved_wall.d_state == INTACT

	source_wall.ChangeTurf(source_type, source_baseturfs)
	moved_wall.ChangeTurf(destination_type, destination_baseturfs)

	if(!kept_dismantled_sprite)
		TEST_FAIL("The copied wall lost its dismantled sprite after smoothing.")
	TEST_ASSERT(repaired, "Wirecutters should repair the copied wall's cut grille.")

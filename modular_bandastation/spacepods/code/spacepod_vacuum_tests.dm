/// An independent space area keeps the shared unit-test room and its gravity untouched.
/area/space/spacepod_vacuum_test
	name = "Spacepod vacuum test enclosure"
	area_flags_mapping = NONE

/datum/unit_test/spacepod_vacuum
	abstract_type = /datum/unit_test/spacepod_vacuum
	/// This is deliberately distinct from the inherited static unit-test reservation.
	var/datum/turf_reservation/vacuum_block
	var/area/space/spacepod_vacuum_test/vacuum_area
	var/list/original_areas = list()
	var/turf/open/space/vacuum_origin

/datum/unit_test/spacepod_vacuum/New()
	..()
	vacuum_block = SSmapping.request_turf_block_reservation(9, 9, 1, turf_type_override = /turf/open/space)
	if(!vacuum_block)
		return
	vacuum_area = new
	for(var/turf/tile as anything in vacuum_block.reserved_turfs)
		var/area/original_area = get_area(tile)
		original_areas[tile] = original_area
		tile.change_area(original_area, vacuum_area)
	vacuum_area.reg_in_areas_in_z()
	var/turf/bottom_left = vacuum_block.bottom_left_turfs[1]
	vacuum_origin = locate(bottom_left.x + 2, bottom_left.y + 2, bottom_left.z)

/datum/unit_test/spacepod_vacuum/Destroy()
	// Delete occupants and vehicles while the reservation and its turfs still exist.
	QDEL_LIST(allocated)
	for(var/turf/tile as anything in original_areas)
		if(get_area(tile) == vacuum_area)
			tile.change_area(vacuum_area, original_areas[tile])
	original_areas.Cut()
	vacuum_origin = null
	QDEL_NULL(vacuum_area)
	QDEL_NULL(vacuum_block)
	return ..()

/// The real thruster path must work in zero gravity and reject repeat/unpowered inputs.
/datum/unit_test/spacepod_vacuum/flight/Run()
	TEST_ASSERT_NOTNULL(vacuum_block, "Could not reserve an independent vacuum enclosure.")
	TEST_ASSERT(isspaceturf(vacuum_origin), "The vacuum enclosure did not contain real space turfs.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "A human could not board a real pod on space turfs.")
	TEST_ASSERT_EQUAL(length(pod.locs), 4, "The vacuum pod does not occupy a 2x2 footprint.")
	for(var/turf/tile as anything in pod.locs)
		TEST_ASSERT(isspaceturf(tile), "Part of the pod's footprint is outside real space.")
		TEST_ASSERT_EQUAL(get_area(tile), vacuum_area, "Part of the pod left its isolated test area.")
	TEST_ASSERT(!pod.has_gravity() && !pilot.has_gravity(), "The vacuum flight fixture has gravity.")
	var/initial_charge = pod.battery.charge
	TEST_ASSERT(pod.relaymove(pilot, EAST), "A pilot could not propel the pod through actual zero-gravity space.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge - SPACEPOD_ENERGY_UNIT, "A vacuum move consumed the wrong amount of energy.")
	var/turf/first_destination = get_step(vacuum_origin, EAST)
	TEST_ASSERT_EQUAL(pod.loc, first_destination, "The vacuum move did not move exactly one tile east.")
	TEST_ASSERT(COOLDOWN_TIMELEFT(pod, cooldown_vehicle_move) > 0, "Moving through space did not start the movement cooldown.")
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "A second movement input bypassed the cooldown.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge - SPACEPOD_ENERGY_UNIT, "A cooldown-rejected input consumed power.")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(pod.loc, first_destination, "The pod drifted after the pilot stopped thrusting.")
	TEST_ASSERT_NULL(pod.drift_handler, "Thruster-held flight incorrectly started a Newtonian drift loop.")
	// Life support may consume power while the movement cooldown elapses.
	var/charge_before_second_move = pod.battery.charge
	TEST_ASSERT(pod.relaymove(pilot, NORTH), "The pod could not move again after its real cooldown elapsed.")
	TEST_ASSERT_EQUAL(pod.battery.charge, charge_before_second_move - SPACEPOD_ENERGY_UNIT, "The vacuum move after cooldown consumed the wrong amount of energy.")
	var/turf/unpowered_position = get_turf(pod)
	pod.battery.charge = 0
	sleep(0.6 SECONDS)
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "An exhausted cell still powered vacuum flight.")
	TEST_ASSERT_EQUAL(pod.loc, unpowered_position, "The pod moved or drifted with an exhausted cell.")
	TEST_ASSERT_EQUAL(pod.battery.charge, 0, "An unpowered movement attempt changed an empty cell's charge.")

/// Inspect real spawned particles without replacing movement or the trail system.
/datum/unit_test/spacepod_vacuum/proc/get_thrust_particles(list/turfs)
	if(isnull(turfs))
		turfs = vacuum_block.reserved_turfs
	var/list/particles = list()
	for(var/turf/tile as anything in turfs)
		for(var/obj/effect/particle_effect/ion_trails/spacepod/particle in tile)
			if(!QDELETED(particle))
				particles += particle
	return particles

/// Successful thrust must leave visible exhaust once, while idle and rejected inputs leave none.
/datum/unit_test/spacepod_vacuum/thrust_effects/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for thruster effects.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The thruster test pilot could not board the pod.")
	TEST_ASSERT(!pod.has_gravity(), "The thruster test pod is not in zero gravity.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 0, "Initializing an idle pod created exhaust.")
	TEST_ASSERT(pod.relaymove(pilot, EAST), "A powered vacuum movement failed.")
	var/list/particles = get_thrust_particles()
	allocated |= particles
	TEST_ASSERT_EQUAL(length(particles), 1, "One powered movement did not produce exactly one exhaust particle.")
	var/obj/effect/particle_effect/ion_trails/spacepod/first_particle = particles[1]
	TEST_ASSERT(!(get_turf(first_particle) in pod.locs), "The 2x2 pod hides its exhaust beneath its footprint.")
	TEST_ASSERT_EQUAL(first_particle.plane, GAME_PLANE, "The exhaust is outside the visible world plane.")
	TEST_ASSERT_EQUAL(pod.ion_trail.oldposition, get_turf(pod), "The trail retained a stale origin after movement.")
	var/datum/looping_sound/spacepod_engine/first_sound = pod.engine_sounds[pilot]
	TEST_ASSERT_NOTNULL(first_sound, "A powered thrust did not create a native cabin sound loop.")
	TEST_ASSERT(first_sound.is_active(), "A powered thrust did not start the native cabin sound loop.")
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "An immediate input bypassed the native movement cooldown.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 1, "A cooldown-rejected input created exhaust.")
	TEST_ASSERT_EQUAL(pod.engine_sounds[pilot], first_sound, "A cooldown-rejected input replaced the active engine sound.")
	sleep(0.35 SECONDS)
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 1, "An idle pod kept generating exhaust without movement.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "The engine sound outlasted the completed movement glide.")
	var/turf/current_turf = get_turf(pod)
	var/obj/structure/blocker = allocate(/obj/structure, locate(current_turf.x + 2, current_turf.y + 1, current_turf.z))
	blocker.density = TRUE
	blocker.anchored = TRUE
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "The blocked vacuum movement unexpectedly succeeded.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 1, "A blocked movement created exhaust.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "A blocked movement started engine sound.")
	qdel(blocker)
	sleep(0.25 SECONDS)
	TEST_ASSERT(pod.relaymove(pilot, NORTH), "A second unblocked vacuum movement failed.")
	particles = get_thrust_particles()
	allocated |= particles
	TEST_ASSERT_EQUAL(length(particles), 2, "A second powered movement did not add one exhaust particle.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 1, "A second powered movement did not start one cabin engine sound.")
	pod.battery.charge = 0
	sleep(0.25 SECONDS)
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "An empty cell powered the thruster effect test.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 2, "An unpowered input created exhaust.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "An unpowered input restarted engine sound.")
	sleep(2.1 SECONDS)
	TEST_ASSERT(QDELETED(first_particle), "The temporary exhaust particle survived its two-second lifetime.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 0, "A stationary pod retained or regenerated exhaust indefinitely.")
	var/datum/effect_system/trail_follow/ion/spacepod/trail = pod.ion_trail
	qdel(pod)
	TEST_ASSERT(QDELETED(trail), "Deleting the pod left its exhaust system alive.")

/// A station floor with normal gravity must not emit the zero-gravity exhaust or engine pulse.
/datum/unit_test/spacepod_vacuum/thrust_on_floor/Run()
	var/turf/origin = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The station-floor test pilot could not board the pod.")
	TEST_ASSERT(pod.has_gravity(), "The station-floor fixture does not have normal gravity.")
	var/list/floor_turfs = get_area_turfs(get_area(origin))
	TEST_ASSERT(pod.relaymove(pilot, EAST), "A powered movement across station floor failed.")
	var/list/particles = get_thrust_particles(floor_turfs)
	allocated |= particles
	TEST_ASSERT_EQUAL(length(particles), 0, "Movement on station floor created a space exhaust trail.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "Movement on station floor started a space engine loop.")
	TEST_ASSERT_NULL(pod.engine_sound_timer, "Movement on station floor scheduled a space engine loop timer.")

/// Real movement owns native sound loops and channels only for the duration of its glide.
/datum/unit_test/spacepod_vacuum/engine_sound_motion/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve space for engine sound motion tests.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	pod.max_passengers = 1
	pod.max_occupants = 2
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	var/mob/living/carbon/human/consistent/passenger = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot) && pod.mob_try_enter(passenger), "The sound test occupants could not board the real cabin.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "An idle cabin allocated engine sound channels.")
	TEST_ASSERT(pod.relaymove(pilot, NORTHEAST), "A real diagonal vacuum movement failed to start the engine.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 2, "A diagonal movement did not create exactly one loop per occupant.")
	var/list/initial_sounds = pod.engine_sounds.Copy()
	var/list/sound_channels = list()
	for(var/mob/living/listener as anything in initial_sounds)
		var/datum/looping_sound/spacepod_engine/engine_sound = initial_sounds[listener]
		TEST_ASSERT(engine_sound.is_active() && engine_sound.direct, "The native cabin loop is inactive or not directed to its listener.")
		TEST_ASSERT_EQUAL(engine_sound.parent, listener, "The cabin sound is attached to the wrong listener.")
		TEST_ASSERT_EQUAL(engine_sound.volume, 15, "The engine sound volume exceeds its original value.")
		TEST_ASSERT_NOTNULL(engine_sound.sound_channel, "The native engine loop has no allocated sound channel.")
		TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(engine_sound.sound_channel)], engine_sound, "The engine channel is not owned by its native sound datum.")
		sound_channels[engine_sound] = engine_sound.sound_channel
	pod.start_engine_sound(COOLDOWN_TIMELEFT(pod, cooldown_vehicle_move))
	TEST_ASSERT_EQUAL(pod.engine_sounds[pilot], initial_sounds[pilot], "Refreshing an active glide replaced the pilot's sound loop.")
	TEST_ASSERT_EQUAL(pod.engine_sounds[passenger], initial_sounds[passenger], "Refreshing an active glide replaced the passenger's sound loop.")
	TEST_ASSERT(!pod.relaymove(pilot, EAST), "A repeated input bypassed the real movement cooldown.")
	TEST_ASSERT(!pod.relaymove(passenger, EAST), "A passenger operated the engine during sound playback.")
	for(var/mob/living/listener as anything in initial_sounds)
		TEST_ASSERT_EQUAL(pod.engine_sounds[listener], initial_sounds[listener], "A cooldown or passenger input restarted the current sample.")
	sleep(0.45 SECONDS)
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "A finite diagonal glide left a six-second sound playing after stopping.")
	TEST_ASSERT_NULL(pod.engine_sound_timer, "The completed glide retained its sound stop timer.")
	for(var/datum/looping_sound/spacepod_engine/engine_sound as anything in sound_channels)
		TEST_ASSERT(QDELETED(engine_sound), "A completed glide retained a live native sound loop.")
		TEST_ASSERT(SSsounds.using_channels[num2text(sound_channels[engine_sound])] != engine_sound, "A completed glide retained its reserved audio channel.")
		TEST_ASSERT(!length(SSsounds.using_channels_by_datum[engine_sound]), "A completed glide leaked managed sound channel ownership.")
	var/list/flight_path = list(EAST, NORTH, WEST, SOUTH)
	var/flight_started = world.time
	for(var/lap in 1 to 12)
		for(var/direction in flight_path)
			var/list/sounds_before_step = pod.engine_sounds.Copy()
			TEST_ASSERT(pod.relaymove(pilot, direction), "Sustained engine flight failed at lap [lap], direction [direction].")
			TEST_ASSERT_EQUAL(length(pod.engine_sounds), 2, "Sustained flight layered or lost cabin sound loops.")
			for(var/mob/living/listener as anything in pod.engine_sounds)
				var/datum/looping_sound/spacepod_engine/engine_sound = pod.engine_sounds[listener]
				if(sounds_before_step[listener])
					TEST_ASSERT_EQUAL(engine_sound, sounds_before_step[listener], "Movement replaced an engine sound that was still active before the step.")
				TEST_ASSERT(engine_sound.is_active(), "A successful sustained-flight step has no active native engine loop.")
				TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(engine_sound.sound_channel)], engine_sound, "Sustained flight lost its managed engine channel.")
				sound_channels[engine_sound] = engine_sound.sound_channel
			// Send the next real step as soon as its native cooldown permits, without changing that cooldown.
			sleep(COOLDOWN_TIMELEFT(pod, cooldown_vehicle_move))
	TEST_ASSERT(world.time - flight_started > 6.2 SECONDS, "The sustained flight did not exceed the original sound sample's length.")
	sleep(0.3 SECONDS)
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "Stopping a long flight left cabin engine sound playing.")
	for(var/datum/looping_sound/spacepod_engine/engine_sound as anything in sound_channels)
		TEST_ASSERT(QDELETED(engine_sound), "Sustained flight accumulated live sound datums.")
		TEST_ASSERT(!length(SSsounds.using_channels_by_datum[engine_sound]), "Sustained flight leaked an engine sound channel.")
	TEST_ASSERT(pod.relaymove(pilot, EAST), "The engine did not restart after a completed long flight.")
	var/datum/looping_sound/spacepod_engine/pilot_sound = pod.engine_sounds[pilot]
	var/datum/looping_sound/spacepod_engine/passenger_sound = pod.engine_sounds[passenger]
	pod.mob_exit(passenger, silent = TRUE)
	TEST_ASSERT(QDELETED(passenger_sound), "A departing passenger retained their native engine loop.")
	TEST_ASSERT(!length(SSsounds.using_channels_by_datum[passenger_sound]), "A departing passenger leaked their cabin sound channel.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 1, "A departing passenger stopped or retained the wrong cabin loops.")
	TEST_ASSERT_EQUAL(pod.engine_sounds[pilot], pilot_sound, "A departing passenger replaced the pilot's sound loop.")
	TEST_ASSERT(pilot_sound.is_active(), "A departing passenger stopped the moving pilot's engine sound.")
	pod.mob_exit(pilot, silent = TRUE)
	TEST_ASSERT(QDELETED(pilot_sound), "A departing pilot left engine sound playing.")
	TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "Losing the pilot retained cabin engine sound listeners.")
	TEST_ASSERT_NULL(pod.engine_sound_timer, "Losing the pilot retained a pending engine sound stop timer.")

/// Interrupt actual engine playback and verify native datum/channel cleanup synchronously.
/datum/unit_test/spacepod_vacuum/engine_sound_interruptions/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve space for engine sound interruption tests.")
	for(var/scenario in list("blocked", "empty cell", "removed cell", "EMP", "pilot exit", "meltdown", "deletion"))
		var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
		pod.enter_delay = 0
		var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
		TEST_ASSERT(pod.mob_try_enter(pilot), "The [scenario] pilot could not board the sound test pod.")
		TEST_ASSERT(pod.relaymove(pilot, EAST), "The [scenario] movement did not start real engine playback.")
		var/datum/looping_sound/spacepod_engine/engine_sound = pod.engine_sounds[pilot]
		TEST_ASSERT_NOTNULL(engine_sound, "The [scenario] fixture has no real engine sound datum.")
		TEST_ASSERT(engine_sound.is_active(), "The [scenario] fixture has no active engine sound.")
		var/channel = engine_sound.sound_channel
		var/sound_stop_timer = pod.engine_sound_timer
		var/obj/item/stock_parts/power_store/cell/cell = pod.battery
		switch(scenario)
			if("blocked")
				var/obj/structure/blocker = allocate(/obj/structure, locate(pod.x + 2, pod.y + 1, pod.z))
				blocker.density = TRUE
				blocker.anchored = TRUE
				// Keep the current audio active while exercising the actual collision branch.
				COOLDOWN_RESET(pod, cooldown_vehicle_move)
				TEST_ASSERT(!pod.relaymove(pilot, EAST), "The blocked sound fixture moved through a real dense obstacle.")
				qdel(blocker)
			if("empty cell")
				cell.charge = 0
				TEST_ASSERT(!pod.relaymove(pilot, EAST), "An empty cell moved the pod during engine playback.")
			if("removed cell")
				cell.forceMove(get_step(pod, SOUTH))
			if("EMP")
				pod.emp_act(EMP_HEAVY)
			if("pilot exit")
				pod.mob_exit(pilot, silent = TRUE)
			if("meltdown")
				pod.atom_destruction(BOMB)
			if("deletion")
				qdel(pod)
		TEST_ASSERT(QDELETED(engine_sound), "[scenario] did not immediately delete the active native engine loop.")
		TEST_ASSERT(SSsounds.using_channels[num2text(channel)] != engine_sound, "[scenario] retained the native engine channel.")
		TEST_ASSERT(!length(SSsounds.using_channels_by_datum[engine_sound]), "[scenario] leaked managed engine channel ownership.")
		TEST_ASSERT(isnull(timeleft(sound_stop_timer)), "[scenario] retained the engine's pending glide timer.")
		if(!QDELETED(pod))
			TEST_ASSERT_EQUAL(length(pod.engine_sounds), 0, "[scenario] left sound listeners registered in the pod.")
			qdel(pod)
		qdel(cell)
		qdel(pilot)

/// A sustained flight and turns must leave temporary particles, never a persistent sparkling wake.
/datum/unit_test/spacepod_vacuum/thrust_trail_cleanup/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve space for the exhaust lifecycle test.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The exhaust lifecycle pilot could not board the pod.")
	TEST_ASSERT(pod.relaymove(pilot, EAST), "The initial exhaust lifecycle movement failed.")
	var/list/all_particles = get_thrust_particles()
	allocated |= all_particles
	TEST_ASSERT_EQUAL(length(all_particles), 1, "An initial thrust did not emit exactly one real particle.")
	var/obj/effect/particle_effect/ion_trails/spacepod/first_particle = all_particles[1]
	var/turf/turning_position = get_turf(pod)
	SEND_SIGNAL(pilot, COMSIG_MOVABLE_KEYBIND_FACE_DIR, NORTH)
	sleep(0.25 SECONDS)
	TEST_ASSERT_EQUAL(pod.loc, turning_position, "Turning in place moved the pod during the exhaust test.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 1, "Turning or idling regenerated the exhaust particle.")
	var/list/flight_path = list(EAST, EAST, NORTH, NORTH, WEST, WEST, SOUTH, SOUTH)
	for(var/lap in 1 to 2)
		for(var/direction in flight_path)
			TEST_ASSERT(pod.relaymove(pilot, direction), "Sustained flight failed at lap [lap], direction [direction].")
			var/list/live_particles = get_thrust_particles()
			all_particles |= live_particles
			allocated |= live_particles
			TEST_ASSERT_EQUAL(pod.ion_trail.oldposition, get_turf(pod), "Exhaust emission retained a previous position during sustained flight.")
			// At 5 movements/second and a two-second lifetime, old particles must expire mid-flight.
			TEST_ASSERT(length(live_particles) <= 12, "Exhaust particles accumulated instead of expiring during sustained flight.")
			sleep(0.2 SECONDS)
	TEST_ASSERT(QDELETED(first_particle), "The initial exhaust particle survived a sustained flight past its lifetime.")
	TEST_ASSERT_EQUAL(length(all_particles), 17, "Seventeen successful movements did not emit seventeen real exhaust particles.")
	sleep(2.2 SECONDS)
	for(var/obj/effect/particle_effect/ion_trails/spacepod/particle as anything in all_particles)
		TEST_ASSERT(QDELETED(particle), "A real exhaust particle remained after the pilot stopped and its lifetime elapsed.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 0, "Stopping the pod left or regenerated a stationary sparkling trail.")
	TEST_ASSERT(pod.relaymove(pilot, EAST), "Exhaust stopped working after the previous wake expired.")
	var/list/final_particles = get_thrust_particles()
	allocated |= final_particles
	TEST_ASSERT_EQUAL(length(final_particles), 1, "The final movement did not emit a real particle before destruction.")
	var/datum/effect_system/trail_follow/ion/spacepod/trail = pod.ion_trail
	qdel(pod)
	TEST_ASSERT(QDELETED(trail), "Deleting a pod in flight left its trail generator alive.")
	sleep(2.2 SECONDS)
	for(var/obj/effect/particle_effect/ion_trails/spacepod/particle as anything in final_particles)
		TEST_ASSERT(QDELETED(particle), "Deleting a pod in flight left a real exhaust particle after its lifetime.")
	TEST_ASSERT_EQUAL(length(get_thrust_particles()), 0, "A deleted pod regenerated its exhaust particles.")

/// Exercise the human's real lungs and environmental Life path without a suit or internals.
/datum/unit_test/spacepod_vacuum/human_breathing/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for breathing.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT_NULL(pilot.internal, "The breathing subject unexpectedly has personal internals.")
	TEST_ASSERT_NULL(pilot.wear_mask, "The breathing subject unexpectedly has a breathing mask.")
	TEST_ASSERT_NULL(pilot.wear_suit, "The breathing subject unexpectedly has a protective suit.")
	TEST_ASSERT(!HAS_TRAIT(pilot, TRAIT_NOBREATH) && !HAS_TRAIT(pilot, TRAIT_GODMODE) && !HAS_TRAIT(pilot, TRAIT_NO_BREATHLESS_DAMAGE), "The breathing subject is immune to vacuum suffocation.")
	TEST_ASSERT(pod.mob_try_enter(pilot), "The breathing subject could not board the cabin.")
	TEST_ASSERT_EQUAL(vacuum_origin.return_air().total_moles(), 0, "The exterior of the cabin is not a vacuum.")
	var/starting_oxygen = pod.cabin_air.moles[/datum/gas/oxygen]
	pilot.Life(SSMOBS_DT)
	for(var/breath in 1 to 6)
		pilot.breathe(SSMOBS_DT)
		var/exhaled_co2 = pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0
		TEST_ASSERT(exhaled_co2 > 0, "Native human exhalation did not return CO2 to the cabin before life-support processing.")
		pod.process(SSMOBS_DT)
		TEST_ASSERT((pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) < exhaled_co2, "Life support did not remove native human exhalation from the cabin.")
	TEST_ASSERT(!pilot.failed_last_breath && !pilot.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "A human cannot breathe cabin air while the pod is in space.")
	TEST_ASSERT_EQUAL(pilot.get_oxy_loss(), 0, "A healthy human accumulated oxygen damage inside the pressurized cabin.")
	TEST_ASSERT(pod.cabin_air.moles[/datum/gas/oxygen] < starting_oxygen, "Native human breathing did not consume the cabin's oxygen.")
	TEST_ASSERT((pod.cabin_air.moles[/datum/gas/carbon_dioxide] || 0) <= MOLAR_ACCURACY, "The powered filter retained CO2 after an ordinary human breath.")
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "The pilot could not switch to exterior air.")
	TEST_ASSERT_EQUAL(pod.return_air(), vacuum_origin.return_air(), "Exterior mode does not expose the actual space atmosphere.")
	var/oxygen_damage_before = pilot.get_oxy_loss()
	for(var/breath in 1 to 3)
		pilot.breathe(SSMOBS_DT)
	TEST_ASSERT(pilot.failed_last_breath && pilot.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "Switching to exterior vacuum did not cause suffocation.")
	TEST_ASSERT(pilot.get_oxy_loss() > oxygen_damage_before, "The human's real lungs did not apply oxygen damage in exterior vacuum mode.")
	var/oxygen_damage_in_vacuum = pilot.get_oxy_loss()
	TEST_ASSERT(pod.toggle_internal_tank(pilot), "A conscious pilot could not reconnect the cabin's internal air supply.")
	pilot.breathe(SSMOBS_DT)
	TEST_ASSERT(!pilot.failed_last_breath && !pilot.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "Reconnecting cabin air failed to restore native human breathing.")
	TEST_ASSERT(pilot.get_oxy_loss() < oxygen_damage_in_vacuum, "Breathing cabin air did not begin healing vacuum hypoxia.")

/// A real, limited tank may equalize with the cabin but cannot manufacture an atmosphere.
/datum/unit_test/spacepod_vacuum/finite_tank/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for the finite tank.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	qdel(pod.cabin_air.remove_ratio(1))
	qdel(tank_air.remove_ratio(1))
	var/limited_moles = 0.2 * ONE_ATMOSPHERE * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C)
	tank_air.set_gas(/datum/gas/oxygen, limited_moles * O2STANDARD)
	tank_air.set_gas(/datum/gas/nitrogen, limited_moles * N2STANDARD)
	var/initial_tank_moles = tank_air.total_moles()
	for(var/step in 1 to 24)
		var/before = tank_air.total_moles() + pod.cabin_air.total_moles()
		pod.give_air()
		var/after = tank_air.total_moles() + pod.cabin_air.total_moles()
		TEST_ASSERT(abs(before - after) <= MAXIMUM_ERROR_GAS_REMOVAL, "A finite-tank regulator step created or destroyed more gas than native quantization permits.")
	TEST_ASSERT(tank_air.total_moles() < initial_tank_moles, "Refilling the cabin did not consume the real tank's finite gas supply.")
	TEST_ASSERT(pod.cabin_air.total_moles() > 0, "The finite tank did not transfer any gas into the empty cabin.")
	var/maximum_possible_pressure = initial_tank_moles * R_IDEAL_GAS_EQUATION * T20C / pod.cabin_air.volume
	var/pressure_tolerance = MAXIMUM_ERROR_GAS_REMOVAL * R_IDEAL_GAS_EQUATION * T20C / pod.cabin_air.volume
	TEST_ASSERT(pod.cabin_air.return_pressure() <= maximum_possible_pressure + pressure_tolerance, "The tank produced cabin pressure beyond what its initial gas supply could provide.")
	TEST_ASSERT(pod.cabin_air.return_pressure() < ONE_ATMOSPHERE, "An insufficient gas supply somehow filled the cabin to one atmosphere.")
	qdel(pod.cabin_air.remove_ratio(1))
	qdel(tank_air.remove_ratio(1))
	for(var/step in 1 to 8)
		pod.process(SSMOBS_DT)
	TEST_ASSERT_EQUAL(pod.cabin_air.total_moles(), 0, "An exhausted tank regenerated gas in an empty cabin.")
	TEST_ASSERT_EQUAL(tank_air.total_moles(), 0, "An exhausted tank regenerated its own gas supply.")

/// Excess pressure must vent into real space, while temperature regulation uses cabin air.
/datum/unit_test/spacepod_vacuum/pressure_and_temperature/Run()
	TEST_ASSERT_NOTNULL(vacuum_origin, "Could not reserve a vacuum enclosure for pressure regulation.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.cabin_air.set_gas(/datum/gas/oxygen, 2 * ONE_ATMOSPHERE * O2STANDARD * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	pod.cabin_air.set_gas(/datum/gas/nitrogen, 2 * ONE_ATMOSPHERE * N2STANDARD * pod.cabin_air.volume / (R_IDEAL_GAS_EQUATION * T20C))
	var/datum/gas_mixture/tank_air = pod.internal_tank.return_air()
	var/tank_before = tank_air.total_moles()
	var/cabin_before = pod.cabin_air.total_moles()
	pod.process(SSMOBS_DT)
	var/pressure_tolerance = MAXIMUM_ERROR_GAS_REMOVAL * R_IDEAL_GAS_EQUATION * T20C / pod.cabin_air.volume
	TEST_ASSERT(abs(pod.cabin_air.return_pressure() - ONE_ATMOSPHERE) <= pressure_tolerance, "An overpressurized cabin was not vented back to one atmosphere.")
	TEST_ASSERT(pod.cabin_air.total_moles() < cabin_before, "Overpressure correction did not remove gas from the cabin.")
	TEST_ASSERT_EQUAL(tank_air.total_moles(), tank_before, "Venting an overpressurized cabin consumed gas from its supply tank.")
	TEST_ASSERT_EQUAL(vacuum_origin.return_air().total_moles(), 0, "Venting into space left a persistent atmosphere outside the pod.")
	pod.cabin_air.temperature = T20C + 40
	var/hot_temperature = pod.cabin_air.temperature
	pod.process(SSMOBS_DT)
	TEST_ASSERT(pod.cabin_air.temperature < hot_temperature && pod.cabin_air.temperature >= T20C, "The cabin regulator did not cool overheated cabin air toward its target.")
	pod.cabin_air.temperature = T20C - 40
	var/cold_temperature = pod.cabin_air.temperature
	pod.process(SSMOBS_DT)
	TEST_ASSERT(pod.cabin_air.temperature > cold_temperature && pod.cabin_air.temperature <= T20C, "The cabin regulator did not warm cold cabin air toward its target.")
	TEST_ASSERT(pod.cabin_air.temperature > vacuum_origin.return_temperature(), "The cabin temperature followed exterior vacuum instead of its internal regulator.")

/// A real mining volley must drill a real ore wall through native projectile processing.
/datum/unit_test/spacepod_vacuum/mining/Run()
	TEST_ASSERT_NOTNULL(vacuum_block, "Could not reserve a vacuum enclosure for pod mining.")
	var/obj/vehicle/sealed/spacepod/civilian/pod = allocate(__IMPLIED_TYPE__, vacuum_origin)
	pod.enter_delay = 0
	var/mob/living/carbon/human/consistent/pilot = allocate(__IMPLIED_TYPE__, get_step(vacuum_origin, SOUTH))
	TEST_ASSERT(pod.mob_try_enter(pilot), "The mining pilot could not board a real pod in space.")
	pod.setDir(EAST)
	var/obj/item/spacepod_equipment/weaponry/mining_laser_basic/weapon = allocate(__IMPLIED_TYPE__, pod)
	TEST_ASSERT(pod.add_equipment(null, weapon, "weapon_system"), "The real mining accelerator could not be installed in the pod.")
	TEST_ASSERT(!pod.has_gravity(), "The mining pod is not in actual zero-gravity space.")
	var/turf/target_space = locate(vacuum_origin.x + 3, vacuum_origin.y, vacuum_origin.z)
	TEST_ASSERT(target_space in vacuum_block.reserved_turfs, "The mining target is outside the private test reservation.")
	var/turf/closed/mineral/iron/target = target_space.ChangeTurf(/turf/closed/mineral/iron)
	var/expected_ore = target.mineral_amt
	var/target_x = target.x
	var/target_y = target.y
	var/target_z = target.z
	var/initial_hull = pod.get_integrity()
	var/initial_pilot_brute = pilot.get_brute_loss()
	var/initial_charge = pod.battery.charge
	TEST_ASSERT(pod.fireWeapon(pilot), "A charged mining accelerator could not fire from its real pilot controls.")
	TEST_ASSERT_EQUAL(pod.battery.charge, initial_charge - weapon.shot_cost * SPACEPOD_ENERGY_UNIT, "A mining volley consumed the wrong amount of real battery power.")
	// Let SSprojectiles move and impact both barrels; do not invoke impact or mining callbacks.
	var/deadline = world.time + 3 SECONDS
	var/projectiles_remaining = TRUE
	while(projectiles_remaining && world.time < deadline)
		projectiles_remaining = FALSE
		for(var/turf/tile as anything in vacuum_block.reserved_turfs)
			for(var/obj/projectile/projectile in tile)
				if(projectile.firer == pod && !QDELETED(projectile))
					projectiles_remaining = TRUE
		if(projectiles_remaining)
			sleep(0.1 SECONDS)
	TEST_ASSERT(!projectiles_remaining, "The real mining volley did not finish processing within three seconds.")
	var/turf/mined_turf = locate(target_x, target_y, target_z)
	TEST_ASSERT(!ismineralturf(mined_turf) && isopenturf(mined_turf), "Real mining projectiles failed to drill the iron-bearing mineral wall.")
	var/obj/item/stack/ore/iron/ore = locate() in mined_turf
	TEST_ASSERT_NOTNULL(ore, "Drilling the real mineral wall did not produce an iron ore stack.")
	TEST_ASSERT_EQUAL(ore.get_amount(), expected_ore, "The mined ore amount differs from the real mineral wall's yield.")
	TEST_ASSERT_EQUAL(pod.get_integrity(), initial_hull, "The pod's own mining volley damaged its hull.")
	TEST_ASSERT_EQUAL(pilot.get_brute_loss(), initial_pilot_brute, "The pod's own mining volley struck its pilot.")
	TEST_ASSERT_EQUAL(pilot.loc, pod, "Mining ejected the pilot from the cabin.")

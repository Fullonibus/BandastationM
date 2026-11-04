/// Test to make sure the pressure pumping proc used by things like portable pumps, pressure pumps, etc actually work.
/datum/unit_test/atmospheric_gas_transfer

/datum/unit_test/atmospheric_gas_transfer/Run()
	for (var/hot_test in list(1e4, 1e6, 1e8, 1e10, 1e12))
		nob_to_trit(hot_test, hot_test, 50, T20C, max(2500, hot_test/100))
	for (var/cold_test in list(1, 1e-2, MOLAR_ACCURACY))
		nob_to_trit(5000, T20C, cold_test, cold_test)
	nob_to_trit(5000, T20C, 100, T20C, 1)

/**
 * Proc to transfer x moles of x temp nob to x moles of x temp trit.
 *
 * Arguments:
 * * nob_moles: Moles for the nob (origin)
 * * nob_temp: Temp for the nob (origin)
 * * trit_moles: Moles for the trit (target)
 * * nob_temp: Temp for the nob (target)
 * * additional_pressure: Optional proc, if unfilled transfer will be 10% of pressure.
 */
/datum/unit_test/atmospheric_gas_transfer/proc/nob_to_trit(nob_moles, nob_temp, trit_moles, trit_temp, additional_pressure)
	var/datum/gas_mixture/first_mix = allocate(/datum/gas_mixture)
	var/datum/gas_mixture/second_mix = allocate(/datum/gas_mixture)

	first_mix.volume = 200
	second_mix.volume = 200

	first_mix.moles[/datum/gas/hypernoblium] = nob_moles
	first_mix.temperature = nob_temp

	second_mix.moles[/datum/gas/tritium] = trit_moles
	second_mix.temperature = trit_temp

	var/initial_pressure = second_mix.return_pressure()
	// A fixed number would mean transfer is too small for high temps. So we make it scaled.

	if(isnull(additional_pressure))
		additional_pressure = first_mix.return_pressure() / 10

	/* ERROR MARGIN CALCULATION
	 * We calculate how much would the pressure change if MOLAR_ACCURACY amount of hothotgas is imparted on the cold mix.
	 * This number gets really big for very high temperatures so it's somewhat meaningless, but our main goal is to ensure the code doesn't break.
	 */
	var/error_margin = first_mix.gas_pressure_minimum_transfer(second_mix) - initial_pressure

	first_mix.pump_gas_to(second_mix, (initial_pressure + additional_pressure))
	var/margin = abs(second_mix.return_pressure() - (initial_pressure+additional_pressure))

	TEST_ASSERT(margin <= error_margin, "Failed to pump [nob_moles] moles of [nob_temp] K Nob to [trit_moles] moles of [trit_temp] K Trit, . Expected pressure = [initial_pressure+additional_pressure] +/- [error_margin]. Got [second_mix.return_pressure()].")

/// Deferred venting to already processed space must rebuild a missing excited group only when gas moves.
/datum/unit_test/deferred_space_gas_transfer
	/// Closed boundaries keep the real gas simulation isolated from other tests and reservations.
	var/datum/turf_reservation/atmos_block

/datum/unit_test/deferred_space_gas_transfer/Destroy()
	if(atmos_block)
		for(var/turf/open/fixture_turf in atmos_block.reserved_turfs)
			SSair.remove_from_active(fixture_turf)
			SSair.high_pressure_delta -= fixture_turf
			SSair.active_super_conductivity -= fixture_turf
		QDEL_NULL(atmos_block)
	return ..()

/datum/unit_test/deferred_space_gas_transfer/Run()
	atmos_block = SSmapping.request_turf_block_reservation(4, 3, 1, turf_type_override = /turf/closed/indestructible)
	TEST_ASSERT_NOTNULL(atmos_block, "Could not reserve an isolated atmos enclosure.")
	var/turf/bottom_left = atmos_block.bottom_left_turfs[1]
	var/turf/open/floor/plating/airless/donor = locate(bottom_left.x + 1, bottom_left.y + 1, bottom_left.z)
	donor = donor.ChangeTurf(/turf/open/floor/plating/airless)
	var/turf/open/space/space_tile = get_step(donor, EAST)
	space_tile = space_tile.ChangeTurf(/turf/open/space)
	donor.immediate_calculate_adjacent_turfs()
	TEST_ASSERT_EQUAL(length(donor.atmos_adjacent_turfs), 1, "The donor must have only its space neighbor available for gas sharing.")
	TEST_ASSERT(space_tile in donor.atmos_adjacent_turfs, "The donor must be connected to real space.")

	var/fire_count = SSair.times_fired
	space_tile.current_cycle = fire_count
	donor.process_cell(fire_count)
	TEST_ASSERT_NULL(donor.excited_group, "Sharing vacuum with vacuum must not create an excited group.")

	var/datum/gas_mixture/injected_air = allocate(/datum/gas_mixture)
	injected_air.moles[/datum/gas/oxygen] = MOLES_CELLSTANDARD
	injected_air.temperature = T20C
	donor.assume_air(injected_air)
	donor.significant_share_ticker = EXCITED_GROUP_DISMANTLE_CYCLES
	donor.process_cell(fire_count)

	TEST_ASSERT_EQUAL(donor.air.total_moles(), 0, "Deferred sharing must vent all donor gas into space even when space already processed this cycle.")
	TEST_ASSERT_NOTNULL(donor.excited_group, "Significant deferred gas sharing must restore the donor's excited group.")
	TEST_ASSERT_EQUAL(space_tile.excited_group, donor.excited_group, "The donor and its space sink must belong to the same excited group.")
	TEST_ASSERT_EQUAL(donor.significant_share_ticker, 0, "Significant deferred gas sharing must reset the donor's share ticker.")

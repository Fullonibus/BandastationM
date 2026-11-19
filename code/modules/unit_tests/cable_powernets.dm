/// Connectivity failures captured after map setup and before gameplay can change the power grid.
/proc/get_powernet_test_failures()
	var/list/failures = list()
	for(var/datum/powernet/network as anything in SSmachines.powernets)
		// Nodes are machines, including APCs and SMES units.
		if(!length(network.nodes))
			if(!length(network.cables))
				failures += "[network] found with no nodes or cables connected."
				continue

			var/obj/structure/cable/cable = network.cables[1]
			var/area/cable_area = get_area(cable)
			if((cable_area.type in GLOB.the_station_areas) && cable_area.requires_power)
				failures += "[network] found with no nodes connected ([cable.x], [cable.y], [cable.z])."
			continue

		if(!length(network.cables))
			var/obj/machinery/power/machine = network.nodes[1]
			var/area/machine_area = get_area(machine)
			if((machine_area.type in GLOB.the_station_areas) && machine_area.requires_power)
				failures += "[network] found with no cables connected ([machine.x], [machine.y], [machine.z])."
			continue

		// An SMES terminal can supply a network that starts with no generation (e.g. solars).
		if(!network.avail && !(locate(/obj/machinery/power/terminal) in network.nodes))
			var/obj/structure/cable/cable = network.cables[1]
			var/area/cable_area = get_area(cable)
			if((cable_area.type in GLOB.the_station_areas) && cable_area.requires_power)
				failures += "[network] found with no power roundstart, connected to a cable at ([cable.x], [cable.y], [cable.z])."

	return failures

GLOBAL_LIST(roundstart_powernet_test_failures)

/// Record diagnostics before the gameplay runlevel starts and mice can chew through exposed cables.
/proc/capture_roundstart_powernet_test_failures()
	GLOB.roundstart_powernet_test_failures = get_powernet_test_failures()

/// Check that the mapped power networks are properly connected and powered at roundstart.
/datum/unit_test/cable_powernets
	test_flags = UNIT_TEST_MAP_TEST

/datum/unit_test/cable_powernets/Run()
	TEST_ASSERT_NOTNULL(GLOB.roundstart_powernet_test_failures, "Power networks were not checked at roundstart.")
	for(var/failure as anything in GLOB.roundstart_powernet_test_failures)
		TEST_FAIL(failure)

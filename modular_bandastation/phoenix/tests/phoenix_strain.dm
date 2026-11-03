/** Environmental limits preserve the distinction between survival and reproduction. */
/datum/unit_test/phoenix_strain_classification/Run()
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	var/list/result = strain.classify(295, 100, 20, 0.1, 0, 4, "grass")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_BREEDING, "The dim lineage must have an attainable breeding environment.")
	for(var/pressure_kpa in list(85, 90, 110, 115))
		result = strain.classify(295, pressure_kpa, 20, 0.1, 0, 4, "grass")
		TEST_ASSERT_EQUAL(result["state"], PHOENIX_BREEDING, "Both pressure boundaries and a ten-kPa deviation from the midpoint must support breeding.")
	for(var/pressure_kpa in list(60, 150))
		result = strain.classify(295, pressure_kpa, 20, 0.1, 0, 4, "grass")
		TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "The outer safe pressure boundaries must remain survivable.")
	for(var/pressure_kpa in list(59.9, 150.1))
		result = strain.classify(295, pressure_kpa, 20, 0.1, 0, 4, "grass")
		TEST_ASSERT_EQUAL(result["state"], PHOENIX_DANGER, "Only pressure beyond the safe boundaries must become dangerous.")
	result = strain.classify(310, 100, 20, 0.1, 0, 4, "grass")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "Safe warmth outside the breeding window must not injure a specimen.")
	result = strain.classify(330, 100, 20, 0.1, 0, 4, "grass")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_DANGER, "Unsafe temperature must take precedence over reproduction.")
	result = strain.classify(295, 100, 5, 0.1, 0, 4, "grass")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_DANGER, "Partial oxygen pressure must be checked independently of total pressure.")
	result = strain.classify(295, 100, 20, 0.1, 1, 4, "grass")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "Light limits must suppress reproduction without causing atmospheric injury.")
	result = strain.classify(295, 100, 20, 0.1, 0, 2, "grass")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "Crowding must suppress reproduction.")
	result = strain.classify(295, 100, 20, 0.1, 0, 4, "sand")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "An unsuitable substrate must suppress reproduction.")
	var/datum/phoenix_strain/cold_strain = allocate(/datum/phoenix_strain, "cold", FALSE)
	result = cold_strain.classify(267, 90, 18, 0.1, 0.5, 3, "snow")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_BREEDING, "The snow lineage must breed in a genuinely subfreezing environment.")

/** Diagnoses identify the direction and severity without exposing hidden numerical limits. */
/datum/unit_test/phoenix_strain_diagnostics/Run()
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	var/list/cases = list(
		list(list(285, 100, 20, 0.1), PHOENIX_SURVIVAL, "Температура ниже диапазона размножения"),
		list(list(330, 100, 20, 0.1), PHOENIX_DANGER, "Температура выше безопасного диапазона — опасно для жизни"),
		list(list(295, 50, 20, 0.1), PHOENIX_DANGER, "Давление ниже безопасного диапазона — опасно для жизни"),
		list(list(295, 125, 20, 0.1), PHOENIX_SURVIVAL, "Давление выше диапазона размножения"),
		list(list(295, 100, 15, 0.1), PHOENIX_SURVIVAL, "Парциальное давление кислорода ниже диапазона размножения"),
		list(list(295, 100, 36, 0.1), PHOENIX_DANGER, "Парциальное давление кислорода выше безопасного диапазона — опасно для жизни"),
		list(list(295, 100, 20, 1), PHOENIX_SURVIVAL, "Парциальное давление углекислого газа выше диапазона размножения"),
		list(list(295, 100, 20, 4), PHOENIX_DANGER, "Парциальное давление углекислого газа выше безопасного диапазона — опасно для жизни"),
	)
	for(var/list/test_case as anything in cases)
		var/list/readings = test_case[1]
		var/list/result = strain.classify(readings[1], readings[2], readings[3], readings[4], 0, 4, "grass")
		TEST_ASSERT_EQUAL(result["state"], test_case[2], "A directional diagnosis must retain the original survival or danger classification.")
		var/list/causes = result["causes"]
		TEST_ASSERT_EQUAL(causes[1], test_case[3], "The diagnosis must identify the parameter, direction and severity without a trailing period.")
	var/datum/phoenix_strain/cold_strain = allocate(/datum/phoenix_strain, "cold", FALSE)
	var/list/result = cold_strain.classify(267, 90, 18, 0.1, 0.1, 3, "snow")
	var/list/causes = result["causes"]
	TEST_ASSERT_EQUAL(causes[1], "Освещение ниже диапазона размножения", "Insufficient light must be distinguishable from excessive light.")
	result = cold_strain.classify(267, 90, 18, 0.1, 0.9, 2, "sand")
	causes = result["causes"]
	TEST_ASSERT_EQUAL(causes[1], "Освещение выше диапазона размножения", "Excessive light must identify the opposite adjustment.")
	for(var/cause in causes)
		TEST_ASSERT(!findtext(cause, "."), "Lighting, space and substrate diagnoses must not include redundant sentence periods.")

/** Random founding strains retain a physically attainable habitat and an available diet. */
/datum/unit_test/phoenix_strain_generation/Run()
	for(var/profile_id in list("cold", "warm", "dim"))
		for(var/sample in 1 to 8)
			var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, profile_id)
			var/list/all_limits = list(strain.temperature, strain.pressure, strain.oxygen, strain.carbon_dioxide)
			for(var/list/limits as anything in all_limits)
				TEST_ASSERT(limits[1] <= limits[2] && limits[2] < limits[3] && limits[3] <= limits[4], "Generated [profile_id] limits must nest a nonempty breeding window inside the safe window.")
			TEST_ASSERT(strain.light[1] >= 0 && strain.light[1] < strain.light[2] && strain.light[2] <= 1, "Generated lighting must be attainable.")
			TEST_ASSERT(strain.space_per_animal >= 3 && strain.space_per_animal <= 5, "Generated area must fit the intended habitat density.")
			TEST_ASSERT(strain.food_demand >= 0.03 && strain.food_demand <= 0.05, "Founding nutrition demand must remain within the playable range.")
			TEST_ASSERT(strain.allergen in list(FRUIT, GRAIN, MEAT), "The generated allergen must leave ordinary vegetables available as food.")
			if(profile_id == "cold")
				TEST_ASSERT(strain.temperature[3] < T0C, "The snow lineage's entire breeding window must stay below freezing.")
			var/temperature_kelvin = (strain.temperature[2] + strain.temperature[3]) / 2
			var/pressure_kpa = (strain.pressure[2] + strain.pressure[3]) / 2
			var/oxygen_kpa = (strain.oxygen[2] + strain.oxygen[3]) / 2
			var/carbon_dioxide_kpa = (strain.carbon_dioxide[2] + strain.carbon_dioxide[3]) / 2
			TEST_ASSERT(oxygen_kpa + carbon_dioxide_kpa < pressure_kpa, "A generated gas mixture must leave nonnegative nitrogen pressure.")
			var/list/environment = strain.classify(temperature_kelvin, pressure_kpa, oxygen_kpa, carbon_dioxide_kpa, (strain.light[1] + strain.light[2]) / 2, 5, strain.substrate_id)
			TEST_ASSERT_EQUAL(environment["state"], PHOENIX_BREEDING, "Generated [profile_id] requirements must admit a shared breeding environment.")

/** An adapted offspring must not mutate its parent or regain spent adaptations. */
/datum/unit_test/phoenix_strain_inheritance/Run()
	var/datum/phoenix_strain/parent_strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	TEST_ASSERT(!parent_strain.adapt("invalid"), "Unknown adaptations must be rejected.")
	TEST_ASSERT_EQUAL(parent_strain.adaptations, 0, "A rejected adaptation must not consume the lineage allowance.")
	TEST_ASSERT(parent_strain.adapt("yield"), "The first yield adaptation must succeed.")
	var/datum/phoenix_strain/child_strain = parent_strain.copy()
	allocated += child_strain
	TEST_ASSERT_EQUAL(child_strain.adaptations, 1, "An offspring must inherit spent adaptations.")
	TEST_ASSERT_EQUAL(child_strain.productivity, parent_strain.productivity, "An offspring must inherit the adapted yield.")
	var/list/parent_limits = list(parent_strain.temperature, parent_strain.pressure, parent_strain.oxygen, parent_strain.carbon_dioxide, parent_strain.light)
	var/list/child_limits = list(child_strain.temperature, child_strain.pressure, child_strain.oxygen, child_strain.carbon_dioxide, child_strain.light)
	for(var/limit_index in 1 to length(parent_limits))
		var/list/source_limits = parent_limits[limit_index]
		var/list/inherited_limits = child_limits[limit_index]
		for(var/value_index in 1 to length(source_limits))
			TEST_ASSERT_EQUAL(inherited_limits[value_index], source_limits[value_index], "Inheritance must copy exact limits without generating another phenotype.")
	TEST_ASSERT_EQUAL(child_strain.allergen, parent_strain.allergen, "Inheritance must preserve the chosen allergen.")
	TEST_ASSERT_EQUAL(child_strain.space_per_animal, parent_strain.space_per_animal, "Inheritance must preserve crowding requirements.")
	TEST_ASSERT_EQUAL(child_strain.food_demand, parent_strain.food_demand, "Inheritance must preserve metabolic demand.")
	child_strain.temperature[1] -= 1
	child_strain.pressure[1] -= 1
	child_strain.oxygen[1] -= 1
	child_strain.carbon_dioxide[4] += 1
	child_strain.light[2] += 0.1
	TEST_ASSERT_NOTEQUAL(child_strain.temperature[1], parent_strain.temperature[1], "Temperature limits must not alias their parent.")
	TEST_ASSERT_NOTEQUAL(child_strain.pressure[1], parent_strain.pressure[1], "Pressure limits must not alias their parent.")
	TEST_ASSERT_NOTEQUAL(child_strain.oxygen[1], parent_strain.oxygen[1], "Oxygen limits must not alias their parent.")
	TEST_ASSERT_NOTEQUAL(child_strain.carbon_dioxide[4], parent_strain.carbon_dioxide[4], "Carbon dioxide limits must not alias their parent.")
	TEST_ASSERT_NOTEQUAL(child_strain.light[2], parent_strain.light[2], "Light limits must not alias their parent.")
	TEST_ASSERT(child_strain.adapt("yield"), "The inherited remaining adaptation must be usable.")
	TEST_ASSERT_EQUAL(child_strain.productivity, 1.5, "Yield must remain capped at 1.5 times base.")
	TEST_ASSERT(!child_strain.adapt("allergy"), "A lineage must not accept a third adaptation.")
	TEST_ASSERT_EQUAL(parent_strain.adaptations, 1, "Adapting an offspring must not spend its parent's allowance.")
	TEST_ASSERT(child_strain.food_demand > parent_strain.food_demand, "Increased yield must have a nutritional cost.")

/** Native atmospheric mixtures must reach observations and scanner diagnoses without losing gas identities. */
/datum/unit_test/phoenix_atmosphere_readings/Run()
	var/turf/open/location = run_loc_floor_bottom_left
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	var/mob/living/basic/phoenix_weaver/specimen = allocate(/mob/living/basic/phoenix_weaver, location, strain, "gas-reading-test")
	var/datum/gas_mixture/native_air = SSair.parse_gas_string("o2=20;n2=79.9;co2=0.1;TEMP=295", /datum/gas_mixture/turf)
	allocated += native_air
	location.copy_air(native_air)
	var/list/environment = specimen.assess_environment()
	var/pressure = location.return_air().return_pressure()
	TEST_ASSERT(abs(environment["oxygen"] - pressure * 0.2) < 0.001, "The observed O2 pressure must equal the native mixture's 20-percent share of total pressure.")
	TEST_ASSERT(abs(environment["carbon_dioxide"] - pressure * 0.001) < 0.001, "The observed CO2 pressure must preserve the native mixture's nonzero trace gas.")
	var/datum/gas_mixture/oxygen_rich_air = SSair.parse_gas_string("o2=50;n2=49.9;co2=0.1;TEMP=295", /datum/gas_mixture/turf)
	allocated += oxygen_rich_air
	location.copy_air(oxygen_rich_air)
	var/list/scan_report = list()
	SEND_SIGNAL(specimen, COMSIG_LIVING_HEALTHSCAN, scan_report, TRUE, null, SCANNER_VERBOSE, FALSE)
	environment = specimen.last_environment
	TEST_ASSERT(abs(environment["oxygen"] - pressure * 0.5) < 0.001, "A new scan must measure the changed native atmosphere instead of retaining a zero or cached O2 reading.")
	TEST_ASSERT(findtext(jointext(scan_report, " "), "Парциальное давление кислорода выше безопасного диапазона"), "The scanner must diagnose excess oxygen in the 50-percent mixture.")
	var/scanner_text = jointext(scan_report, " ")
	for(var/environment_label in list("Температура:", "давление:", "O₂:", "CO₂:", "свет:", "Площадь на особь:", "субстрат:"))
		TEST_ASSERT(!findtext(scanner_text, environment_label), "The health scanner must report symptoms without surveying environmental values ([environment_label]).")
	TEST_ASSERT(findtext(scanner_text, "запас питания"), "Removing environmental readings must preserve the specimen's biological status.")
	var/datum/gas_mixture/carbon_rich_air = SSair.parse_gas_string("o2=20;n2=70;co2=10;TEMP=295", /datum/gas_mixture/turf)
	allocated += carbon_rich_air
	location.copy_air(carbon_rich_air)
	environment = specimen.assess_environment()
	TEST_ASSERT(abs(environment["carbon_dioxide"] - pressure * 0.1) < 0.001, "Native CO2 enrichment must reach the observed partial pressure.")
	TEST_ASSERT("Парциальное давление углекислого газа выше безопасного диапазона — опасно для жизни" in environment["causes"], "Native CO2 enrichment must be diagnosed as dangerous excess.")
	var/datum/gas_mixture/oxygen_free_air = SSair.parse_gas_string("n2=100;TEMP=295", /datum/gas_mixture/turf)
	allocated += oxygen_free_air
	location.copy_air(oxygen_free_air)
	environment = specimen.assess_environment()
	TEST_ASSERT_EQUAL(environment["oxygen"], 0, "A missing oxygen entry must produce a genuine zero reading.")
	TEST_ASSERT_EQUAL(environment["carbon_dioxide"], 0, "A missing carbon dioxide entry must remain zero.")
	TEST_ASSERT("Парциальное давление кислорода ниже безопасного диапазона — опасно для жизни" in environment["causes"], "A genuinely oxygen-free atmosphere must retain the low-oxygen diagnosis.")

/** Real airtight boundaries, substrate and occupancy determine usable area. */
/datum/unit_test/phoenix_habitat/Run()
	var/turf/open/origin = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/list/room = block(origin, locate(origin.x + 1, origin.y + 1, origin.z))
	var/list/border = block(locate(origin.x - 1, origin.y - 1, origin.z), locate(origin.x + 2, origin.y + 2, origin.z)) - room
	for(var/turf/border_turf as anything in border)
		allocate(/obj/structure/window/reinforced/fulltile, border_turf)
	var/datum/gas_mixture/native_air = SSair.parse_gas_string("o2=20;n2=80;TEMP=295", /datum/gas_mixture/turf)
	allocated += native_air
	for(var/turf/open/room_turf as anything in room)
		room_turf.immediate_calculate_adjacent_turfs()
		room_turf.copy_air(native_air)
		allocate(/obj/structure/phoenix_substrate/grass, room_turf)
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	// Lighting is orthogonal to this geometry scenario and tested by classification above.
	strain.light = list(0, 1)
	var/mob/living/basic/phoenix_weaver/first = allocate(/mob/living/basic/phoenix_weaver, origin, strain, "habitat-test")
	var/list/result = strain.assess_environment(first)
	TEST_ASSERT_EQUAL(result["space"], 4, "The airtight room must provide four substrate tiles for one specimen.")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_BREEDING, "The real room must support breeding.")
	var/mob/living/basic/phoenix_weaver/second = allocate(/mob/living/basic/phoenix_weaver, origin, strain, "habitat-test")
	result = strain.assess_environment(first)
	TEST_ASSERT_EQUAL(result["space"], 2, "A second living specimen must share the room's area.")
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "The crowded room must stop supporting breeding.")
	var/obj/structure/closet/crate/container = allocate(/obj/structure/closet/crate, origin)
	second.forceMove(container)
	result = strain.assess_environment(first)
	TEST_ASSERT_EQUAL(result["space"], 4, "Contained animals must not occupy habitat turfs.")
	result = strain.assess_environment(second)
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_SURVIVAL, "A generic container must not count as a breeding habitat.")
	origin.air.moles.Cut()
	result = strain.assess_environment(second)
	TEST_ASSERT_EQUAL(result["state"], PHOENIX_DANGER, "A generic container must not grant immunity to the turf atmosphere.")

/** Placement consumes held material once and validates physical reach on the server. */
/datum/unit_test/phoenix_bedding/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/stack/phoenix_bedding/grass/bedding = allocate(/obj/item/stack/phoenix_bedding/grass, null, 2)
	user.put_in_hands(bedding)
	var/turf/adjacent = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/distant = get_step(adjacent, EAST)
	bedding.interact_with_atom(distant, user)
	TEST_ASSERT_EQUAL(bedding.get_amount(), 2, "Distant placement must not consume bedding.")
	bedding.interact_with_atom(adjacent, user)
	var/obj/structure/phoenix_substrate/placed = locate() in adjacent
	TEST_ASSERT_NOTNULL(placed, "Held bedding did not place a physical substrate.")
	TEST_ASSERT_EQUAL(placed.substrate_id, "grass", "Placed substrate lost its ecological type.")
	TEST_ASSERT_EQUAL(bedding.get_amount(), 1, "Placement must consume exactly one unit.")
	bedding.interact_with_atom(adjacent, user)
	TEST_ASSERT_EQUAL(bedding.get_amount(), 1, "Duplicate placement must not consume another unit.")
	user.dropItemToGround(bedding)
	bedding.interact_with_atom(run_loc_floor_bottom_left, user)
	TEST_ASSERT_EQUAL(bedding.get_amount(), 1, "A dropped pack must not be usable remotely.")

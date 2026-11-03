/** Owned ecological requirements; eggs and specimens inherit independent copies. */
/datum/phoenix_strain
	/// Correlated founding phenotype, retained after directed adaptations.
	var/profile_id
	/// Four limits: safe minimum, breeding minimum, breeding maximum, safe maximum.
	var/list/temperature
	/// Total pressure limits in kPa, in the same order as temperature.
	var/list/pressure
	/// Oxygen partial pressure limits in kPa.
	var/list/oxygen
	/// Carbon dioxide partial pressure limits in kPa.
	var/list/carbon_dioxide
	/// Minimum and maximum reproductive illumination, using get_lumcount's scale.
	var/list/light
	/// Required physical bedding or natural ground.
	var/substrate_id
	/// Suitable substrate tiles required per living animal.
	var/space_per_animal
	/// Nutrition consumed per second of active biology.
	var/food_demand = 0.04
	/// One foodtypes flag; zero after allergy adaptation.
	var/allergen
	/// Fiber yield multiplier.
	var/productivity = 1
	/// Adaptations already spent by this lineage, inherited by descendants.
	var/adaptations = 0

/** Generate a correlated founding phenotype; inheritance skips randomization before copying exact values. */
/datum/phoenix_strain/New(profile_id, randomize = TRUE)
	. = ..()
	src.profile_id = profile_id || (randomize ? pick("cold", "warm", "dim") : "dim")
	switch(src.profile_id)
		if("cold")
			temperature = list(250, 263, 270, 295)
			pressure = list(55, 75, 100, 145)
			oxygen = list(8, 14, 22, 32)
			carbon_dioxide = list(0, 0, 0.5, 3)
			light = list(0.2, 0.8)
			substrate_id = "snow"
			space_per_animal = 3
			allergen = FRUIT
		if("warm")
			temperature = list(280, 303, 313, 330)
			pressure = list(65, 100, 130, 165)
			oxygen = list(12, 21, 30, 40)
			carbon_dioxide = list(0, 0, 0.8, 4)
			light = list(0.4, 1)
			substrate_id = "sand"
			space_per_animal = 5
			allergen = GRAIN
		else
			src.profile_id = "dim"
			temperature = list(273, 290, 300, 323)
			pressure = list(60, 85, 115, 150)
			oxygen = list(10, 17, 25, 35)
			carbon_dioxide = list(0, 0, 0.5, 3)
			light = list(0, 0.35)
			substrate_id = "grass"
			space_per_animal = 4
			allergen = MEAT
	if(!randomize)
		return
	var/temperature_shift = rand(-2, 2)
	var/pressure_factor = rand(90, 110) / 100
	// Warmer variants need proportionally more oxygen and food, while pressure scales every gas window.
	var/metabolic_factor = 1 + temperature_shift * 0.02
	for(var/index in 1 to 4)
		temperature[index] += temperature_shift
		pressure[index] *= pressure_factor
		oxygen[index] *= pressure_factor * metabolic_factor
		carbon_dioxide[index] *= pressure_factor * metabolic_factor
	var/light_shift = rand(-5, 5) / 100
	light[1] = clamp(light[1] + light_shift, 0, 1)
	light[2] = clamp(light[2] + light_shift, 0, 1)
	space_per_animal = clamp(space_per_animal + rand(-1, 1), 3, 5)
	food_demand *= metabolic_factor * rand(90, 110) / 100
	allergen = pick(FRUIT, GRAIN, MEAT)

/datum/phoenix_strain/Destroy()
	temperature = null
	pressure = null
	oxygen = null
	carbon_dioxide = null
	light = null
	return ..()

/** Inherit the current phenotype, including spent adaptations, without shared lists. */
/datum/phoenix_strain/proc/copy()
	var/datum/phoenix_strain/offspring = new(profile_id, FALSE)
	offspring.temperature = temperature.Copy()
	offspring.pressure = pressure.Copy()
	offspring.oxygen = oxygen.Copy()
	offspring.carbon_dioxide = carbon_dioxide.Copy()
	offspring.light = light.Copy()
	offspring.substrate_id = substrate_id
	offspring.space_per_animal = space_per_animal
	offspring.food_demand = food_demand
	offspring.allergen = allergen
	offspring.productivity = productivity
	offspring.adaptations = adaptations
	return offspring

/** Spend one inherited adaptation; breathing specialization and substrate stay fixed. */
/datum/phoenix_strain/proc/adapt(id)
	if(adaptations >= PHOENIX_MAX_ADAPTATIONS)
		return FALSE
	switch(id)
		if("temperature")
			var/shift = clamp(T20C - (temperature[2] + temperature[3]) / 2, -3, 3)
			if(!shift)
				return FALSE
			for(var/index in 1 to 4)
				temperature[index] += shift
		if("pressure")
			var/shift = clamp(ONE_ATMOSPHERE - (pressure[2] + pressure[3]) / 2, -10, 10)
			if(!shift)
				return FALSE
			for(var/index in 1 to 4)
				pressure[index] += shift
		if("light")
			if(light[1] <= 0 && light[2] >= 1)
				return FALSE
			light[1] = max(0, light[1] - 0.15)
			light[2] = min(1, light[2] + 0.15)
		if("allergy")
			if(!allergen)
				return FALSE
			allergen = NONE
		if("yield")
			if(productivity >= 1.5)
				return FALSE
			productivity = min(1.5, productivity + 0.25)
			food_demand *= 1.25
		else
			return FALSE
	adaptations++
	return TRUE

/** Classify real readings; only unsafe temperature or atmosphere causes injury. */
/datum/phoenix_strain/proc/classify(temperature_kelvin, pressure_kpa, oxygen_kpa, carbon_dioxide_kpa, illumination, available_space, observed_substrate)
	var/state = PHOENIX_BREEDING
	var/list/causes = list()
	var/list/readings = list(temperature_kelvin, pressure_kpa, oxygen_kpa, carbon_dioxide_kpa)
	var/list/limits = list(temperature, pressure, oxygen, carbon_dioxide)
	var/list/labels = list("Температура", "Давление", "Парциальное давление кислорода", "Парциальное давление углекислого газа")
	for(var/index in 1 to 4)
		var/value = readings[index]
		var/list/range_limits = limits[index]
		if(value < range_limits[1] || value > range_limits[4])
			state = PHOENIX_DANGER
			causes += "[labels[index]] [value < range_limits[1] ? "ниже" : "выше"] безопасного диапазона — опасно для жизни"
		else if(value < range_limits[2] || value > range_limits[3])
			state = min(state, PHOENIX_SURVIVAL)
			causes += "[labels[index]] [value < range_limits[2] ? "ниже" : "выше"] диапазона размножения"
	if(illumination < light[1] || illumination > light[2])
		state = min(state, PHOENIX_SURVIVAL)
		causes += "Освещение [illumination < light[1] ? "ниже" : "выше"] диапазона размножения"
	if(available_space < space_per_animal)
		state = min(state, PHOENIX_SURVIVAL)
		causes += "Недостаточно пригодной площади на особь"
	if(observed_substrate != substrate_id)
		state = min(state, PHOENIX_SURVIVAL)
		causes += "Неподходящий субстрат"
	return list("state" = state, "causes" = causes)

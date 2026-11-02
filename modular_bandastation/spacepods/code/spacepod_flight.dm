#define SPACEPOD_FLIGHT_MAX_SPEED (1 / 0.15)
#define SPACEPOD_FLIGHT_GRAVITY_MAX_SPEED (1 / 0.4)
#define SPACEPOD_FLIGHT_ANGULAR_SPEED 360
#define SPACEPOD_FLIGHT_EPSILON 0.001
#define SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED 3
#define SPACEPOD_FLIGHT_IMPACT_DAMAGE 1
#define SPACEPOD_FLIGHT_BREACH_SPEED 5
#define SPACEPOD_FLIGHT_REINFORCED_WALL_DAMAGE 0.5

/**
 * Pixel flight with relative thrusters, adapted from the Yogstation/Paradise spacepod physics.
 * Native Move owns collision and sector transitions; this datum owns velocity and visual offsets.
 */
/datum/spacepod_flight
	/// The vehicle owns and deletes its flight controller.
	var/obj/vehicle/sealed/spacepod/pod
	/// World-space velocity in tiles per second.
	var/velocity_x = 0
	/// World-space velocity in tiles per second.
	var/velocity_y = 0
	/// Sub-tile displacement relative to the checked native origin.
	var/offset_x = 0
	/// Sub-tile displacement relative to the checked native origin.
	var/offset_y = 0
	/// Clockwise degrees, with north at zero.
	var/heading = 0
	/// Last requested mouse heading; null means no target.
	var/desired_heading
	/// Clockwise degrees per second.
	var/angular_velocity = 0
	/// Braking uses the same finite thrusters as manual input.
	var/brakes = FALSE
	/// Doubles linear thruster output and the speed limit; energy follows actual thrust.
	var/turbo = FALSE
	/// Relative thrust requested for the next physics tick only.
	var/input_direction = NONE
	/// Per-occupant camera contribution, without retaining clients.
	var/list/camera_offsets = list()
	/// A real obstacle was hit during the last native hull step.
	var/last_step_bumped = FALSE
	/// Only retained until the checked Move returns, including directional window exits.
	var/atom/last_step_obstacle

/datum/spacepod_flight/New(obj/vehicle/sealed/spacepod/owner)
	..()
	pod = owner
	heading = dir2angle(owner.dir)
	RegisterSignal(owner, COMSIG_MOVABLE_BUMP, PROC_REF(on_bump))

/datum/spacepod_flight/Destroy()
	STOP_PROCESSING(SSnewtonian_movement, src)
	UnregisterSignal(pod, COMSIG_MOVABLE_BUMP)
	last_step_obstacle = null
	release_camera()
	pod = null
	return ..()

/// Queue one relative thruster input; held movement keys repeat it through the native key loop.
/datum/spacepod_flight/proc/set_input(direction)
	input_direction = NONE
	if(!isnum(direction))
		return FALSE
	direction &= NORTH|SOUTH|EAST|WEST
	if((direction & (NORTH|SOUTH)) == (NORTH|SOUTH))
		direction &= ~(NORTH|SOUTH)
	if((direction & (EAST|WEST)) == (EAST|WEST))
		direction &= ~(EAST|WEST)
	if(!direction)
		return TRUE
	if(!can_thrust())
		return FALSE
	input_direction = direction
	START_PROCESSING(SSnewtonian_movement, src)
	return TRUE

/// Turn toward a mouse heading; null clears the target without starting processing.
/datum/spacepod_flight/proc/aim(angle)
	if(isnull(angle))
		desired_heading = null
		return TRUE
	if(!isnum(angle) || !can_thrust())
		return FALSE
	desired_heading = WRAP(angle, 0, 360)
	START_PROCESSING(SSnewtonian_movement, src)
	return TRUE

/// Toggle powered counter-thrust; changing the setting itself needs no energy.
/datum/spacepod_flight/proc/toggle_brakes()
	if(QDELETED(pod) || !pod.can_control(pod.pilot))
		return FALSE
	brakes = !brakes
	START_PROCESSING(SSnewtonian_movement, src)
	return TRUE

/// Switching the thruster setting preserves existing momentum and needs no energy itself.
/datum/spacepod_flight/proc/toggle_turbo()
	if(QDELETED(pod) || !pod.can_control(pod.pilot))
		return FALSE
	turbo = !turbo
	return TRUE

/// Stop motion after an external relocation, restoring ordinary movement rendering.
/datum/spacepod_flight/proc/reset_motion()
	STOP_PROCESSING(SSnewtonian_movement, src)
	velocity_x = 0
	velocity_y = 0
	offset_x = 0
	offset_y = 0
	angular_velocity = 0
	desired_heading = null
	input_direction = NONE
	release_camera()
	if(QDELETED(pod))
		return
	heading = dir2angle(pod.dir)
	animate(pod, pixel_x = pod.base_pixel_x, pixel_y = pod.base_pixel_y, transform = matrix(), time = 0, flags = ANIMATION_END_NOW)
	pod.animate_movement = initial(pod.animate_movement)
	pod.set_thruster_flame(FALSE)
	pod.stop_engine_sound()

/// Attach only an actual cabin listener; the current client is resolved again for each render.
/datum/spacepod_flight/proc/attach_camera(mob/listener)
	if(QDELETED(pod) || QDELETED(listener) || listener.loc != pod || !pod.is_occupant(listener) || listener.client?.eye != pod)
		return FALSE
	if(!camera_offsets[listener])
		var/client/viewer = listener.client
		var/delta_x = offset_x * ICON_SIZE_X
		var/delta_y = offset_y * ICON_SIZE_Y
		camera_offsets[listener] = list(delta_x, delta_y)
		if(delta_x || delta_y)
			animate(viewer, pixel_x = viewer.pixel_x + delta_x, pixel_y = viewer.pixel_y + delta_y, time = 0, flags = ANIMATION_END_NOW)
	return TRUE

/// Remove our own camera delta before an occupant exits, logs out or changes perspective.
/datum/spacepod_flight/proc/release_camera(mob/listener)
	if(!listener)
		for(var/mob/occupant as anything in camera_offsets.Copy())
			release_camera(occupant)
		return
	var/list/offset = camera_offsets[listener]
	if(!offset)
		return
	camera_offsets -= listener
	var/client/viewer = listener.client
	if(viewer)
		animate(viewer, pixel_x = viewer.pixel_x - offset[1], pixel_y = viewer.pixel_y - offset[2], time = 0, flags = ANIMATION_END_NOW)

/// Validate controls at the point of acceleration rather than trusting queued input.
/datum/spacepod_flight/proc/can_thrust()
	return !QDELETED(pod) && isturf(pod.loc) && pod.can_control(pod.pilot) && COOLDOWN_FINISHED(pod, cooldown_emp) && pod.battery?.charge > 0

/// Cell callbacks may delete the vehicle, remove the cell, or invalidate its pilot.
/datum/spacepod_flight/proc/use_power(amount)
	if(!can_thrust())
		return FALSE
	var/obj/item/stock_parts/power_store/cell/cell = pod.battery
	var/mob/living/original_pilot = pod.pilot
	var/atom/previous_location = pod.loc
	if(!cell.use(amount))
		return FALSE
	return !QDELETED(src) && !QDELETED(pod) && pod.loc == previous_location && pod.pilot == original_pilot && pod.battery == cell && !QDELETED(cell) && cell.loc == pod && pod.can_control(original_pilot) && COOLDOWN_FINISHED(pod, cooldown_emp)

/// Record contact without applying damage inside Move or its callbacks.
/datum/spacepod_flight/proc/on_bump(datum/source, atom/obstacle)
	SIGNAL_HANDLER
	if(!QDELETED(src) && !QDELETED(pod) && pod.inertia_moving && obstacle?.density)
		last_step_bumped = TRUE
		last_step_obstacle = obstacle

/// Run a checked cardinal move; null aborts the tick after a callback relocates or deletes the hull.
/datum/spacepod_flight/proc/step_hull(direction, impact_speed, list/rammed_mobs)
	last_step_bumped = FALSE
	if(QDELETED(pod) || !isturf(pod.loc))
		return FALSE
	var/atom/previous_location = pod.loc
	var/breached = FALSE
	while(!QDELETED(pod) && pod.loc == previous_location)
		pod.inertia_moving = TRUE
		. = pod.Move(get_step(pod.loc, direction), direction, 0, FALSE)
		var/atom/obstacle = last_step_obstacle
		last_step_obstacle = null
		if(QDELETED(src) || QDELETED(pod))
			return null
		pod.inertia_moving = FALSE
		if(pod.loc != previous_location)
			last_step_bumped = breached
			return !!.
		if(impact_speed <= SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED || !obstacle?.density)
			return !!.
		if(isliving(obstacle))
			var/mob/living/victim = obstacle
			if(!isturf(victim.loc) || pod.is_occupant(victim) || (victim in rammed_mobs))
				return !!.
			rammed_mobs += victim
			var/turf/victim_turf = victim.loc
			var/atom/attacker = pod.pilot || pod
			victim.visible_message(span_danger("[capitalize(pod.declent_ru(NOMINATIVE))] врезается в [victim.declent_ru(ACCUSATIVE)]!"), span_userdanger("[capitalize(pod.declent_ru(NOMINATIVE))] врезается в вас!"))
			victim.apply_damage((impact_speed ** 2 - SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED ** 2) * SPACEPOD_FLIGHT_IMPACT_DAMAGE, BRUTE, blocked = victim.run_armor_check(null, MELEE), spread_damage = TRUE, attack_direction = direction)
			if(!QDELETED(attacker) && !QDELETED(victim))
				log_combat(attacker, victim, "rammed", QDELETED(pod) ? null : pod, "(impact speed: [round(impact_speed, 0.1)] tiles/s)")
			if(QDELETED(src) || QDELETED(pod))
				return null
			if(pod.loc != previous_location)
				reset_motion()
				return null
			if(!QDELETED(victim) && victim.loc == victim_turf && !pod.is_occupant(victim))
				victim.Knockdown(clamp(impact_speed - SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED, 1, 5) SECONDS)
		else if(obstacle.type == /turf/closed/wall || obstacle.type == /turf/closed/wall/rust || obstacle.type == /turf/closed/wall/heretic_rust)
			var/turf/closed/wall/wall = obstacle
			if(impact_speed >= SPACEPOD_FLIGHT_BREACH_SPEED)
				wall.dismantle_wall(devastated = TRUE)
			else
				wall.AddComponent(/datum/component/torn_wall)
		else if(obstacle.type == /turf/closed/wall/r_wall || obstacle.type == /turf/closed/wall/r_wall/rust || obstacle.type == /turf/closed/wall/r_wall/heretic_rust)
			obstacle.AddComponent(/datum/component/torn_wall, null, SPACEPOD_FLIGHT_REINFORCED_WALL_DAMAGE)
		else if(istype(obstacle, /obj/structure/window))
			var/obj/structure/window/window = obstacle
			var/ordinary_glass = !window.reinf && window.glass_type == /obj/item/stack/sheet/glass
			var/reinforced_glass = window.reinf && window.glass_type == /obj/item/stack/sheet/rglass
			if((window.resistance_flags & INDESTRUCTIBLE) || (!ordinary_glass && !reinforced_glass))
				return !!.
			if(ordinary_glass && impact_speed >= SPACEPOD_FLIGHT_BREACH_SPEED)
				window.deconstruct(FALSE)
			else
				window.take_damage((impact_speed ** 2 - SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED ** 2) * SPACEPOD_FLIGHT_IMPACT_DAMAGE, BRUTE, MELEE)
		else
			return !!.
		if(QDELETED(src) || QDELETED(pod))
			return null
		if(pod.loc != previous_location)
			reset_motion()
			return null
		if(!QDELETED(obstacle) && obstacle.density)
			return FALSE
		// Every retry removes a real blocker; native Move checks the rest of the 2x2 hull again.
		breached = TRUE

/datum/spacepod_flight/process(seconds_per_tick)
	if(QDELETED(pod) || !isturf(pod.loc))
		reset_motion()
		return PROCESS_KILL
	if(seconds_per_tick <= 0)
		return
	pod.animate_movement = NO_STEPS
	var/last_heading = heading
	var/last_offset_x = offset_x
	var/last_offset_y = offset_y
	var/turf/previous_turf = pod.loc
	var/relative_input = input_direction
	var/mob/living/tick_pilot = pod.pilot
	input_direction = NONE
	var/controlled = can_thrust()
	var/angle_difference = controlled && isnum(desired_heading) ? closer_angle_difference(heading, desired_heading) : 0
	var/desired_spin = 0
	if(controlled && isnum(desired_heading))
		desired_spin = clamp(angle_difference / seconds_per_tick, -SPACEPOD_FLIGHT_ANGULAR_SPEED, SPACEPOD_FLIGHT_ANGULAR_SPEED)
	var/spin_adjustment = desired_spin - angular_velocity
	if(controlled && spin_adjustment && use_power(abs(spin_adjustment) * 0.05 * SPACEPOD_ENERGY_UNIT))
		angular_velocity += spin_adjustment
	if(QDELETED(src) || QDELETED(pod))
		return PROCESS_KILL
	if(pod.loc != previous_turf)
		reset_motion()
		return PROCESS_KILL
	controlled = controlled && pod.pilot == tick_pilot && can_thrust()
	if(abs(angular_velocity) < SPACEPOD_FLIGHT_EPSILON)
		angular_velocity = 0
	heading = WRAP(heading + angular_velocity * seconds_per_tick, 0, 360)
	var/forward_x = sin(heading)
	var/forward_y = cos(heading)
	var/forward_thrust = 0
	var/right_thrust = 0
	var/thrust_multiplier = turbo ? 2 : 1
	if(controlled)
		if(brakes)
			forward_thrust = clamp(-(forward_x * velocity_x + forward_y * velocity_y) / seconds_per_tick, -3 * thrust_multiplier, 4 * thrust_multiplier)
			right_thrust = clamp(-(forward_y * velocity_x - forward_x * velocity_y) / seconds_per_tick, -3 * thrust_multiplier, 3 * thrust_multiplier)
		else
			if(relative_input & NORTH)
				forward_thrust += 4 * thrust_multiplier
			if(relative_input & SOUTH)
				forward_thrust -= 3 * thrust_multiplier
			if(relative_input & EAST)
				right_thrust += 3 * thrust_multiplier
			if(relative_input & WEST)
				right_thrust -= 3 * thrust_multiplier
	var/thrust_x = forward_thrust * forward_x + right_thrust * forward_y
	var/thrust_y = forward_thrust * forward_y - right_thrust * forward_x
	var/thrust_magnitude = sqrt(thrust_x ** 2 + thrust_y ** 2)
	var/powered_thrust = thrust_magnitude && use_power(10 * SPACEPOD_ENERGY_UNIT * thrust_magnitude * seconds_per_tick)
	if(QDELETED(src) || QDELETED(pod))
		return PROCESS_KILL
	if(pod.loc != previous_turf)
		reset_motion()
		return PROCESS_KILL
	var/previous_speed = sqrt(velocity_x ** 2 + velocity_y ** 2)
	if(powered_thrust)
		velocity_x += thrust_x * seconds_per_tick
		velocity_y += thrust_y * seconds_per_tick
	var/speed = sqrt(velocity_x ** 2 + velocity_y ** 2)
	var/speed_limit = SPACEPOD_FLIGHT_GRAVITY_MAX_SPEED * thrust_multiplier
	// Gravity limits incoming momentum; lowering turbo in space must not brake a coasting cabin.
	if(!pod.has_gravity())
		speed_limit = max(SPACEPOD_FLIGHT_MAX_SPEED * thrust_multiplier, previous_speed)
	if(speed > speed_limit)
		velocity_x *= speed_limit / speed
		velocity_y *= speed_limit / speed
	if(abs(velocity_x) < SPACEPOD_FLIGHT_EPSILON)
		velocity_x = 0
	if(abs(velocity_y) < SPACEPOD_FLIGHT_EPSILON)
		velocity_y = 0
	offset_x += velocity_x * seconds_per_tick
	offset_y += velocity_y * seconds_per_tick
	var/impact_speed_squared = 0
	var/list/rammed_mobs
	if(abs(velocity_x) > SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED || abs(velocity_y) > SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED)
		rammed_mobs = list()
	// Check the leading cells before drawing the cabin into them, including every tile at high speed.
	while((offset_x * velocity_x > 0) || (offset_y * velocity_y > 0) || (!velocity_x && abs(offset_x) > 0.5) || (!velocity_y && abs(offset_y) > 0.5))
		if(offset_x * velocity_x > 0 || (!velocity_x && abs(offset_x) > 0.5))
			var/step_x = sign(offset_x)
			var/moved_x = step_hull(step_x > 0 ? EAST : WEST, abs(velocity_x), rammed_mobs)
			if(isnull(moved_x))
				return PROCESS_KILL
			if(last_step_bumped)
				impact_speed_squared += velocity_x ** 2
			if(moved_x)
				offset_x -= step_x
				last_offset_x -= step_x
			else
				velocity_x = 0
				offset_x = 0
		if(QDELETED(src) || QDELETED(pod))
			return PROCESS_KILL
		if(offset_y * velocity_y > 0 || (!velocity_y && abs(offset_y) > 0.5))
			var/step_y = sign(offset_y)
			var/moved_y = step_hull(step_y > 0 ? NORTH : SOUTH, abs(velocity_y), rammed_mobs)
			if(isnull(moved_y))
				return PROCESS_KILL
			if(last_step_bumped)
				impact_speed_squared += velocity_y ** 2
			if(moved_y)
				offset_y -= step_y
				last_offset_y -= step_y
			else
				velocity_y = 0
				offset_y = 0
		if(QDELETED(src) || QDELETED(pod))
			return PROCESS_KILL
	// Combine corner contacts once; tangential speed does not contribute to the impact.
	if(impact_speed_squared > SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED ** 2)
		var/atom/impact_location = pod.loc
		var/impact_damage = (impact_speed_squared - SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED ** 2) * SPACEPOD_FLIGHT_IMPACT_DAMAGE
		var/mob/living/impact_pilot = pod.pilot
		if(!QDELETED(impact_pilot) && impact_pilot.loc == pod && pod.is_occupant(impact_pilot))
			impact_pilot.adjust_brute_loss(impact_damage * 0.5)
			if(!QDELETED(src) && !QDELETED(pod) && pod.loc == impact_location && !QDELETED(impact_pilot) && impact_pilot.loc == pod && pod.is_occupant(impact_pilot) && iscarbon(impact_pilot) && impact_speed_squared >= SPACEPOD_FLIGHT_BREACH_SPEED ** 2)
				var/mob/living/carbon/carbon_pilot = impact_pilot
				if(length(carbon_pilot.bodyparts))
					carbon_pilot.cause_wound_of_type_and_severity(WOUND_BLUNT, null, WOUND_SEVERITY_SEVERE, wound_source = "столкновение пода")
		if(QDELETED(src) || QDELETED(pod))
			return PROCESS_KILL
		if(pod.loc != impact_location || pod.melting_down)
			reset_motion()
			return PROCESS_KILL
		pod.take_damage(impact_damage, BRUTE, MELEE)
		if(QDELETED(src) || QDELETED(pod))
			return PROCESS_KILL
		if(pod.loc != impact_location || pod.melting_down)
			reset_motion()
			return PROCESS_KILL
	if(!render(last_heading, last_offset_x, last_offset_y, seconds_per_tick))
		return PROCESS_KILL
	var/moving = velocity_x || velocity_y
	var/visual_movement = abs(offset_x - last_offset_x) > SPACEPOD_FLIGHT_EPSILON || abs(offset_y - last_offset_y) > SPACEPOD_FLIGHT_EPSILON
	if(powered_thrust && visual_movement && can_thrust())
		pod.start_engine_sound(2 * seconds_per_tick SECONDS)
	else
		pod.stop_engine_sound()
	pod.set_thruster_flame(powered_thrust && forward_thrust > 0 && can_thrust())
	if(QDELETED(src) || QDELETED(pod))
		return PROCESS_KILL
	// A final idle tick removes the flame even when the last thrust was blocked.
	if(!moving && !angular_velocity && !pod.thruster_flame_active)
		return PROCESS_KILL

/// Interpolate the hull and each listener from the same previous physical position.
/datum/spacepod_flight/proc/render(last_heading, last_offset_x, last_offset_y, seconds_per_tick)
	var/next_dir = angle2dir_cardinal(heading)
	if(pod.dir != next_dir)
		pod.setDir(next_dir)
	if(QDELETED(src) || QDELETED(pod))
		return FALSE
	var/cardinal_heading = dir2angle(pod.dir)
	pod.animate_movement = NO_STEPS
	pod.transform = matrix().Turn(last_heading - cardinal_heading)
	pod.pixel_x = pod.base_pixel_x + last_offset_x * ICON_SIZE_X
	pod.pixel_y = pod.base_pixel_y + last_offset_y * ICON_SIZE_Y
	animate(pod, transform = matrix().Turn(heading - cardinal_heading), pixel_x = pod.base_pixel_x + offset_x * ICON_SIZE_X, pixel_y = pod.base_pixel_y + offset_y * ICON_SIZE_Y, time = seconds_per_tick SECONDS, easing = LINEAR_EASING, flags = ANIMATION_END_NOW)
	for(var/mob/listener as anything in pod.occupants)
		if(!attach_camera(listener))
			release_camera(listener)
			continue
		var/client/viewer = listener.client
		var/list/last_camera = camera_offsets[listener]
		var/base_x = viewer.pixel_x - last_camera[1]
		var/base_y = viewer.pixel_y - last_camera[2]
		viewer.pixel_x = base_x + last_offset_x * ICON_SIZE_X
		viewer.pixel_y = base_y + last_offset_y * ICON_SIZE_Y
		animate(viewer, pixel_x = base_x + offset_x * ICON_SIZE_X, pixel_y = base_y + offset_y * ICON_SIZE_Y, time = seconds_per_tick SECONDS, easing = LINEAR_EASING, flags = ANIMATION_END_NOW)
		last_camera[1] = offset_x * ICON_SIZE_X
		last_camera[2] = offset_y * ICON_SIZE_Y
	return TRUE

#undef SPACEPOD_FLIGHT_MAX_SPEED
#undef SPACEPOD_FLIGHT_GRAVITY_MAX_SPEED
#undef SPACEPOD_FLIGHT_ANGULAR_SPEED
#undef SPACEPOD_FLIGHT_EPSILON
#undef SPACEPOD_FLIGHT_SAFE_IMPACT_SPEED
#undef SPACEPOD_FLIGHT_IMPACT_DAMAGE
#undef SPACEPOD_FLIGHT_BREACH_SPEED
#undef SPACEPOD_FLIGHT_REINFORCED_WALL_DAMAGE

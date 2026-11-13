/**
 * Time runs faster for its owner: they move and work quicker, blur as they go, and after long exposure
 * their wounds close. Coming back into step leaves them sick and dizzy.
 *
 * Adapted from Shiptest's accelerando without its screen overlays, ageing and fatal variant.
 */
/datum/status_effect/accelerando
	id = "accelerando"
	alert_type = null
	status_type = STATUS_EFFECT_UNIQUE
	tick_interval = 0.5 SECONDS
	/// How hard it hit them, for the comedown.
	var/intensity = 0

/datum/status_effect/accelerando/on_creation(mob/living/new_owner, duration = 10 SECONDS)
	src.duration = duration
	return ..()

/datum/status_effect/accelerando/on_apply()
	owner.add_filter("chronoblur", 1, motion_blur_filter(0, 0))
	owner.add_movespeed_modifier(/datum/movespeed_modifier/accelerando)
	owner.add_actionspeed_modifier(/datum/actionspeed_modifier/accelerando)
	owner.visible_message(span_notice("[owner] выпадает из местного времени!"), span_warning("Вы рассинхронизируетесь со временем, и неспешность мира становится очевидной!"))
	return TRUE

/datum/status_effect/accelerando/tick(seconds_between_ticks)
	// Power in tens of seconds left: half a minute or more beside the anomaly builds it up.
	var/power = duration / (10 SECONDS)
	if(power > 4)
		animate(owner.get_filter("chronoblur"), time = 0.5 SECONDS, x = rand(-2, 2), y = rand(-2, 2))
		intensity = max(intensity, 1)
	if(power > 8)
		intensity = 2
		owner.heal_overall_damage(brute = 1, burn = 1)
		if(SPT_PROB(10, seconds_between_ticks))
			to_chat(owner, span_nicegreen("Плоть срастается, залечивая вчерашние раны!"))

/datum/status_effect/accelerando/on_remove()
	owner.remove_filter("chronoblur")
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/accelerando)
	owner.remove_actionspeed_modifier(/datum/actionspeed_modifier/accelerando)
	owner.visible_message(span_notice("[owner] возвращается в местное время."), span_warning("Тело рывком возвращается в местное время!"))
	if(intensity >= 2)
		owner.adjust_disgust(75)
		owner.adjust_confusion(10 SECONDS)

/datum/movespeed_modifier/accelerando
	multiplicative_slowdown = -0.4

/datum/actionspeed_modifier/accelerando
	multiplicative_slowdown = -0.6

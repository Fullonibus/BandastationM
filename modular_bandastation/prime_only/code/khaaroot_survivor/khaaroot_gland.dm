/** A concealable chest gland owning its overlay, targeting action, and unfinished reveal. */
/datum/action/cooldown/khaaroot_mutation/gland
	name = "Железа разложения"
	desc = "Раскрыть или скрыть пульсирующую железу. Раскрытая железа позволяет плеваться разъедающим ферментом."
	button_icon_state = "gland"
	/// Time required to unfold the organ.
	var/reveal_time = 0.8 SECONDS
	/// The overlay belonging exclusively to this gland.
	var/mutable_appearance/gland_overlay
	/// The gland owns this action across concealment so its cooldown cannot be reset by toggling.
	var/datum/action/cooldown/khaaroot_mutation/gland_spit/spit_action
	/// The temporary visual belonging to the current reveal.
	var/obj/effect/temp_visual/khaaroot_mutation_reveal/reveal_visual
	/// Prevents simultaneous reveals and is invalidated by forced concealment.
	var/revealing = FALSE
	/// Revision captured by an asynchronous reveal.
	var/reveal_revision = 0

/datum/action/cooldown/khaaroot_mutation/gland/Destroy()
	conceal(forced = TRUE)
	QDEL_NULL(spit_action)
	return ..()

/datum/action/cooldown/khaaroot_mutation/gland/Remove(mob/removed_from)
	conceal(forced = TRUE)
	return ..()

/datum/action/cooldown/khaaroot_mutation/gland/is_revealed()
	return !isnull(gland_overlay)

/datum/action/cooldown/khaaroot_mutation/gland/Activate(atom/target)
	if(!IsAvailable(feedback = TRUE))
		return FALSE
	if(is_revealed() || revealing)
		conceal()
		return TRUE
	if(!isturf(owner.loc))
		return FALSE

	var/mob/living/carbon/human/user = owner
	var/revision = ++reveal_revision
	revealing = TRUE
	reveal_visual = new(get_turf(user), "reveal_gland")
	reveal_visual.setDir(user.dir)
	playsound(user, 'sound/mobs/non-humanoids/bileworm/bileworm_spit.ogg', 40, TRUE)
	user.visible_message(span_warning("Кожа на груди [user.declent_ru(GENITIVE)] вздувается и расходится вокруг пульсирующей железы!"))
	var/revealed = do_after(user, reveal_time, user, extra_checks = CALLBACK(src, PROC_REF(can_finish_reveal), user, revision))
	if(QDELETED(src))
		return FALSE
	if(!revealed || !can_finish_reveal(user, revision))
		if(reveal_revision == revision)
			conceal(forced = TRUE)
		return FALSE

	revealing = FALSE
	QDEL_NULL(reveal_visual)
	gland_overlay = mutable_appearance('modular_bandastation/prime_only/icons/khaaroot_mutations.dmi', "gland", -BODY_FRONT_LAYER, appearance_flags = RESET_COLOR | KEEP_APART)
	RegisterSignal(user, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(add_gland_overlay))
	user.update_appearance(UPDATE_OVERLAYS)
	if(!spit_action)
		spit_action = new(get_mutations(), src)
	spit_action.Grant(user)
	build_all_button_icons(UPDATE_BUTTON_STATUS)
	return TRUE

/** Revalidate the exact actor, membership, and current reveal after each asynchronous gap. */
/datum/action/cooldown/khaaroot_mutation/gland/proc/can_finish_reveal(mob/living/carbon/human/user, revision)
	return !QDELETED(src) && revealing && revision == reveal_revision && owner == user && isturf(user.loc) && !action_disabled && get_mutations()?.can_use(user)

/datum/action/cooldown/khaaroot_mutation/gland/conceal(forced = FALSE)
	reveal_revision++
	revealing = FALSE
	QDEL_NULL(reveal_visual)
	spit_action?.cancel_pending_spit()
	if(spit_action?.owner)
		spit_action.Remove(spit_action.owner)
	if(owner && gland_overlay)
		UnregisterSignal(owner, COMSIG_ATOM_UPDATE_OVERLAYS)
		owner.cut_overlay(gland_overlay)
		gland_overlay = null
		owner.update_appearance(UPDATE_OVERLAYS)
	else
		gland_overlay = null
	build_all_button_icons(UPDATE_BUTTON_STATUS)

/// Keep the owned organ visible through normal appearance regeneration without touching other overlays.
/datum/action/cooldown/khaaroot_mutation/gland/proc/add_gland_overlay(atom/source, list/overlays)
	SIGNAL_HANDLER
	if(gland_overlay)
		overlays += gland_overlay

/** Targeted secretion belonging to a revealed gland; it is never granted independently. */
/datum/action/cooldown/khaaroot_mutation/gland_spit
	name = "Ферментный плевок"
	desc = "Выплюнуть вязкий фермент на расстояние до шести тайлов. Он разъедает одежду и обнажённую плоть."
	button_icon_state = "gland_spit"
	cooldown_time = 10 SECONDS
	click_to_activate = TRUE
	/// Weak link to the toggle owning this action.
	var/datum/weakref/gland_ref
	/// Maximum flight distance and targeting range.
	var/spit_range = 6
	/// Strength passed to native acid_act on the actual collision target.
	var/acid_power = 50
	/// Volume passed to native acid_act on the actual collision target.
	var/acid_volume = 20
	/// A single unfinished projectile; concealment or teardown cancels it.
	var/obj/projectile/khaaroot_gland_spit/pending_spit

/datum/action/cooldown/khaaroot_mutation/gland_spit/New(datum/khaaroot_mutations/mutations, datum/action/cooldown/khaaroot_mutation/gland/gland)
	gland_ref = WEAKREF(gland)
	return ..(mutations)

/datum/action/cooldown/khaaroot_mutation/gland_spit/Destroy()
	cancel_pending_spit()
	gland_ref = null
	return ..()

/datum/action/cooldown/khaaroot_mutation/gland_spit/IsAvailable(feedback = FALSE)
	var/datum/action/cooldown/khaaroot_mutation/gland/gland = gland_ref?.resolve()
	return gland?.is_revealed() && gland.owner == owner && !pending_spit && ..()

/datum/action/cooldown/khaaroot_mutation/gland_spit/InterceptClickOn(mob/living/clicker, params, atom/target)
	if(clicker != owner)
		return FALSE
	return ..()

/datum/action/cooldown/khaaroot_mutation/gland_spit/Activate(atom/target)
	if(!IsAvailable(feedback = TRUE) || QDELETED(target) || !isturf(owner.loc))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf.z != owner.z || get_dist(owner, target_turf) > spit_range)
		owner.balloon_alert(owner, "слишком далеко!")
		return FALSE
	var/mob/living/carbon/human/user = owner
	pending_spit = new(user.loc, src)
	RegisterSignal(pending_spit, COMSIG_QDELETING, PROC_REF(on_spit_deleted))
	pending_spit.range = spit_range
	pending_spit.acid_power = acid_power
	pending_spit.acid_volume = acid_volume
	pending_spit.firer = user
	pending_spit.aim_projectile(target, user)
	StartCooldown()
	user.visible_message(span_danger("Железа на груди [user.declent_ru(GENITIVE)] сжимается, выплёвывая сгусток фермента!"))
	playsound(user, 'sound/mobs/non-humanoids/bileworm/bileworm_spit.ogg', 60, TRUE)
	pending_spit.fire()
	return TRUE

/** Confirms that an in-flight shot still belongs to the current revealed mutation and body. */
/datum/action/cooldown/khaaroot_mutation/gland_spit/proc/can_deliver(obj/projectile/khaaroot_gland_spit/projectile)
	var/datum/action/cooldown/khaaroot_mutation/gland/gland = gland_ref?.resolve()
	return pending_spit == projectile && gland?.is_revealed() && gland.owner == owner && projectile.firer == owner && get_mutations()?.can_use(owner)

/** Cancel the owned shot rather than allowing a retracted or removed mutation to deliver a late effect. */
/datum/action/cooldown/khaaroot_mutation/gland_spit/proc/cancel_pending_spit()
	QDEL_NULL(pending_spit)

/// Release the owning action's projectile reference on impact, expiry, or cancellation.
/datum/action/cooldown/khaaroot_mutation/gland_spit/proc/on_spit_deleted(datum/source)
	SIGNAL_HANDLER
	if(pending_spit == source)
		pending_spit = null

/** A visible non-damaging projectile delivering native corrosion at its actual point of impact. */
/obj/projectile/khaaroot_gland_spit
	name = "ферментный сгусток"
	icon = 'modular_bandastation/prime_only/icons/khaaroot_mutations.dmi'
	icon_state = "spit"
	damage = 0
	armor_flag = BIO
	can_hit_turfs = TRUE
	hitsound = 'sound/items/weapons/sear.ogg'
	hitsound_wall = 'sound/items/weapons/sear.ogg'
	impact_effect_type = /obj/effect/temp_visual/impact_effect/khaaroot_gland
	/// Weak link to the secretion action, which owns this projectile.
	var/datum/weakref/spit_action_ref
	/// Native acid power copied from the firing action.
	var/acid_power
	/// Native acid volume copied from the firing action.
	var/acid_volume

/obj/projectile/khaaroot_gland_spit/Initialize(mapload, datum/action/cooldown/khaaroot_mutation/gland_spit/spit_action)
	. = ..()
	spit_action_ref = WEAKREF(spit_action)

/obj/projectile/khaaroot_gland_spit/Destroy()
	spit_action_ref = null
	return ..()

/obj/projectile/khaaroot_gland_spit/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/datum/action/cooldown/khaaroot_mutation/gland_spit/spit_action = spit_action_ref?.resolve()
	if((isliving(target) && blocked >= 100) || pierce_hit || QDELETED(target) || !spit_action?.can_deliver(src))
		return .
	if(isliving(target))
		new /obj/effect/temp_visual/impact_effect/khaaroot_gland(get_turf(target))
	target.acid_act(acid_power, acid_volume)

/** Amber organic splash shared by object and body impacts. */
/obj/effect/temp_visual/impact_effect/khaaroot_gland
	icon = 'modular_bandastation/prime_only/icons/khaaroot_mutations.dmi'
	icon_state = "impact"

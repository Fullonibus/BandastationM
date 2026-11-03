/** Isolates a test project while preserving an already selected round goal. */
/datum/unit_test/phoenix_goal_fixture
	abstract_type = /datum/unit_test/phoenix_goal_fixture
	/// Original round registry, restored by reference after the test project is deleted.
	var/list/original_goals_by_type
	/// Owned pre-existing round goal when the round did not already select Phoenix.
	var/datum/station_goal/phoenix/temporary_round_goal

/datum/unit_test/phoenix_goal_fixture/New()
	. = ..()
	original_goals_by_type = SSstation.goals_by_type
	// Exercise an existing round goal regardless of random station goal selection.
	if(!SSstation.get_station_goal(/datum/station_goal/phoenix))
		temporary_round_goal = new()
	SSstation.goals_by_type = original_goals_by_type.Copy()
	SSstation.goals_by_type -= /datum/station_goal/phoenix

/datum/unit_test/phoenix_goal_fixture/Destroy()
	. = ..()
	SSstation.goals_by_type = original_goals_by_type
	original_goals_by_type = null
	QDEL_NULL(temporary_round_goal)
	return .

/// Material provenance must survive stack operations without mixing projects.
/datum/unit_test/phoenix_fiber_provenance/Run()
	var/obj/item/stack/phoenix_fiber/first = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 5, "first")
	var/obj/item/stack/phoenix_fiber/other = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 3, "other")
	TEST_ASSERT(!first.can_merge(other), "Different projects must not merge their fiber")
	var/obj/item/stack/phoenix_fiber/split = first.split_stack(2)
	TEST_ASSERT_EQUAL(split.project_id, "first", "Splitting must preserve the source project")
	TEST_ASSERT_EQUAL(first.amount + split.amount, 5, "Splitting must conserve the material")
	qdel(split)

/// Submissions consume real matching material once and reject other projects.
/datum/unit_test/phoenix_fiber_submission
	parent_type = /datum/unit_test/phoenix_goal_fixture

/datum/unit_test/phoenix_fiber_submission/Run()
	var/datum/station_goal/phoenix/goal = allocate(/datum/station_goal/phoenix)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/stack/phoenix_fiber/foreign = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 5, "foreign")
	TEST_ASSERT_EQUAL(goal.accept_fiber(foreign, user), 0, "Unrelated material must be refused")
	TEST_ASSERT_EQUAL(foreign.amount, 5, "Refusal must preserve the material")
	var/obj/item/stack/phoenix_fiber/matching = allocate(/obj/item/stack/phoenix_fiber, run_loc_floor_bottom_left, 4, goal.project_id)
	TEST_ASSERT_EQUAL(goal.accept_fiber(matching, user), 4, "The actual matching batch must be accepted")
	TEST_ASSERT(QDELETED(matching), "Accepted material must be consumed")
	TEST_ASSERT_EQUAL(goal.accept_fiber(matching, user), 0, "The deleted stack cannot be submitted twice")
	TEST_ASSERT_EQUAL(goal.fiber_delivered, 4, "Repeated submission must not add credit")
	TEST_ASSERT(!goal.check_completion(), "Material alone is not a recovered population")

/// Releasing or deleting preservation equipment must remove its stasis source.
/datum/unit_test/phoenix_capsule_cleanup/Run()
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain)
	var/obj/machinery/phoenix_capsule/capsule = allocate(/obj/machinery/phoenix_capsule, run_loc_floor_bottom_left, strain, "capsule-test")
	var/mob/living/basic/phoenix_weaver/specimen = capsule.archived_specimen
	TEST_ASSERT_NOTNULL(specimen, "A delivered capsule needs its archived specimen")
	allocated |= specimen
	TEST_ASSERT(HAS_TRAIT(specimen, TRAIT_STASIS), "The archive must preserve its specimen")
	TEST_ASSERT_EQUAL(capsule.icon_state, "capsule_occupied", "Loading an archive must show the preserved specimen.")
	specimen.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE), "Leaving must remove capsule stasis")
	TEST_ASSERT_NULL(capsule.archived_specimen, "The capsule must release its reference")
	TEST_ASSERT_EQUAL(capsule.icon_state, "capsule_empty", "An externally removed specimen must disappear from the capsule sprite.")
	TEST_ASSERT(capsule.preserve(specimen), "The specimen must be preservable again")
	TEST_ASSERT_EQUAL(capsule.icon_state, "capsule_occupied", "Preserving a nearby specimen must update the capsule sprite.")
	capsule.release_specimen()
	TEST_ASSERT_EQUAL(capsule.icon_state, "capsule_empty", "Waking the specimen must clear the capsule sprite.")
	TEST_ASSERT(capsule.preserve(specimen), "The released specimen must be preservable again.")
	qdel(specimen)
	TEST_ASSERT_NULL(capsule.archived_specimen, "Deleting the archived specimen must clear the capsule reference.")
	TEST_ASSERT_EQUAL(capsule.icon_state, "capsule_empty", "A deleted specimen must not remain visible inside the capsule.")
	TEST_ASSERT(capsule.load_archive(strain, "capsule-test"), "The emptied capsule must accept another archive.")
	specimen = capsule.archived_specimen
	allocated |= specimen
	qdel(capsule)
	TEST_ASSERT(!QDELETED(specimen), "Deleting the equipment must release the specimen")
	TEST_ASSERT(!HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE), "Deleted equipment cannot keep a specimen frozen")
	qdel(specimen)

/// Announcing unlocks cargo; only the first real order contains the archived founder.
/datum/unit_test/phoenix_capsule_delivery
	parent_type = /datum/unit_test/phoenix_goal_fixture
	/// Restore the shared cargo catalogue flags even if an assertion fails.
	var/datum/supply_pack/equipment_pack
	/// Original flags before announcing the goal.
	var/original_order_flags

/datum/unit_test/phoenix_capsule_delivery/Destroy()
	if(equipment_pack)
		equipment_pack.order_flags = original_order_flags
		equipment_pack = null
	return ..()

/datum/unit_test/phoenix_capsule_delivery/Run()
	var/datum/station_goal/phoenix/goal = allocate(/datum/station_goal/phoenix)
	equipment_pack = SSshuttle.supply_packs[/datum/supply_pack/science/phoenix_equipment]
	TEST_ASSERT_NOTNULL(equipment_pack, "The Phoenix cargo pack is missing.")
	original_order_flags = equipment_pack.order_flags
	var/list/previous_capsules = SSmachines.get_machines_by_type(/obj/machinery/phoenix_capsule)
	goal.on_report()
	var/list/automatic_capsules = SSmachines.get_machines_by_type(/obj/machinery/phoenix_capsule) - previous_capsules
	// Capture unexpected deliveries before asserting, so the old auto-delivery path also tears down safely.
	for(var/obj/machinery/phoenix_capsule/automatic_capsule as anything in automatic_capsules)
		allocated |= automatic_capsule
		var/obj/structure/closet/supplypod/pod = automatic_capsule.loc
		if(!istype(pod))
			continue
		allocated |= pod.get_all_contents()
		for(var/obj/effect/pod_landingzone/landing_zone in world)
			if(landing_zone.pod == pod)
				allocated |= landing_zone
				if(landing_zone.helper)
					allocated |= landing_zone.helper
				break
	TEST_ASSERT_EQUAL(length(automatic_capsules), 0, "Announcing must not deliver equipment automatically.")
	TEST_ASSERT(equipment_pack.order_flags & ORDER_SPECIAL_ENABLED, "Announcing did not unlock the cargo pack.")
	var/datum/supply_pack/science/phoenix_equipment/admin_pack = allocate(/datum/supply_pack/science/phoenix_equipment)
	admin_pack.order_flags |= ORDER_ADMIN_SPAWNED | ORDER_SPECIAL_ENABLED
	var/obj/admin_crate = admin_pack.generate(run_loc_floor_top_right)
	TEST_ASSERT_NOTNULL(admin_crate, "The admin equipment spawn did not generate a container.")
	allocated |= admin_crate.get_all_contents()
	var/obj/machinery/phoenix_capsule/admin_capsule = locate() in admin_crate
	TEST_ASSERT_NOTNULL(admin_capsule, "The admin equipment spawn has no capsule.")
	TEST_ASSERT_NULL(admin_capsule.archived_specimen, "An admin equipment spawn must not claim the archive.")
	var/datum/supply_order/first_order = allocate(/datum/supply_order, equipment_pack)
	// Keep unrelated manifest RNG out of the delivery contract; production protects the archive separately.
	first_order.manifest_can_fail = FALSE
	var/obj/structure/closet/crate/first_crate = first_order.generate(run_loc_floor_bottom_left)
	TEST_ASSERT_NOTNULL(first_crate, "The first cargo order did not generate its crate.")
	allocated |= first_crate.get_all_contents()
	var/obj/machinery/phoenix_capsule/capsule = locate() in first_crate
	TEST_ASSERT_NOTNULL(capsule, "The first cargo order has no capsule.")
	var/mob/living/basic/phoenix_weaver/specimen = capsule.archived_specimen
	TEST_ASSERT_NOTNULL(specimen, "The first cargo order arrived without its archived founder.")
	TEST_ASSERT_EQUAL(capsule.icon_state, "capsule_occupied", "Cargo must update the capsule sprite after loading the unique archive.")
	TEST_ASSERT_EQUAL(specimen.loc, capsule, "The founder was not preserved inside its capsule.")
	TEST_ASSERT_EQUAL(specimen.project_id, goal.project_id, "The cargo order lost the founder's project identity.")
	TEST_ASSERT(specimen.nutrition >= 0 && specimen.nutrition <= 100, "The delivered founder's nutrition is outside its displayed 0–100 scale.")
	TEST_ASSERT(HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE), "The cargo order woke its archived founder.")
	TEST_ASSERT(specimen.stat != DEAD, "The archived founder died during delivery.")
	var/obj/item/stack/phoenix_bedding/sand = locate(/obj/item/stack/phoenix_bedding) in first_crate
	TEST_ASSERT_EQUAL(sand.amount, 50, "The cargo order lost the starter substrate quantity.")
	TEST_ASSERT_NOTNULL(locate(/obj/item/healthanalyzer/advanced) in first_crate, "The cargo order lost the starter analyzer.")
	TEST_ASSERT_NOTNULL(locate(/obj/item/food/grown/soybeans) in first_crate, "The cargo order lost the starter feed.")
	goal.on_report()
	var/datum/supply_order/repeat_order = allocate(/datum/supply_order, equipment_pack)
	repeat_order.manifest_can_fail = FALSE
	var/obj/structure/closet/crate/repeat_crate = repeat_order.generate(run_loc_floor_top_right)
	TEST_ASSERT_NOTNULL(repeat_crate, "A replacement order did not generate its crate.")
	allocated |= repeat_crate.get_all_contents()
	var/obj/machinery/phoenix_capsule/replacement = locate() in repeat_crate
	TEST_ASSERT_NOTNULL(replacement, "A replacement order has no capsule.")
	TEST_ASSERT_NULL(replacement.archived_specimen, "Repeated orders or announcements must not create another founder.")
	TEST_ASSERT_EQUAL(length(goal.population), 1, "The project did not retain exactly one founder across repeated orders.")

/// Power changes must switch the adaptation station's display without a manual appearance refresh.
/datum/unit_test/phoenix_research_power_appearance/Run()
	var/obj/machinery/phoenix_research/station = allocate(/obj/machinery/phoenix_research, run_loc_floor_bottom_left)
	station.set_machine_stat(station.machine_stat | NOPOWER)
	TEST_ASSERT_EQUAL(station.icon_state, "adaptation_off", "Losing power must extinguish the adaptation station's display.")
	station.set_machine_stat(station.machine_stat & ~NOPOWER)
	TEST_ASSERT_EQUAL(station.icon_state, "adaptation_on", "Restoring power must restore the adaptation station's display.")

/// Examining a preserved mob must format the state before the notice macro concatenates it.
/datum/unit_test/phoenix_capsule_examine/Run()
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	var/obj/machinery/phoenix_capsule/capsule = allocate(/obj/machinery/phoenix_capsule, run_loc_floor_bottom_left, strain, "examine-test")
	allocated |= capsule.archived_specimen
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/list/details = capsule.examine(user)
	TEST_ASSERT(findtext(jointext(details, "\n"), "Образец сохранён в стазисе"), "The occupied capsule's examination lost its specimen state.")
	capsule.release_specimen()
	details = capsule.examine(user)
	TEST_ASSERT(findtext(jointext(details, "\n"), "Капсула пуста"), "The released capsule still reports an archived specimen.")

/// Native UI actions validate stale targets, occupancy and the actor at the server boundary.
/datum/unit_test/phoenix_capsule_ui_actions/Run()
	var/obj/machinery/phoenix_capsule/capsule = allocate(/obj/machinery/phoenix_capsule, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/basic/phoenix_weaver/specimen = allocate(/mob/living/basic/phoenix_weaver, run_loc_floor_bottom_left)
	var/mob/living/basic/phoenix_weaver/other = allocate(/mob/living/basic/phoenix_weaver, run_loc_floor_bottom_left)
	var/datum/tgui/ui = allocate(/datum/tgui, user, capsule, "PhoenixCapsule")
	var/list/data = capsule.ui_data(user)
	TEST_ASSERT_EQUAL(length(data["candidates"]), 2, "The capsule UI must list each nearby exposed specimen separately.")
	var/specimen_ref = REF(specimen)
	specimen.forceMove(run_loc_floor_top_right)
	capsule.ui_act("preserve", list("specimen" = specimen_ref), ui, ui.state)
	TEST_ASSERT_NULL(capsule.archived_specimen, "A stale client selection captured a distant specimen.")
	var/obj/structure/closet/crate/container = allocate(/obj/structure/closet/crate, run_loc_floor_bottom_left)
	specimen.forceMove(container)
	capsule.ui_act("preserve", list("specimen" = specimen_ref), ui, ui.state)
	TEST_ASSERT_NULL(capsule.archived_specimen, "The capsule captured a specimen hidden in another container.")
	capsule.ui_act("preserve", list("specimen" = REF(container)), ui, ui.state)
	TEST_ASSERT_NULL(capsule.archived_specimen, "A forged non-specimen reference entered the capsule.")
	specimen.forceMove(run_loc_floor_bottom_left)
	capsule.ui_act("preserve", list("specimen" = specimen_ref), ui, ui.state)
	TEST_ASSERT_EQUAL(capsule.archived_specimen, specimen, "The native preserve action did not archive the selected specimen.")
	TEST_ASSERT(HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE), "The native preserve action omitted capsule stasis.")
	capsule.ui_act("preserve", list("specimen" = REF(other)), ui, ui.state)
	TEST_ASSERT_EQUAL(capsule.archived_specimen, specimen, "A second preserve action replaced an occupied capsule.")
	user.forceMove(run_loc_floor_top_right)
	capsule.ui_act("release", list("specimen" = specimen_ref), ui, ui.state)
	TEST_ASSERT_EQUAL(capsule.archived_specimen, specimen, "A distant actor released a specimen through an already-open UI.")
	user.forceMove(run_loc_floor_bottom_left)
	capsule.ui_act("release", list("specimen" = REF(other)), ui, ui.state)
	TEST_ASSERT_EQUAL(capsule.archived_specimen, specimen, "A stale release request awakened a different archived specimen.")
	capsule.ui_act("release", list("specimen" = specimen_ref), ui, ui.state)
	TEST_ASSERT_NULL(capsule.archived_specimen, "The native release action left the capsule occupied.")
	TEST_ASSERT(!HAS_TRAIT_FROM(specimen, TRAIT_STASIS, PHOENIX_STASIS_SOURCE), "The native release action retained capsule stasis.")
	data = capsule.ui_data(user)
	TEST_ASSERT_NULL(data["specimen"], "Live UI data retained a released specimen.")

/// Medicine poured through the real item interaction powers gradual treatment in stasis.
/datum/unit_test/phoenix_capsule_treatment/Run()
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	var/obj/machinery/phoenix_capsule/capsule = allocate(/obj/machinery/phoenix_capsule, run_loc_floor_bottom_left, strain, "treatment-test")
	var/mob/living/basic/phoenix_weaver/specimen = capsule.archived_specimen
	allocated += specimen
	specimen.adjust_brute_loss(36)
	var/initial_health = specimen.health
	var/initial_nutrition = specimen.nutrition
	TEST_ASSERT_NOTNULL(capsule.reagents, "The capsule needs a refillable medicine reservoir.")
	var/list/ui_data = capsule.ui_data()
	TEST_ASSERT_NOTNULL(ui_data["specimen"], "The capsule must expose its preserved specimen to its live interface.")
	TEST_ASSERT_EQUAL(ui_data["treatment_status"], "no_medicine", "An injured specimen without medicine must report suspended treatment.")
	capsule.process(180)
	TEST_ASSERT_EQUAL(specimen.health, initial_health, "An empty capsule healed without medicine.")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker, run_loc_floor_bottom_left)
	beaker.amount_per_transfer_from_this = 10
	user.put_in_hands(beaker)
	beaker.reagents.add_reagent(/datum/reagent/water, 10)
	beaker.melee_attack_chain(user, capsule)
	TEST_ASSERT_EQUAL(capsule.reagents.get_reagent_amount(/datum/reagent/water), 10, "The ordinary pouring interaction did not fill the reservoir.")
	ui_data = capsule.ui_data(user)
	TEST_ASSERT_EQUAL(ui_data["total_volume"], 10, "The live reservoir data did not update after pouring.")
	TEST_ASSERT_EQUAL(ui_data["medicine_amount"], 0, "The interface counted unrelated liquid as Libital.")
	capsule.process(180)
	TEST_ASSERT_EQUAL(specimen.health, initial_health, "An unrelated reagent substituted for medicine.")
	beaker.reagents.add_reagent(/datum/reagent/medicine/c2/libital, 10)
	beaker.melee_attack_chain(user, capsule)
	TEST_ASSERT_EQUAL(capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital), 10, "The capsule did not receive the poured medicine.")
	ui_data = capsule.ui_data(user)
	TEST_ASSERT_EQUAL(ui_data["medicine_amount"], 10, "The live medicine quantity did not update after refilling.")
	TEST_ASSERT_EQUAL(ui_data["treatment_status"], "treating", "A supplied injured specimen must report active treatment.")
	specimen.Life(180)
	capsule.process(120)
	TEST_ASSERT(specimen.health > initial_health && specimen.health < specimen.maxHealth, "Near-fatal damage must recover gradually and still need treatment after two minutes.")
	ui_data = capsule.ui_data(user)
	TEST_ASSERT(ui_data["medicine_amount"] < 10, "The live medicine quantity did not decrease during treatment.")
	var/list/ui_specimen = ui_data["specimen"]
	TEST_ASSERT_EQUAL(ui_specimen["health"], specimen.health, "The live health reading did not follow treatment.")
	capsule.process(60)
	TEST_ASSERT_EQUAL(specimen.health, specimen.maxHealth, "A supplied capsule did not finish treatment within three minutes.")
	ui_data = capsule.ui_data(user)
	TEST_ASSERT_EQUAL(ui_data["treatment_status"], "healthy", "Completed treatment must update the interface status.")
	TEST_ASSERT_EQUAL(specimen.nutrition, initial_nutrition, "Treatment resumed metabolism inside stasis.")
	TEST_ASSERT(capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital) < 10, "Treatment did not consume medicine.")
	var/remaining_medicine = capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital)
	capsule.process(180)
	TEST_ASSERT_EQUAL(capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital), remaining_medicine, "A healthy specimen kept consuming medicine.")

/// Insufficient medicine bounds recovery, while released or dead specimens cannot be treated.
/datum/unit_test/phoenix_capsule_treatment_limits/Run()
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	var/obj/machinery/phoenix_capsule/capsule = allocate(/obj/machinery/phoenix_capsule, run_loc_floor_bottom_left, strain, "treatment-limits")
	var/mob/living/basic/phoenix_weaver/specimen = capsule.archived_specimen
	allocated += specimen
	specimen.adjust_brute_loss(20)
	TEST_ASSERT_NOTNULL(capsule.reagents, "The capsule needs a medicine reservoir.")
	capsule.reagents.add_reagent(/datum/reagent/medicine/c2/libital, 1)
	capsule.process(180)
	TEST_ASSERT_EQUAL(specimen.health, 24, "One unit of medicine must only restore four health.")
	TEST_ASSERT_EQUAL(capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital), 0, "The small medicinal dose was not consumed.")
	capsule.process(180)
	TEST_ASSERT_EQUAL(specimen.health, 24, "Treatment continued after the medicine ran out.")
	capsule.release_specimen()
	capsule.reagents.add_reagent(/datum/reagent/medicine/c2/libital, 2)
	capsule.process(180)
	TEST_ASSERT_EQUAL(specimen.health, 24, "The capsule healed a released specimen.")
	TEST_ASSERT_EQUAL(capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital), 2, "An empty capsule consumed medicine.")
	TEST_ASSERT(capsule.preserve(specimen), "The released specimen could not be preserved again.")
	specimen.death()
	capsule.process(180)
	var/list/ui_data = capsule.ui_data()
	TEST_ASSERT_EQUAL(ui_data["treatment_status"], "dead", "The interface must distinguish a dead sample from suspended treatment.")
	TEST_ASSERT(specimen.stat == DEAD, "Treatment resurrected a dead specimen.")
	TEST_ASSERT_EQUAL(capsule.reagents.get_reagent_amount(/datum/reagent/medicine/c2/libital), 2, "A dead specimen consumed medicine.")

/// Both a real material batch and supported adult descendants are required for success.
/datum/unit_test/phoenix_goal_completion
	parent_type = /datum/unit_test/phoenix_goal_fixture

/datum/unit_test/phoenix_goal_completion/Run()
	var/datum/station_goal/phoenix/goal = allocate(/datum/station_goal/phoenix)
	var/turf/open/origin = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/list/room = block(origin, locate(origin.x + 3, origin.y + 3, origin.z))
	var/list/border = block(locate(origin.x - 1, origin.y - 1, origin.z), locate(origin.x + 4, origin.y + 4, origin.z)) - room
	for(var/turf/border_turf as anything in border)
		allocate(/obj/structure/window/reinforced/fulltile, border_turf)
	var/datum/gas_mixture/native_air = SSair.parse_gas_string("o2=20;n2=80;TEMP=295", /datum/gas_mixture/turf)
	allocated += native_air
	for(var/turf/open/room_turf as anything in room)
		room_turf.immediate_calculate_adjacent_turfs()
		room_turf.copy_air(native_air)
		allocate(/obj/structure/phoenix_substrate/grass, room_turf)
	var/datum/phoenix_strain/strain = allocate(/datum/phoenix_strain, "dim", FALSE)
	// The goal boundary is independent of lighting subsystem scheduling.
	strain.light = list(0, 1)
	for(var/index in 1 to PHOENIX_DESCENDANT_TARGET)
		var/obj/item/phoenix_egg/egg = allocate(/obj/item/phoenix_egg, origin, strain, goal.project_id, 1)
		egg.process(PHOENIX_EGG_SECONDS)
	for(var/mob/living/basic/phoenix_weaver/specimen in origin)
		allocated += specimen
		specimen.Life(PHOENIX_LARVA_SECONDS + PHOENIX_COCOON_SECONDS)
	TEST_ASSERT(!goal.check_completion(), "A living population still needs its actual material batch")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, origin)
	var/obj/item/stack/phoenix_fiber/material = allocate(/obj/item/stack/phoenix_fiber, origin, PHOENIX_FIBER_TARGET, goal.project_id)
	TEST_ASSERT_EQUAL(goal.accept_fiber(material, user), PHOENIX_FIBER_TARGET, "The material batch must be consumed at the goal boundary")
	TEST_ASSERT(goal.check_completion(), "Supported natural descendants plus the submitted batch must complete the project")

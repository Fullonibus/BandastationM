/// Disconnect private techwebs before either the machines or their research datums are deleted.
/datum/unit_test/spacepod_fabricator
	abstract_type = /datum/unit_test/spacepod_fabricator
	var/list/fabricators = list()

/datum/unit_test/spacepod_fabricator/Destroy()
	for(var/obj/machinery/mecha_part_fabricator/fabricator as anything in fabricators)
		if(!QDELETED(fabricator))
			fabricator.connect_techweb(null)
	fabricators = null
	return ..()

/datum/unit_test/spacepod_fabricator/proc/make_fabricator(typepath, turf/location)
	var/obj/machinery/mecha_part_fabricator/fabricator = allocate(typepath, location)
	fabricators += fabricator
	return fabricator

/// Research and server-side requests must keep the pod and exosuit catalogs separate.
/datum/unit_test/spacepod_fabricator/research_filter/Run()
	var/obj/machinery/mecha_part_fabricator/legacy = make_fabricator(/obj/machinery/mecha_part_fabricator, run_loc_floor_bottom_left)
	var/obj/machinery/mecha_part_fabricator/spacepod/fabricator = make_fabricator(/obj/machinery/mecha_part_fabricator/spacepod, run_loc_floor_top_right)
	TEST_ASSERT_EQUAL(legacy.allowed_buildtypes, MECHFAB, "The existing exosuit fabricator lost its default build mask.")
	TEST_ASSERT_EQUAL(fabricator.allowed_buildtypes, PODFAB, "The dedicated pod fabricator can manufacture unrelated machine designs.")
	var/pod_design_count = 0
	for(var/design_path in SSresearch.techweb_designs)
		if(findtext("[design_path]", "/datum/design/spacepod_") != 1)
			continue
		var/datum/design/pod_design = SSresearch.techweb_designs[design_path]
		pod_design_count++
		TEST_ASSERT_EQUAL(pod_design.build_type, PODFAB, "[design_path] must be exclusive to the dedicated pod fabricator.")
	TEST_ASSERT_EQUAL(pod_design_count, 24, "The separation check did not cover all pod part designs.")
	var/datum/techweb/research = allocate(/datum/techweb)
	TEST_ASSERT(research.add_design(/datum/design/borg_suit), "Could not add the non-pod design to private research.")
	TEST_ASSERT(research.researched_designs[/datum/design/spacepod_main], "A fresh techweb did not unlock starter pod assembly.")
	TEST_ASSERT(!research.researched_designs[/datum/design/spacepod_laser], "The test laser is already researched before its prerequisite research.")
	legacy.connect_techweb(research)
	fabricator.connect_techweb(research)
	TEST_ASSERT(!(/datum/design/spacepod_main in legacy.cached_designs), "The ordinary exosuit fabricator still offers a pod design.")
	TEST_ASSERT(/datum/design/borg_suit in legacy.cached_designs, "The existing fab stopped offering non-pod mech designs.")
	TEST_ASSERT(/datum/design/spacepod_main in fabricator.cached_designs, "The pod fab does not offer its researched starter design.")
	TEST_ASSERT(!(/datum/design/borg_suit in fabricator.cached_designs), "The pod fab offered a researched cyborg design.")
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_top_right, SOUTH))
	TEST_ASSERT(fabricator.allowed(user), "A person without an ID cannot use the pod fabricator.")
	var/list/static_data = fabricator.ui_static_data(user)
	TEST_ASSERT_EQUAL(static_data["machine_name"], "Фабрикатор подов", "The shared native UI did not receive the dedicated fabricator's translated title.")
	var/list/ui_designs = static_data["designs"]
	TEST_ASSERT_NOTNULL(ui_designs[/datum/design/spacepod_main], "The native UI omitted researched pod assembly.")
	TEST_ASSERT_NULL(ui_designs[/datum/design/borg_suit], "The native UI advertised a non-pod design.")
	TEST_ASSERT_NULL(ui_designs[/datum/design/spacepod_laser], "The native UI advertised an unresearched pod weapon.")
	TEST_ASSERT(!fabricator.add_to_queue(SSresearch.techweb_designs[/datum/design/borg_suit]), "A direct queue call bypassed the pod build mask.")
	TEST_ASSERT(!fabricator.build_part(SSresearch.techweb_designs[/datum/design/borg_suit], FALSE), "A direct print call bypassed the pod build mask.")
	TEST_ASSERT(!legacy.add_to_queue(SSresearch.techweb_designs[/datum/design/spacepod_main]), "A direct queue call printed a pod part through the ordinary fab.")
	TEST_ASSERT(!legacy.build_part(SSresearch.techweb_designs[/datum/design/spacepod_main], FALSE), "A direct print call bypassed the ordinary fab's build mask.")
	for(var/design_path in ui_designs)
		var/datum/design/design = SSresearch.techweb_designs[design_path]
		TEST_ASSERT(research.researched_designs[design_path] && (design.build_type & PODFAB), "The pod UI exposed a design outside its researched build mask.")
	var/datum/tgui/ui = allocate(/datum/tgui, user, fabricator, "ExosuitFabricator")
	fabricator.ui_act("build", list("designs" = list("/datum/design/borg_suit", "/datum/design/spacepod_laser", "/datum/design/spacepod_main")), ui, ui.state)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "A forged build request queued an unrelated or unresearched design.")
	var/alist/queued_part = fabricator.queue[1]
	TEST_ASSERT_EQUAL(queued_part["design"], SSresearch.techweb_designs[/datum/design/spacepod_main], "The validated request did not queue the permitted pod part.")
	fabricator.ui_act("clear_queue", list(), ui, ui.state)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 0, "A person without an ID could not clear the pod fabrication queue.")
	research.remove_design(/datum/design/spacepod_main)
	fabricator.ui_act("build", list("designs" = list("/datum/design/spacepod_main")), ui, ui.state)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 0, "A stale client request bypassed revoked research.")
	TEST_ASSERT(research.add_design(/datum/design/spacepod_laser), "Could not research the pod weapon in the private techweb.")
	fabricator.update_menu_tech()
	TEST_ASSERT(/datum/design/spacepod_laser in fabricator.cached_designs, "Newly researched pod equipment did not enter the native menu.")
	fabricator.ui_act("build", list("designs" = list("/datum/design/spacepod_laser")), ui, ui.state)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "Researching a pod weapon did not authorize its native build request.")
	research.remove_design(/datum/design/spacepod_laser)
	TEST_ASSERT(!fabricator.build_next_in_queue(FALSE), "A queued design bypassed revoked research at print time.")
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "Rejecting a stale researched design silently discarded its queue record.")
	TEST_ASSERT_NULL(fabricator.being_built, "Revoked research still started a print.")

/// The inherited queue must charge real local materials and dispense the actual pod board.
/datum/unit_test/spacepod_fabricator/printing/Run()
	var/obj/machinery/mecha_part_fabricator/spacepod/fabricator = make_fabricator(/obj/machinery/mecha_part_fabricator/spacepod, run_loc_floor_top_right)
	var/datum/techweb/research = allocate(/datum/techweb)
	fabricator.connect_techweb(research)
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, get_step(run_loc_floor_top_right, SOUTH))
	TEST_ASSERT(fabricator.allowed(user), "The printing test user cannot use the pod fabricator without an ID.")
	var/datum/tgui/ui = allocate(/datum/tgui, user, fabricator, "ExosuitFabricator")
	fabricator.ui_act("build", list("designs" = list("/datum/design/spacepod_main")), ui, ui.state)
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "The native request did not queue a pod mainboard.")
	TEST_ASSERT(!fabricator.build_next_in_queue(FALSE), "An empty material store fabricated a pod part.")
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "Insufficient materials discarded the queued pod part.")
	var/datum/design/design = SSresearch.techweb_designs[/datum/design/spacepod_main]
	var/datum/material/iron = SSmaterials.get_material(/datum/material/iron)
	var/expected_cost = OPTIMAL_COST(design.materials[iron] * fabricator.component_coeff)
	TEST_ASSERT(expected_cost > 0, "The real mainboard design has no iron cost.")
	var/datum/material_container/materials = fabricator.rmat.mat_container
	TEST_ASSERT_EQUAL(materials.insert_amount_mat(expected_cost * 2, iron), expected_cost * 2, "Could not load local materials into the pod fabricator.")
	// Keep the real build and completion paths while avoiding a ten-second unit-test wait.
	fabricator.time_coeff = 0.01
	TEST_ASSERT(fabricator.build_next_in_queue(FALSE), "The native queue could not start a researched part with sufficient material.")
	TEST_ASSERT_EQUAL(fabricator.being_built, design, "The fabricator started a different design.")
	TEST_ASSERT_EQUAL(materials.get_material_amount(iron), expected_cost, "Native printing consumed a different amount than the advertised material cost.")
	TEST_ASSERT_EQUAL(length(fabricator.queue), 0, "A started print remained duplicated in the queue.")
	sleep(0.2 SECONDS)
	fabricator.process()
	TEST_ASSERT_NULL(fabricator.being_built, "The native processing path did not finish the print.")
	var/obj/item/circuitboard/mecha/pod/printed = locate() in get_step(fabricator, fabricator.drop_direction)
	TEST_ASSERT_NOTNULL(printed, "The dedicated pod fabricator did not dispense the real mainboard.")
	allocated += printed
	TEST_ASSERT_EQUAL(materials.get_material_amount(iron), expected_cost, "Completing a print charged its materials a second time.")

/// Its printable circuit must construct a dedicated machine usable without an ID.
/datum/unit_test/spacepod_fabricator/construction_access/Run()
	var/turf/origin = run_loc_floor_top_right
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/datum/design/board_design = SSresearch.techweb_designs[/datum/design/board/spacepod_fabricator]
	TEST_ASSERT_NOTNULL(board_design, "The pod fabricator has no research design for its machine circuit.")
	TEST_ASSERT(board_design.build_type & IMPRINTER, "The pod fabricator circuit is not printable by the circuit imprinter.")
	var/datum/techweb/research = allocate(/datum/techweb)
	TEST_ASSERT(research.researched_designs[board_design.type], "Starter pod assembly does not unlock the fabricator circuit.")
	var/obj/machinery/rnd/production/techfab/department/engineering/engineering_printer = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	engineering_printer.connect_techweb(research)
	var/board_available_in_engineering = (board_design in engineering_printer.cached_designs)
	engineering_printer.connect_techweb(null)
	TEST_ASSERT(board_available_in_engineering, "The starter circuit is missing from the engineering techfab's real imprinter catalog.")
	var/obj/item/circuitboard/machine/mechfab/spacepod/board = board_design.create_result(origin)
	allocated += board
	TEST_ASSERT(istype(board), "The research design created a different machine circuit.")
	TEST_ASSERT_EQUAL(board.build_path, /obj/machinery/mecha_part_fabricator/spacepod, "The new circuit still constructs an ordinary mech fabricator.")
	var/obj/structure/frame/machine/secured/frame = allocate(__IMPLIED_TYPE__, origin)
	user.put_in_hands(board)
	TEST_ASSERT(frame.install_board(user, board, by_hand = TRUE), "The real machine frame rejected the pod fabricator circuit.")
	var/obj/item/screwdriver/screwdriver = allocate(__IMPLIED_TYPE__, user)
	TEST_ASSERT(!frame.finalize_construction(user, screwdriver), "The pod fabricator circuit bypassed its stock-part requirements.")
	for(var/component_path in frame.req_components.Copy())
		var/required_count = frame.req_components[component_path]
		for(var/index in 1 to required_count)
			var/physical_type = component_path
			if(ispath(component_path, /datum/stock_part))
				var/datum/stock_part/component_type = component_path
				physical_type = initial(component_type.physical_object_type)
			TEST_ASSERT(ispath(physical_type, /obj/item), "The construction fixture must allocate physical parts, not global stock-part singletons.")
			var/obj/item/component
			if(ispath(physical_type, /obj/item/stack))
				component = allocate(physical_type, origin, 1, FALSE)
			else
				component = allocate(physical_type, origin)
			user.put_in_hands(component)
			var/previous_requirement = frame.req_components[component_path]
			var/result = component.melee_attack_chain(user, frame, list())
			TEST_ASSERT(result, "The native frame could not accept required component [component_path].")
			if(ispath(physical_type, /obj/item/stack))
				TEST_ASSERT(QDELETED(component), "The native frame did not consume its one-sheet construction fixture.")
			TEST_ASSERT_EQUAL(frame.req_components[component_path], previous_requirement - 1, "Installing a physical component did not consume exactly one required part.")
		TEST_ASSERT_EQUAL(frame.req_components[component_path], 0, "A required circuit component was not consumed by the real frame.")
	TEST_ASSERT(frame.finalize_construction(user, screwdriver), "A complete pod-fabricator frame could not finish construction.")
	var/obj/machinery/mecha_part_fabricator/spacepod/fabricator = locate() in origin
	TEST_ASSERT_NOTNULL(fabricator, "Native machine construction did not create a pod fabricator.")
	allocated += fabricator
	fabricators += fabricator
	TEST_ASSERT_EQUAL(fabricator.circuit, board, "The constructed pod fabricator discarded its dedicated circuit.")
	TEST_ASSERT(fabricator.allowed(user), "A person without an ID cannot operate the constructed pod fabricator.")
	var/obj/item/card/id/advanced/card = allocate(__IMPLIED_TYPE__, origin)
	user.put_in_hands(card)
	TEST_ASSERT(fabricator.allowed(user), "An ID without access locked the constructed pod fabricator.")

/// Inherited EMP and blocked-output paths must keep the queue, material charge and original output.
/datum/unit_test/spacepod_fabricator/blocked_output_emp/Run()
	var/obj/machinery/mecha_part_fabricator/spacepod/fabricator = make_fabricator(/obj/machinery/mecha_part_fabricator/spacepod, run_loc_floor_top_right)
	var/datum/techweb/research = allocate(/datum/techweb)
	fabricator.connect_techweb(research)
	var/datum/design/design = SSresearch.techweb_designs[/datum/design/spacepod_main]
	var/datum/material/iron = SSmaterials.get_material(/datum/material/iron)
	var/expected_cost = OPTIMAL_COST(design.materials[iron] * fabricator.component_coeff)
	var/datum/material_container/materials = fabricator.rmat.mat_container
	materials.insert_amount_mat(expected_cost * 3, iron)
	TEST_ASSERT(fabricator.add_to_queue(design), "Could not queue the first researched pod board.")
	TEST_ASSERT(fabricator.add_to_queue(design), "Could not queue a second pod board behind the active print.")
	fabricator.drop_direction = NORTH
	var/turf/blocked_outlet = get_step(fabricator, NORTH)
	TEST_ASSERT(blocked_outlet.density, "The blocked-output fixture must face the native test room's solid wall.")
	fabricator.time_coeff = 0.01
	TEST_ASSERT(fabricator.build_next_in_queue(FALSE), "The real pod-fabricator queue could not begin its funded print.")
	fabricator.emp_act(EMP_LIGHT)
	TEST_ASSERT_EQUAL(fabricator.being_built, design, "Inherited EMP handling changed the active print.")
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "Inherited EMP handling discarded or duplicated the pending queue.")
	TEST_ASSERT_EQUAL(materials.get_material_amount(iron), expected_cost * 2, "EMP handling charged or refunded the print's material cost.")
	sleep(0.2 SECONDS)
	fabricator.process()
	var/obj/item/circuitboard/mecha/pod/stored_board = fabricator.stored_part
	TEST_ASSERT(istype(stored_board), "The blocked output failed to retain the real printed pod mainboard.")
	allocated += stored_board
	TEST_ASSERT_EQUAL(stored_board.loc, fabricator, "A printed board escaped through the blocked output.")
	TEST_ASSERT_NULL(fabricator.being_built, "A completed blocked print remains active.")
	TEST_ASSERT_EQUAL(length(fabricator.queue), 1, "Blocking the output changed the queued second print.")
	fabricator.drop_direction = SOUTH
	var/turf/open_outlet = get_step(fabricator, SOUTH)
	fabricator.process()
	TEST_ASSERT_EQUAL(stored_board.loc, open_outlet, "Clearing the output did not dispense the same stored board.")
	TEST_ASSERT_NULL(fabricator.stored_part, "The dispensed board remains referenced inside the fabricator.")
	fabricator.process()
	var/output_count = 0
	for(var/obj/item/circuitboard/mecha/pod/output in open_outlet)
		output_count++
	TEST_ASSERT_EQUAL(output_count, 1, "Repeated processing duplicated the completed board.")
	TEST_ASSERT_EQUAL(materials.get_material_amount(iron), expected_cost * 2, "Output recovery charged materials a second time.")

/// Destroy real incomplete frames without deleting their shared stock-part singletons.
/datum/unit_test/spacepod_fabricator/partial_frame_destroy/Run()
	var/turf/origin = run_loc_floor_top_right
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, get_step(origin, SOUTH))
	var/obj/structure/frame/machine/secured/frame = allocate(__IMPLIED_TYPE__, origin)
	var/obj/item/circuitboard/machine/mechfab/spacepod/board = allocate(__IMPLIED_TYPE__, origin)
	user.put_in_hands(board)
	TEST_ASSERT(frame.install_board(user, board, by_hand = TRUE), "The incomplete-frame fixture could not install its real pod-fabricator board.")
	var/list/shared_parts = list()
	for(var/stock_path in list(/datum/stock_part/matter_bin, /datum/stock_part/servo, /datum/stock_part/micro_laser))
		var/datum/stock_part/shared_part = GLOB.stock_part_datums[stock_path]
		TEST_ASSERT_NOTNULL(shared_part, "A required stock-part singleton was not registered before frame destruction.")
		shared_parts += shared_part
		var/obj/item/physical_part = allocate(shared_part.physical_object_type, origin)
		user.put_in_hands(physical_part)
		TEST_ASSERT(physical_part.melee_attack_chain(user, frame, list()), "A physical stock part could not be installed into the incomplete frame.")
		TEST_ASSERT(shared_part in frame.components, "The native frame did not replace a physical stock part with its shared datum.")
	TEST_ASSERT(frame.req_components[/obj/item/stack/sheet/glass] > 0, "The destruction fixture must remain an incomplete frame.")
	qdel(frame)
	TEST_ASSERT(QDELETED(frame), "Direct destruction failed to delete the incomplete frame.")
	TEST_ASSERT(QDELETED(board), "Direct frame destruction leaked its owned circuit board.")
	TEST_ASSERT_NULL(frame.components, "A destroyed frame retained its component references.")
	for(var/datum/stock_part/shared_part as anything in shared_parts)
		TEST_ASSERT(!QDELETED(shared_part), "Direct frame destruction deleted a shared stock-part datum.")
		TEST_ASSERT_EQUAL(GLOB.stock_part_datums[shared_part.type], shared_part, "Frame destruction replaced the canonical stock-part singleton.")
		TEST_ASSERT(!QDELETED(shared_part.physical_object_reference), "Frame destruction deleted a stock part's shared physical reference.")
	// A second native board accepts durable physical components as well as shared stock parts.
	var/obj/structure/frame/machine/secured/physical_frame = allocate(__IMPLIED_TYPE__, origin)
	var/obj/item/circuitboard/machine/chem_master/physical_board = allocate(__IMPLIED_TYPE__, origin)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(__IMPLIED_TYPE__, origin)
	user.put_in_hands(physical_board)
	TEST_ASSERT(physical_frame.install_board(user, physical_board, by_hand = TRUE), "The owned-component fixture could not install its native board.")
	user.put_in_hands(beaker)
	TEST_ASSERT(beaker.melee_attack_chain(user, physical_frame, list()), "The native frame did not install its durable physical component.")
	TEST_ASSERT_EQUAL(beaker.loc, physical_frame, "A durable physical component was not owned by the frame.")
	qdel(physical_frame)
	TEST_ASSERT(QDELETED(physical_board), "Frame destruction leaked an owned machine board.")
	TEST_ASSERT(QDELETED(beaker), "Frame destruction leaked an owned durable physical component.")

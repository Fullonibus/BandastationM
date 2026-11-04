/// Exercises the UI trust boundary while replacing only supplypod delivery with a captured request.
/datum/unit_test/sidearm_beacon_ui_delivery/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/choice_beacon/weapon/security_pistol/ui_test/beacon = allocate(/obj/item/choice_beacon/weapon/security_pistol/ui_test, user)
	var/datum/tgui/ui = allocate(/datum/tgui, user, beacon, "ChoiceBeaconWeapons")
	var/list/options = beacon.generate_display_names()
	var/choice = options[1]
	var/obj/item/choice_beacon/weapon/hos/hos_beacon = allocate(/obj/item/choice_beacon/weapon/hos)
	var/list/hos_options = hos_beacon.generate_display_names()

	beacon.ui_act("deliver", list("choice" = hos_options[1]), ui, ui.state)
	beacon.ui_act("deliver", list("choice" = list(choice)), ui, ui.state)
	beacon.ui_act("deliver", list(), ui, ui.state)
	TEST_ASSERT_EQUAL(length(beacon.delivered_types), 0, "A foreign or malformed choice requested a delivery")
	TEST_ASSERT_EQUAL(beacon.uses, 1, "Invalid requests consumed the beacon")

	ui.status = UI_DISABLED
	beacon.ui_act("deliver", list("choice" = choice), ui, ui.state)
	TEST_ASSERT_EQUAL(length(beacon.delivered_types), 0, "A disabled UI requested a delivery")
	ui.status = UI_INTERACTIVE
	beacon.forceMove(run_loc_floor_top_right)
	beacon.ui_act("deliver", list("choice" = choice), ui, ui.state)
	TEST_ASSERT_EQUAL(length(beacon.delivered_types), 0, "A stale distant UI requested a delivery")

	user.forceMove(run_loc_floor_bottom_left)
	beacon.forceMove(holder)
	beacon.ui_act("deliver", list("choice" = choice), ui, ui.state)
	TEST_ASSERT_EQUAL(length(beacon.delivered_types), 0, "A stale UI used a beacon in another mob's inventory")
	TEST_ASSERT_EQUAL(beacon.uses, 1, "Rejected stale requests consumed the beacon")

	beacon.forceMove(user)
	ui.on_act_message("deliver", list("choice" = choice), ui.state)
	TEST_ASSERT_EQUAL(length(beacon.delivered_types), 1, "A reachable valid choice did not request exactly one delivery")
	TEST_ASSERT_EQUAL(beacon.delivered_types[1], options[choice], "The delivered loadout did not match the server's choice list")
	TEST_ASSERT(QDELETED(beacon), "The one-use beacon survived a successful delivery")
	ui.on_act_message("deliver", list("choice" = choice), ui.state)
	TEST_ASSERT_EQUAL(length(beacon.delivered_types), 1, "Replaying the action delivered a second loadout")

/// Preserve the real UI validation and use consumption without launching a pod across the test map.
/obj/item/choice_beacon/weapon/security_pistol/ui_test
	/// Loadout paths passed to the delivery boundary.
	var/list/delivered_types = list()

/obj/item/choice_beacon/weapon/security_pistol/ui_test/spawn_option(obj/choice_path, mob/living/user)
	delivered_types += choice_path

/// Catalogue stats must describe the supplied ammunition and keep each job's catalogue independent.
/datum/unit_test/sidearm_beacon_ui_catalogue/Run()
	var/obj/item/choice_beacon/weapon/security_pistol/security_beacon = allocate(/obj/item/choice_beacon/weapon/security_pistol)
	var/list/security_data = security_beacon.ui_static_data(null)
	var/list/security_weapons = security_data["weapons"]
	var/obj/item/choice_beacon/weapon/blueshield/blueshield_beacon = allocate(/obj/item/choice_beacon/weapon/blueshield)
	var/list/blueshield_data = blueshield_beacon.ui_static_data(null)
	var/list/blueshield_weapons = blueshield_data["weapons"]
	var/obj/item/choice_beacon/weapon/hos/hos_beacon = allocate(/obj/item/choice_beacon/weapon/hos)
	var/list/hos_data = hos_beacon.ui_static_data(null)
	var/list/hos_weapons = hos_data["weapons"]
	for(var/obj/item/choice_beacon/weapon/beacon as anything in list(security_beacon, blueshield_beacon, hos_beacon))
		var/list/data = beacon.ui_static_data(null)
		var/list/weapons = data["weapons"]
		var/list/options = beacon.generate_display_names()
		TEST_ASSERT_EQUAL(length(weapons), length(options), "The job's UI catalogue lost a loadout")
		for(var/list/weapon as anything in weapons)
			TEST_ASSERT(options[weapon["name"]], "The job's UI catalogue included another job's weapon")
	TEST_ASSERT(security_weapons != blueshield_weapons && security_weapons != hos_weapons, "The beacon types shared a cached catalogue")

	var/list/gp9_info = security_weapons[1]
	var/list/gp9_modes = gp9_info["modes"]
	var/list/gp9_mode = gp9_modes[1]
	TEST_ASSERT(gp9_mode["hits_to_exhaust"], "The issued rubber ammunition lost its stamina estimate")
	var/list/disabler_info = security_weapons[2]
	var/list/disabler_modes = disabler_info["modes"]
	var/list/disabler_mode = disabler_modes[1]
	TEST_ASSERT_NULL(disabler_mode["hits_to_neutralize"], "The disabler advertised lethal damage")
	TEST_ASSERT(disabler_mode["hits_to_exhaust"], "The disabler omitted stamina damage")

	var/obj/item/storage/toolbox/guncase/ntspecial/pistol/ladon/guncase = allocate(/obj/item/storage/toolbox/guncase/ntspecial/pistol/ladon)
	var/obj/item/gun/ballistic/gun = locate() in guncase
	TEST_ASSERT_NOTNULL(gun, "The Ladon loadout contained no gun")
	TEST_ASSERT(istype(gun.magazine, /obj/item/ammo_box/magazine/m50/lowpower), "The delivered Ladon started with full-power ammunition")
	for(var/obj/item/ammo_box/magazine/spare in guncase)
		TEST_ASSERT(istype(spare, gun.magazine.type), "The delivered Ladon's spare and loaded ammunition differed")

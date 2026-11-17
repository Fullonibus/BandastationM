/// Chat, automatic reactions and forced dispatch must select the mechanical variants of shared keys.
/datum/unit_test/ipc_emote_execution
	var/emotes_used = 0
	var/datum/emote/last_emote

/datum/unit_test/ipc_emote_execution/Run()
	var/list/cases = list(
		list("key" = "scream", "type" = /datum/emote/living/ipc/scream, "sound" = 'sound/mobs/non-humanoids/cyborg/harmalarm.ogg'),
		list("key" = "crack", "type" = /datum/emote/living/ipc/crack, "sound" = 'modular_bandastation/species/sound/ipc/ipc_crunch.ogg'),
	)
	for(var/list/emote_case as anything in cases)
		for(var/mode in list("chat", "automatic", "forced"))
			var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
			ipc.set_species(/datum/species/ipc)
			RegisterSignal(ipc, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
			emotes_used = 0
			last_emote = null
			if(mode == "chat")
				ipc.key = "IpcEmoteTestKey"
				ipc.say("*[emote_case["key"]]")
				ipc.key = null
			else
				TEST_ASSERT(ipc.emote(emote_case["key"], forced = (mode == "forced")), "An automatic or forced IPC emote was rejected.")
			TEST_ASSERT_EQUAL(emotes_used, 1, "An IPC emote did not complete exactly once.")
			TEST_ASSERT(istype(last_emote, emote_case["type"]), "An IPC used the organic variant of a shared emote key.")
			TEST_ASSERT_EQUAL(last_emote.get_sound(ipc), emote_case["sound"], "An IPC emote retained an organic sound.")
			UnregisterSignal(ipc, COMSIG_MOB_EMOTE)
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	RegisterSignal(human, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
	emotes_used = 0
	last_emote = null
	TEST_ASSERT(human.emote("scream", forced = TRUE), "A forced human scream was rejected.")
	TEST_ASSERT_EQUAL(emotes_used, 1, "A forced human scream did not complete exactly once.")
	TEST_ASSERT_EQUAL(last_emote.type, /datum/emote/living/scream, "Forced dispatch gave a human the IPC alarm variant.")
	UnregisterSignal(human, COMSIG_MOB_EMOTE)

/datum/unit_test/ipc_emote_execution/proc/on_emote(datum/source, datum/emote/emote)
	SIGNAL_HANDLER
	emotes_used++
	last_emote = emote

/// A transplanted organic brain uses the receiving chassis' voicebox and emotion controls.
/datum/unit_test/ipc_emote_brain_transplant/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/datum/mind/personality = donor.mind
	var/obj/item/organ/brain/brain = donor.get_organ_slot(ORGAN_SLOT_BRAIN)
	allocated += brain
	brain.Remove(donor)
	TEST_ASSERT_EQUAL(brain.brainmob?.mind, personality, "Removing the donor brain did not preserve its personality.")
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left, /datum/species/ipc)
	TEST_ASSERT(brain.Insert(ipc, special = TRUE, movement_flags = DELETE_IF_REPLACED), "The organic brain could not be transplanted into the IPC fixture.")
	TEST_ASSERT_EQUAL(ipc.mind, personality, "The organic brain did not transfer its personality to the IPC.")
	TEST_ASSERT(is_species(ipc, /datum/species/ipc), "An organic brain replaced the chassis' species.")
	TEST_ASSERT(HAS_TRAIT(ipc, TRAIT_SILICON_EMOTES_ALLOWED), "An organic brain removed the chassis' voicebox capability.")
	TEST_ASSERT(/mob/living/carbon/human/proc/open_ipc_emote_panel in ipc.verbs, "The organic brain transplant lost the IPC emotion panel verb.")
	var/datum/emote_panel/panel = allocate(/datum/emote_panel)
	var/list/panel_data = panel.ui_static_data(ipc)
	var/list/panel_keys = list()
	for(var/list/emote_data as anything in panel_data["emotes"])
		panel_keys += emote_data["key"]
	for(var/emote_key in list("beep", "ping", "buzz", "yes", "no", "scream"))
		TEST_ASSERT(emote_key in panel_keys, "The emotion panel hid a transplanted brain's machine emotion: [emote_key].")
		TEST_ASSERT_NOTNULL(get_available_emote(ipc, emote_key, status_check = TRUE), "An organic brain prevented the IPC from using its machine emotion: [emote_key].")
	TEST_ASSERT(ipc.emote("beep", intentional = TRUE), "The transplanted human personality could not beep through its IPC voicebox.")

/// Organic reactions are rejected even by forced dispatch, while gestures and freeform roleplay remain available.
/datum/unit_test/ipc_emote_restrictions/Run()
	var/mob/living/carbon/human/ipc = allocate(/mob/living/carbon/human/consistent)
	ipc.set_species(/datum/species/ipc)
	TEST_ASSERT(!ipc.emote("cry", forced = TRUE), "Forced dispatch let an IPC cry like an organic character.")
	TEST_ASSERT(!ipc.emote("laugh", intentional = TRUE, force_silence = TRUE), "An IPC could use human laughter.")
	for(var/key in list("screech", "roar", "hiss", "tongue"))
		TEST_ASSERT(!ipc.emote(key, forced = TRUE), "An alternate emote bypassed the IPC's organic voice restriction: [key].")
	TEST_ASSERT(ipc.emote("shrug", intentional = TRUE), "Restricting organic reactions also blocked an IPC's gesture.")
	TEST_ASSERT(ipc.emote("me", message = "checks its diagnostics.", intentional = TRUE), "An IPC lost freeform roleplay emotes.")

	var/datum/emote/beep = GLOB.emote_list["beep"][1]
	TEST_ASSERT(beep.can_run_emote(ipc), "An operational IPC could not use its voicebox.")
	ADD_TRAIT(ipc, TRAIT_EMOTEMUTE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!beep.can_run_emote(ipc), "Machine emotes bypassed emote muting.")
	REMOVE_TRAIT(ipc, TRAIT_EMOTEMUTE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(ipc, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!beep.should_play_sound(ipc, intentional = TRUE), "Machine audio bypassed muting.")
	REMOVE_TRAIT(ipc, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	ipc.Unconscious(1 MINUTES, ignore_canstun = TRUE)
	TEST_ASSERT(IS_UNCONSCIOUS(ipc), "The unconscious IPC fixture remained awake.")
	TEST_ASSERT(!beep.can_run_emote(ipc), "An unconscious IPC could deliberately beep.")
	ipc.SetUnconscious(0)

	var/obj/item/organ/tongue/voicebox = ipc.get_organ_slot(ORGAN_SLOT_TONGUE)
	TEST_ASSERT_NOTNULL(voicebox, "The IPC fixture had no voicebox.")
	allocated += voicebox
	voicebox.Remove(ipc)
	TEST_ASSERT(!beep.can_run_emote(ipc), "An IPC without its voicebox retained machine audio.")
	voicebox.Insert(ipc)
	TEST_ASSERT(beep.can_run_emote(ipc), "Reinstalling the voicebox did not restore machine emotes.")

/// A reused panel and verb list must follow transformations without adding an extra HUD action.
/datum/unit_test/ipc_emote_panel/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/datum/emote_panel/panel = allocate(/datum/emote_panel)
	for(var/is_ipc in list(TRUE, FALSE, TRUE))
		human.set_species(is_ipc ? /datum/species/ipc : /datum/species/human)
		TEST_ASSERT_EQUAL((/mob/living/carbon/human/proc/open_ipc_emote_panel in human.verbs), is_ipc, "The IPC emotion panel verb did not follow a species transformation.")
		for(var/datum/action/action as anything in human.actions)
			TEST_ASSERT(action.name != "Эмоции КПБ", "The IPC emotion panel still occupied a HUD action slot.")

		var/list/data = panel.ui_static_data(human)
		var/list/emote_keys = list()
		for(var/list/emote_data as anything in data["emotes"])
			emote_keys += emote_data["key"]
		for(var/key in list("beep", "buzz", "ping", "yes", "no"))
			TEST_ASSERT_EQUAL((key in emote_keys), is_ipc, "The panel retained or omitted a species-specific machine emote: [key].")
		for(var/key in list("cry", "laugh", "gasp", "cough", "blush"))
			TEST_ASSERT_EQUAL((key in emote_keys), !is_ipc, "The panel offered the wrong species' organic reaction: [key].")
		for(var/key in list("shrug", "nod", "wave", "point", "scream"))
			TEST_ASSERT(key in emote_keys, "The panel lost a supported gesture or shared emote: [key].")

	human.set_species(/datum/species/human)
	TEST_ASSERT(human.emote("laugh", intentional = TRUE), "Organic laughter was not restored after leaving the IPC species.")
	TEST_ASSERT(human.emote("scream", intentional = FALSE), "Organic screaming was not restored after leaving the IPC species.")
	TEST_ASSERT(!human.emote("yes", intentional = TRUE, force_silence = TRUE), "A former IPC retained its machine voicebox emotes.")

/// Species filtering must hide favorites temporarily and return independent copies, never rewrite saved roleplay.
/datum/unit_test/ipc_emote_favorites/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	// Existing saves persist numeric type IDs: 1 normal, 2 custom text, 3 freeform.
	var/list/cry_entry = list("type" = 1, "key" = "cry")
	var/list/beep_entry = list("type" = 2, "key" = "beep", "message_override" = "signals readiness.")
	var/list/me_entry = list("type" = 3, "message" = "checks the surroundings.")
	var/list/saved = list("Crying" = cry_entry, "Signal" = beep_entry, "Roleplay" = me_entry)
	for(var/is_ipc in list(TRUE, FALSE, TRUE))
		human.set_species(is_ipc ? /datum/species/ipc : /datum/species/human)
		var/list/available = get_available_emote_panel_entries(human, saved)
		TEST_ASSERT_EQUAL(("Crying" in available), !is_ipc, "Favorites retained or lost the wrong species' cry.")
		TEST_ASSERT_EQUAL(("Signal" in available), is_ipc, "Favorites retained or lost the wrong species' beep.")
		TEST_ASSERT("Roleplay" in available, "Species filtering removed a saved freeform emote.")
		var/list/shown_me = available["Roleplay"]
		shown_me["message"] = "modified payload"
		var/list/shown_signal = available["Signal"]
		if(shown_signal)
			shown_signal["key"] = "laugh"
		var/list/shown_cry = available["Crying"]
		if(shown_cry)
			shown_cry["key"] = "beep"
		available.Remove("Roleplay")
		available["Changed"] = list()
		TEST_ASSERT_EQUAL(length(saved), 3, "Filtering or changing its payload altered the saved favorites map.")
		TEST_ASSERT_EQUAL(saved["Crying"], cry_entry, "Filtering replaced the original cry favorite.")
		TEST_ASSERT_EQUAL(saved["Signal"], beep_entry, "Filtering replaced the original machine favorite.")
		TEST_ASSERT_EQUAL(saved["Roleplay"], me_entry, "Filtering replaced the original roleplay favorite.")
		TEST_ASSERT_EQUAL(cry_entry["key"], "cry", "Changing the filtered cry changed its saved entry.")
		TEST_ASSERT_EQUAL(beep_entry["key"], "beep", "Changing the filtered beep changed its saved entry.")
		TEST_ASSERT_EQUAL(beep_entry["message_override"], "signals readiness.", "Filtering changed a saved custom emote's text.")
		TEST_ASSERT_EQUAL(me_entry["message"], "checks the surroundings.", "Changing the filtered roleplay changed its saved text.")

	for(var/mob_type in list(/mob/dead/new_player, /mob/dead/observer))
		var/mob/user = allocate(mob_type)
		var/list/available = get_available_emote_panel_entries(user, saved)
		for(var/emote_name in saved)
			TEST_ASSERT(emote_name in available, "[mob_type] could not manage a saved favorite: [emote_name].")
		TEST_ASSERT(isnull(get_available_emote(user, "me")), "Editing favorites enabled out-of-body roleplay.")

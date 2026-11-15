/// OGG sync requires bilateral consent and never replaces the follower's track or cues.
/datum/unit_test/music_ogg_unison/Run()
	var/datum/job/musician = allocate(/datum/job/donor/musician)
	var/list/players = list()
	var/list/songs = list()
	for(var/index in 1 to 2)
		var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
		player.mind_initialize()
		player.mind.assigned_role = musician
		var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
		if(!player.put_in_active_hand(instrument))
			Fail("The OGG fixture could not hold its instrument.", __FILE__, __LINE__)
			return
		players += player
		songs += instrument.song
	var/datum/song/leader = songs[1]
	var/datum/song/follower = songs[2]
	leader.playback_mode = "file"
	leader.file_track = 'sound/items/bikehorn.ogg'
	leader.file_track_length = 60 SECONDS
	follower.playback_mode = "file"
	follower.file_track = 'sound/items/barcodebeep.ogg'
	follower.file_track_length = 30 SECONDS
	follower.file_track_hash = "own-track"
	var/list/own_cues = list(list("time" = 1, "text" = "Own lyrics"))
	follower.song_cues = own_cues
	for(var/list/consent as anything in list(list(FALSE, TRUE), list(TRUE, FALSE), list(TRUE, TRUE)))
		leader.auto_unison_enabled = consent[1]
		follower.auto_unison_enabled = consent[2]
		leader.start_playing(players[1])
		if(!leader.playing)
			Fail("The OGG leader did not start through start_playing.", __FILE__, __LINE__)
			return
		if(follower.playing != (consent[1] && consent[2]))
			Fail("OGG unison ignored bilateral consent ([consent[1]]/[consent[2]]).", __FILE__, __LINE__)
		if(follower.playing && (follower.file_track != 'sound/items/barcodebeep.ogg' || follower.song_cues != own_cues || follower.file_track_hash != "own-track" || follower.file_track_finish_time != follower.playback_started_at + 30 SECONDS))
			Fail("OGG unison replaced the follower's own track, lyrics or duration.", __FILE__, __LINE__)
		leader.stop_playing()
		follower.stop_playing()
	if(leader.using_sound_channels || follower.using_sound_channels)
		Fail("Stopping OGG unison did not release its allocated channels.", __FILE__, __LINE__)
	var/obj/item/instrument/follower_instrument = follower.parent
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, run_loc_floor_bottom_left)
	follower_instrument.forceMove(bag)
	leader.start_playing(players[1])
	if(follower.playing)
		Fail("OGG unison started an instrument inside a bag.", __FILE__, __LINE__)
	leader.stop_playing()

/// Removing groups must preserve MIDI unison and release the follower on stop.
/datum/unit_test/music_midi_unison/Run()
	var/datum/job/musician = allocate(/datum/job/donor/musician)
	var/list/players = list()
	var/list/songs = list()
	for(var/index in 1 to 2)
		var/mob/living/carbon/human/consistent/player = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
		player.mind_initialize()
		player.mind.assigned_role = musician
		var/obj/item/instrument/guitar/instrument = allocate(/obj/item/instrument/guitar, run_loc_floor_bottom_left)
		if(!player.put_in_active_hand(instrument))
			Fail("The MIDI fixture could not hold its instrument.", __FILE__, __LINE__)
			return
		players += player
		songs += instrument.song
		instrument.song.playback_mode = "sequence"
		instrument.song.id = "midi-unison"
		if(!instrument.song.load_sequence(list("version" = 1, "title" = "Own part [index]", "notes" = list(list("time" = 0, "duration" = 60, "key" = 60 + index, "velocity" = 100, "channel" = 0, "track" = 0)), "tempos" = list(list("time" = 0, "bpm" = 120)), "tracks" = list(list("id" = 0, "name" = "Part")))))
			Fail("The MIDI fixture document was rejected.", __FILE__, __LINE__)
			return
	var/datum/song/leader = songs[1]
	var/datum/song/follower = songs[2]
	leader.start_playing(players[1])
	if(!leader.playing || !follower.playing || follower.sequence_master != leader || !(follower in leader.sequence_followers))
		Fail("The legacy ID-based MIDI unison did not start its follower.", __FILE__, __LINE__)
	if(follower.midi_title != "Own part 2")
		Fail("MIDI unison overwrote the follower's saved composition.", __FILE__, __LINE__)
	follower.stop_playing()
	if(follower.sequence_master || (follower in leader.sequence_followers))
		Fail("Stopping MIDI unison retained a follower reference.", __FILE__, __LINE__)
	leader.stop_playing()

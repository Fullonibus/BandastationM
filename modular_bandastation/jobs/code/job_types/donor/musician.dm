/datum/job/donor/musician
	title = "Музыкант"
	alternate_titles = list("Музыкант")
	description = "Играйте музыку и устраивайте концерты для экипажа."
	config_tag = "MUSICIAN"
	display_order = JOB_DISPLAY_ORDER_DONOR_NAVY_JUNIOR_OFFICER + 1
	total_positions = 2
	spawn_positions = 2
	required_donator_level = DONATOR_TIER_5
	donor_spawn_landmark = JOB_CURATOR
	outfit = /datum/outfit/job/donor/musician
	plasmaman_outfit = /datum/outfit/plasmaman/curator
	tgui_icon = FA_ICON_MUSIC

/datum/outfit/job/donor/musician
	name = "Musician"
	jobtype = /datum/job/donor/musician
	id_trim = /datum/id_trim/job/donor/musician
	uniform = /obj/item/clothing/under/suit/black
	shoes = /obj/item/clothing/shoes/laceup
	ear_right = /obj/item/radio/headset/headset_srv
	backpack_contents = list(/obj/item/instrument/piano_synth = 1)

/datum/id_trim/job/donor/musician
	assignment = "Музыкант"
	job = /datum/job/donor/musician
	parent_type = /datum/id_trim/job/curator
	minimal_access = list(ACCESS_SERVICE, ACCESS_THEATRE, ACCESS_LIBRARY)

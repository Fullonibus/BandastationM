/mob/dead/observer/Login()
	. = ..()
	if(!. || !client)
		return FALSE

	ghost_accs = client.prefs.read_preference(/datum/preference/choiced/ghost_accessories)
	ghost_others = client.prefs.read_preference(/datum/preference/choiced/ghost_others)
	var/preferred_form = client.prefs.read_preference(/datum/preference/choiced/ghost_form)
	if(!(preferred_form in list("ghost", "ghost_static")) && !client.is_content_unlocked())
		preferred_form = "ghost"

	if(client.prefs.unlock_content)
		ghost_orbit = client.prefs.read_preference(/datum/preference/choiced/ghost_orbit)

	update_icon(ALL, preferred_form)
	updateghostimages()
	client.set_right_click_menu_mode(FALSE)
	lighting_cutoff = default_lighting_cutoff()
	update_sight()



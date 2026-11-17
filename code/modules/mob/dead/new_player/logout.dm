/mob/dead/new_player/Logout()
	ready = PLAYER_NOT_READY
	..()
	if(!spawning)//Here so that if they are spawning and log out, the other procs can play out and they will have a mob to come back to.
		if(mind)
			var/datum/job/job = mind.assigned_role
			if(assigned_job_character && job && !is_unassigned_job(job))
				job.current_positions = max(0, job.current_positions - 1)
		QDEL_NULL(assigned_job_character)
		key = null//We null their key before deleting the mob, so they are properly kicked out.
		QDEL_NULL(mind) //Clean out mind, yes this fucking sucks
		qdel(src)
	return

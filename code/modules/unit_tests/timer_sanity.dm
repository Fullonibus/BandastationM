/datum/unit_test/timer_sanity/Run()
	TEST_ASSERT(SStimer.bucket_count >= 0,
		"SStimer is going into negative bucket count from something")

/// A private fixture queue. The normal constructor replaces the live SStimer.
/datum/controller/subsystem/timer/client_time_test_fixture
	name = "Client time timer test fixture"
	ss_flags = SS_NO_INIT | SS_NO_FIRE

/datum/controller/subsystem/timer/client_time_test_fixture/New()
	PreInit()

/// Checks callbacks that insert an earlier timer after a longer loop has been rescheduled.
/datum/unit_test/client_time_timer_callback_insertion
	/// Isolated queue, not registered with the master controller.
	var/datum/controller/subsystem/timer/test_timer_subsystem
	/// Records the callbacks executed during the pass.
	var/list/invocations = list()

/datum/unit_test/client_time_timer_callback_insertion/Run()
	var/datum/controller/subsystem/timer/live_timer = SStimer
	test_timer_subsystem = allocate(/datum/controller/subsystem/timer/client_time_test_fixture)
	TEST_ASSERT_EQUAL(SStimer, live_timer, "The isolated queue must not replace SStimer")
	test_timer_subsystem.state = SS_RUNNING

	var/due_at = REALTIMEOFDAY
	for (var/index in 1 to 5)
		var/flags = TIMER_CLIENT_TIME|TIMER_STOPPABLE|TIMER_DELETE_ME
		if (index == 3)
			flags |= TIMER_LOOP
		var/timer_id = addtimer(CALLBACK(src, PROC_REF(record_callback), index), 1, flags, test_timer_subsystem)
		var/datum/timedevent/timer = test_timer_subsystem.timer_id_dict[timer_id]
		timer.timeToRun = due_at
		if (index == 3)
			timer.wait = 2 MINUTES

	var/previous_ticklimit = Master.current_ticklimit
	var/runtime_message
	Master.current_ticklimit = INFINITY
	try
		test_timer_subsystem.fire()
	catch (var/exception/error)
		runtime_message = error.name
	Master.current_ticklimit = previous_ticklimit

	TEST_ASSERT_NULL(runtime_message, "Firing the client-time queue raised a runtime")
	TEST_ASSERT_EQUAL(invocations.Join(","), "1,2,3,4,5", "Each due callback should run once in insertion order")
	TEST_ASSERT_EQUAL(length(test_timer_subsystem.clienttime_timers), 2, "The next callback and rescheduled loop should remain queued")

/datum/unit_test/client_time_timer_callback_insertion/Destroy()
	for(var/datum/timedevent/timer as anything in test_timer_subsystem?.clienttime_timers.Copy())
		qdel(timer)
	test_timer_subsystem = null
	return ..()

/// Records a due callback and reproduces a callback scheduling its next step.
/datum/unit_test/client_time_timer_callback_insertion/proc/record_callback(index)
	invocations += index
	if (index == 4)
		addtimer(CALLBACK(src, PROC_REF(record_callback), 6), 1 MINUTES, TIMER_CLIENT_TIME|TIMER_DELETE_ME, test_timer_subsystem)

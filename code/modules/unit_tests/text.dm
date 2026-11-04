/// Tests strip_outer_punctuation()
/datum/unit_test/strip_outer_punctuation

/datum/unit_test/strip_outer_punctuation/Run()
	var/list/sample_to_expected = list(
		"Hello, world!" = "Hello, world",
		"|Who are you?|" = "Who are you",
		"Oh wow..." = "Oh wow",
		"My name is E.T, the alien!" = "My name is E.T, the alien",
		"I'm +YELLING+ at you!" = "I'm +YELLING+ at you",
		"+I'm REALLY yelling!+" = "I'm REALLY yelling",
	)

	for(var/sample in sample_to_expected)
		TEST_ASSERT_EQUAL(strip_outer_punctuation(sample), sample_to_expected[sample], "Strip punctuation failed for sample text: [sample]")

/// Tests find_last_punctuation()
/datum/unit_test/find_last_punctuation

/datum/unit_test/find_last_punctuation/Run()
	var/list/sample_to_expected = list(
		"Hello, world!" = "!",
		"|Who are you?|" = "?",
		"Really, |WHO are you|?" = "?",
		"Oh wow..." = "...",
		"My name is E.T, the alien!" = "!",
	)

	for(var/sample in sample_to_expected)
		TEST_ASSERT_EQUAL(find_last_punctuation(sample), sample_to_expected[sample], "Find punctuation failed for sample text: [sample]")

/// Capitalizing translated names must remove proper/improper macros without losing Cyrillic letters.
/datum/unit_test/capitalize_unicode/Run()
	TEST_ASSERT_EQUAL(capitalize("\proper test name"), "Test name", "Proper macro was not removed before capitalization.")
	TEST_ASSERT_EQUAL(capitalize("\improper test name"), "Test name", "Improper macro was not removed before capitalization.")
	TEST_ASSERT_EQUAL(capitalize("\proper ёлка"), "Ёлка", "A proper Cyrillic name was not capitalized.")
	TEST_ASSERT_EQUAL(capitalize("\improper аварийный лом"), "Аварийный лом", "A translated item name lost Cyrillic capitalization.")
	TEST_ASSERT_EQUAL(full_capitalize("\proper test name"), "\proper Test Name", "Full capitalization corrupted the proper macro.")
	TEST_ASSERT_EQUAL(full_capitalize("\improper test name"), "\improper Test Name", "Full capitalization corrupted the improper macro.")

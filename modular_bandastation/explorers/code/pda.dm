/obj/item/modular_computer/pda/crew/explorer
	name = "explorer PDA"
	painting_region = REGION_EXPEDITION
	greyscale_config = /datum/greyscale_config/tablet/stripe_split
	greyscale_colors = "#BDC3C7#D2D7D3#6C7A89"
	starting_programs = list(
		/datum/computer_file/program/arcade,
		/datum/computer_file/program/skill_tracker,
		/datum/computer_file/data/text/expedition_field_notes,
		/datum/computer_file/program/expedition_journal,
	)

/// Editable field report template opened with the PDA's standard Notepad app.
/datum/computer_file/data/text/expedition_field_notes
	filename = "field_notes"
	stored_text = "ПОЛЕВАЯ ЗАПИСЬ\n\
		Автор и участники:\n\
		Время и место:\n\n\
		Общая цель экспедиции:\n\
		Личная исследовательская цель:\n\n\
		Находки и номера проб:\n\
		Условия и выполненные действия:\n\
		Наблюдения и измерения:\n\n\
		Гипотезы:\n\
		Выводы и нерешённые вопросы:\n\
		Результат выполнения целей:\n"

/// Account for the template's text before the PDA checks its remaining capacity.
/datum/computer_file/data/text/expedition_field_notes/New()
	. = ..()
	calculate_size()

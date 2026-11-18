#define WELL_CONNECTED_DISCOUNT 0.8
#define WELL_CONNECTED_CRAB_DRAIN 0.5

/datum/quirk/well_connected
	name = "Полезные связи"
	desc = "У ваших знакомых есть знакомые, которые могут устроить вам выгодную сделку. \
		Личные заказы из каталога карго и покупки на чёрном рынке обходятся вам дешевле."
	icon = FA_ICON_MONEY_BILL_TRANSFER
	value = 6
	gain_text = span_notice("У вас есть нужные связи.")
	lose_text = span_danger("Вы потеряли свои связи.")
	medical_record_text = "У пациента есть индивидуальная медицинская страховка."
	mail_goodies = list(
		/obj/item/reagent_containers/cup/glass/bottle/vodka,
		/obj/item/reagent_containers/cup/glass/bottle/whiskey,
		/obj/item/reagent_containers/cup/glass/bottle/wine,
	)
	quirk_flags = QUIRK_HUMAN_ONLY | QUIRK_HIDE_FROM_SCAN

	/// The holder's own account, even when they're carrying someone else's ID.
	VAR_PRIVATE/datum/weakref/affected_account

/datum/quirk/well_connected/add(client/client_source)
	if(affected_account?.resolve())
		return

	var/mob/living/carbon/human/holder = quirk_holder
	var/datum/bank_account/account = SSeconomy.bank_accounts_by_id["[holder.account_id]"]
	if(QDELETED(account))
		return

	affected_account = WEAKREF(account)
	account.cargo_order_cost_modifier *= WELL_CONNECTED_DISCOUNT
	account.black_market_cost_modifier *= WELL_CONNECTED_DISCOUNT
	account.crab_17_drain_rate_modifier *= WELL_CONNECTED_CRAB_DRAIN

// The same quirk datum follows the character between slime bodies.
/datum/quirk/well_connected/remove_from_current_holder(quirk_transfer = FALSE)
	if(!quirk_transfer)
		clear_account_discount()
	return ..()

/datum/quirk/well_connected/Destroy()
	// A failed transfer can delete the quirk with no current holder.
	clear_account_discount()
	return ..()

/// Removes the effect from the account it was originally applied to.
/datum/quirk/well_connected/proc/clear_account_discount()
	var/datum/bank_account/account = affected_account?.resolve()
	affected_account = null
	if(isnull(account))
		return

	account.cargo_order_cost_modifier /= WELL_CONNECTED_DISCOUNT
	account.black_market_cost_modifier /= WELL_CONNECTED_DISCOUNT
	account.crab_17_drain_rate_modifier /= WELL_CONNECTED_CRAB_DRAIN

#undef WELL_CONNECTED_DISCOUNT
#undef WELL_CONNECTED_CRAB_DRAIN

/datum/quirk/weird_mail
	name = "Необычный корреспондент"
	desc = "Кто-то из друзей или родных присылает вам необычные посылки. Вам могут достаться подарки для других профессий."
	value = 2
	icon = FA_ICON_ENVELOPE
	mail_weight = 50
	quirk_flags = QUIRK_HUMAN_ONLY | QUIRK_HIDE_FROM_SCAN | QUIRK_NO_RECORD
	/// Completely random stuff to add to their mail pool with high unpredictability
	var/static/list/random_mail_items = list(
		/obj/item/assembly/relic/lavaland/revealed, // immediately usable
		/obj/item/assembly/relic/revealed, // ditto
		/obj/item/chainsaw,
		/obj/item/gibtonite, // does not immediately explode, but can
		/obj/item/melee/baton/security/cattleprod/loaded, // functioning stunprod
		/obj/item/pickaxe/mini,
		/obj/item/spess_knife, // full toolset
		/obj/item/switchblade, // decent weapon
		/obj/item/tome, // useless, but cool
	)
	/// Completely random stuff to add to their mail pool, but generally safer / less likely to cause trouble
	var/static/list/limited_mail_items = list(
		/obj/item/banhammer,
		/obj/item/bikehorn/airhorn,
		/obj/item/boxcutter,
		/obj/item/clothing/neck/petcollar/wearable,
		/obj/item/disk/nuclear/fake, // useless but funny
		/obj/item/feather,
		/obj/item/flashlight/lantern/jade,
		/obj/item/gift, // not the christmas gift. fooled you!
		/obj/item/gun/ballistic/revolver/russian,
		/obj/item/newspaper,
		/obj/item/pen/fountain,
		/obj/item/phone, // entirely useless
		/obj/item/ship_in_a_bottle, // almost entirely useless
		/obj/item/stack/ore/diamond,
		/obj/item/stack/ore/uranium,
		/obj/item/stack/sheet/bluespace_crystal, // little bit of shenanigan potential, but one use
		/obj/item/stock_parts/power_store/cell,
		/obj/item/table_clock,
		/obj/item/throwing_star, // one use
		/obj/item/tourniquet,
		/obj/item/transfer_valve, // not dangerous without components
	)

/datum/quirk/weird_mail/get_mail_goodies(datum/job/recipient_job)
	if(recipient_job?.exclusive_mail_goodies)
		return null

	var/list/rewards = limited_mail_items | random_mail_items
	for(var/datum/job/other_job as anything in SSjob.joinable_occupations)
		if(other_job == recipient_job || other_job.exclusive_mail_goodies)
			continue
		for(var/reward in other_job.mail_goodies)
			rewards |= reward
	return rewards

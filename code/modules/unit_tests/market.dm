#define CATEGORY_CODERBUS "Coderbus"
/// Ensures market items have acceptable variable values and restocking works.
/datum/unit_test/market

/datum/unit_test/market/Run()
	for(var/datum/market_item/prototype as anything in subtypesof(/datum/market_item))
		if(prototype::abstract_path == prototype) //skip abstract paths
			continue
		if(!prototype::category)
			TEST_FAIL("[prototype] doesn't have a set category (or the abstract path var isn't correctly set)")
			continue
		if(!prototype::item)
			TEST_FAIL("[prototype] doesn't have a set item (or the abstract path var isn't correctly set)")
			continue
		if(isnull(prototype::price) && prototype::price_max <= prototype::price_min)
			TEST_FAIL("[prototype] doesn't have a correctly set random price (price_max should be higher than price_min)")
		if(isnull(prototype::stock) && prototype::stock_max < prototype::stock_min)
			TEST_FAIL("[prototype] doesn't have a correctly set random stock (stock_max shouldn't be lower than stock_min)")
		if(!isnum(prototype::availability_prob))
			TEST_FAIL("[prototype] doesn't have a set availability_prob (must be a number)")
		if(!prototype::name)
			TEST_FAIL("[prototype] doesn't have a set name")
		if(!prototype::desc)
			TEST_FAIL("[prototype] doesn't have a set desc")


	var/datum/market/unit_test/market = SSmarket.markets[/datum/market/unit_test]
	TEST_ASSERT(market, "Couldn't find the unit test market")
	var/list/category_items = market.available_items[CATEGORY_CODERBUS]
	var/datum/market_item/unit_test/item = category_items[category_items[1]]
	TEST_ASSERT(item, "Couldn't find the unit test market item")
	TEST_ASSERT_EQUAL(item.stock, 1, "The unit test market item is incorrectly stocked. Only one should be in stock")

	var/mob/living/user = allocate(/mob/living)
	var/obj/item/holochip/chip = allocate(/obj/item/holochip, run_loc_floor_bottom_left, INFINITY)
	var/obj/machinery/ltsrbt/pad = allocate(/obj/machinery/ltsrbt)

	pad.item_interaction(user, chip)

	TEST_ASSERT_EQUAL(item, category_items[category_items[1]], "The unit test market item has been replaced during restock")
	TEST_ASSERT_EQUAL(item.stock, 2, "The unit test market item is incorrectly stocked after restock. There should be two in stock")

/datum/market/unit_test
	name = "Unit Test Market"
	shipping = list(SHIPPING_METHOD_TELEPORT = 0)

/datum/market_item/unit_test
	name = "Your Own Special Singularity"
	desc = "ALL HAIL LORD SINGULOTH!!!"
	category = CATEGORY_CODERBUS
	markets = list(/datum/market/unit_test)
	item = /obj/singularity
	price = 42069
	stock_min = 1
	stock = 1
	stock_max = 2
	availability_prob = 100

/// Orders use the buyer's current ID and include delivery in the balance check.
/datum/unit_test/market_purchase_account

/datum/unit_test/market_purchase_account/Run()
	var/datum/market/unit_test/market = allocate(/datum/market/unit_test)
	var/datum/market_item/unit_test/item = allocate(/datum/market_item/unit_test)
	item.price = 100
	market.shipping = list(SHIPPING_METHOD_TELEPORT = 20)
	market.add_item(item)

	var/mob/living/carbon/human/buyer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/market_uplink/blackmarket/uplink = allocate(/obj/item/market_uplink/blackmarket)
	TEST_ASSERT(!market.purchase(item.identifier, item.category, SHIPPING_METHOD_TELEPORT, uplink, buyer), "Purchase accepted without a bank account.")
	TEST_ASSERT_EQUAL(item.stock, 1, "Denied purchase changed the stock.")

	var/datum/job/assistant/job = SSjob.get_job_type(/datum/job/assistant)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Market buyer", job)
	buyer.account_id = account.account_id
	TEST_ASSERT(buyer.add_quirk(/datum/quirk/well_connected), "Could not add Well Connected.")
	var/obj/item/card/id/id_card = allocate(/obj/item/card/id/advanced)
	id_card.set_account(account)
	TEST_ASSERT(buyer.put_in_active_hand(id_card), "Could not put the buyer's ID in their hand.")

	account.account_balance = 99
	TEST_ASSERT(!market.purchase(item.identifier, item.category, SHIPPING_METHOD_TELEPORT, uplink, buyer), "The discounted price plus delivery exceeded the balance.")
	TEST_ASSERT_EQUAL(item.stock, 1, "An unaffordable purchase changed the stock.")
	TEST_ASSERT_EQUAL(account.account_balance, 99, "An unaffordable purchase charged the account.")

	account.account_balance = 100
	TEST_ASSERT(!market.purchase(item.identifier, item.category, SHIPPING_METHOD_TELEPORT, uplink, buyer, 95), "Purchase accepted a different total than the buyer confirmed.")
	TEST_ASSERT_EQUAL(account.account_balance, 100, "A rejected quote charged the account.")
	TEST_ASSERT(market.purchase(item.identifier, item.category, SHIPPING_METHOD_TELEPORT, uplink, buyer, 100), "The account could afford the discounted item and delivery.")
	TEST_ASSERT_EQUAL(item.stock, 0, "The purchase did not reserve one item.")
	TEST_ASSERT_EQUAL(account.account_balance, 0, "The purchase did not charge 80 credits plus 20 for delivery.")

	var/mob/living/carbon/human/backup_body = allocate(/mob/living/carbon/human/consistent)
	buyer.transfer_quirk_datums(backup_body)
	TEST_ASSERT_EQUAL(item.get_purchase_price(account), 80, "Transferring the quirk to a new body removed the account's discount.")
	backup_body.remove_quirk(/datum/quirk/well_connected)
	TEST_ASSERT_EQUAL(item.get_purchase_price(account), 100, "Removing the quirk should restore the undiscounted price.")
	qdel(uplink)

#undef CATEGORY_CODERBUS

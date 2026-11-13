/// Who places orders: a Nanotrasen division keeping the result, or a corporation buying it.
/datum/expedition_customer
	/// Display name.
	var/name
	/// The station keeps the result of a Nanotrasen order; a corporation buys what it ordered.
	var/nanotrasen = TRUE
	/// Order types this customer places.
	var/list/contract_types = list()
	/// Hidden research node a corporation opens after its first fulfilled contract.
	var/reward_node
	/// Special cargo pack a corporation enables after its first fulfilled contract.
	var/reward_pack
	/// The one-time reward for the first fulfilled contract was paid.
	var/rewarded = FALSE

/// Nanotrasen's research and development division.
/datum/expedition_customer/ntfid
	name = "NTFID"
	contract_types = list(/datum/expedition_contract/survey, /datum/expedition_contract/field_artefact)

/// Nanotrasen's mining and refining division.
/datum/expedition_customer/nthi
	name = "NTHI"
	contract_types = list(/datum/expedition_contract/core_sample, /datum/expedition_contract/large_find)

/// Nanotrasen's medical division.
/datum/expedition_customer/deforest
	name = "Nanotrasen-DeForest"
	contract_types = list(/datum/expedition_contract/containment)

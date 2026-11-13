/obj/item/encryptionkey/expedition
	name = "ключ шифрования экспедиционного корпуса"
	channels = list(RADIO_CHANNEL_EXPEDITION = 1)

/obj/item/encryptionkey/expedition/leader
	name = "ключ шифрования главы экспедиционного корпуса"
	channels = list(RADIO_CHANNEL_EXPEDITION = 1, RADIO_CHANNEL_COMMAND = 1)

// Keep the mapped headset path; its key now belongs to the independent corps.
/obj/item/radio/headset/headset_cargo/explorer
	name = "гарнитура экспедиционного корпуса"
	desc = "Гарнитура корпуса с коротковолновым режимом для связи на одном уровне без станционной сети."
	keyslot = /obj/item/encryptionkey/expedition
	subspace_switchable = TRUE

/obj/item/radio/headset/headset_cargo/explorer/leader
	name = "гарнитура главы экспедиционного корпуса"
	keyslot = /obj/item/encryptionkey/expedition/leader
	command = TRUE

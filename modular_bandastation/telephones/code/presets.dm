/// Recolors the telephone bodies and handsets without tinting their status lights.
/datum/greyscale_config/transmitter
	name = "Telephone"
	icon_file = 'modular_bandastation/telephones/icons/phone.dmi'
	json_config = 'code/datums/greyscale/json_configs/telephone.json'

/// A public payphone that can place calls but is absent from the telephone directory.
/obj/structure/transmitter/mounted
	name = "wallmount telephone"
	desc = "Настенный таксофон. Принимает монеты и банковские карты."
	icon_state = "wall_phone"
	post_init_icon_state = "wall_phone"
	is_free = FALSE
	is_advanced = FALSE
	greyscale_colors = "#6e7766"
	phone_category = null
	anchored = TRUE

/obj/structure/transmitter/mounted/Initialize(mapload)
	. = ..()
	if(mapload && !find_and_mount_on_atom(mark_for_late_init = TRUE))
		return INITIALIZE_HINT_LATELOAD

/obj/structure/transmitter/mounted/LateInitialize()
	find_and_mount_on_atom(late_init = TRUE)

MAPPING_DIRECTIONAL_HELPERS(/obj/structure/transmitter/mounted, 24)

/// A private office line that can call public, command and bridge phones.
/obj/structure/transmitter/command
	phone_category = PHONE_NET_COMMAND
	networks_transmit = list(PHONE_NET_PUBLIC, PHONE_NET_COMMAND, PHONE_NET_BRIDGE)
	greyscale_colors = "#8198E1"
	phone_icon = "shield-halved"
	was_renamed = TRUE

/// The bridge line is the station's outgoing connection to Central Command.
/obj/structure/transmitter/bridge
	phone_category = PHONE_NET_BRIDGE
	networks_transmit = list(PHONE_NET_PUBLIC, PHONE_NET_COMMAND, PHONE_NET_CENTCOM)
	greyscale_colors = "#CB3E3E"
	phone_icon = "shield-halved"
	was_renamed = TRUE

/// Engineering's public line can also reach command offices.
/obj/structure/transmitter/engineering
	phone_category = PHONE_NET_PUBLIC
	networks_transmit = list(PHONE_NET_PUBLIC, PHONE_NET_COMMAND)
	greyscale_colors = COLOR_ENGINEERING_ORANGE
	phone_icon = "gear"
	was_renamed = TRUE

/// Cargo's public telephone.
/obj/structure/transmitter/cargo
	greyscale_colors = COLOR_CARGO_BROWN
	phone_icon = "boxes-stacked"
	was_renamed = TRUE

/// Medical's public telephone.
/obj/structure/transmitter/medbay
	greyscale_colors = COLOR_MEDICAL_BLUE
	phone_icon = "kit-medical"
	was_renamed = TRUE

/// Security's public line can also reach command offices.
/obj/structure/transmitter/security
	networks_transmit = list(PHONE_NET_PUBLIC, PHONE_NET_COMMAND)
	greyscale_colors = COLOR_SECURITY_RED
	phone_icon = "user-secret"
	was_renamed = TRUE

/// Science's public telephone.
/obj/structure/transmitter/science
	greyscale_colors = COLOR_SCIENCE_PINK
	phone_icon = "flask"
	was_renamed = TRUE

/// Service's public telephone.
/obj/structure/transmitter/service
	greyscale_colors = COLOR_SERVICE_LIME
	phone_icon = "bell-concierge"
	was_renamed = TRUE

/// Central Command can reach every directory category, including the bridge.
/obj/structure/transmitter/centcom
	phone_category = PHONE_NET_CENTCOM
	networks_transmit = list(PHONE_NET_PUBLIC, PHONE_NET_COMMAND, PHONE_NET_BRIDGE, PHONE_NET_CENTCOM, PHONE_NET_SYNDICATE)
	greyscale_colors = "#415F78"
	phone_icon = "closed-captioning"

/// A player-built business can order a public telephone through cargo.
/datum/supply_pack/imports/telephone
	name = "Стационарный телефон"
	desc = "Один стационарный телефон для связи по станционной телефонной сети."
	cost = CARGO_CRATE_VALUE
	crate_name = "стационарный телефон"
	crate_type = /obj/structure/closet/crate
	contains = list(/obj/structure/transmitter)

/datum/instrument
	var/list/pcm_samples

/datum/instrument/hardcoded/Initialize()
	. = ..()
	if(legacy_instrument_ext != "mid")
		return
	var/static/list/banks = list(
		"accordion" = list('modular_bandastation/music/sound/legacy/accordion/c3.ogg', 'modular_bandastation/music/sound/legacy/accordion/c4.ogg', 'modular_bandastation/music/sound/legacy/accordion/c5.ogg'),
		"glockenspiel" = list('modular_bandastation/music/sound/legacy/glockenspiel/c3.ogg', 'modular_bandastation/music/sound/legacy/glockenspiel/c4.ogg', 'modular_bandastation/music/sound/legacy/glockenspiel/c5.ogg'),
		"harmonica" = list('modular_bandastation/music/sound/legacy/harmonica/c3.ogg', 'modular_bandastation/music/sound/legacy/harmonica/c4.ogg', 'modular_bandastation/music/sound/legacy/harmonica/c5.ogg'),
		"recorder" = list('modular_bandastation/music/sound/legacy/recorder/c3.ogg', 'modular_bandastation/music/sound/legacy/recorder/c4.ogg', 'modular_bandastation/music/sound/legacy/recorder/c5.ogg'),
		"saxophone" = list('modular_bandastation/music/sound/legacy/saxophone/c3.ogg', 'modular_bandastation/music/sound/legacy/saxophone/c4.ogg', 'modular_bandastation/music/sound/legacy/saxophone/c5.ogg'),
		"trombone" = list('modular_bandastation/music/sound/legacy/trombone/c3.ogg', 'modular_bandastation/music/sound/legacy/trombone/c4.ogg', 'modular_bandastation/music/sound/legacy/trombone/c5.ogg'),
		"violin" = list('modular_bandastation/music/sound/legacy/violin/c3.ogg', 'modular_bandastation/music/sound/legacy/violin/c4.ogg', 'modular_bandastation/music/sound/legacy/violin/c5.ogg'),
		"xylophone" = list('modular_bandastation/music/sound/legacy/xylophone/c3.ogg', 'modular_bandastation/music/sound/legacy/xylophone/c4.ogg', 'modular_bandastation/music/sound/legacy/xylophone/c5.ogg')
	)
	var/list/bank = banks[id]
	if(!bank)
		return
	pcm_samples = list()
	for(var/key in 0 to 127)
		var/base = key < 54 ? 48 : (key < 66 ? 60 : 72)
		pcm_samples[num2text(key)] = new /datum/instrument_key(bank[(base - 48) / 12 + 1], key, key - base)

/datum/song/proc/get_music_sample(key, datum/instrument/instrument = using_instrument)
	if(QDELETED(instrument))
		return null
	if(!(instrument.instrument_flags & INSTRUMENT_LEGACY))
		return instrument.samples?[num2text(key)]
	if(instrument.pcm_samples?[num2text(key)])
		return instrument.pcm_samples[num2text(key)]
	if(instrument.legacy_instrument_ext != "ogg")
		return null
	var/static/list/names = list("Cn", "Db", "Dn", "Eb", "En", "Fn", "Gb", "Gn", "Ab", "An", "Bb", "Bn")
	var/path = "sound/runtime/instruments/[instrument.legacy_instrument_path]/[names[key % 12 + 1]][floor(key / 12) - 1].ogg"
	if(!fexists(path))
		return null
	LAZYINITLIST(instrument.pcm_samples)
	var/datum/instrument_key/sample = new(file(path), key, 0)
	instrument.pcm_samples[num2text(key)] = sample
	return sample


/datum/instrument/Destroy()
	pcm_samples = null
	return ..()

import { type MidiData, type MidiEvent, parseMidi, writeMidi } from 'midi-file';

export type Note = {
  time: number;
  duration: number;
  key: number;
  velocity: number;
  channel: number;
  track: number;
};
export type MidiTrack = {
  id: number;
  name: string;
  instrument?: string | null;
  muted?: boolean | 0 | 1;
};
export type MusicDocument = {
  version: 1;
  title: string;
  notes: Note[];
  tempos: { time: number; bpm: number }[];
  tracks: MidiTrack[];
};

const trackMetadataPrefix = 'CP13:track:';

function readTrackMetadata(
  data: ArrayLike<number>,
): Partial<Omit<MidiTrack, 'id'>> {
  if (data[0] !== 0x7d) return {};
  const text = new TextDecoder().decode(
    new Uint8Array(Array.from(data).slice(1)),
  );
  if (!text.startsWith(trackMetadataPrefix)) return {};
  const value = JSON.parse(text.slice(trackMetadataPrefix.length));
  if (
    !value ||
    typeof value !== 'object' ||
    Array.isArray(value) ||
    (value.name !== undefined &&
      (typeof value.name !== 'string' || value.name.length > 64)) ||
    (value.instrument != null &&
      (typeof value.instrument !== 'string' ||
        !value.instrument.length ||
        value.instrument.length > 200)) ||
    (value.muted !== undefined && typeof value.muted !== 'boolean')
  )
    throw new Error('Invalid CP13 MIDI track settings.');
  return { name: value.name, instrument: value.instrument, muted: value.muted };
}

export function removeMidiTrack(doc: MusicDocument, id: number): MusicDocument {
  return {
    ...doc,
    tracks: doc.tracks.filter((track) => track.id !== id),
    notes: doc.notes.filter((note) => note.track !== id),
  };
}

export function resolveMidiInstruments(
  doc: MusicDocument,
  defaultInstrument?: string | null,
): MusicDocument {
  return {
    ...doc,
    tracks: doc.tracks.map((track) => ({
      ...track,
      instrument: track.instrument ?? defaultInstrument ?? null,
    })),
  };
}

export function midiView(doc: MusicDocument, track?: number) {
  const selectedTrack = track ?? doc.notes[0]?.track ?? doc.tracks[0]?.id ?? 0;
  const notes = doc.notes.filter((note) => note.track === selectedTrack);
  const baseKey = notes.length
    ? Math.floor(Math.min(...notes.map((note) => note.key)) / 12) * 12
    : 48;
  const highest = Math.max(baseKey + 23, ...notes.map((note) => note.key));
  const keyCount = Math.min(
    128 - baseKey,
    Math.ceil((highest - baseKey + 1) / 12) * 12,
  );
  const duration = Math.max(
    10,
    ...doc.notes.map((note) => note.time + note.duration),
  );
  return {
    track: selectedTrack,
    baseKey,
    keyCount,
    zoom: 720 / duration,
    duration,
  };
}

export function validateDocument(
  value: MusicDocument,
  allowedInstruments?: readonly string[],
) {
  if (
    value?.version !== 1 ||
    typeof value.title !== 'string' ||
    !Array.isArray(value.notes) ||
    !Array.isArray(value.tracks) ||
    !Array.isArray(value.tempos) ||
    value.notes.length > 4096 ||
    value.tracks.length > 128 ||
    value.tempos.length > 1024
  )
    throw new Error('Invalid MIDI project.');
  if (!value.tempos.length || value.tempos[0].time !== 0)
    throw new Error('A tempo at time zero is required.');
  if (
    value.tempos.some(
      (t) =>
        !Number.isFinite(t.time) ||
        !Number.isFinite(t.bpm) ||
        t.time < 0 ||
        t.time > 1800 ||
        t.bpm < 1 ||
        t.bpm > 1000,
    )
  )
    throw new Error('Invalid tempo map.');
  if (
    value.tracks.some(
      (t) =>
        !t ||
        !Number.isInteger(t.id) ||
        t.id < 0 ||
        t.id > 127 ||
        typeof t.name !== 'string' ||
        (t.instrument != null &&
          (typeof t.instrument !== 'string' ||
            !t.instrument.length ||
            t.instrument.length > 200)) ||
        (t.muted !== undefined &&
          typeof t.muted !== 'boolean' &&
          t.muted !== 0 &&
          t.muted !== 1),
    ) ||
    new Set(value.tracks.map((track) => track.id)).size !== value.tracks.length
  )
    throw new Error('Invalid track.');
  if (allowedInstruments) {
    const unavailable = value.tracks.find(
      (track) =>
        track.instrument && !allowedInstruments.includes(track.instrument),
    );
    if (unavailable)
      throw new Error(
        `Instrument unavailable for track "${unavailable.name}": ${unavailable.instrument}`,
      );
  }
  if (
    value.notes.some(
      (n) =>
        !n ||
        Object.values(n).some((v) => !Number.isFinite(v)) ||
        !Number.isFinite(n.time) ||
        !Number.isFinite(n.duration) ||
        n.time < 0 ||
        n.duration <= 0 ||
        n.time + n.duration > 1800 ||
        !Number.isInteger(n.key) ||
        n.key < 0 ||
        n.key > 127 ||
        !Number.isInteger(n.velocity) ||
        n.velocity < 1 ||
        n.velocity > 127 ||
        !Number.isInteger(n.channel) ||
        n.channel < 0 ||
        n.channel > 15 ||
        !value.tracks.some((t) => t.id === n.track),
    )
  )
    throw new Error('Invalid note or composition exceeds 30 minutes.');
}

/// Preserve musical tick positions when editing a tempo marker.
export function editTempo(
  doc: MusicDocument,
  index: number,
  time: number,
  bpm: number | null,
): MusicDocument {
  const oldTempos = [...doc.tempos].sort((a, b) => a.time - b.time);
  const toTick = (seconds: number) => {
    let ticks = 0;
    let previous = 0;
    let speed = 120;
    for (const tempo of oldTempos) {
      if (tempo.time > seconds) break;
      ticks += (tempo.time - previous) * speed * 8;
      previous = tempo.time;
      speed = tempo.bpm;
    }
    return ticks + (seconds - previous) * speed * 8;
  };
  const markers = oldTempos
    .map((t, i) => ({
      tick: toTick(i === index ? time : t.time),
      bpm: i === index && bpm !== null ? bpm : t.bpm,
    }))
    .filter((_, i) => bpm !== null || i !== index);
  if (index >= oldTempos.length && bpm !== null)
    markers.push({ tick: toTick(time), bpm });
  markers.sort((a, b) => a.tick - b.tick);
  const fromTick = (ticks: number) => {
    let seconds = 0;
    let previous = 0;
    let speed = 120;
    for (const marker of markers) {
      if (marker.tick > ticks) break;
      seconds += (marker.tick - previous) / (speed * 8);
      previous = marker.tick;
      speed = marker.bpm;
    }
    return seconds + (ticks - previous) / (speed * 8);
  };
  return {
    ...doc,
    tempos: markers.map((m) => ({ time: fromTick(m.tick), bpm: m.bpm })),
    notes: doc.notes.map((n) => {
      const start = fromTick(toTick(n.time));
      return {
        ...n,
        time: start,
        duration: fromTick(toTick(n.time + n.duration)) - start,
      };
    }),
  };
}

export function readMidi(bytes: Uint8Array, title: string): MusicDocument {
  const midi = parseMidi(bytes);
  if (midi.header.format === 2 || midi.tracks.length > 128) {
    throw new Error(
      'Only simultaneous MIDI formats 0/1 with up to 128 tracks are supported.',
    );
  }
  const ticksPerBeat = midi.header.ticksPerBeat || 480;
  const fixedRate =
    (midi.header.framesPerSecond || 0) * (midi.header.ticksPerFrame || 0);
  const tempoEvents: { tick: number; bpm: number }[] = [{ tick: 0, bpm: 120 }];
  const absolute = midi.tracks.map((track) => {
    let tick = 0;
    return track.map((event) => {
      tick += event.deltaTime;
      if (event.type === 'setTempo') {
        tempoEvents.push({ tick, bpm: 60000000 / event.microsecondsPerBeat });
      }
      return { tick, event };
    });
  });
  tempoEvents.sort((a, b) => a.tick - b.tick);
  const tempoMap = tempoEvents
    .filter((entry, index) => tempoEvents[index + 1]?.tick !== entry.tick)
    .filter(
      (entry, index, entries) => !index || entry.bpm !== entries[index - 1].bpm,
    );
  const tickToTime = (tick: number) => {
    if (fixedRate) return tick / fixedRate;
    let time = 0;
    let previous = 0;
    let bpm = 120;
    for (const entry of tempoMap) {
      if (entry.tick > tick) break;
      time += ((entry.tick - previous) * 60) / (ticksPerBeat * bpm);
      previous = entry.tick;
      bpm = entry.bpm;
    }
    return time + ((tick - previous) * 60) / (ticksPerBeat * bpm);
  };
  const notes: Note[] = [];
  const tracks = absolute.map((events, track) => {
    let name = `Track ${track + 1}`;
    let settings: Partial<Omit<MidiTrack, 'id'>> = {};
    const active = new Map<string, { tick: number; velocity: number }[]>();
    for (const { tick, event } of events) {
      if (event.type === 'trackName') name = event.text;
      if (event.type === 'sequencerSpecific')
        settings = { ...settings, ...readTrackMetadata(event.data) };
      if (event.type !== 'noteOn' && event.type !== 'noteOff') continue;
      const id = `${event.channel}:${event.noteNumber}`;
      if (event.type === 'noteOn' && event.velocity > 0) {
        const queue = active.get(id) || [];
        queue.push({ tick, velocity: event.velocity });
        active.set(id, queue);
      } else {
        const start = active.get(id)?.shift();
        if (!start) continue;
        notes.push({
          time: tickToTime(start.tick),
          duration: Math.max(0.01, tickToTime(tick) - tickToTime(start.tick)),
          key: event.noteNumber,
          velocity: start.velocity,
          channel: event.channel,
          track,
        });
      }
    }
    return {
      id: track,
      ...settings,
      name: (settings.name ?? name).slice(0, 64),
    };
  });
  if (notes.length > 4096 || notes.some((n) => n.time + n.duration > 1800)) {
    throw new Error('Maximum 4096 notes and 30 minutes per composition.');
  }
  const tempos = fixedRate
    ? [{ time: 0, bpm: 120 }]
    : tempoMap.map((t) => ({ time: tickToTime(t.tick), bpm: t.bpm }));
  return {
    version: 1,
    title: title.slice(0, 80),
    notes: notes.sort((a, b) => a.time - b.time),
    tempos,
    tracks,
  };
}

export function exportMidi(doc: MusicDocument): Uint8Array {
  validateDocument(doc);
  const tempos = [...doc.tempos].sort((a, b) => a.time - b.time);
  const toTick = (time: number) => {
    let tick = 0;
    let previous = 0;
    let bpm = 120;
    for (const tempo of tempos) {
      if (tempo.time > time) break;
      tick += ((tempo.time - previous) * bpm * 480) / 60;
      previous = tempo.time;
      bpm = tempo.bpm;
    }
    return Math.round(tick + ((time - previous) * bpm * 480) / 60);
  };
  const deltaTrack = (events: { tick: number; event: MidiEvent }[]) => {
    events.sort(
      (a, b) =>
        a.tick - b.tick ||
        Number(b.event.type === 'noteOff') - Number(a.event.type === 'noteOff'),
    );
    let previous = 0;
    const result = events.map(({ tick, event }) => {
      const next = { ...event, deltaTime: tick - previous };
      previous = tick;
      return next;
    });
    result.push({ deltaTime: 0, type: 'endOfTrack', meta: true });
    return result;
  };
  const midi: MidiData = {
    header: {
      format: 1,
      numTracks: Math.max(1, doc.tracks.length),
      ticksPerBeat: 480,
    },
    tracks: [],
  };
  const tempoEvents: { tick: number; event: MidiEvent }[] = tempos.map(
    (tempo) => ({
      tick: toTick(tempo.time),
      event: {
        deltaTime: 0,
        type: 'setTempo',
        meta: true,
        microsecondsPerBeat: Math.round(60000000 / tempo.bpm),
      },
    }),
  );
  for (const [index, track] of doc.tracks.entries()) {
    const events: { tick: number; event: MidiEvent }[] = [
      {
        tick: 0,
        event: {
          deltaTime: 0,
          type: 'trackName',
          meta: true,
          text: track.name,
        },
      },
    ];
    events.push({
      tick: 0,
      event: {
        deltaTime: 0,
        type: 'sequencerSpecific',
        meta: true,
        data: [
          0x7d,
          ...new TextEncoder().encode(
            trackMetadataPrefix +
              JSON.stringify({
                name: track.name.slice(0, 64),
                instrument: track.instrument,
                muted: !!track.muted,
              }),
          ),
        ],
      },
    });
    if (index === 0) events.push(...tempoEvents);
    for (const note of doc.notes.filter((n) => n.track === track.id)) {
      events.push({
        tick: toTick(note.time),
        event: {
          deltaTime: 0,
          type: 'noteOn',
          channel: note.channel,
          noteNumber: note.key,
          velocity: note.velocity,
        },
      });
      events.push({
        tick: toTick(note.time + note.duration),
        event: {
          deltaTime: 0,
          type: 'noteOff',
          channel: note.channel,
          noteNumber: note.key,
          velocity: 0,
        },
      });
    }
    midi.tracks.push(deltaTrack(events));
  }
  if (!doc.tracks.length) midi.tracks.push(deltaTrack(tempoEvents));
  return new Uint8Array(writeMidi(midi));
}

export function download(
  name: string,
  data: string | Uint8Array,
  type: string,
) {
  const blob = new Blob(
    [typeof data === 'string' ? data : new Uint8Array(data)],
    { type },
  );
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

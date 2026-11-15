import { describe, expect, it } from 'bun:test';
import { writeMidi } from 'midi-file';
import {
  exportMidi,
  type MusicDocument,
  midiView,
  readMidi,
  removeMidiTrack,
  resolveMidiInstruments,
  validateDocument,
} from './midi';
import { splitMusicDocument } from './upload';

function longMidi() {
  return new Uint8Array(
    writeMidi({
      header: { format: 1, numTracks: 3, ticksPerBeat: 960 },
      tracks: [
        [
          {
            deltaTime: 0,
            type: 'setTempo',
            meta: true,
            microsecondsPerBeat: 625000,
          },
          { deltaTime: 0, type: 'endOfTrack', meta: true },
        ],
        ...[0, 1].map((channel) => [
          ...Array.from({ length: 1500 }, (_, index) => [
            {
              deltaTime: index === 0 ? 0 : 120,
              type: 'noteOn' as const,
              channel,
              noteNumber: 36 + (index % 48),
              velocity: 100,
            },
            {
              deltaTime: 120,
              type: 'noteOff' as const,
              channel,
              noteNumber: 36 + (index % 48),
              velocity: 0,
            },
          ]).flat(),
          { deltaTime: 0, type: 'endOfTrack' as const, meta: true as const },
        ]),
      ],
    }),
  );
}

describe('large MIDI projects', () => {
  it('preserves all notes and the end of every simultaneous track', () => {
    const doc = readMidi(longMidi(), 'Long composition');
    validateDocument(doc);
    expect(doc.notes.length).toBe(3000);
    expect(doc.notes.filter((note) => note.track === 1).length).toBe(1500);
    expect(doc.notes.filter((note) => note.track === 2).length).toBe(1500);
    expect(midiView(doc).duration).toBeCloseTo(234.296875);
    const exported = readMidi(exportMidi(doc), 'Round trip');
    expect(exported.notes.length).toBe(3000);
    expect(midiView(exported).duration).toBeCloseTo(midiView(doc).duration);
  });

  it('opens a note-bearing track and fits its full time and pitch range', () => {
    const doc = readMidi(longMidi(), 'Long composition');
    const view = midiView(doc);
    expect(view.track).toBe(1);
    expect(view.baseKey).toBe(36);
    expect(view.keyCount).toBe(48);
    expect(720 / view.zoom).toBeCloseTo(view.duration);
    expect(view.zoom).toBeLessThan(10);
  });

  it('transfers a full project in bounded, lossless parts', () => {
    const doc = readMidi(longMidi(), 'Long composition');
    const parts = splitMusicDocument(doc);
    expect(JSON.stringify(doc).length).toBeGreaterThan(200000);
    expect(parts.length).toBeGreaterThan(1);
    expect(JSON.parse(parts.join(''))).toEqual(doc);
    for (const [index, part] of parts.entries()) {
      const payload = {
        id: 'test',
        index,
        count: parts.length,
        kind: 'sequence',
        part,
        play_action: 'play_music',
      };
      expect(encodeURIComponent(JSON.stringify(payload)).length).toBeLessThan(
        10000,
      );
      expect(part.length).toBeLessThanOrEqual(8192);
    }
  });

  it('preserves Unicode and escaping without oversized TGUI actions', () => {
    const doc = {
      lyrics:
        '\u041f\u0435\u0441\u043d\u044f \ud83c\udfb5 "quoted" \\ \n'.repeat(
          2000,
        ),
    };
    const parts = splitMusicDocument(doc);
    expect(JSON.parse(parts.join(''))).toEqual(doc);
    for (const part of parts) {
      expect(encodeURIComponent(JSON.stringify({ part })).length).toBeLessThan(
        9000,
      );
    }
  });

  it('rejects oversized projects before starting a transfer', () => {
    expect(() => splitMusicDocument({ text: 'x'.repeat(600000) })).toThrow();
  });
});

describe('MIDI track arrangements', () => {
  const arrangement = (): MusicDocument => ({
    version: 1,
    title: 'Two guitars',
    tempos: [{ time: 0, bpm: 120 }],
    tracks: [
      { id: 0, name: '\u0420\u0438\u0442\u043c', instrument: 'cshrockgt' },
      { id: 2, name: 'Bass', instrument: 'cshbassgt', muted: 0 },
      { id: 7, name: 'Vocal', muted: true },
    ],
    notes: [
      { time: 0, duration: 1, key: 60, velocity: 100, channel: 0, track: 0 },
      { time: 0, duration: 1, key: 36, velocity: 100, channel: 0, track: 2 },
      { time: 1, duration: 1, key: 72, velocity: 100, channel: 1, track: 7 },
    ],
  });

  it('keeps per-track instruments and mute states in exported projects', () => {
    const doc = arrangement();
    const restored = JSON.parse(JSON.stringify(doc));
    validateDocument(restored, ['cshrockgt', 'cshbassgt']);
    expect(restored).toEqual(doc);
  });

  it('captures the current default timbre when exporting an arrangement', () => {
    const doc = arrangement();
    const snapshot = resolveMidiInstruments(doc, 'cshmetalgt');
    expect(snapshot.tracks.map((track) => track.instrument)).toEqual([
      'cshrockgt',
      'cshbassgt',
      'cshmetalgt',
    ]);
    expect(doc.tracks[2].instrument).toBeUndefined();
    const restored = readMidi(exportMidi(snapshot), doc.title);
    expect(restored.tracks[2].instrument).toBe('cshmetalgt');
  });

  it('restores exact CP13 instruments, Unicode names and mute settings from MIDI', () => {
    const doc = arrangement();
    const restored = readMidi(exportMidi(doc), doc.title);
    validateDocument(restored, ['cshrockgt', 'cshbassgt']);
    expect(
      restored.tracks.map(({ name, instrument, muted }) => ({
        name,
        instrument,
        muted,
      })),
    ).toEqual([
      {
        name: '\u0420\u0438\u0442\u043c',
        instrument: 'cshrockgt',
        muted: false,
      },
      { name: 'Bass', instrument: 'cshbassgt', muted: false },
      { name: 'Vocal', instrument: undefined, muted: true },
    ]);
    expect(
      restored.notes.map(({ key, track }) => [
        key,
        restored.tracks.find((item) => item.id === track)?.name,
      ]),
    ).toEqual([
      [60, '\u0420\u0438\u0442\u043c'],
      [36, 'Bass'],
      [72, 'Vocal'],
    ]);
  });

  it('removes only the deleted track, even when another track shares its channel', () => {
    const doc = arrangement();
    const next = removeMidiTrack(doc, 0);
    expect(next.tracks.map((track) => track.id)).toEqual([2, 7]);
    expect(next.notes.map((note) => note.track)).toEqual([2, 7]);
    expect(next.tracks[0].instrument).toBe('cshbassgt');
    expect(doc.notes.length).toBe(3);
    expect(doc.tracks.length).toBe(3);
    const restored = readMidi(exportMidi(next), next.title);
    expect(restored.tracks.map((track) => track.name)).toEqual([
      'Bass',
      'Vocal',
    ]);
    expect(restored.notes.length).toBe(2);
  });

  it('rejects unavailable instruments, duplicate IDs and orphan notes', () => {
    const doc = arrangement();
    expect(() => validateDocument(doc, ['cshrockgt'])).toThrow('Bass');
    expect(() =>
      validateDocument({ ...doc, tracks: [...doc.tracks, doc.tracks[0]] }),
    ).toThrow();
    expect(() =>
      validateDocument({ ...doc, tracks: doc.tracks.slice(1) }),
    ).toThrow();
    expect(() =>
      validateDocument({
        ...doc,
        tracks: [{ id: 0, name: 'Bad', muted: 2 } as never],
      }),
    ).toThrow();
  });

  it('accepts old projects with no per-track settings', () => {
    const doc = readMidi(longMidi(), 'Old MIDI');
    validateDocument(doc, ['cshrockgt']);
    expect(doc.tracks.every((track) => track.instrument === undefined)).toBe(
      true,
    );
  });

  it('does not add empty tracks or tempo markers on repeated MIDI round trips', () => {
    let doc = readMidi(longMidi(), 'Round trips');
    const count = doc.tracks.length;
    const tempos = doc.tempos.length;
    for (let index = 0; index < 5; index++)
      doc = readMidi(exportMidi(doc), doc.title);
    expect(doc.tracks.length).toBe(count);
    expect(doc.tempos.length).toBe(tempos);
    expect(doc.notes.length).toBe(3000);
  });

  it('exports all 128 tracks without creating an unimportable extra conductor track', () => {
    const doc = arrangement();
    doc.tracks = Array.from({ length: 128 }, (_, id) => ({
      id,
      name: `Track ${id}`,
    }));
    const restored = readMidi(exportMidi(doc), doc.title);
    expect(restored.tracks.length).toBe(128);
    expect(restored.notes.length).toBe(3);
  });

  it('allows deleting every track and later creating a new arrangement', () => {
    let doc = arrangement();
    for (const id of [0, 2, 7]) doc = removeMidiTrack(doc, id);
    validateDocument(doc);
    expect(doc.tracks).toEqual([]);
    expect(doc.notes).toEqual([]);
    expect(readMidi(exportMidi(doc), doc.title).notes).toEqual([]);
  });
});

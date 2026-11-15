import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Input,
  NumberInput,
  Section,
  Slider,
  Stack,
} from 'tgui-core/components';
import { musicDecimal, musicInteger } from './format';
import {
  download,
  editTempo,
  exportMidi,
  type MusicDocument,
  midiView,
  type Note,
  readMidi,
  removeMidiTrack,
  resolveMidiInstruments,
  validateDocument,
} from './midi';
import type { PlayAction } from './upload';

type Props = {
  commitRef: { current: ((action?: PlayAction) => boolean) | null };
  upload: (
    document: MusicDocument,
    action?: PlayAction,
    onComplete?: () => void,
  ) => void;
  pianoRoll?: boolean;
  uploading?: boolean;
  instruments: { id: string; name: string }[];
  defaultInstrument: string | null;
  document: MusicDocument;
  disabled: boolean;
  channels: number[];
  position: number;
  playing: boolean;
  act: (action: string, payload?: object) => void;
};
const empty: MusicDocument = {
  version: 1,
  title: 'Untitled',
  notes: [],
  tempos: [{ time: 0, bpm: 120 }],
  tracks: [{ id: 0, name: 'Track 1' }],
};

export function MidiEditor({
  commitRef,
  document: serverDocument,
  disabled,
  channels,
  position,
  act,
  upload,
  playing,
  instruments,
  defaultInstrument,
  pianoRoll = false,
  uploading = false,
}: Props) {
  const [doc, setDoc] = useState<MusicDocument>(serverDocument || empty);
  const [history, setHistory] = useState<MusicDocument[]>([]);
  const [future, setFuture] = useState<MusicDocument[]>([]);
  const [selection, setSelection] = useState<number[]>([]);
  const [track, setTrack] = useState(
    () => midiView(serverDocument || empty).track,
  );
  const [channel, setChannel] = useState(0);
  const [snap, setSnap] = useState(0.25);
  const [zoom, setZoom] = useState(
    () => midiView(serverDocument || empty).zoom,
  );
  const [baseKey, setBaseKey] = useState(
    () => midiView(serverDocument || empty).baseKey,
  );
  const [keyCount, setKeyCount] = useState(
    () => midiView(serverDocument || empty).keyCount,
  );
  const [follow, setFollow] = useState(true);
  const [viewTime, setViewTime] = useState(0);
  const [error, setError] = useState('');
  const [clipboard, setClipboard] = useState<Note[]>([]);
  const fileInput = useRef<HTMLInputElement>(null);
  const drag = useRef<{
    time: number;
    key: number;
    resize: boolean;
    original: MusicDocument;
    indexes: number[];
  } | null>(null);
  useEffect(() => {
    setDoc(serverDocument || empty);
    setHistory([]);
    setFuture([]);
    setSelection([]);
    setTrack((current) =>
      serverDocument?.notes.some((note) => note.track === current)
        ? current
        : midiView(serverDocument || empty).track,
    );
  }, [serverDocument]);
  const change = (next: MusicDocument) => {
    if (disabled) return;
    setHistory((old) => [...old.slice(-29), doc]);
    setFuture([]);
    setDoc(next);
  };
  const updateNote = (key: keyof Note, value: number) =>
    change({
      ...doc,
      notes: doc.notes.map((note, i) =>
        selection.includes(i) ? { ...note, [key]: value } : note,
      ),
    });
  const undo = () => {
    if (!history.length) return;
    setFuture([doc, ...future]);
    setDoc(history[history.length - 1]);
    setHistory(history.slice(0, -1));
    setSelection([]);
  };
  const redo = () => {
    if (!future.length) return;
    setHistory([...history, doc]);
    setDoc(future[0]);
    setFuture(future.slice(1));
    setSelection([]);
  };
  const commit = (action?: PlayAction, onComplete?: () => void) => {
    try {
      validateDocument(
        doc,
        instruments.map((instrument) => instrument.id),
      );
      upload(
        {
          ...doc,
          notes: [...doc.notes].sort((a, b) => a.time - b.time),
        },
        action,
        onComplete,
      );
      setError('');
      return true;
    } catch (e) {
      setError(String(e));
      return false;
    }
  };
  commitRef.current = commit;
  const exportDocument = (format: 'midi' | 'json') => {
    try {
      const snapshot = resolveMidiInstruments(doc, defaultInstrument);
      validateDocument(snapshot);
      if (format === 'midi')
        download('composition.mid', exportMidi(snapshot), 'audio/midi');
      else
        download(
          'composition.json',
          JSON.stringify(snapshot),
          'application/json',
        );
      setError('');
    } catch (err) {
      setError(String(err));
    }
  };
  const importFile = async (file?: File) => {
    if (!file) return;
    try {
      if (file.size > 2 * 1024 * 1024)
        throw new Error('Maximum MIDI file size: 2 MB.');
      const next = file.name.toLowerCase().endsWith('.json')
        ? (JSON.parse(await file.text()) as MusicDocument)
        : readMidi(new Uint8Array(await file.arrayBuffer()), file.name);
      if (
        next.version !== 1 ||
        !Array.isArray(next.notes) ||
        !Array.isArray(next.tracks) ||
        !Array.isArray(next.tempos) ||
        next.notes.length > 4096
      )
        throw new Error('Invalid MIDI project.');
      validateDocument(next);
      change(next);
      const view = midiView(next);
      setTrack(view.track);
      setChannel(
        next.notes.find((note) => note.track === view.track)?.channel || 0,
      );
      setBaseKey(view.baseKey);
      setKeyCount(view.keyCount);
      setZoom(view.zoom);
      setViewTime(0);
      setSelection([]);
      setError('');
    } catch (e) {
      setError(String(e));
    }
  };
  const quantize = (n: number) => Math.round(n / snap) * snap;
  const beatSeconds = 60 / (doc.tempos[0]?.bpm || 120);
  const snapSeconds = snap * beatSeconds;
  const snapTime = (n: number) =>
    Math.max(0, Math.round(n / snapSeconds) * snapSeconds);
  const selected = selection.length === 1 ? doc.notes[selection[0]] : undefined;
  const point = (e: React.PointerEvent<SVGSVGElement>) => {
    const rect = e.currentTarget.getBoundingClientRect();
    return {
      time: viewTime + ((e.clientX - rect.left) / rect.width) * (720 / zoom),
      key:
        baseKey +
        keyCount -
        1 -
        Math.floor(((e.clientY - rect.top) / rect.height) * keyCount),
    };
  };
  const maxTime = Math.max(10, ...doc.notes.map((n) => n.time + n.duration));
  const windowSeconds = 720 / zoom;
  const maxViewTime = Math.max(0, maxTime - windowSeconds);
  const rowHeight = 16;
  const rollHeight = rowHeight * keyCount;
  const gridSeconds =
    snapSeconds * Math.max(1, Math.ceil(windowSeconds / snapSeconds / 180));
  const trackNotes = doc.notes.filter((note) => note.track === track);
  const selectedTrack = doc.tracks.find((item) => item.id === track);
  const defaultOption = `Default: ${instruments.find((item) => item.id === defaultInstrument)?.name || 'Instrument'}`;
  const updateTrack = (patch: Partial<NonNullable<typeof selectedTrack>>) =>
    change({
      ...doc,
      tracks: doc.tracks.map((item) =>
        item.id === track ? { ...item, ...patch } : item,
      ),
    });
  const fit = () => {
    const view = midiView(doc, track);
    setBaseKey(view.baseKey);
    setKeyCount(view.keyCount);
    setZoom(view.zoom);
    setViewTime(0);
  };
  useEffect(() => {
    if (
      playing &&
      follow &&
      (position < viewTime || position >= viewTime + windowSeconds)
    ) {
      setViewTime(
        Math.min(
          maxViewTime,
          Math.floor(position / windowSeconds) * windowSeconds,
        ),
      );
    }
  }, [playing, follow, position, viewTime, windowSeconds, maxViewTime]);
  useEffect(() => {
    if (!doc.tracks.some((item) => item.id === track)) {
      setTrack(midiView(doc).track);
      setSelection([]);
    }
  }, [doc.tracks, track]);

  return (
    <Section title={doc.title} buttons={<Box>{doc.notes.length}/4096</Box>}>
      <Stack wrap align="center">
        <Stack.Item>
          <Button
            icon="file"
            tooltip="New MIDI"
            disabled={disabled}
            onClick={() => change(empty)}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="folder-open"
            tooltip="Import MIDI / JSON"
            disabled={disabled}
            onClick={() => fileInput.current?.click()}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="save"
            tooltip="Apply to instrument"
            disabled={disabled}
            onClick={() => commit()}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="download"
            tooltip="Export MIDI"
            onClick={() => exportDocument('midi')}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="file-export"
            tooltip="Export project"
            onClick={() => exportDocument('json')}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="undo"
            tooltip="Undo"
            disabled={disabled || !history.length}
            onClick={undo}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="redo"
            tooltip="Redo"
            disabled={disabled || !future.length}
            onClick={redo}
          />
        </Stack.Item>
        {!pianoRoll && (
          <Stack.Item>
            <Button
              icon="keyboard"
              disabled={uploading}
              onClick={() =>
                disabled
                  ? act('open_piano_roll')
                  : commit(undefined, () => act('open_piano_roll'))
              }
            >
              Piano roll
            </Button>
          </Stack.Item>
        )}
        {pianoRoll && (
          <>
            <Stack.Item>
              <Button
                icon="copy"
                tooltip="Copy selection"
                disabled={!selection.length}
                onClick={() =>
                  setClipboard(selection.map((i) => ({ ...doc.notes[i] })))
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="paste"
                tooltip="Paste at cursor"
                disabled={disabled || !clipboard.length}
                onClick={() => {
                  const start = Math.min(...clipboard.map((n) => n.time));
                  change({
                    ...doc,
                    notes: [
                      ...doc.notes,
                      ...clipboard.map((n) => ({
                        ...n,
                        time: n.time - start + viewTime,
                        track,
                      })),
                    ],
                  });
                }}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="trash"
                tooltip="Delete selection"
                disabled={disabled || !selection.length}
                onClick={() => {
                  change({
                    ...doc,
                    notes: doc.notes.filter((_, i) => !selection.includes(i)),
                  });
                  setSelection([]);
                }}
              />
            </Stack.Item>
          </>
        )}
      </Stack>
      <input
        ref={fileInput}
        type="file"
        accept=".mid,.midi,.json"
        style={{ display: 'none' }}
        onChange={(e) => {
          void importFile(e.target.files?.[0]);
          e.target.value = '';
        }}
      />
      {!!error && <Box color="bad">{error}</Box>}
      <Stack mt={1} align="center" wrap>
        <Stack.Item grow>
          <Input
            value={doc.title}
            maxLength={80}
            disabled={disabled}
            onChange={(value) => change({ ...doc, title: value })}
          />
        </Stack.Item>
        {pianoRoll && (
          <>
            <Stack.Item>
              BPM{' '}
              <NumberInput
                width="5em"
                minValue={1}
                maxValue={1000}
                step={1}
                format={musicInteger}
                value={doc.tempos[0]?.bpm || 120}
                disabled={disabled}
                onChange={(value) =>
                  change(editTempo(doc, 0, 0, Math.round(value)))
                }
              />
            </Stack.Item>
            <Stack.Item>
              Grid{' '}
              <NumberInput
                width="4em"
                minValue={0.0625}
                maxValue={4}
                step={0.0625}
                format={musicDecimal}
                value={snap}
                onChange={setSnap}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="magnet"
                tooltip="Quantize selection"
                disabled={disabled || !selection.length}
                onClick={() =>
                  change({
                    ...doc,
                    notes: doc.notes.map((n, i) =>
                      selection.includes(i)
                        ? {
                            ...n,
                            time: snapTime(n.time),
                            duration: Math.max(
                              snapSeconds,
                              snapTime(n.duration),
                            ),
                          }
                        : n,
                    ),
                  })
                }
              />
            </Stack.Item>
          </>
        )}
      </Stack>
      <Stack mt={1} wrap align="center">
        {doc.tracks.map((item) => (
          <Stack.Item key={item.id}>
            <Button
              selected={track === item.id}
              icon={item.muted ? 'volume-mute' : undefined}
              onClick={() => {
                const view = midiView(doc, item.id);
                setTrack(item.id);
                setBaseKey(view.baseKey);
                setKeyCount(view.keyCount);
                setChannel(
                  doc.notes.find((note) => note.track === item.id)?.channel ||
                    0,
                );
              }}
            >
              {item.name} (
              {doc.notes.filter((note) => note.track === item.id).length})
            </Button>
          </Stack.Item>
        ))}
        <Stack.Item>
          <Button
            icon="plus"
            tooltip="Add track"
            disabled={disabled || doc.tracks.length >= 128}
            onClick={() => {
              const id =
                Array.from({ length: 128 }, (_, i) => i).find(
                  (i) => !doc.tracks.some((t) => t.id === i),
                ) ?? 0;
              change({
                ...doc,
                tracks: [...doc.tracks, { id, name: `Track ${id + 1}` }],
              });
              setTrack(id);
            }}
          />
        </Stack.Item>
      </Stack>
      {selectedTrack && (
        <Stack mt={1} wrap align="center">
          <Stack.Item grow>
            <Input
              fluid
              value={selectedTrack.name}
              maxLength={64}
              disabled={disabled}
              onChange={(name) => updateTrack({ name })}
            />
          </Stack.Item>
          <Stack.Item grow>
            <Dropdown
              fluid
              selected={
                selectedTrack.instrument
                  ? instruments.find(
                      (item) => item.id === selectedTrack.instrument,
                    )?.name || selectedTrack.instrument
                  : defaultOption
              }
              options={[defaultOption, ...instruments.map((item) => item.name)]}
              disabled={disabled}
              onSelected={(name) =>
                updateTrack({
                  instrument:
                    name === defaultOption
                      ? null
                      : instruments.find((item) => item.name === name)?.id,
                })
              }
            />
          </Stack.Item>
          <Stack.Item>
            <Button
              icon={selectedTrack.muted ? 'volume-mute' : 'volume-up'}
              tooltip={selectedTrack.muted ? 'Enable track' : 'Mute track'}
              selected={!!selectedTrack.muted}
              disabled={disabled}
              onClick={() => updateTrack({ muted: !selectedTrack.muted })}
            />
            <Button.Confirm
              icon="trash"
              tooltip="Delete track and its notes"
              disabled={disabled}
              onClick={() => {
                const next = removeMidiTrack(doc, track);
                change(next);
                const view = midiView(next);
                setTrack(view.track);
                setBaseKey(view.baseKey);
                setKeyCount(view.keyCount);
                setViewTime(0);
                setSelection([]);
              }}
            />
          </Stack.Item>
        </Stack>
      )}
      {pianoRoll && (
        <>
          <Stack mt={1} align="center" wrap>
            <Stack.Item>
              Channel{' '}
              <NumberInput
                width="4em"
                value={channel + 1}
                minValue={1}
                maxValue={16}
                step={1}
                format={musicInteger}
                onChange={(v) => setChannel(v - 1)}
              />
            </Stack.Item>
            <Stack.Item>
              Octave{' '}
              <NumberInput
                width="4em"
                value={baseKey / 12 - 1}
                minValue={-1}
                maxValue={7}
                step={1}
                format={musicInteger}
                onChange={(v) => {
                  setBaseKey((v + 1) * 12);
                  setKeyCount(24);
                }}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="search-minus"
                tooltip="Zoom out"
                onClick={() => {
                  setZoom(Math.max(0.4, zoom / 1.5));
                  setViewTime(
                    Math.min(
                      viewTime,
                      Math.max(0, maxTime - 720 / Math.max(0.4, zoom / 1.5)),
                    ),
                  );
                }}
              />
              <Button icon="expand" tooltip="Fit composition" onClick={fit} />
              <Button.Checkbox
                checked={follow}
                onClick={() => setFollow(!follow)}
              >
                Follow
              </Button.Checkbox>
              <Button
                icon="search-plus"
                tooltip="Zoom in"
                onClick={() => setZoom(Math.min(400, zoom * 1.5))}
              />
            </Stack.Item>
            <Stack.Item>
              Time{' '}
              <NumberInput
                width="6em"
                value={viewTime}
                minValue={0}
                maxValue={maxViewTime}
                step={snapSeconds}
                format={musicDecimal}
                onChange={(value) => {
                  setFollow(false);
                  setViewTime(value);
                }}
              />
            </Stack.Item>
          </Stack>
          <Box mt={1} color="label">
            {trackNotes.length} notes / {maxTime.toFixed(2)} s / View{' '}
            {viewTime.toFixed(2)}-
            {Math.min(maxTime, viewTime + windowSeconds).toFixed(2)} s
          </Box>
          <svg
            width="100%"
            height="48"
            viewBox="0 0 720 48"
            preserveAspectRatio="none"
            style={{ background: '#0b1118', cursor: 'pointer' }}
            onPointerDown={(event) => {
              const rect = event.currentTarget.getBoundingClientRect();
              setFollow(false);
              setViewTime(
                Math.max(
                  0,
                  Math.min(
                    maxViewTime,
                    ((event.clientX - rect.left) / rect.width) * maxTime -
                      windowSeconds / 2,
                  ),
                ),
              );
            }}
          >
            {doc.notes.map((note, index) => (
              <rect
                key={index}
                x={(note.time / maxTime) * 720}
                y={46 - (note.key / 128) * 44}
                width={Math.max(1, (note.duration / maxTime) * 720)}
                height={2}
                fill={note.track === track ? '#72aeb6' : '#34444d'}
                pointerEvents="none"
              />
            ))}
            <rect
              x={(viewTime / maxTime) * 720}
              y={0.5}
              width={Math.min(720, (windowSeconds / maxTime) * 720)}
              height={47}
              fill="#72aeb615"
              stroke="#72aeb6"
              pointerEvents="none"
            />
          </svg>
          <Slider
            value={viewTime}
            minValue={0}
            maxValue={Math.max(0.01, maxViewTime)}
            step={0.1}
            format={musicDecimal}
            disabled={maxViewTime === 0}
            onChange={(_, value) => {
              setFollow(false);
              setViewTime(Math.min(maxViewTime, value));
            }}
          />
          <Box mt={1} style={{ maxHeight: '480px', overflowY: 'auto' }}>
            <Box
              style={{
                display: 'flex',
                height: `${rollHeight}px`,
                background: '#0b1118',
                border: '1px solid #34444d',
                userSelect: 'none',
              }}
            >
              <Box style={{ width: '44px', flexShrink: 0 }}>
                {Array.from({ length: keyCount }, (_, i) => {
                  const key = baseKey + keyCount - 1 - i;
                  return (
                    <Box
                      key={key}
                      style={{
                        height: `${rowHeight}px`,
                        fontSize: '11px',
                        lineHeight: `${rowHeight}px`,
                        textAlign: 'right',
                        color: '#b4cbd0',
                        background: [1, 3, 6, 8, 10].includes(key % 12)
                          ? '#10151c'
                          : '#26313a',
                        borderBottom: '1px solid #34444d',
                      }}
                    >
                      {
                        [
                          'C',
                          'C#',
                          'D',
                          'D#',
                          'E',
                          'F',
                          'F#',
                          'G',
                          'G#',
                          'A',
                          'A#',
                          'B',
                        ][key % 12]
                      }
                      {Math.floor(key / 12) - 1}
                    </Box>
                  );
                })}
              </Box>
              <svg
                width="100%"
                height={rollHeight}
                viewBox={`0 0 720 ${rollHeight}`}
                preserveAspectRatio="none"
                style={{ touchAction: 'none' }}
                onPointerDown={(e) => {
                  if (disabled || !selectedTrack || e.button !== 0) return;
                  const p = point(e);
                  const index = Number(
                    (e.target as SVGElement).getAttribute('data-note'),
                  );
                  const hasNote = (e.target as SVGElement).hasAttribute(
                    'data-note',
                  );
                  if (hasNote) {
                    const indexes = e.shiftKey
                      ? [...new Set([...selection, index])]
                      : selection.includes(index)
                        ? selection
                        : [index];
                    setSelection(indexes);
                    const note = doc.notes[index];
                    drag.current = {
                      ...p,
                      resize: (note.time + note.duration - p.time) * zoom < 7,
                      original: doc,
                      indexes,
                    };
                    setHistory((old) => [...old.slice(-29), doc]);
                    setFuture([]);
                    e.currentTarget.setPointerCapture(e.pointerId);
                  } else {
                    const note: Note = {
                      time: snapTime(p.time),
                      duration: snapSeconds,
                      key: Math.max(0, Math.min(127, p.key)),
                      velocity: 100,
                      channel,
                      track,
                    };
                    if (doc.notes.length >= 4096) return;
                    change({ ...doc, notes: [...doc.notes, note] });
                    setSelection([doc.notes.length]);
                  }
                }}
                onPointerMove={(e) => {
                  const state = drag.current;
                  if (!state) return;
                  const p = point(e);
                  const delta =
                    Math.round((p.time - state.time) / snapSeconds) *
                    snapSeconds;
                  setDoc({
                    ...state.original,
                    notes: state.original.notes.map((n, i) =>
                      !state.indexes.includes(i)
                        ? n
                        : state.resize
                          ? {
                              ...n,
                              duration: Math.max(
                                snapSeconds,
                                n.duration + delta,
                              ),
                            }
                          : {
                              ...n,
                              time: Math.max(0, n.time + delta),
                              key: Math.max(
                                0,
                                Math.min(127, n.key + p.key - state.key),
                              ),
                            },
                    ),
                  });
                }}
                onPointerUp={() => {
                  drag.current = null;
                }}
                onPointerCancel={() => {
                  drag.current = null;
                }}
              >
                {Array.from({ length: keyCount + 1 }, (_, i) => (
                  <line
                    key={`row${i}`}
                    x1={0}
                    x2={720}
                    y1={i * rowHeight}
                    y2={i * rowHeight}
                    stroke="#25313b"
                  />
                ))}
                {Array.from(
                  { length: Math.ceil(windowSeconds / gridSeconds) + 1 },
                  (_, i) => {
                    const time =
                      Math.ceil(viewTime / gridSeconds) * gridSeconds +
                      i * gridSeconds;
                    const x = (time - viewTime) * zoom;
                    return (
                      <line
                        key={`col${i}`}
                        x1={x}
                        x2={x}
                        y1={0}
                        y2={rollHeight}
                        stroke={
                          Math.abs(quantize(time / beatSeconds) % 1) < 0.001
                            ? '#46515b'
                            : '#202a33'
                        }
                      />
                    );
                  },
                )}
                {doc.notes.map((note, i) =>
                  note.track === track &&
                  note.key >= baseKey &&
                  note.key < baseKey + keyCount &&
                  note.time + note.duration >= viewTime &&
                  (note.time - viewTime) * zoom < 720 ? (
                    <rect
                      key={i}
                      data-note={i}
                      x={(note.time - viewTime) * zoom}
                      y={(baseKey + keyCount - 1 - note.key) * rowHeight + 0.5}
                      width={Math.max(3, note.duration * zoom)}
                      height={Math.max(1, rowHeight - 1)}
                      fill={
                        selection.includes(i)
                          ? '#d7747f'
                          : selectedTrack?.muted
                            ? '#40515a'
                            : '#72aeb6'
                      }
                      stroke={selection.includes(i) ? '#ffc3c5' : '#9cc7cb'}
                    />
                  ) : null,
                )}
                <line
                  x1={(position - viewTime) * zoom}
                  x2={(position - viewTime) * zoom}
                  y1={0}
                  y2={rollHeight}
                  stroke="#ead17b"
                  pointerEvents="none"
                />
              </svg>
            </Box>
          </Box>
          {selected && (
            <Stack mt={1} align="center" wrap>
              <Stack.Item>
                Start{' '}
                <NumberInput
                  width="6em"
                  value={selected.time}
                  minValue={0}
                  maxValue={1800}
                  step={snapSeconds}
                  format={musicDecimal}
                  disabled={disabled}
                  onChange={(v) => updateNote('time', v)}
                />
              </Stack.Item>
              <Stack.Item>
                Length{' '}
                <NumberInput
                  width="6em"
                  value={selected.duration}
                  minValue={0.01}
                  maxValue={1800}
                  step={snapSeconds}
                  format={musicDecimal}
                  disabled={disabled}
                  onChange={(v) => updateNote('duration', v)}
                />
              </Stack.Item>
              <Stack.Item>
                Key{' '}
                <NumberInput
                  width="4em"
                  value={selected.key}
                  minValue={0}
                  maxValue={127}
                  step={1}
                  format={musicInteger}
                  disabled={disabled}
                  onChange={(v) => updateNote('key', v)}
                />
              </Stack.Item>
              <Stack.Item>
                Velocity{' '}
                <NumberInput
                  width="4em"
                  value={selected.velocity}
                  minValue={1}
                  maxValue={127}
                  step={1}
                  format={musicInteger}
                  disabled={disabled}
                  onChange={(v) => updateNote('velocity', v)}
                />
              </Stack.Item>
            </Stack>
          )}
          <Collapsible title="Tempo map">
            {doc.tempos.map((tempo, i) => (
              <Stack key={i} mt={0.5} align="center">
                <Stack.Item>
                  <NumberInput
                    width="6em"
                    value={tempo.time}
                    minValue={0}
                    maxValue={1800}
                    step={0.1}
                    format={musicDecimal}
                    disabled={disabled || i === 0}
                    onChange={(time) =>
                      change(editTempo(doc, i, time, tempo.bpm))
                    }
                  />
                </Stack.Item>
                <Stack.Item>
                  <NumberInput
                    width="5em"
                    value={tempo.bpm}
                    minValue={1}
                    maxValue={1000}
                    step={1}
                    format={musicInteger}
                    disabled={disabled}
                    onChange={(value) =>
                      change(editTempo(doc, i, tempo.time, Math.round(value)))
                    }
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="trash"
                    tooltip="Delete tempo marker"
                    disabled={disabled || i === 0}
                    onClick={() => change(editTempo(doc, i, tempo.time, null))}
                  />
                </Stack.Item>
              </Stack>
            ))}
            <Button
              icon="plus"
              tooltip="Add tempo marker at cursor"
              disabled={disabled || doc.tempos.length >= 1024}
              onClick={() =>
                change(
                  editTempo(
                    doc,
                    doc.tempos.length,
                    viewTime,
                    doc.tempos[0]?.bpm || 120,
                  ),
                )
              }
            />
          </Collapsible>
          <Slider
            mt={1}
            value={position}
            minValue={0}
            maxValue={maxTime}
            step={0.1}
            format={musicDecimal}
            onChange={(_, value) => act('sequence_seek', { seconds: value })}
          />
          <Stack mt={1} wrap>
            {Array.from({ length: 16 }, (_, i) => (
              <Stack.Item key={i}>
                <Button
                  selected={channels.includes(i)}
                  onClick={() => act('sequence_channel', { channel: i })}
                >
                  {i + 1}
                </Button>
              </Stack.Item>
            ))}
          </Stack>
        </>
      )}
    </Section>
  );
}

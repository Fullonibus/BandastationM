import { useRef, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Icon,
  Input,
  Knob,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { type CueDocument, CueEditor } from './InstrumentEditor220/CueEditor';
import { musicDecimal, musicInteger } from './InstrumentEditor220/format';
import { MidiEditor } from './InstrumentEditor220/MidiEditor';
import type { MusicDocument } from './InstrumentEditor220/midi';
import type {
  MusicUploadStatus,
  PlayAction,
} from './InstrumentEditor220/upload';
import { useMusicUpload } from './InstrumentEditor220/useMusicUpload';

type InstrumentData = { name: string; id: string };
type LineData = { line_count: number; line_text: string };
type LoadedFileTrack = {
  name: string;
  length?: string | null;
  length_seconds: number;
  selected?: BooleanLike;
};

export type Data = {
  id: string;
  auto_unison_enabled: BooleanLike;
  multi_sync_enabled: BooleanLike;
  multi_tracks: { target_id: string | null; delay_beats: number }[];
  advanced_music_access: BooleanLike;
  music_upload?: MusicUploadStatus | null;
  sequence_document: MusicDocument;
  cue_document: CueDocument;
  midi_channels: number[];
  sequence_length: number;
  playback_seconds: number;
  auto_sing: BooleanLike;
  singing_tts: BooleanLike;
  midi_shared: BooleanLike;
  using_instrument: string;
  using_instrument_id: string | null;

  note_shift_min: number;
  note_shift_max: number;
  note_shift: number;
  octaves: number;

  sustain_modes: string[];
  sustain_mode: string;
  sustain_mode_button: string;
  sustain_mode_duration: number;
  sustain_mode_min: number;
  sustain_mode_max: number;
  sustain_indefinitely: BooleanLike;

  instrument_ready: BooleanLike;

  volume: number;
  min_volume: number;
  max_volume: number;
  volume_dropoff_threshold: number;

  playing: BooleanLike;
  max_repeats: number;
  repeat: number;
  midi_start_delay_ticks: number;
  midi_start_pending: BooleanLike;
  auto_repeat: BooleanLike;
  playback_mode: string;
  file_track_name?: string | null;
  file_track_length?: string | null;
  file_track_length_seconds: number;
  can_load_file_tracks: BooleanLike;
  preset_file_tracks: string[];
  loaded_file_tracks: LoadedFileTrack[];

  bpm: number;
  lines: LineData[];

  can_switch_instrument: BooleanLike;
  possible_instruments: InstrumentData[];

  max_line_chars: number;
  max_lines: number;
};

export function InstrumentEditor220() {
  const { act, data } = useBackend<Data>();
  const [showHelp, setShowHelp] = useState(false);
  const applyMidi = useRef<((action?: PlayAction) => boolean) | null>(null);
  const applyOgg = useRef<((action?: PlayAction) => boolean) | null>(null);
  const transfer = useMusicUpload(act, data.music_upload);
  const [tab, setTab] = useState<'main' | 'midi' | 'library'>(() =>
    data.advanced_music_access && data.playback_mode === 'file'
      ? 'library'
      : data.advanced_music_access && data.playback_mode === 'sequence'
        ? 'midi'
        : 'main',
  );
  const mode = tab === 'main' ? 'midi' : tab === 'midi' ? 'sequence' : 'file';
  const selectTab = (next: typeof tab) => {
    if (transfer.busy || (next !== 'main' && !data.advanced_music_access))
      return;
    setTab(next);
    setShowHelp(false);
    act('select_music_mode', {
      mode: next === 'main' ? 'midi' : next === 'midi' ? 'sequence' : 'file',
    });
  };
  const playbackControls = (
    <TopBar
      showHelp={showHelp}
      setShowHelp={setShowHelp}
      mode={mode}
      uploading={transfer.busy}
      onPlay={(action) => {
        if (transfer.busy) return;
        if (!data.playing && !data.midi_start_pending) {
          if (mode === 'sequence' && !data.midi_shared) {
            applyMidi.current?.(action);
            return;
          }
          if (mode === 'file') {
            applyOgg.current?.(action);
            return;
          }
        }
        act(action, { mode });
      }}
    />
  );
  return (
    <Window width={960} height={820}>
      <Window.Content scrollable>
        <Tabs>
          <Tabs.Tab
            icon="music"
            selected={tab === 'main'}
            onClick={() => selectTab('main')}
          >
            Notes
          </Tabs.Tab>
          <Tabs.Tab
            icon="keyboard"
            selected={tab === 'midi'}
            onClick={() => selectTab('midi')}
            style={
              !data.advanced_music_access ? { display: 'none' } : undefined
            }
          >
            MIDI
          </Tabs.Tab>
          <Tabs.Tab
            icon="compact-disc"
            selected={tab === 'library'}
            onClick={() => selectTab('library')}
            style={
              !data.advanced_music_access ? { display: 'none' } : undefined
            }
          >
            OGG
          </Tabs.Tab>
        </Tabs>
        {playbackControls}
        <SyncControls />
        {showHelp && tab === 'main' && <HelpInline />}
        {transfer.busy && (
          <Section>
            Uploading music: {transfer.progress}{' '}
            <Button
              icon="times"
              tooltip="Cancel upload"
              onClick={transfer.cancel}
            />
          </Section>
        )}
        {!!transfer.error && <Box color="bad">{transfer.error}</Box>}
        {tab === 'main' && (
          <>
            <MainPanel />
            <MusicEditor />
          </>
        )}
        {tab === 'midi' && !!data.advanced_music_access && (
          <MidiEditor
            commitRef={applyMidi}
            document={data.sequence_document}
            uploading={transfer.busy}
            instruments={data.possible_instruments}
            defaultInstrument={data.using_instrument_id}
            disabled={!!data.playing || !!data.midi_shared || transfer.busy}
            channels={data.midi_channels}
            position={
              data.playback_mode === 'sequence' ? data.playback_seconds : 0
            }
            act={act}
            upload={(document, action, onComplete) =>
              transfer.upload('sequence', document, action, onComplete)
            }
            playing={!!data.playing && data.playback_mode === 'sequence'}
          />
        )}
        {tab === 'library' && !!data.advanced_music_access && (
          <>
            <LibraryPanel />
            <CueEditor
              commitRef={applyOgg}
              document={data.cue_document}
              disabled={!!data.playing || transfer.busy}
              length={data.file_track_length_seconds}
              autoSing={!!data.auto_sing}
              tts={!!data.singing_tts}
              act={act}
              upload={(document, action) =>
                transfer.upload('cues', document, action)
              }
            />
          </>
        )}
        {tab === 'midi' && (
          <Section>
            <Stack align="center" justify="end" wrap>
              <Stack.Item>
                Volume{' '}
                <NumberInput
                  width="5em"
                  minValue={0}
                  maxValue={100}
                  value={data.volume}
                  step={1}
                  format={musicInteger}
                  onChange={(amount) => act('set_volume', { amount })}
                />
              </Stack.Item>
            </Stack>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
}

type TopBarProps = {
  onPlay: (action: PlayAction) => void;
  uploading: boolean;
  mode: string;
  showHelp: boolean;
  setShowHelp: (v: boolean) => void;
};

export function TopBar(props: TopBarProps) {
  const { act, data } = useBackend<Data>();
  const {
    instrument_ready,
    repeat,
    max_repeats,
    auto_repeat,
    lines,
    file_track_name,
  } = data;
  const { showHelp, setShowHelp, mode, onPlay, uploading } = props;
  const playing = !!data.playing && data.playback_mode === mode;
  const midi_start_pending =
    !!data.midi_start_pending && data.playback_mode === mode;
  const ready =
    mode === 'file'
      ? !!file_track_name
      : !!instrument_ready &&
        (mode === 'sequence'
          ? data.sequence_document.notes.length > 0
          : lines.length > 0);

  return (
    <Section>
      <Stack align="center" justify="space-between">
        <Stack.Item>
          <Stack align="center">
            <Stack.Item>
              <Button
                icon={playing || midi_start_pending ? 'stop' : 'play'}
                color={playing || midi_start_pending ? 'average' : 'good'}
                disabled={uploading}
                onClick={() => onPlay('play_music')}
              >
                {playing || midi_start_pending ? 'Stop' : 'Start'}
              </Button>
            </Stack.Item>
            <Stack.Item ml={1}>
              <Icon
                name={ready ? 'check-circle' : 'circle'}
                color={ready ? 'good' : 'average'}
                mr={0.5}
              />
              {ready
                ? 'Ready'
                : mode === 'file'
                  ? 'No OGG'
                  : mode === 'sequence'
                    ? 'No MIDI'
                    : 'No notes'}
            </Stack.Item>
          </Stack>
        </Stack.Item>

        <Stack.Item>
          <Stack align="center">
            <Stack.Item>
              <Button
                icon={auto_repeat ? 'repeat' : 'rotate-right'}
                color={auto_repeat ? 'good' : 'default'}
                selected={!!auto_repeat}
                onClick={() =>
                  act('set_auto_repeat', { enabled: !auto_repeat })
                }
              >
                {auto_repeat ? 'Loop ON' : 'Loop'}
              </Button>
            </Stack.Item>
            <Stack.Item ml={1}>
              Repeats:
              <NumberInput
                ml={0.5}
                step={1}
                format={musicInteger}
                minValue={0}
                maxValue={max_repeats}
                value={repeat}
                onChange={(v) => act('set_repeat_amount', { amount: v })}
              />
            </Stack.Item>
            {mode === 'midi' && (
              <Stack.Item ml={1}>
                <Button icon="question" onClick={() => setShowHelp(!showHelp)}>
                  Help
                </Button>
              </Stack.Item>
            )}
          </Stack>
        </Stack.Item>
      </Stack>

      {mode === 'midi' && lines.length === 0 && (
        <Box mt={1} color="average">
          Load or type a song below to enable playback.
        </Box>
      )}
    </Section>
  );
}

const HelpInline = () => {
  const { data } = useBackend<Data>();
  const { max_line_chars, max_lines } = data;

  return (
    <Section fitted>
      <Box mt={0.5} mb={0.5}>
        <b>Help</b>
      </Box>
      <Box>
        Lines are a series of chords separated by commas (,), each chord has
        notes separated by hyphens (-).
        <br />
        Notes default to natural in octave 3; accidentals/octaves persist:
        <i> C,C4,C,C3</i> → <i>C3,C4,C4,C3</i>.<br />
        Chords: <i>A-C#,Cn-E,E-G#,Gn-B</i>; pause with empty chord:{' '}
        <i>C,E,,C,G</i>.<br />
        Change chord length via <i>/x</i>: <i>C,G/2,E/4</i>. Example:
        <i> E-E4/4,F#/2,G#/8,B/8,E3-E4/4</i>.<br />
        Max line length: {max_line_chars}. Max lines: {max_lines}.
      </Box>
    </Section>
  );
};

const MainPanel = () => {
  return (
    <Section>
      <Stack>
        <Stack.Item grow basis="50%">
          <LeftColumn />
        </Stack.Item>
        <Stack.Item grow basis="50%">
          <RightKnobs />
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const LibraryPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    playing,
    file_track_name,
    file_track_length,
    file_track_length_seconds,
    can_load_file_tracks,
    preset_file_tracks = [],
    loaded_file_tracks = [],
    volume,
    min_volume,
    max_volume,
  } = data;
  const volVal = Math.max(0, Math.min(100, volume));
  const handleVolume = (...args: any[]) => {
    let value: number | undefined;
    if (typeof args[1] === 'number') value = args[1];
    else if (typeof args[0] === 'number') value = args[0];
    else if (args[0]?.target?.value != null)
      value = Number(args[0].target.value);
    else if (args[0]?.currentTarget?.value != null)
      value = Number(args[0].currentTarget.value);
    if (typeof value === 'number' && !Number.isNaN(value)) {
      act('set_volume', {
        amount: Math.max(min_volume, Math.min(max_volume, Math.round(value))),
      });
    }
  };
  const commitLength = (value: string) => {
    const seconds = Number(value);
    if (!Number.isNaN(seconds)) {
      act('set_file_track_length', {
        seconds: Math.max(1, Math.min(1800, Math.round(seconds))),
      });
    }
  };

  return (
    <Section title="Track Library">
      <Stack>
        <Stack.Item grow basis="50%">
          <Section title="Loaded Tracks">
            <Button
              fluid
              icon="folder-open"
              disabled={!!playing || !can_load_file_tracks}
              tooltip={
                can_load_file_tracks
                  ? 'Load an OGG file'
                  : 'Requires Music skill 2'
              }
              onClick={() => act('import_file_song')}
            >
              Load OGG
            </Button>
            {loaded_file_tracks.length === 0 ? (
              <Box mt={1} color="label">
                No OGG tracks loaded.
              </Box>
            ) : (
              loaded_file_tracks.map((track) => (
                <Stack key={track.name} align="center">
                  <Stack.Item grow>
                    <Button
                      fluid
                      mb={0.5}
                      mt={0.5}
                      selected={!!track.selected}
                      onClick={() =>
                        act('select_loaded_file_track', { track: track.name })
                      }
                    >
                      <Box
                        style={{
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {track.name}
                      </Box>
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="trash"
                      tooltip="Remove OGG"
                      disabled={!!playing}
                      onClick={() =>
                        act('remove_file_track', { track: track.name })
                      }
                    />
                  </Stack.Item>
                </Stack>
              ))
            )}
            <Box mt={1} color="label">
              Prepared presets: {preset_file_tracks.length || 0}
            </Box>
          </Section>
        </Stack.Item>
        <Stack.Item grow basis="50%">
          <Section title="Loaded Track">
            {file_track_name ? (
              <>
                <Box bold>{file_track_name}</Box>
                <Box mt={0.5} color="label">
                  Detected: {file_track_length}
                </Box>
                <Stack align="center" mt={1}>
                  <Stack.Item>Length:</Stack.Item>
                  <Stack.Item>
                    <Input
                      width="5rem"
                      value={musicDecimal(file_track_length_seconds)}
                      disabled={!!playing}
                      onBlur={commitLength}
                      onEnter={commitLength}
                    />
                  </Stack.Item>
                  <Stack.Item>sec</Stack.Item>
                </Stack>
              </>
            ) : (
              <Box color="label">No OGG loaded.</Box>
            )}

            <Stack align="center" mt={1.5}>
              <Stack.Item grow textAlign="center">
                <Knob
                  size={1.8}
                  value={volVal}
                  minValue={0}
                  maxValue={100}
                  step={1}
                  format={musicInteger}
                  stepPixelSize={6}
                  onChange={handleVolume}
                  onDrag={handleVolume}
                />
                <Box mt={0.3}>
                  Volume{' '}
                  <Box as="span" color="label">
                    ({musicInteger(volVal)}%)
                  </Box>
                </Box>
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const LeftColumn = () => {
  const { act, data } = useBackend<Data>();
  const {
    using_instrument,
    can_switch_instrument,
    possible_instruments = [],
    sustain_modes,
    sustain_mode,
    sustain_indefinitely,
    midi_start_delay_ticks,
  } = data;

  const instrument_id_by_name = (name: string) =>
    possible_instruments.find((i) => i.name === name)?.id;

  return (
    <Section title="Instrument">
      <Box>
        Using:
        <Dropdown
          ml={1}
          width="100%"
          selected={using_instrument}
          disabled={!can_switch_instrument}
          options={possible_instruments.map((i) => i.name)}
          onSelected={(v) =>
            act('change_instrument', {
              new_instrument: instrument_id_by_name(v as string),
            })
          }
        />
      </Box>

      <Box mt={1}>Mode:</Box>
      <Dropdown
        width="100%"
        selected={sustain_mode}
        options={sustain_modes}
        onSelected={(v) => act('set_sustain_mode', { new_mode: v })}
      />
      <Box mt={0.5}>
        <Button
          fluid
          selected={!!sustain_indefinitely}
          onClick={() => act('toggle_sustain_hold_indefinitely')}
        >
          {sustain_indefinitely ? 'Hold last note' : 'No hold'}
        </Button>
      </Box>

      <Stack align="center" mt={1}>
        <Stack.Item color="label">MIDI delay:</Stack.Item>
        <Stack.Item grow>
          <Input
            width="100%"
            value={`${midi_start_delay_ticks}`}
            onBlur={(value) =>
              act('set_midi_start_delay', { amount: Number(value) })
            }
            onEnter={(value) =>
              act('set_midi_start_delay', { amount: Number(value) })
            }
          />
        </Stack.Item>
        <Stack.Item>ticks</Stack.Item>
      </Stack>
    </Section>
  );
};

const RightKnobs = () => {
  const { act, data } = useBackend<Data>();
  const {
    volume,
    max_volume,
    volume_dropoff_threshold,
    note_shift,
    sustain_mode_duration,
  } = data;

  const VOL_MAX = 100;
  const DROP_MIN = 0;
  const DROP_MAX = 100;
  const PITCH_MIN = -100;
  const PITCH_MAX = 100;
  const SUSTAIN_MIN = 0;
  const SUSTAIN_MAX = 5;

  const clamp = (v: number, a: number, b: number) =>
    Math.max(a, Math.min(b, v));
  const r0 = (v: number) => Math.round(v);
  const r1 = (v: number) => Math.round(v * 10) / 10;

  const volVal = clamp(volume, 0, VOL_MAX);
  const dropVal = clamp(volume_dropoff_threshold, DROP_MIN, DROP_MAX);
  const pitchVal = clamp(note_shift, PITCH_MIN, PITCH_MAX);
  const sustainVal = clamp(sustain_mode_duration, SUSTAIN_MIN, SUSTAIN_MAX);

  const volLabel = `${r0(volVal)}%`;
  const dropLabel = `${r0(dropVal)}`;
  const pitchLabel = `${pitchVal > 0 ? '+' : ''}${r0(pitchVal)}`;
  const sustainLabel = `${r1(sustainVal).toFixed(1)}s`;

  // Универсальный адаптер под любые сигнатуры Knob
  const asKnobHandler =
    (cb: (value: number) => void) =>
    // даём тайпинги через any, чтобы не бодаться с разными версиями типов
    (...args: any[]) => {
      // варианты: (value), (event), (event, value)
      let value: number | undefined;

      if (typeof args[1] === 'number') value = args[1];
      else if (typeof args[0] === 'number') value = args[0];
      else if (args[0]?.target?.value != null)
        value = Number(args[0].target.value);
      else if (args[0]?.currentTarget?.value != null)
        value = Number(args[0].currentTarget.value);

      if (typeof value === 'number' && !Number.isNaN(value)) cb(value);
    };

  return (
    <Section title="Amp">
      <Stack>
        <Stack.Item grow basis="50%" textAlign="center">
          <Knob
            size={1.8}
            value={volVal}
            minValue={0}
            maxValue={VOL_MAX}
            step={1}
            format={musicInteger}
            stepPixelSize={6}
            // поддержим и onChange, и onDrag — что бы ни ожидал Knob
            onChange={asKnobHandler((v) =>
              act('set_volume', { amount: clamp(r0(v), 0, max_volume) }),
            )}
            onDrag={asKnobHandler((v) =>
              act('set_volume', { amount: clamp(r0(v), 0, max_volume) }),
            )}
          />
          <Box mt={0.3}>
            Volume{' '}
            <Box as="span" color="label">
              ({volLabel})
            </Box>
          </Box>
        </Stack.Item>

        <Stack.Item grow basis="50%" textAlign="center">
          <Knob
            size={1.8}
            value={dropVal}
            minValue={DROP_MIN}
            maxValue={DROP_MAX}
            step={1}
            format={musicInteger}
            stepPixelSize={6}
            onChange={asKnobHandler((v) =>
              act('set_dropoff_volume', { amount: r0(v) }),
            )}
            onDrag={asKnobHandler((v) =>
              act('set_dropoff_volume', { amount: r0(v) }),
            )}
          />
          <Box mt={0.3}>
            Dropoff{' '}
            <Box as="span" color="label">
              ({dropLabel})
            </Box>
          </Box>
        </Stack.Item>
      </Stack>

      <Stack mt={1}>
        <Stack.Item grow basis="50%" textAlign="center">
          <Knob
            size={1.8}
            value={pitchVal}
            minValue={PITCH_MIN}
            maxValue={PITCH_MAX}
            step={1}
            format={musicInteger}
            stepPixelSize={6}
            onChange={asKnobHandler((v) =>
              act('set_note_shift', { amount: r0(v) }),
            )}
            onDrag={asKnobHandler((v) =>
              act('set_note_shift', { amount: r0(v) }),
            )}
          />
          <Box mt={0.3}>
            Pitch{' '}
            <Box as="span" color="label">
              ({pitchLabel})
            </Box>
          </Box>
        </Stack.Item>

        <Stack.Item grow basis="50%" textAlign="center">
          <Knob
            size={1.8}
            value={sustainVal}
            minValue={SUSTAIN_MIN}
            maxValue={SUSTAIN_MAX}
            step={0.1}
            format={musicDecimal}
            stepPixelSize={5}
            onChange={asKnobHandler((v) =>
              act('edit_sustain_mode', { amount: r1(v) }),
            )}
            onDrag={asKnobHandler((v) =>
              act('edit_sustain_mode', { amount: r1(v) }),
            )}
          />
          <Box mt={0.3}>
            Sustain{' '}
            <Box as="span" color="label">
              ({sustainLabel})
            </Box>
          </Box>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const MusicEditor = () => {
  const { act, data } = useBackend<Data>();
  const { bpm, lines } = data;

  return (
    <Collapsible open title="Music Editor" icon="pencil">
      <Section>
        <Stack align="center">
          <Stack.Item>
            <Button onClick={() => act('start_new_song')}>
              Start a New Song
            </Button>
          </Stack.Item>
          <Stack.Item ml={1}>
            <Button onClick={() => act('import_song')}>Import a Song</Button>
          </Stack.Item>
          <Stack.Item grow />
          <Stack.Item>
            Tempo:
            <Button
              ml={1}
              onClick={() =>
                act('tempo_big_step', { tempo_change: 'decrease_speed' })
              }
            >
              --
            </Button>
            <Button
              ml={0.5}
              onClick={() => act('tempo', { tempo_change: 'decrease_speed' })}
            >
              -
            </Button>
            <NumberInput
              ml={0.5}
              step={1}
              format={musicInteger}
              minValue={1}
              maxValue={999}
              value={bpm}
              onChange={(v) => act('set_bpm_slider', { amount: Math.round(v) })}
            />
            <Button
              ml={0.5}
              onClick={() => act('tempo', { tempo_change: 'increase_speed' })}
            >
              +
            </Button>
            <Button
              ml={0.5}
              onClick={() =>
                act('tempo_big_step', { tempo_change: 'increase_speed' })
              }
            >
              ++
            </Button>
          </Stack.Item>
        </Stack>

        <Box mt={1}>
          {lines.map((line, index) => (
            <Box key={index} fontSize="11px" mb={0.5}>
              <Stack align="center">
                <Stack.Item>Line {index}:</Stack.Item>
                <Stack.Item ml={1}>
                  <Button
                    onClick={() =>
                      act('modify_line', { line_editing: line.line_count })
                    }
                  >
                    Edit
                  </Button>
                </Stack.Item>
                <Stack.Item ml={1}>
                  <Button
                    color="bad"
                    onClick={() =>
                      act('delete_line', { line_deleted: line.line_count })
                    }
                  >
                    X
                  </Button>
                </Stack.Item>
                <Stack.Item grow ml={1}>
                  <Box opacity={0.9}>{line.line_text}</Box>
                </Stack.Item>
              </Stack>
            </Box>
          ))}
        </Box>

        <Box mt={1}>
          <Button icon="plus" onClick={() => act('add_new_line')}>
            Add Line
          </Button>
        </Box>
      </Section>
    </Collapsible>
  );
};

function SyncControls() {
  const { act, data } = useBackend<Data>();
  const ogg = data.playback_mode === 'file';
  return (
    <Collapsible title="Synchronization" icon="link">
      <Section>
        <Stack wrap align="center">
          {!ogg && (
            <Stack.Item grow>
              <Input
                value={data.id}
                maxLength={20}
                placeholder="Sync ID"
                onChange={(id) => act('set_instrument_id', { id })}
              />
            </Stack.Item>
          )}
          <Stack.Item>
            <Button.Checkbox
              checked={!!data.auto_unison_enabled}
              tooltip={
                ogg
                  ? 'Start your selected OGG when a nearby instrument starts; both instruments must enable Unison'
                  : 'Automatically follow nearby playing Notes or MIDI'
              }
              onClick={() => act('toggle_auto_unison')}
            >
              Unison
            </Button.Checkbox>
            {!ogg && (
              <Button.Checkbox
                checked={!!data.multi_sync_enabled}
                onClick={() => act('toggle_multi_sync')}
              >
                Detailed sync
              </Button.Checkbox>
            )}
          </Stack.Item>
        </Stack>
        {!ogg && !!data.multi_sync_enabled && (
          <>
            {(data.multi_tracks || []).map((track, index) => (
              <Stack mt={0.5} align="center" key={index}>
                <Stack.Item grow>
                  <Input
                    value={track.target_id || ''}
                    maxLength={20}
                    placeholder="Target ID"
                    onChange={(value) =>
                      act('ms_set', {
                        idx: String(index + 1),
                        field: 'target_id',
                        value,
                      })
                    }
                  />
                </Stack.Item>
                <Stack.Item>
                  Delay, beats{' '}
                  <NumberInput
                    value={track.delay_beats}
                    minValue={0}
                    maxValue={120}
                    step={1}
                    format={musicInteger}
                    onChange={(value) =>
                      act('ms_set', {
                        idx: String(index + 1),
                        field: 'delay_beats',
                        value: String(value),
                      })
                    }
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="trash"
                    tooltip="Remove synchronized part"
                    onClick={() => act('ms_del', { idx: String(index + 1) })}
                  />
                </Stack.Item>
              </Stack>
            ))}
            <Button
              mt={1}
              icon="plus"
              tooltip="Add synchronized part"
              disabled={(data.multi_tracks?.length || 0) >= 16}
              onClick={() => act('ms_add')}
            />
          </>
        )}
      </Section>
    </Collapsible>
  );
}

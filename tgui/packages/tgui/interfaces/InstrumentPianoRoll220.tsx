import { useRef } from 'react';
import { Box, Button, Section } from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { type Data, TopBar } from './InstrumentEditor220';
import { MidiEditor } from './InstrumentEditor220/MidiEditor';
import type { PlayAction } from './InstrumentEditor220/upload';
import { useMusicUpload } from './InstrumentEditor220/useMusicUpload';

export function InstrumentPianoRoll220() {
  const { act, data } = useBackend<Data>();
  const apply = useRef<((action?: PlayAction) => boolean) | null>(null);
  const transfer = useMusicUpload(act, data.music_upload);
  return (
    <Window width={1120} height={880}>
      <Window.Content scrollable>
        <TopBar
          mode="sequence"
          uploading={transfer.busy}
          showHelp={false}
          setShowHelp={() => {}}
          onPlay={(action) => {
            if (transfer.busy) return;
            if (
              !data.playing &&
              !data.midi_start_pending &&
              !data.midi_shared
            ) {
              apply.current?.(action);
              return;
            }
            act(action, { mode: 'sequence' });
          }}
        />
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
        <MidiEditor
          pianoRoll
          commitRef={apply}
          document={data.sequence_document}
          instruments={data.possible_instruments}
          defaultInstrument={data.using_instrument_id}
          disabled={!!data.playing || !!data.midi_shared || transfer.busy}
          channels={data.midi_channels}
          position={
            data.playback_mode === 'sequence' ? data.playback_seconds : 0
          }
          playing={!!data.playing && data.playback_mode === 'sequence'}
          act={act}
          upload={(document, action) =>
            transfer.upload('sequence', document, action)
          }
        />
      </Window.Content>
    </Window>
  );
}

import { expect, it, mock } from 'bun:test';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { useRef } from 'react';
import { MidiEditor } from './MidiEditor';
import type { MusicDocument } from './midi';
import type { MusicUploadStatus, PlayAction } from './upload';
import { useMusicUpload } from './useMusicUpload';

const document: MusicDocument = {
  version: 1,
  title: 'Test',
  notes: [],
  tempos: [{ time: 0, bpm: 92.0001 }],
  tracks: [{ id: 0, name: 'Guitar' }],
};

for (const state of ['complete', 'error'] as const) {
  it(`keeps the piano roll hidden and handles upload ${state} before opening`, async () => {
    const send = mock((_action: string, _payload?: object) => {});
    function Editor({ status }: { status?: MusicUploadStatus }) {
      const transfer = useMusicUpload(send, status);
      const commit = useRef<((action?: PlayAction) => boolean) | null>(null);
      return (
        <MidiEditor
          commitRef={commit}
          document={document}
          instruments={[]}
          defaultInstrument={null}
          disabled={transfer.busy}
          uploading={transfer.busy}
          channels={[0]}
          position={0}
          playing={false}
          act={send}
          upload={(doc, action, complete) =>
            transfer.upload('sequence', doc, action, complete)
          }
        />
      );
    }
    const view = render(<Editor />);
    expect(screen.queryByText('Octave')).toBeNull();
    fireEvent.click(screen.getByText('Piano roll'));
    await waitFor(() => expect(send).toHaveBeenCalledTimes(1));
    const [action, payload] = send.mock.calls[0];
    expect(action).toBe('upload_music_document');
    expect(send.mock.calls.some(([name]) => name === 'open_piano_roll')).toBe(
      false,
    );
    const part = payload as { id: string; count: number };
    view.rerender(<Editor status={{ id: part.id, next: part.count, state }} />);
    expect(
      send.mock.calls.filter(([name]) => name === 'open_piano_roll').length,
    ).toBe(state === 'complete' ? 1 : 0);
  });
}

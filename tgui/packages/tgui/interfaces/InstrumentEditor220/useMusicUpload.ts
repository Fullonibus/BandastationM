import { useEffect, useRef, useState } from 'react';
import {
  type MusicUploadStatus,
  type PlayAction,
  splitMusicDocument,
} from './upload';

type Transfer = {
  id: string;
  kind: 'sequence' | 'cues';
  parts: string[];
  playAction?: PlayAction;
  onComplete?: () => void;
};

export function useMusicUpload(
  act: (action: string, payload?: object) => void,
  status?: MusicUploadStatus | null,
) {
  const [transfer, setTransfer] = useState<Transfer | null>(null);
  const [error, setError] = useState('');
  const serial = useRef(0);
  const sent = useRef('');
  const send = useRef(act);
  send.current = act;
  const next = status?.id === transfer?.id ? status?.next || 0 : 0;
  const state = status?.id === transfer?.id ? status?.state : undefined;
  const serverError = status?.id === transfer?.id ? status?.error : undefined;

  useEffect(() => {
    if (!transfer) return;
    if (state === 'complete' || state === 'error') {
      setError(state === 'error' ? serverError || 'Upload rejected.' : '');
      setTransfer(null);
      if (state === 'complete') transfer.onComplete?.();
      return;
    }
    const key = `${transfer.id}:${next}`;
    if (sent.current !== key && next < transfer.parts.length) {
      sent.current = key;
      send.current('upload_music_document', {
        id: transfer.id,
        kind: transfer.kind,
        index: next,
        count: transfer.parts.length,
        part: transfer.parts[next],
        play_action: transfer.playAction,
      });
    }
    const timeout = setTimeout(() => {
      send.current('cancel_music_upload', { id: transfer.id });
      setError(
        'Music upload timed out. The previous composition was not started.',
      );
      setTransfer(null);
    }, 15000);
    return () => clearTimeout(timeout);
  }, [transfer, next, state, serverError]);

  const upload = (
    kind: Transfer['kind'],
    document: object,
    playAction?: PlayAction,
    onComplete?: () => void,
  ) => {
    if (transfer) return;
    const parts = splitMusicDocument(document);
    setError('');
    setTransfer({
      id: `${Date.now()}-${++serial.current}`,
      kind,
      parts,
      playAction,
      onComplete,
    });
  };
  return {
    upload,
    busy: !!transfer,
    error,
    progress: transfer ? `${next}/${transfer.parts.length}` : '',
    cancel: () => {
      if (transfer) send.current('cancel_music_upload', { id: transfer.id });
      setTransfer(null);
    },
  };
}

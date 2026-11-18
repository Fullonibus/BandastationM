import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Input,
  NumberInput,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';
import {
  appendCueText,
  type Cue,
  rippleCueTime,
  shiftCues,
  validateCueInterval,
  validateCues,
} from './cues';
import { musicDecimal } from './format';
import { download } from './midi';
import type { PlayAction } from './upload';

export type CueDocument = {
  version: 1;
  audio_hash: string | null;
  spacing_seconds?: number;
  cues: Cue[];
};
type Row = Cue & { id: number; selected: boolean };
type Props = {
  document: CueDocument;
  commitRef: { current: ((action?: PlayAction) => boolean) | null };
  upload: (document: CueDocument, action?: PlayAction) => void;
  length: number;
  disabled: boolean;
  autoSing: boolean;
  tts: boolean;
  act: (action: string, payload?: object) => void;
};

export function CueEditor({
  document: source,
  commitRef,
  length,
  disabled,
  autoSing,
  tts,
  act,
  upload,
}: Props) {
  const nextId = useRef(0);
  const makeRows = (cues: Cue[]) =>
    cues.map((cue) => ({ ...cue, id: nextId.current++, selected: false }));
  const [rows, setRows] = useState<Row[]>(() => makeRows(source.cues));
  const [interval, setInterval] = useState(source.spacing_seconds || 5);
  const [massShift, setMassShift] = useState(0);
  const [bulkText, setBulkText] = useState('');
  const [error, setError] = useState('');
  const file = useRef<HTMLInputElement>(null);
  useEffect(() => {
    setRows(makeRows(source.cues));
    setInterval(source.spacing_seconds || 5);
    setMassShift(0);
    setError('');
  }, [source]);
  const document = (): CueDocument => ({
    version: 1,
    audio_hash: source.audio_hash,
    spacing_seconds: interval,
    cues: rows.map(({ time, text }) => ({ time, text })),
  });
  const commit = (action?: PlayAction) => {
    if (!source.audio_hash) return false;
    try {
      validateCues(rows, length);
      upload(document(), action);
      setError('');
      return true;
    } catch (err) {
      setError(String(err));
      return false;
    }
  };
  commitRef.current = commit;
  const mutate = (fn: () => Row[]) => {
    if (disabled) return;
    try {
      setRows(fn());
      setMassShift(0);
      setError('');
    } catch (err) {
      setError(String(err));
    }
  };
  const selectedCount = rows.filter((cue) => cue.selected).length;
  const selectRows = (next: Row[]) => {
    setRows(next);
    setMassShift(0);
  };

  return (
    <Section title="Auto singing" buttons={<Box>{rows.length}/200</Box>}>
      <Stack wrap align="center">
        <Stack.Item>
          <Button.Checkbox
            checked={autoSing}
            onClick={() => act('auto_sing', { enabled: !autoSing })}
          >
            Auto singing
          </Button.Checkbox>
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={tts}
            onClick={() => act('singing_tts', { enabled: !tts })}
          >
            TTS
          </Button.Checkbox>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="plus"
            tooltip="Add cue after last line (+T)"
            disabled={disabled || !source.audio_hash || rows.length >= 200}
            onClick={() =>
              mutate(() => {
                const cue = {
                  time: rows.length
                    ? Math.round(
                        (rows[rows.length - 1].time + interval) * 1000,
                      ) / 1000
                    : 0,
                  text: '',
                };
                validateCues([...rows, cue], length);
                return [...rows, ...makeRows([cue])];
              })
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="save"
            tooltip="Apply cues"
            disabled={disabled || !source.audio_hash}
            onClick={() => commit()}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="folder-open"
            tooltip="Import cue sheet"
            disabled={disabled || !source.audio_hash}
            onClick={() => file.current?.click()}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="file-export"
            tooltip="Export cue sheet"
            onClick={() => {
              try {
                validateCues(rows, length);
                download(
                  'lyrics.json',
                  JSON.stringify(document()),
                  'application/json',
                );
                setError('');
              } catch (err) {
                setError(String(err));
              }
            }}
          />
        </Stack.Item>
      </Stack>
      <Stack mt={1} wrap align="center">
        <Stack.Item>Interval T, s</Stack.Item>
        <Stack.Item>
          <NumberInput
            width="6em"
            value={interval}
            minValue={0.1}
            maxValue={120}
            step={0.1}
            format={musicDecimal}
            disabled={disabled}
            onChange={(value) => {
              if (disabled) return;
              try {
                validateCueInterval(value);
                setInterval(value);
                setError('');
              } catch (err) {
                setError(String(err));
              }
            }}
          />
        </Stack.Item>
        <Stack.Item>Mass shift, s</Stack.Item>
        <Stack.Item>
          <NumberInput
            width="6em"
            value={massShift}
            minValue={-length}
            maxValue={length}
            step={0.1}
            format={musicDecimal}
            disabled={disabled || !rows.length}
            onChange={(value) => {
              if (disabled) return;
              try {
                setRows(shiftCues(rows, value - massShift, length));
                setMassShift(value);
                setError('');
              } catch (err) {
                setError(String(err));
              }
            }}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon={
              selectedCount === rows.length && rows.length
                ? 'square'
                : 'check-square'
            }
            tooltip="Select all / clear selection"
            disabled={disabled || !rows.length}
            onClick={() =>
              selectRows(
                rows.map((cue) => ({
                  ...cue,
                  selected: selectedCount !== rows.length,
                })),
              )
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="exchange-alt"
            tooltip="Invert selection"
            disabled={disabled || !rows.length}
            onClick={() =>
              selectRows(
                rows.map((cue) => ({ ...cue, selected: !cue.selected })),
              )
            }
          />
        </Stack.Item>
        <Stack.Item>
          {selectedCount} / {rows.length}
        </Stack.Item>
      </Stack>
      <Box mt={1}>
        <Stack align="center" mb={0.5}>
          <Stack.Item grow>Mass cue</Stack.Item>
          <Stack.Item>
            <Button
              icon="list-ol"
              tooltip="Append text as timed lines (+T per line)"
              disabled={disabled || !source.audio_hash || !bulkText.trim()}
              onClick={() =>
                mutate(() => [
                  ...rows,
                  ...makeRows(appendCueText(rows, bulkText, interval, length)),
                ])
              }
            />
          </Stack.Item>
        </Stack>
        <TextArea
          fluid
          height="8em"
          value={bulkText}
          maxLength={60200}
          disabled={disabled}
          onChange={setBulkText}
        />
      </Box>
      <input
        ref={file}
        type="file"
        accept=".json"
        style={{ display: 'none' }}
        onChange={async (e) => {
          const uploaded = e.target.files?.[0];
          e.target.value = '';
          if (!uploaded) return;
          try {
            if (uploaded.size > 300000)
              throw new Error('Cue sheet exceeds 300 KB.');
            const next = JSON.parse(await uploaded.text()) as CueDocument;
            if (
              next.version !== 1 ||
              !source.audio_hash ||
              next.audio_hash !== source.audio_hash ||
              !Array.isArray(next.cues)
            )
              throw new Error('Cue sheet does not match the loaded OGG.');
            validateCues(next.cues, length);
            const spacing = next.spacing_seconds ?? 5;
            validateCueInterval(spacing);
            setRows(makeRows([...next.cues].sort((a, b) => a.time - b.time)));
            setInterval(spacing);
            setMassShift(0);
            setError('');
          } catch (err) {
            setError(String(err));
          }
        }}
      />
      {!!error && (
        <Box color="bad" mt={1}>
          {error}
        </Box>
      )}
      {rows.map((cue, i) => (
        <Stack key={cue.id} mt={0.5} align="center">
          <Stack.Item>
            <Button.Checkbox
              checked={cue.selected}
              tooltip="Select cue"
              disabled={disabled}
              onClick={() =>
                selectRows(
                  rows.map((row) =>
                    row.id === cue.id
                      ? { ...row, selected: !row.selected }
                      : row,
                  ),
                )
              }
            />
          </Stack.Item>
          <Stack.Item>
            <NumberInput
              width="6em"
              value={cue.time}
              minValue={rows[i - 1]?.time || 0}
              maxValue={
                length - ((rows[rows.length - 1]?.time || 0) - cue.time)
              }
              step={0.1}
              format={musicDecimal}
              disabled={disabled}
              onChange={(time) =>
                mutate(() => rippleCueTime(rows, i, time, length))
              }
            />
          </Stack.Item>
          <Stack.Item grow>
            <Input
              fluid
              value={cue.text}
              maxLength={300}
              disabled={disabled}
              onChange={(text) =>
                setRows(
                  rows.map((row) =>
                    row.id === cue.id ? { ...row, text } : row,
                  ),
                )
              }
            />
          </Stack.Item>
          <Stack.Item>
            <Button
              icon="trash"
              tooltip="Delete cue"
              disabled={disabled}
              onClick={() =>
                mutate(() => rows.filter((row) => row.id !== cue.id))
              }
            />
          </Stack.Item>
        </Stack>
      ))}
    </Section>
  );
}

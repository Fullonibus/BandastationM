import {
  Box,
  Button,
  Input,
  NoticeBox,
  NumberInput,
  Section,
  Slider,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Track = {
  ref: string;
  name: string;
  duration: number;
  selected: BooleanLike;
};

type Receiver = {
  ref: string;
  name: string | null;
  volume: number;
  active: BooleanLike;
};

type Data = {
  disk: string | null;
  tracks: Track[];
  used_mib: number;
  can_write: BooleanLike;
  busy: BooleanLike;
  upload_cooldown: number;
  playing: BooleanLike;
  volume: number;
  loop: BooleanLike;
  operational: BooleanLike;
  receivers: Receiver[];
};

export const ConcertPlayer220 = () => {
  const { act, data } = useBackend<Data>();
  const locked = !data.can_write || !!data.busy;
  const selected = data.tracks.some((track) => track.selected);

  return (
    <Window width={650} height={540}>
      <Window.Content scrollable>
        {!data.operational && <NoticeBox>No power / not secured</NoticeBox>}
        <Section
          title="Playback"
          buttons={
            <Button
              icon="eject"
              tooltip="Eject disk"
              disabled={!data.disk}
              onClick={() => act('eject')}
            />
          }
        >
          <Stack align="center">
            <Stack.Item>
              <Button
                icon={data.playing ? 'stop' : 'play'}
                content={data.playing ? 'Stop' : 'Play'}
                selected={data.playing}
                disabled={!selected || !data.operational}
                onClick={() => act('play')}
              />
              <Button.Checkbox
                checked={data.loop}
                content="Loop"
                onClick={() => act('loop')}
              />
            </Stack.Item>
            <Stack.Item grow>
              <Slider
                value={data.volume}
                minValue={0}
                maxValue={100}
                step={1}
                format={(value) => `${Math.round(value)}%`}
                onChange={(_, value) => act('volume', { value })}
              />
            </Stack.Item>
          </Stack>
        </Section>
        <Section
          title={data.disk || 'No disk'}
          buttons={
            <Button
              icon="upload"
              content={
                data.busy
                  ? 'Recording...'
                  : data.upload_cooldown
                    ? `Record OGG (${data.upload_cooldown}s)`
                    : 'Record OGG'
              }
              disabled={
                locked || data.upload_cooldown > 0 || data.tracks.length >= 12
              }
              onClick={() => act('upload')}
            />
          }
        >
          <Box color="label" mb={1}>
            {data.tracks.length}/12 | {data.used_mib}/50 MiB
          </Box>
          <Stack vertical>
            {data.tracks.map((track, index) => (
              <Stack.Item key={track.ref}>
                <Stack align="center">
                  <Stack.Item>
                    <Button
                      icon={track.selected ? 'check' : 'music'}
                      selected={track.selected}
                      tooltip="Select track"
                      onClick={() => act('select', { ref: track.ref })}
                    />
                  </Stack.Item>
                  <Stack.Item grow basis="0" minWidth={0}>
                    {data.can_write ? (
                      <Input
                        fluid
                        value={track.name}
                        maxLength={80}
                        disabled={locked}
                        onChange={(_, value) =>
                          act('rename', { ref: track.ref, value })
                        }
                      />
                    ) : (
                      <Box style={{ overflowWrap: 'anywhere' }}>{track.name}</Box>
                    )}
                  </Stack.Item>
                  <Stack.Item width="4.5em" textAlign="right" color="label">
                    {Math.floor(track.duration / 60)}:
                    {String(Math.floor(track.duration % 60)).padStart(2, '0')}
                  </Stack.Item>
                  {data.can_write && (
                    <Stack.Item>
                      <Button
                        icon="arrow-up"
                        tooltip="Move up"
                        disabled={locked || index === 0}
                        onClick={() =>
                          act('move', { ref: track.ref, value: -1 })
                        }
                      />
                      <Button
                        icon="arrow-down"
                        tooltip="Move down"
                        disabled={locked || index === data.tracks.length - 1}
                        onClick={() => act('move', { ref: track.ref, value: 1 })}
                      />
                      <Button.Confirm
                        icon="trash"
                        tooltip="Erase track"
                        disabled={locked}
                        onClick={() => act('remove', { ref: track.ref })}
                      />
                    </Stack.Item>
                  )}
                </Stack>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
        <Section title={`Stage | ${data.receivers.length}/16`}>
          <Stack vertical>
            {data.receivers.map((receiver) => (
              <Stack.Item key={receiver.ref}>
                <Stack align="center">
                  <Stack.Item grow color={receiver.active ? undefined : 'label'}>
                    {receiver.name || 'Disconnected receiver'}
                  </Stack.Item>
                  <Stack.Item>
                    <NumberInput
                      value={receiver.volume}
                      minValue={0}
                      maxValue={100}
                      step={1}
                      unit="%"
                      format={(value) => String(Math.round(value))}
                      onChange={(value) =>
                        act('receiver_volume', { ref: receiver.ref, value })
                      }
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};

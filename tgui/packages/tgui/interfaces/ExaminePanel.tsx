import { useState } from 'react';
import { Box, Button, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { CharacterPreview } from './common/CharacterPreview';

type Data = {
  character_name: string;
  obscured: BooleanLike;
  assigned_map: string;
  flavor_text: string | null;
  portrait_urls?: string[] | null;
};

const PORTRAIT_SIZE = 320;
// Button renders a div and forwards DOM roles, though its props omit role.
const buttonRole = { role: 'button' };

export const ExaminePanel = () => {
  const { data } = useBackend<Data>();
  const { character_name, obscured, assigned_map, flavor_text, portrait_urls } =
    data;
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [failedPortraits, setFailedPortraits] = useState(
    () => new Set<string>(),
  );
  const portraits = obscured ? [] : (portrait_urls ?? []);
  const index = selectedIndex < portraits.length ? selectedIndex : 0;
  const portraitSource = portraits[index];
  const portrait =
    portraitSource && !failedPortraits.has(portraitSource)
      ? portraitSource
      : null;
  const hasPortraits = portraits.length > 0;
  const showDescription = !hasPortraits || !!flavor_text?.trim();

  return (
    <Window
      title="Подробное описание"
      width={hasPortraits ? (showDescription ? 700 : 356) : 600}
      height={hasPortraits ? 408 : 350}
      theme="ntos"
    >
      <Window.Content>
        <Stack fill justify={showDescription ? undefined : 'center'}>
          <Stack.Item>
            <Section
              fill
              title={portrait ? 'Портрет персонажа' : 'Превью персонажа'}
              buttons={
                portraits.length > 1 && (
                  <Stack align="center" g={0.5}>
                    <Stack.Item>
                      <Button
                        compact
                        icon="chevron-left"
                        {...buttonRole}
                        aria-label="Предыдущий портрет"
                        onClick={() =>
                          setSelectedIndex(
                            (index + portraits.length - 1) % portraits.length,
                          )
                        }
                      />
                    </Stack.Item>
                    <Stack.Item aria-live="polite">
                      {index + 1} / {portraits.length}
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        compact
                        icon="chevron-right"
                        {...buttonRole}
                        aria-label="Следующий портрет"
                        onClick={() =>
                          setSelectedIndex((index + 1) % portraits.length)
                        }
                      />
                    </Stack.Item>
                  </Stack>
                )
              }
            >
              {!obscured &&
                (portrait ? (
                  <img
                    key={portrait}
                    alt="Портрет персонажа"
                    src={portrait}
                    width={PORTRAIT_SIZE}
                    height={PORTRAIT_SIZE}
                    style={{ display: 'block', objectFit: 'cover' }}
                    referrerPolicy="no-referrer"
                    onError={() =>
                      setFailedPortraits((failed) =>
                        new Set(failed).add(portrait),
                      )
                    }
                  />
                ) : (
                  <CharacterPreview id={assigned_map} height="100%" />
                ))}
            </Section>
          </Stack.Item>
          {showDescription && (
            <Stack.Item grow>
              <Section scrollable fill title={`${character_name}, описание:`}>
                <Box
                  style={{
                    whiteSpace: 'pre-wrap',
                    wordBreak: 'break-word',
                    overflowWrap: 'break-word',
                  }}
                >
                  {flavor_text}
                </Box>
              </Section>
            </Stack.Item>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

import {
  Box,
  Button,
  Divider,
  Icon,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import { toFixed } from 'tgui-core/math';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Egg = {
  ref: string;
  name: string;
  generation: number;
  adaptations: number;
};

type Adaptation = {
  id: string;
  name: string;
  description: string;
  available: BooleanLike;
  reason: string | null;
};

type Data = {
  research_connected: BooleanLike;
  points: number;
  adaptation_cost: number;
  max_adaptations: number;
  operational: BooleanLike;
  access_allowed: BooleanLike;
  can_operate: BooleanLike;
  egg: Egg | null;
  adaptations: Adaptation[];
};

const adaptationIcons: Record<string, string> = {
  temperature: 'thermometer-half',
  pressure: 'compress-arrows-alt',
  light: 'lightbulb',
  allergy: 'leaf',
  yield: 'seedling',
};

export const PhoenixAdaptation = () => {
  const { act, data } = useBackend<Data>();
  const { egg, adaptations = [] } = data;
  const firstReason = adaptations[0]?.reason;
  const commonReason =
    firstReason &&
    adaptations.every(
      (adaptation) =>
        !adaptation.available && adaptation.reason === firstReason,
    )
      ? firstReason
      : null;
  const remainingAdaptations = egg
    ? Math.max(0, data.max_adaptations - egg.adaptations)
    : data.max_adaptations;

  return (
    <Window width={560} height={700}>
      <Window.Content scrollable>
        <Section
          title="Образец линии"
          buttons={
            egg && (
              <Button
                icon="eject"
                disabled={!data.can_operate}
                onClick={() => act('eject', { egg: egg.ref })}
              >
                Извлечь яйцо
              </Button>
            )
          }
        >
          {egg ? (
            <>
              <Box bold fontSize={1.2} mb={0.5}>
                {egg.name}
              </Box>
              <Stack align="center" mb={1}>
                <Stack.Item grow color="label">
                  Поколение {egg.generation}
                </Stack.Item>
                <Stack.Item color="label">
                  <Icon name="snowflake" mr={0.5} />
                  Развитие приостановлено
                </Stack.Item>
              </Stack>
              <ProgressBar
                value={egg.adaptations}
                minValue={0}
                maxValue={data.max_adaptations}
                color={remainingAdaptations <= 1 ? 'average' : 'teal'}
              >
                Адаптации линии: {egg.adaptations} / {data.max_adaptations}
              </ProgressBar>
            </>
          ) : (
            <Box py={1}>
              <Box bold fontSize={1.2} mb={0.5}>
                <Icon name="egg" mr={0.5} />
                Поместите яйцо в станцию
              </Box>
            </Box>
          )}
        </Section>
        <Section title="Научная сеть">
          <LabeledList>
            <LabeledList.Item label="Общий баланс">
              <Stack align="baseline">
                <Stack.Item grow>
                  <Box
                    bold
                    color={
                      !data.research_connected
                        ? 'bad'
                        : data.points >= data.adaptation_cost
                          ? 'good'
                          : 'average'
                    }
                  >
                    {data.research_connected
                      ? `${toFixed(data.points, 1)} очков`
                      : 'Нет связи'}
                  </Box>
                </Stack.Item>
                <Stack.Item color="label">
                  Одна адаптация: {data.adaptation_cost} очков
                </Stack.Item>
              </Stack>
            </LabeledList.Item>
          </LabeledList>
          <Box color="label" mt={0.5}>
            Баланс используется и другими исследовательскими консолями.
          </Box>
        </Section>
        <Section title="Направления адаптации">
          <Box mb={1}>
            Изменение нельзя отменить. Потомство наследует адаптации и общий
            лимит линии.
          </Box>
          {egg && remainingAdaptations === 1 && (
            <Box color="average" mb={1}>
              Осталась одна адаптация — выберите направление внимательно.
            </Box>
          )}
          {!!commonReason && (
            <NoticeBox danger={!data.operational || !data.access_allowed}>
              {commonReason}
            </NoticeBox>
          )}
          {adaptations.map((adaptation, index) => (
            <Box key={adaptation.id}>
              {index > 0 && <Divider />}
              <Stack align="center" py={0.5}>
                <Stack.Item color="label" width={2} textAlign="center">
                  <Icon name={adaptationIcons[adaptation.id] || 'flask'} />
                </Stack.Item>
                <Stack.Item grow basis={0}>
                  <Box bold mb={0.5}>
                    {adaptation.name}
                  </Box>
                  <Box color="label">{adaptation.description}</Box>
                  {!!adaptation.reason && !commonReason && (
                    <Box color="average" mt={0.5}>
                      {adaptation.reason}
                    </Box>
                  )}
                </Stack.Item>
                <Stack.Item>
                  <Button.Confirm
                    key={`${egg?.ref}-${egg?.adaptations}-${data.adaptation_cost}-${!!adaptation.available}-${!!data.can_operate}`}
                    width={9.5}
                    textAlign="center"
                    icon="flask"
                    confirmIcon="check"
                    confirmContent={`Списать ${data.adaptation_cost}?`}
                    tooltip={
                      adaptation.reason ||
                      `${adaptation.name}: ${data.adaptation_cost} очков, одно изменение линии. Наследуется потомством.`
                    }
                    disabled={
                      !egg || !data.can_operate || !adaptation.available
                    }
                    onClick={() =>
                      egg &&
                      act('adapt', {
                        egg: egg.ref,
                        adaptation: adaptation.id,
                        expected_adaptations: egg.adaptations,
                      })
                    }
                  >
                    Применить
                  </Button.Confirm>
                </Stack.Item>
              </Stack>
            </Box>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};

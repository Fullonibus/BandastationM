import {
  Box,
  Button,
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

export const PhoenixAdaptation = () => {
  const { act, data } = useBackend<Data>();
  const { egg, adaptations = [] } = data;

  return (
    <Window width={560} height={700}>
      <Window.Content scrollable>
        {!data.operational && (
          <NoticeBox danger>
            Станция не работает. Проверьте питание и состояние оборудования.
          </NoticeBox>
        )}
        {!data.access_allowed && (
          <NoticeBox danger>
            Для работы со станцией необходим научный доступ.
          </NoticeBox>
        )}
        <Section title="Научная сеть">
          {!data.research_connected && (
            <NoticeBox danger>Нет связи с исследовательской сетью</NoticeBox>
          )}
          <LabeledList>
            <LabeledList.Item label="Научные очки">
              <Box
                bold
                color={
                  !data.research_connected
                    ? 'label'
                    : data.points >= data.adaptation_cost
                      ? 'good'
                      : 'average'
                }
              >
                {data.research_connected
                  ? toFixed(data.points, 1)
                  : 'Недоступны'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Стоимость адаптации">
              {data.adaptation_cost} очков
            </LabeledList.Item>
          </LabeledList>
          <Box color="label" mt={1}>
            Это общий баланс подключённой научной сети. Эти же очки расходуются
            на исследования других консолей.
          </Box>
        </Section>
        <Section
          title="Образец"
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
              <LabeledList>
                <LabeledList.Item label="Яйцо">{egg.name}</LabeledList.Item>
                <LabeledList.Item label="Поколение">
                  {egg.generation}
                </LabeledList.Item>
                <LabeledList.Item label="Адаптации линии">
                  <ProgressBar
                    value={egg.adaptations}
                    minValue={0}
                    maxValue={data.max_adaptations}
                    color={
                      egg.adaptations >= data.max_adaptations
                        ? 'average'
                        : 'teal'
                    }
                  >
                    Использовано {egg.adaptations} / {data.max_adaptations}
                  </ProgressBar>
                </LabeledList.Item>
              </LabeledList>
              <Box color="label" mt={1}>
                Пока яйцо находится в станции, его развитие приостановлено.
              </Box>
            </>
          ) : (
            <>
              <NoticeBox info>Яйцо не загружено</NoticeBox>
              <Box>Возьмите яйцо в руку и нажмите им на станцию.</Box>
            </>
          )}
        </Section>
        <Section title="Адаптации">
          <NoticeBox>
            Изменения сохраняются в потомстве. Вся линия наследует общий лимит
            из {data.max_adaptations} адаптаций.
          </NoticeBox>
          {adaptations.map((adaptation) => (
            <Box key={adaptation.id} mb={1.5}>
              <Stack align="center" mb={0.5}>
                <Stack.Item grow>
                  <Box bold>{adaptation.name}</Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="flask"
                    disabled={
                      !egg || !data.can_operate || !adaptation.available
                    }
                    tooltip={adaptation.reason || undefined}
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
                  </Button>
                </Stack.Item>
              </Stack>
              <Box color="label">{adaptation.description}</Box>
              {!!adaptation.reason && (
                <Box color="average" mt={0.5}>
                  {adaptation.reason}
                </Box>
              )}
            </Box>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};

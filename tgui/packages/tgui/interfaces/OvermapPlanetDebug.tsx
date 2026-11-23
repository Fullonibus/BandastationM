import { useState } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Modifier = {
  id: string;
  name: string;
  group: string;
};

type Profile = {
  id: string;
  name: string;
  modifiers: Modifier[];
};

type Planet = {
  id: string;
  ref: string;
  name: string;
  profile: string;
  profile_name: string;
  seed: number;
  level: number;
  width: number;
  modifiers: string[];
  status: string;
  can_generate: boolean;
  can_replace: boolean;
};

type Data = {
  profiles: Profile[];
  systems: { id: string; name: string; planets: Planet[] }[];
};

type ModifierMode = 'random' | 'manual' | 'none';

const modifierModes: { id: ModifierMode; name: string }[] = [
  { id: 'random', name: 'Случайно' },
  { id: 'manual', name: 'Вручную' },
  { id: 'none', name: 'Без модификаторов' },
];

const sizes = [
  { value: 0, displayText: 'По профилю' },
  { value: 128, displayText: '128 × 128' },
  { value: 176, displayText: '176 × 176' },
];

const modifierGroups: Record<string, string> = {
  ore: 'Руда',
  fauna: 'Фауна',
  weather: 'Погода',
  underground: 'Подземелья',
  nest: 'Логова',
  boss: 'Мегафауна',
  anomaly: 'Аномалии',
  hazard: 'Опасности',
  guardians: 'Стражи',
  geysers: 'Гейзеры',
  light: 'Освещение',
};

export function OvermapPlanetDebug() {
  const { data } = useBackend<Data>();
  const { systems, profiles } = data;
  const [systemId, setSystemId] = useState('');
  const [planetId, setPlanetId] = useState('');
  const system = systems.find(({ id }) => id === systemId) || systems[0];
  const planet =
    system?.planets.find(({ id }) => id === planetId) || system?.planets[0];

  return (
    <Window title="Планеты системы" width={900} height={620}>
      <Window.Content>
        {system ? (
          <Stack fill>
            <Stack.Item width={19}>
              <Section fill scrollable title="Система">
                {systems.map(({ id, name }) => (
                  <Button
                    key={id}
                    fluid
                    selected={id === system.id}
                    onClick={() => {
                      setSystemId(id);
                      setPlanetId('');
                    }}
                  >
                    {name}
                  </Button>
                ))}
                <Stack vertical mt={1}>
                  {system.planets.map((site) => (
                    <Stack.Item key={site.id}>
                      <Button
                        fluid
                        icon="globe"
                        selected={site.id === planet?.id}
                        onClick={() => setPlanetId(site.id)}
                      >
                        {site.name}
                      </Button>
                      <Box color="label" ml={2} fontSize={0.9}>
                        {site.profile_name} · {site.status}
                      </Box>
                    </Stack.Item>
                  ))}
                </Stack>
              </Section>
            </Stack.Item>
            <Stack.Item grow minWidth={0}>
              {planet ? (
                <PlanetPanel
                  key={planet.ref}
                  planet={planet}
                  profiles={profiles}
                  systemId={system.id}
                />
              ) : (
                <NoticeBox>В этой системе нет процедурных планет.</NoticeBox>
              )}
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox>Нет готовых секторов овермапы.</NoticeBox>
        )}
      </Window.Content>
    </Window>
  );
}

function PlanetPanel(props: {
  planet: Planet;
  profiles: Profile[];
  systemId: string;
}) {
  const { planet, profiles, systemId } = props;
  const { act } = useBackend<Data>();
  const [profileId, setProfileId] = useState(planet.profile);
  const [seed, setSeed] = useState(planet.seed);
  const [level, setLevel] = useState(planet.level);
  const [width, setWidth] = useState(0);
  const [mode, setMode] = useState<ModifierMode>('random');
  const [modifiers, setModifiers] = useState<Record<string, string>>({});
  const profile = profiles.find(({ id }) => id === profileId);
  const groups = new Map<string, Modifier[]>();
  for (const modifier of profile?.modifiers || []) {
    const group = groups.get(modifier.group);
    if (group) {
      group.push(modifier);
    } else {
      groups.set(modifier.group, [modifier]);
    }
  }
  const target = { system: systemId, planet: planet.id, ref: planet.ref };
  const selectedIds = Object.values(modifiers).filter(Boolean);

  return (
    <Stack fill vertical>
      <Stack.Item grow minHeight={0}>
        <Section fill scrollable title={planet.name}>
          <LabeledList>
            <LabeledList.Item label="Профиль">
              {planet.profile_name}
            </LabeledList.Item>
            <LabeledList.Item label="Поверхность">
              {planet.width} × {planet.width} · {planet.status}
            </LabeledList.Item>
            <LabeledList.Item label="Seed и уровень">
              {planet.seed} · {planet.level}
            </LabeledList.Item>
            <LabeledList.Item label="Модификаторы">
              {planet.modifiers.join(', ') || 'Нет'}
            </LabeledList.Item>
          </LabeledList>
          <Box mt={0.75}>
            <Button icon="list" onClick={() => act('details', target)}>
              Отчёт
            </Button>
            <Button.Confirm
              icon="mountain"
              confirmContent="Подтвердить генерацию"
              disabled={!planet.can_generate}
              tooltip="Создаёт поверхность и блокирует последующую замену планеты"
              onClick={() => act('generate', target)}
            >
              Сгенерировать поверхность
            </Button.Confirm>
          </Box>
          {planet.can_replace ? (
            <Section
              title="Настройки замены"
              mt={1}
              buttons={
                <Button.Confirm
                  icon="dice"
                  confirmContent="Подтвердить случайную замену"
                  tooltip="Случайный профиль, сид и модификаторы"
                  onClick={() => act('random_replace', target)}
                >
                  Случайная замена
                </Button.Confirm>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Профиль">
                  {profiles.map(({ id, name }) => (
                    <Button
                      key={id}
                      selected={id === profileId}
                      onClick={() => {
                        if (id !== profileId) {
                          setProfileId(id);
                          setModifiers({});
                        }
                      }}
                    >
                      {name}
                    </Button>
                  ))}
                </LabeledList.Item>
                <LabeledList.Item label="Seed рельефа">
                  <NumberInput
                    value={seed}
                    minValue={1}
                    maxValue={1000000}
                    onChange={(value) => setSeed(Math.round(value))}
                    width={8}
                  />
                  <Button
                    ml={0.5}
                    icon="dice"
                    tooltip="Случайный seed"
                    onClick={() =>
                      setSeed(Math.floor(Math.random() * 1000000) + 1)
                    }
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Уровень">
                  <NumberInput
                    value={level}
                    minValue={0}
                    maxValue={10}
                    step={0.1}
                    onChange={setLevel}
                    width={5}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Размер">
                  {sizes.map(({ value, displayText }) => (
                    <Button
                      key={value}
                      selected={width === value}
                      onClick={() => setWidth(value)}
                    >
                      {displayText}
                    </Button>
                  ))}
                </LabeledList.Item>
                <LabeledList.Item label="Модификаторы">
                  {modifierModes.map(({ id, name }) => (
                    <Button
                      key={id}
                      selected={mode === id}
                      onClick={() => setMode(id)}
                    >
                      {name}
                    </Button>
                  ))}
                </LabeledList.Item>
              </LabeledList>
              {mode === 'manual' && (
                <Section
                  title={`Выбрано модификаторов: ${selectedIds.length}`}
                  mt={1}
                >
                  {groups.size ? (
                    <LabeledList>
                      {Array.from(groups, ([group, options]) => (
                        <LabeledList.Item
                          key={group}
                          label={modifierGroups[group] || group}
                        >
                          {options.map(({ id, name }) => (
                            <Button.Checkbox
                              key={id}
                              checked={modifiers[group] === id}
                              onClick={() =>
                                setModifiers((previous) => ({
                                  ...previous,
                                  [group]: previous[group] === id ? '' : id,
                                }))
                              }
                            >
                              {name}
                            </Button.Checkbox>
                          ))}
                        </LabeledList.Item>
                      ))}
                    </LabeledList>
                  ) : (
                    <Box color="label">Совместимых модификаторов нет.</Box>
                  )}
                </Section>
              )}
            </Section>
          ) : (
            <Box color="label" mt={1}>
              Замена доступна до генерации поверхности и без активного захода
              корабля.
            </Box>
          )}
        </Section>
      </Stack.Item>
      {planet.can_replace && (
        <Stack.Item>
          <Box textAlign="right">
            <Button.Confirm
              color="good"
              icon="check"
              confirmContent="Подтвердить замену"
              disabled={!profile}
              onClick={() =>
                act('replace', {
                  ...target,
                  profile: profileId,
                  seed,
                  level,
                  width,
                  mode,
                  modifiers: selectedIds,
                })
              }
            >
              Заменить планету
            </Button.Confirm>
          </Box>
        </Stack.Item>
      )}
    </Stack>
  );
}

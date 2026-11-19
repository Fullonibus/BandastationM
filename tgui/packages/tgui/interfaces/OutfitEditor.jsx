import { useState } from 'react';
import {
  Box,
  Button,
  Image,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const tabs = [
  { id: 'gear', label: 'Equipment', icon: 'tshirt' },
  { id: 'storage', label: 'Containers', icon: 'box-open' },
  { id: 'implants', label: 'Implants', icon: 'microchip' },
  { id: 'cybernetics', label: 'Кибернетика', icon: 'robot' },
];

export const OutfitEditor = () => {
  const { act, data } = useBackend();
  const { outfit, saveable } = data;
  const [tab, setTab] = useState('gear');

  return (
    <Window width={460} height={620} theme="admin">
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item shrink={0}>
            <Section
              title={
                <Stack>
                  <Stack.Item
                    grow={1}
                    title={outfit.name}
                    style={{
                      overflow: 'hidden',
                      whiteSpace: 'nowrap',
                      textOverflow: 'ellipsis',
                    }}
                  >
                    <Button
                      ml={0.5}
                      color="transparent"
                      icon="pencil-alt"
                      title="Rename this outfit"
                      onClick={() => act('rename', {})}
                    />
                    {outfit.name}
                  </Stack.Item>
                  <Stack.Item align="end" shrink={0}>
                    <Button
                      color="transparent"
                      icon="info"
                      tooltip="Ctrl-click an equipment slot to search all items."
                      tooltipPosition="bottom-start"
                    />
                    <Button
                      color={outfit.mental_conditioning ? 'good' : undefined}
                      icon="brain"
                      role="button"
                      aria-label="Mental conditioning"
                      aria-pressed={!!outfit.mental_conditioning}
                      tooltip={
                        outfit.mental_conditioning
                          ? 'Mental conditioning: ON (click to disable)'
                          : 'Mental conditioning: OFF (click to enable)'
                      }
                      tooltipPosition="bottom-start"
                      onClick={() => act('toggle_mental_conditioning')}
                    />
                    <Button
                      icon="code"
                      tooltip="Edit this outfit on a VV window"
                      tooltipPosition="bottom-start"
                      onClick={() => act('vv')}
                    />
                    <Button
                      color={!saveable && 'bad'}
                      icon={saveable ? 'save' : 'trash-alt'}
                      tooltip={
                        saveable
                          ? 'Save this outfit to the custom outfit list'
                          : 'Remove this outfit from the custom outfit list'
                      }
                      tooltipPosition="bottom-start"
                      onClick={() => act(saveable ? 'save' : 'delete')}
                    />
                  </Stack.Item>
                </Stack>
              }
            >
              <Tabs style={{ flexWrap: 'wrap' }}>
                {tabs.map(({ id, label, icon }) => (
                  <Tabs.Tab
                    key={id}
                    icon={icon}
                    role="button"
                    tabIndex={0}
                    aria-label={label}
                    aria-pressed={id === tab}
                    selected={id === tab}
                    style={{ '--space-m': 'var(--space-s)', outlineOffset: -2 }}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault();
                        event.currentTarget.click();
                      }
                    }}
                    onClick={() => setTab(id)}
                  >
                    {label}
                  </Tabs.Tab>
                ))}
              </Tabs>
            </Section>
          </Stack.Item>
          <Stack.Item
            key={tab}
            grow
            basis={0}
            role="region"
            aria-label="Содержимое редактора"
            tabIndex={0}
            style={{ minHeight: 0, overflowY: 'auto' }}
          >
            {tab === 'gear' && (
              <>
                <Equipment />
                <AdditionalEquipment />
              </>
            )}
            {tab === 'storage' && <Containers />}
            {tab === 'implants' && <Implants />}
            {tab === 'cybernetics' && <Cybernetics />}
            {tab === 'check' && <OutfitCheck />}
          </Stack.Item>
          <Stack.Item shrink={0}>
            <Section>
              <Box textAlign="right">
                <Button
                  icon="clipboard-check"
                  role="button"
                  aria-label="Проверить аутфит"
                  aria-pressed={tab === 'check'}
                  selected={tab === 'check'}
                  onClick={() => {
                    setTab('check');
                    act('check_outfit');
                  }}
                >
                  Проверить аутфит
                </Button>
              </Box>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const destinationLabels = {
  head: 'Головной убор',
  glasses: 'Очки',
  ear_right: 'Правое ухо',
  ear_left: 'Левое ухо',
  neck: 'Шея',
  mask: 'Маска',
  uniform: 'Форма',
  accessory: 'Аксессуар формы',
  undershirt: 'Майка',
  underwear: 'Бельё',
  socks: 'Носки',
  suit: 'Костюм',
  gloves: 'Перчатки',
  suit_store: 'Слот костюма',
  back: 'Слот спины',
  id: 'ID',
  belt: 'Пояс',
  l_hand: 'Левая рука',
  r_hand: 'Правая рука',
  shoes: 'Обувь',
  l_pocket: 'Левый карман',
  r_pocket: 'Правый карман',
  box: 'Коробка в рюкзаке',
  backpack_contents: 'Содержимое рюкзака',
  belt_contents: 'Содержимое пояса',
  box_contents: 'Содержимое коробки',
};

const OutfitCheck = () => {
  const { outfit_check: result, cybernetics } = useBackend().data;
  if (!result) {
    return (
      <Section title="Примерка на манекене">
        Здесь появится результат проверки текущего аутфита.
      </Section>
    );
  }

  return (
    <>
      <Section title="Примерка на манекене">
        <Stack align="center">
          <Stack.Item shrink={0}>
            <Image
              width="96px"
              height="96px"
              src={`data:image/jpeg;base64,${result.dummy64}`}
              title="Манекен после примерки"
            />
          </Stack.Item>
          <Stack.Item grow>
            <Box color={result.issues.length ? 'bad' : 'good'} bold>
              {result.issues.length
                ? 'Часть комплекта не удалось выдать'
                : 'Экипировка и содержимое подошли'}
            </Box>
            <Box color="label" mt={0.5}>
              Проверены экипировка, контейнеры, протезы и киберорганы.
            </Box>
          </Stack.Item>
        </Stack>
      </Section>
      {!!result.issues.length && (
        <Section title="Что не удалось выдать">
          {result.issues.map(({ destination, path, name, reason, count }) => (
            <Box key={`${destination}|${path}|${reason}`} mb={1}>
              <Box bold title={path}>
                {getDestinationLabel(destination, cybernetics)} · {name}
                {count > 1 && ` ×${count}`}
              </Box>
              <Box color="label">{reason}</Box>
            </Box>
          ))}
        </Section>
      )}
    </>
  );
};

const Equipment = () => {
  const { dummy64 } = useBackend().data;

  return (
    <Section>
      <Box position="relative">
        <Image
          fillPositionedParent
          width="100%"
          height="100%"
          opacity={0.5}
          src={`data:image/jpeg;base64,${dummy64}`}
          style={{ pointerEvents: 'none' }}
        />
        <Box position="relative" textAlign="center">
          <Stack mb={1}>
            <OutfitSlot name="Headgear" icon="hard-hat" slot="head" />
            <OutfitSlot name="Glasses" icon="glasses" slot="glasses" />
            {/* AI EDIT START - Expose both ear slots in the outfit editor */}
            {/* BANDASTATION EDIT - Dual ear slots */}
            <OutfitSlot
              name="Right Ear"
              icon="headphones-alt"
              slot="ear_right"
            />
            <OutfitSlot name="Left Ear" icon="headphones-alt" slot="ear_left" />
            {/* AI EDIT END */}
          </Stack>
          <Stack mb={1}>
            <OutfitSlot name="Neck" icon="stethoscope" slot="neck" />
            <OutfitSlot name="Mask" icon="theater-masks" slot="mask" />
          </Stack>
          <Stack mb={1}>
            <OutfitSlot name="Uniform" icon="tshirt" slot="uniform" />
            <OutfitSlot name="Suit" icon="user-tie" slot="suit" />
            <OutfitSlot name="Gloves" icon="mitten" slot="gloves" />
          </Stack>
          <Stack mb={1}>
            <OutfitSlot
              name="Suit Storage"
              icon="briefcase-medical"
              slot="suit_store"
            />
            <OutfitSlot name="Back" icon="shopping-bag" slot="back" />
            <OutfitSlot name="ID" icon="id-card-o" slot="id" />
          </Stack>
          <Stack mb={1}>
            <OutfitSlot name="Belt" icon="band-aid" slot="belt" />
            <OutfitSlot name="Left Hand" icon="hand-paper" slot="l_hand" />
            <OutfitSlot name="Right Hand" icon="hand-paper" slot="r_hand" />
          </Stack>
          <Stack>
            <OutfitSlot name="Shoes" icon="socks" slot="shoes" />
            <OutfitSlot
              name="Left Pocket"
              icon="envelope-open-o"
              iconRot={180}
              slot="l_pocket"
            />
            <OutfitSlot
              name="Right Pocket"
              icon="envelope-open-o"
              iconRot={180}
              slot="r_pocket"
            />
          </Stack>
        </Box>
      </Box>
    </Section>
  );
};

const getDestinationLabel = (destination, cybernetics) => {
  const [kind, slot] = destination.split(':');
  return (
    cybernetics?.[kind]?.find((entry) => entry.slot === slot)?.label ??
    destinationLabels[destination] ??
    destination
  );
};

const additionalEquipmentSlots = ['accessory', 'undershirt', 'underwear', 'socks'];

const AdditionalEquipment = () => {
  const { act, data } = useBackend();
  const { outfit, outfit_check } = data;
  return (
    <Section title="Дополнительные слоты">
      {additionalEquipmentSlots.map((slot) => (
        <SlotChoiceRow
          key={slot}
          label={destinationLabels[slot]}
          item={outfit[slot]}
          empty={slot === 'accessory' ? 'Без аксессуара' : 'Как у персонажа'}
          issue={outfit_check?.issues.find((entry) => entry.destination === slot)}
          onChoose={() => act('click', { slot })}
          onClear={() => act('clear', { slot })}
        />
      ))}
    </Section>
  );
};

const Cybernetics = () => {
  const { act, data } = useBackend();
  const { cybernetics, outfit_check } = data;
  return (
    <>
      {[
        { kind: 'prosthetics', title: 'Протезы' },
        { kind: 'cyber_organs', title: 'Киберорганы и устройства' },
      ].map(({ kind, title }) => (
        <Section key={kind} title={title}>
          {cybernetics?.[kind]?.map(({ slot, label, item, chooseable }) => (
            <SlotChoiceRow
              key={slot}
              label={label}
              item={item}
              empty="Без замены"
              issue={outfit_check?.issues.find(
                (entry) => entry.destination === `${kind}:${slot}`,
              )}
              onChoose={
                chooseable
                  ? () => act('cyber_choose', { kind, slot })
                  : undefined
              }
              onClear={() => act('cyber_clear', { kind, slot })}
            />
          ))}
        </Section>
      ))}
    </>
  );
};

const SlotChoiceRow = ({ label, item, empty, issue, onChoose, onClear }) => (
  <Stack align="center" mb={0.5}>
    <Stack.Item basis="40%" shrink={0}>
      {label}
    </Stack.Item>
    <Stack.Item basis="26px" shrink={0}>
      {item?.sprite && (
        <Image
          width="24px"
          height="24px"
          verticalAlign="middle"
          src={`data:image/jpeg;base64,${item.sprite}`}
          title={item.desc}
        />
      )}
    </Stack.Item>
    <Stack.Item grow minWidth={0}>
      <Button
        fluid
        ellipsis
        icon={item ? 'pen' : 'plus'}
        color={(issue && 'bad') || (!item && 'transparent')}
        disabled={!onChoose}
        role="button"
        aria-label={`Выбрать для слота «${label}»`}
        tooltip={issue?.reason}
        title={issue?.reason || item?.name || empty}
        onClick={onChoose}
        content={item?.name || empty}
      />
    </Stack.Item>
    <Stack.Item basis="22px" shrink={0} ml={0.5}>
      {item && (
        <Button
          compact
          color="transparent"
          icon="times"
          role="button"
          aria-label={`Сбросить слот «${label}»`}
          title={`Сбросить слот «${label}»`}
          onClick={onClear}
        />
      )}
    </Stack.Item>
  </Stack>
);

const Containers = () => {
  const { act, data } = useBackend();
  const { outfit } = data;

  return (
    <>
      <Container
        title="Backpack"
        slot="backpack_contents"
        container={outfit.back}
        emptyContainer="Choose a backpack in Equipment to carry these items."
      />
      <Container
        title="Belt"
        slot="belt_contents"
        container={outfit.belt}
        emptyContainer="Choose a belt in Equipment to carry these items."
      />
      <Container
        title="Box in backpack"
        slot="box_contents"
        container={outfit.box}
        emptyContainer="Choose a box to carry these items."
        controls={
          <>
            <Button icon="box" onClick={() => act('click', { slot: 'box' })}>
              {outfit.box ? 'Change box' : 'Choose box'}
            </Button>
            {!!outfit.box && (
              <Button
                icon="times"
                tooltip="Remove box"
                title="Remove box"
                onClick={() => act('clear', { slot: 'box' })}
              />
            )}
          </>
        }
      />
    </>
  );
};

const Container = ({ title, slot, container, emptyContainer, controls }) => {
  const { act, data } = useBackend();
  const { storage, max_item_count } = data;
  const items = storage[slot];

  return (
    <Section
      title={title}
      buttons={
        <>
          {controls}
          <Button icon="plus" onClick={() => act('storage_add', { slot })}>
            Add item
          </Button>
        </>
      }
    >
      <Box color="label" mb={1}>
        {container?.name || emptyContainer}
        {slot === 'box_contents' &&
          container &&
          ' · Added items go alongside the box’s default contents.'}
      </Box>
      {!items.length && <Box color="label">No added items.</Box>}
      {items.map((item) => (
        <ItemRow key={item.path} item={item}>
          <NumberInput
            width="48px"
            minValue={1}
            maxValue={Math.max(max_item_count, item.count)}
            step={1}
            value={item.count}
            onChange={(count) =>
              act('storage_count', { slot, path: item.path, count })
            }
          />
          <Button
            ml={0.5}
            icon="trash-alt"
            tooltip={`Remove ${item.name}`}
            title={`Remove ${item.name}`}
            onClick={() => act('storage_remove', { slot, path: item.path })}
          />
        </ItemRow>
      ))}
    </Section>
  );
};

const Implants = () => {
  const { act, data } = useBackend();
  const { implants } = data;

  return (
    <Section
      title="Starting implants"
      buttons={
        <Button icon="plus" onClick={() => act('implant_add')}>
          Add implant
        </Button>
      }
    >
      {!implants.length && <Box color="label">No implants configured.</Box>}
      {implants.map((item) => (
        <ItemRow key={item.path} item={item}>
          {item.count > 1 && (
            <Box inline mr={1}>
              ×{item.count}
            </Box>
          )}
          <Button
            icon="trash-alt"
            tooltip={`Remove ${item.name}`}
            title={`Remove ${item.name}`}
            onClick={() => act('implant_remove', { path: item.path })}
          />
        </ItemRow>
      ))}
    </Section>
  );
};

const ItemRow = ({ item, children }) => (
  <Stack align="center" mb={0.5}>
    <Stack.Item basis="32px" shrink={0} height="32px">
      {item.sprite && (
        <Image
          src={`data:image/jpeg;base64,${item.sprite}`}
          title={item.desc}
        />
      )}
    </Stack.Item>
    <Stack.Item grow style={{ minWidth: 0 }}>
      <Box
        title={item.path}
        style={{
          overflow: 'hidden',
          whiteSpace: 'nowrap',
          textOverflow: 'ellipsis',
        }}
      >
        {item.name}
      </Box>
    </Stack.Item>
    <Stack.Item shrink={0}>{children}</Stack.Item>
  </Stack>
);

const OutfitSlot = (props) => {
  const { act, data } = useBackend();
  const { name, icon, iconRot, slot } = props;
  const { outfit } = data;
  const currItem = outfit[slot];
  const failed = data.outfit_check?.issues.find(
    (issue) => issue.destination === slot,
  );
  return (
    <Stack.Item grow={1} basis={0} style={{ minWidth: 0 }}>
      <Button
        fluid
        height={2}
        bold
        ellipsis
        icon={icon}
        iconRotation={iconRot}
        color={failed && 'bad'}
        tooltip={failed?.reason || name}
        role="button"
        aria-label={name}
        onClick={(e) => act(e.ctrlKey ? 'ctrlClick' : 'click', { slot })}
      >
        {name}
      </Button>
      <Box height="32px" position="relative">
        {currItem?.sprite && (
          <Image
            src={`data:image/jpeg;base64,${currItem.sprite}`}
            title={currItem.desc}
          />
        )}
        {currItem?.path && (
          <Button
            position="absolute"
            top={0}
            right={0}
            compact
            icon="times"
            role="button"
            aria-label={`Clear ${name}`}
            tooltip={`Clear ${name}`}
            color="transparent"
            onClick={() => act('clear', { slot })}
          />
        )}
      </Box>
      <Box
        color="label"
        style={{
          overflow: 'hidden',
          whiteSpace: 'nowrap',
          textOverflow: 'ellipsis',
        }}
        title={currItem?.path}
      >
        {currItem?.name || 'Empty'}
      </Box>
    </Stack.Item>
  );
};

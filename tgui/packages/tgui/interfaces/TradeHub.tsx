import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Image,
  Input,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';
import { createSearch } from 'tgui-core/string';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import '../styles/themes/trade-hub.scss';

type Data = {
  name: string;
  specialization: string;
  connected: BooleanLike;
  operational: BooleanLike;
  balance: number;
  status: string;
  input_ready: BooleanLike;
  output_ready: BooleanLike;
  offers: {
    id: string;
    name: string;
    description: string;
    group: string;
    price: number;
    stock: number;
    capacity: number;
  }[];
  requests: {
    id: string;
    name: string;
    icon: string;
    group: string;
    category: string;
    base_unit_reward: number;
    price_multiplier: number;
    delivered: number;
    required: number;
    remaining: number;
    unit_reward: number;
    restock_amount: number;
    ready_in: number;
    renew_in: number;
  }[];
  contracts?: {
    id: string;
    name: string;
    customer: string;
    target: string;
    credits: number;
  }[];
};

export function TradeHub() {
  const { data } = useBackend<Data>();
  const {
    name,
    specialization,
    connected,
    operational,
    balance,
    status,
    input_ready,
    output_ready,
  } = data;

  return (
    <Window title="Торговый узел" width={820} height={660} theme="trade-hub">
      <Window.Content scrollable>
        <Section
          title={name}
          buttons={
            <Box bold color="good">
              Бюджет карго: {formatMoney(balance)} кр.
            </Box>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Специализация">
              {specialization}
            </LabeledList.Item>
            <LabeledList.Item
              label="Подключение"
              color={connected && operational ? 'good' : 'bad'}
            >
              {!connected
                ? 'Нет связи'
                : operational
                  ? 'Узел готов к торговле'
                  : 'Терминал недоступен'}
            </LabeledList.Item>
            <LabeledList.Item
              label="Приём груза"
              color={input_ready ? 'good' : 'average'}
            >
              {input_ready ? 'Площадка готова' : 'Площадка недоступна'}
            </LabeledList.Item>
            <LabeledList.Item
              label="Выдача заказа"
              color={output_ready ? 'good' : 'average'}
            >
              {output_ready
                ? 'Площадка свободна'
                : 'Площадка недоступна или занята'}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        {!connected ? (
          <NoticeBox danger>
            Нет связи с торговым узлом. Покупка и приём грузов недоступны.
          </NoticeBox>
        ) : (
          !operational && (
            <NoticeBox danger>
              Терминал не готов к работе. Проверьте питание и состояние
              оборудования.
            </NoticeBox>
          )
        )}
        {!!status && <NoticeBox info>{status}</NoticeBox>}
        <TradeHubContracts />
        <TradeHubOffers />
        <TradeHubRequests />
      </Window.Content>
    </Window>
  );
}

function TradeHubOffers() {
  const { act, data } = useBackend<Data>();
  const { connected, operational, balance, output_ready, offers = [] } = data;
  const [searchText, setSearchText] = useState('');
  const [selectedGroup, setSelectedGroup] = useState('');
  const groups = [...new Set(offers.map((offer) => offer.group))].sort();
  const search = createSearch(
    searchText,
    (offer: Data['offers'][number]) =>
      `${offer.name} ${offer.description} ${offer.group}`,
  );
  const filteredOffers = offers.filter(
    (offer) => (!selectedGroup || offer.group === selectedGroup) && search(offer),
  );

  return (
    <Section
      title="Предложения узла"
      buttons={
        <Box color="label">
          Показано: {filteredOffers.length}/{offers.length}
        </Box>
      }
    >
      <Box color="label" mb={1}>
        Один заказ выдаёт один ящик на площадку выдачи. Оплата — из бюджета карго.
      </Box>
      <Box mb={1}>
        <Input
          width={30}
          mr={1}
          alwaysUpdate
          placeholder="Поиск по названию, описанию или группе"
          value={searchText}
          onChange={setSearchText}
        />
        <Dropdown
          width={22}
          mr={1}
          selected={selectedGroup}
          displayText={selectedGroup || 'Все группы'}
          options={[{ displayText: 'Все группы', value: '' }, ...groups]}
          onSelected={setSelectedGroup}
        />
        <Button
          icon="times"
          disabled={!searchText && !selectedGroup}
          onClick={() => {
            setSearchText('');
            setSelectedGroup('');
          }}
        >
          Сбросить
        </Button>
      </Box>
      {offers.length === 0 ? (
        <Box color="label">Нет доступных предложений.</Box>
      ) : filteredOffers.length === 0 ? (
        <Box color="label">
          По заданным фильтрам ничего не найдено. Измените поиск или сбросьте
          фильтры.
        </Box>
      ) : (
        <Table>
          <Table.Row header>
            <Table.Cell>Товар / группа</Table.Cell>
            <Table.Cell collapsing textAlign="center">
              Запас
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              Цена
            </Table.Cell>
            <Table.Cell collapsing />
          </Table.Row>
          {filteredOffers.map((offer) => {
            const blockedReason = !connected
              ? 'Нет связи с узлом.'
              : !operational
                ? 'Терминал недоступен.'
                : !output_ready
                  ? 'Освободите площадку выдачи.'
                  : offer.stock <= 0
                    ? 'Товара сейчас нет на этом узле.'
                    : balance < offer.price
                      ? 'В бюджете карго недостаточно средств.'
                      : undefined;

            return (
              <Table.Row key={offer.id} className="candystripe">
                <Table.Cell py={0.75}>
                  <Box bold>{offer.name}</Box>
                  <Box color="label">{offer.group}</Box>
                  <Box fontSize={0.9}>{offer.description}</Box>
                </Table.Cell>
                <Table.Cell
                  collapsing
                  textAlign="center"
                  color={offer.stock > 0 ? 'good' : 'bad'}
                >
                  {offer.stock}/{offer.capacity}
                </Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  {formatMoney(offer.price)} кр.
                </Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  <Button
                    icon="shopping-cart"
                    disabled={!!blockedReason}
                    tooltip={blockedReason || 'Купить один ящик.'}
                    onClick={() => act('buy', { id: offer.id })}
                  >
                    Купить
                  </Button>
                </Table.Cell>
              </Table.Row>
            );
          })}
        </Table>
      )}
    </Section>
  );
}

function TradeHubContracts() {
  const { act, data } = useBackend<Data>();
  const { connected, operational, input_ready, contracts = [] } = data;

  if (contracts.length === 0) {
    return null;
  }
  const blockedReason = !connected
    ? 'Нет связи с узлом.'
    : !operational
      ? 'Терминал недоступен.'
      : !input_ready
        ? 'Площадка приёма недоступна.'
        : undefined;

  return (
    <Section title="Контракты экспедиционного корпуса">
      <Box color="label" mb={1}>
        Находка сдаётся в закрытом ящике на площадке приёма: аномальная — в
        ящике для образцов, остальное — в любом ящике. Оплата поступает в
        бюджет карго.
      </Box>
      <Table>
        {contracts.map((contract) => (
          <Table.Row key={contract.id} className="candystripe">
            <Table.Cell py={0.75}>
              <Box bold>
                {contract.id}: {contract.name}
              </Box>
              <Box color="label">
                {contract.customer} · {contract.target}
              </Box>
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              {formatMoney(contract.credits)} кр.
            </Table.Cell>
            <Table.Cell collapsing textAlign="right">
              <Button
                icon="box"
                disabled={!!blockedReason}
                tooltip={
                  blockedReason || 'Сдать ящик с находкой с площадки приёма.'
                }
                onClick={() => act('deliver_contract', { id: contract.id })}
              >
                Сдать контракт
              </Button>
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
}

function TradeHubRequests() {
  const { act, data } = useBackend<Data>();
  const { connected, operational, input_ready, requests = [] } = data;

  return (
    <Section title="Местные потребности">
      <Box color="label" mb={1}>
        Положите товар на площадку приёма отдельно или в открытом ящике. Ненужные
        предметы и излишки остаются на месте. Награда поступает в бюджет карго.
      </Box>
      <Box color="label" mb={1}>
        В одной группе может быть несколько независимых заявок на разные товары.
        После исчерпания каждой квоты её сменит другой товар.
      </Box>
      {requests.length === 0 ? (
        <Box color="label">Активных заявок нет.</Box>
      ) : (
        <Table>
          <Table.Row header>
            <Table.Cell>Товар / группа</Table.Cell>
            <Table.Cell>Партия и пополнение</Table.Cell>
            <Table.Cell collapsing textAlign="right">
              За единицу
            </Table.Cell>
            <Table.Cell collapsing />
          </Table.Row>
          {requests.map((request) => {
            const pending = request.ready_in > 0;
            const renewing = request.renew_in > 0;
            const blockedReason = !connected
              ? 'Нет связи с узлом.'
              : !operational
                ? 'Терминал недоступен.'
                : !input_ready
                  ? 'Площадка приёма недоступна.'
                  : pending
                    ? 'Дождитесь пополнения запасов.'
                    : renewing
                      ? 'Дождитесь заявки на другой товар этой группы.'
                      : request.remaining <= 0
                        ? 'Спрос закрыт.'
                        : undefined;

            return (
              <Table.Row key={request.id} className="candystripe">
                <Table.Cell py={0.75}>
                  <Stack align="center">
                    <Stack.Item>
                      <Image
                        width="32px"
                        height="32px"
                        objectFit="contain"
                        src={`data:image/png;base64,${request.icon}`}
                      />
                    </Stack.Item>
                    <Stack.Item grow>
                      <Box bold>{request.name}</Box>
                      <Box color="label">{request.group}</Box>
                      <Box color="label" fontSize={0.9}>
                        {request.category} · ×{request.price_multiplier}
                      </Box>
                      <Box>Осталось квоты: {request.remaining}</Box>
                    </Stack.Item>
                  </Stack>
                </Table.Cell>
                <Table.Cell py={0.75}>
                  <ProgressBar
                    value={request.delivered}
                    maxValue={Math.max(request.required, 1)}
                  >
                    {request.delivered}/{request.required}
                  </ProgressBar>
                  <Box color={pending ? 'good' : 'label'} mt={0.5}>
                    {pending
                      ? `Пополнение через ${Math.ceil(request.ready_in)} с`
                      : renewing
                        ? `Другой товар через ${Math.ceil(request.renew_in)} с`
                        : request.remaining <= 0
                          ? 'Спрос закрыт'
                          : 'Соберите полную партию для пополнения'}
                  </Box>
                  <Box color="label" fontSize={0.9}>
                    +{request.restock_amount} к каждому предложению группы, до
                    вместимости склада
                  </Box>
                </Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  <Box>{formatMoney(request.unit_reward)} кр.</Box>
                  <Box color="label" fontSize={0.9}>
                    База: {formatMoney(request.base_unit_reward)} кр.
                  </Box>
                </Table.Cell>
                <Table.Cell collapsing textAlign="right">
                  <Button
                    icon="box-open"
                    disabled={!!blockedReason}
                    tooltip={
                      blockedReason || 'Принять подходящий товар с площадки.'
                    }
                    onClick={() => act('accept', { id: request.id })}
                  >
                    Сдать груз
                  </Button>
                </Table.Cell>
              </Table.Row>
            );
          })}
        </Table>
      )}
    </Section>
  );
}

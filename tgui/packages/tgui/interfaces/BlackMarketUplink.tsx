import { useState } from 'react';
import {
  AnimatedNumber,
  Box,
  Button,
  Image,
  Modal,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  categories: string[] | null;
  markets: Market[];
  items: Item[];
  money: number;
  has_account: boolean;
  viewing_market: string;
  viewing_category: string;
  ltsrbt_built: boolean;
  delivery_method_description: Record<string, string>;
};

type Market = {
  id: string;
  name: string;
};

type Item = {
  id: string;
  name: string;
  desc: string;
  amount: number;
  cost: number;
  html_icon: string;
  delivery_methods: DeliveryMethod[];
};

type DeliveryMethod = {
  name: string;
  price: number;
};

export const BlackMarketUplink = (props) => {
  const { act, data } = useBackend<Data>();
  const [selection, setSelection] = useState<Selection | null>(null);
  const {
    categories,
    markets = [],
    items = [],
    money,
    has_account,
    viewing_market,
    viewing_category,
  } = data;
  return (
    <Window width={670} height={480} theme="hackerman">
      {!!selection && (
        <ShipmentSelector
          selection={selection}
          onClose={() => setSelection(null)}
        />
      )}
      <Window.Content scrollable>
        <Section
          title="Black Market Uplink"
          buttons={
            <Box inline bold>
              <AnimatedNumber
                value={money}
                format={(value) => `${formatMoney(value)} cr`}
              />
            </Box>
          }
        />
        <Tabs>
          {markets.map((market) => (
            <Tabs.Tab
              key={market.id}
              selected={market.id === viewing_market}
              onClick={() =>
                act('set_market', {
                  market: market.id,
                })
              }
            >
              {market.name}
            </Tabs.Tab>
          ))}
        </Tabs>
        <Stack>
          <Stack.Item>
            <Tabs vertical>
              {categories?.map((category) => (
                <Tabs.Tab
                  key={category}
                  mt={0.5}
                  selected={viewing_category === category}
                  onClick={() =>
                    act('set_category', {
                      category: category,
                    })
                  }
                >
                  {category}
                </Tabs.Tab>
              ))}
            </Tabs>
          </Stack.Item>
          <Stack.Item grow>
            {items.map((item) => (
              <Box key={item.id} className="candystripe" p={1} pb={2}>
                <Stack align="baseline">
                  <Stack.Item grow>
                    <Stack align="horizontal">
                      {!!item.html_icon && (
                        <Stack.Item>
                          <Image
                            m={1}
                            src={`data:image/jpeg;base64,${item.html_icon}`}
                            height="64px"
                            width="64px"
                          />
                        </Stack.Item>
                      )}
                      <Stack.Item grow bold>
                        {item.name}
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                  <Stack.Item color="label">
                    {item.amount ? `${item.amount} in stock` : 'Out of stock'}
                  </Stack.Item>
                  <Stack.Item>{`${formatMoney(item.cost)} cr`}</Stack.Item>
                  <Stack.Item>
                    <Button
                      content="Buy"
                      disabled={
                        !has_account || !item.amount || item.cost > money
                      }
                      onClick={() =>
                        setSelection({
                          item,
                          market: viewing_market,
                          category: viewing_category,
                        })
                      }
                    />
                  </Stack.Item>
                </Stack>
                {item.desc}
              </Box>
            ))}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

type Selection = {
  item: Item;
  market: string;
  category: string;
};

type ShipmentSelectorProps = {
  selection: Selection;
  onClose: () => void;
};

const ShipmentSelector = (props: ShipmentSelectorProps) => {
  const { selection, onClose } = props;
  const { act, data } = useBackend<Data>();
  const { has_account, ltsrbt_built, money } = data;
  return (
    <Modal textAlign="center">
      <Stack mb={1}>
        {selection.item.delivery_methods.map((method) => {
          if (method.name === 'LTSRBT' && !ltsrbt_built) {
            return null;
          }
          const totalCost = selection.item.cost + method.price;
          return (
            <Stack.Item key={method.name} mx={1} width="17.5rem">
              <Box fontSize="30px">{method.name}</Box>
              <Box mt={1}>{data.delivery_method_description[method.name]}</Box>
              <Button
                mt={2}
                content={`${formatMoney(totalCost)} cr`}
                disabled={!has_account || money < totalCost}
                onClick={() => {
                  act('buy', {
                    item: selection.item.id,
                    market: selection.market,
                    category: selection.category,
                    method: method.name,
                    total: totalCost,
                  });
                  onClose();
                }}
              />
            </Stack.Item>
          );
        })}
      </Stack>
      <Button content="Cancel" color="bad" onClick={onClose} />
    </Modal>
  );
};

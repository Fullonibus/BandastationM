import { Button, Input, Stack } from 'tgui-core/components';

import {
  type Feature,
  FeatureTextInput,
  type FeatureValueProps,
} from '../base';

export const flavor_text: Feature<string> = {
  name: 'Описание внешности',
  description: 'Опишите вашего персонажа!',
  component: FeatureTextInput,
};

export const silicon_flavor_text: Feature<string> = {
  name: 'Описание внешности (Синтетик)',
  description: 'Опишите вашего синтетика!',
  component: FeatureTextInput,
};

type PortraitsData = {
  maximum_entries: number;
  maximum_length: number;
};

function PortraitsInput(
  props: FeatureValueProps<string[], string[], PortraitsData>,
) {
  const { value, serverData, handleSetValue } = props;
  return (
    <Stack vertical>
      {value.map((url, index) => (
        <Stack.Item key={index}>
          <Stack>
            <Stack.Item grow>
              <Input
                fluid
                alwaysUpdate
                aria-label={`Ссылка на портрет ${index + 1}`}
                disabled={!serverData}
                value={url}
                maxLength={serverData?.maximum_length}
                onBlur={(newUrl) => {
                  const urls = [...value];
                  urls[index] = newUrl;
                  handleSetValue(urls);
                }}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                {...{ role: 'button' }}
                aria-label={`Удалить портрет ${index + 1}`}
                icon="trash"
                disabled={!serverData}
                onClick={() =>
                  handleSetValue(value.filter((_, row) => row !== index))
                }
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
      ))}
      <Stack.Item>
        <Button
          {...{ role: 'button' }}
          disabled={!serverData || value.length >= serverData.maximum_entries}
          onClick={() => handleSetValue([...value, ''])}
        >
          Добавить портрет
        </Button>
      </Stack.Item>
    </Stack>
  );
}

export const character_portrait_urls: Feature<
  string[],
  string[],
  PortraitsData
> = {
  name: 'Портреты персонажа',
  description:
    'До трёх прямых HTTPS-ссылок на PNG или JPEG с Gyazo, Lensdump, Imgbox, Catbox или File Garden. Очистите поле, чтобы убрать портрет из галереи.',
  component: PortraitsInput,
};

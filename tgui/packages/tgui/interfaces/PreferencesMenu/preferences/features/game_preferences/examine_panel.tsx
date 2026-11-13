import { CheckboxInput, type FeatureToggle } from '../base';

export const show_character_portraits_in_chat: FeatureToggle = {
  name: 'Показывать портреты персонажей в чате',
  category: 'Чат',
  description: 'Показывает небольшую картинку при осмотре персонажа.',
  component: CheckboxInput,
};

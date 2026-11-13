import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import { type Feature, FeatureValueInput } from './preferences/features/base';
import * as features from './preferences/features/character_preferences/examine_panel';
import { ServerPrefs, useServerPrefs } from './useServerPrefs';

const first = 'https://i.gyazo.com/first.png';
const second = 'https://files.catbox.moe/second.jpg';
const third = 'https://images4.imgbox.com/third.png';

function PortraitPreference(props: { value: string[]; loaded?: boolean }) {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference defaults are missing');
  }
  return (
    <ServerPrefs.Provider
      value={{
        ...defaults,
        character_portrait_urls:
          props.loaded === false
            ? undefined
            : { maximum_entries: 3, maximum_length: 400 },
      }}
    >
      <FeatureValueInput
        feature={
          features.character_portrait_urls as unknown as Feature<unknown>
        }
        featureId="character_portrait_urls"
        value={props.value}
      />
    </ServerPrefs.Provider>
  );
}

afterEach(() => {
  resetStore();
});

describe('character portrait list preference', () => {
  it('sends the complete ordered list when editing a row', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, { active_slot: 1, character_preferences: {} });
      const original = [first, second];
      render(<PortraitPreference value={original} />);
      const input = screen.getByRole('textbox', {
        name: 'Ссылка на портрет 2',
      });
      expect(input.getAttribute('maxlength')).toBe('400');
      fireEvent.input(input, { target: { value: third } });
      fireEvent.blur(input);
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [first, third],
      });
      expect(original).toEqual([first, second]);
    } finally {
      sendAct.mockRestore();
    }
  });

  it('adds blank rows up to three and removes rows without reordering siblings', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, { active_slot: 1, character_preferences: {} });
      const view = render(<PortraitPreference value={[first, second]} />);
      const add = screen.getByRole('button', { name: 'Добавить портрет' });
      fireEvent.click(add);
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [first, second, ''],
      });
      expect(screen.getAllByRole('textbox')).toHaveLength(3);
      const callsAtLimit = sendAct.mock.calls.length;
      fireEvent.click(add);
      expect(sendAct.mock.calls).toHaveLength(callsAtLimit);

      fireEvent.click(
        screen.getByRole('button', { name: 'Удалить портрет 2' }),
      );
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [first, ''],
      });
      expect(screen.getAllByRole('textbox')).toHaveLength(2);
      fireEvent.click(add);
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [first, '', ''],
      });

      view.rerender(<PortraitPreference value={[third]} />);
      fireEvent.click(
        screen.getByRole('button', { name: 'Удалить портрет 1' }),
      );
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [],
      });
      expect(screen.queryAllByRole('textbox')).toHaveLength(0);
      fireEvent.click(add);
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [''],
      });
    } finally {
      sendAct.mockRestore();
    }
  });

  it('disables editing, adding and removal until metadata arrives', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, { active_slot: 1, character_preferences: {} });
      const view = render(
        <PortraitPreference value={[first]} loaded={false} />,
      );
      const input = screen.getByRole<HTMLInputElement>('textbox', {
        name: 'Ссылка на портрет 1',
      });
      expect(input.disabled).toBe(true);
      fireEvent.click(screen.getByRole('button', { name: 'Добавить портрет' }));
      fireEvent.click(
        screen.getByRole('button', { name: 'Удалить портрет 1' }),
      );
      expect(sendAct).not.toHaveBeenCalled();
      view.rerender(<PortraitPreference value={[first]} />);
      expect(input.disabled).toBe(false);
      fireEvent.click(
        screen.getByRole('button', { name: 'Удалить портрет 1' }),
      );
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: [],
      });
    } finally {
      sendAct.mockRestore();
    }
  });

  it('replaces visible values after backend updates and character slot changes', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      store.set(gameDataAtom, { active_slot: 1, character_preferences: {} });
      const view = render(<PortraitPreference value={[first, second]} />);
      const input = screen.getByRole<HTMLInputElement>('textbox', {
        name: 'Ссылка на портрет 1',
      });
      fireEvent.input(input, { target: { value: '' } });
      fireEvent.blur(input);
      expect(sendAct).toHaveBeenLastCalledWith('set_preference', {
        preference: 'character_portrait_urls',
        value: ['', second],
      });

      input.focus();
      view.rerender(<PortraitPreference value={[third]} />);
      expect(input.value).toBe(third);
      expect(screen.getAllByRole('textbox')).toHaveLength(1);

      const slotValue = [second];
      view.rerender(<PortraitPreference value={slotValue} />);
      fireEvent.input(input, { target: { value: first } });
      fireEvent.blur(input);
      expect(input.value).toBe(first);
      store.set(gameDataAtom, { active_slot: 2, character_preferences: {} });
      view.rerender(<PortraitPreference value={slotValue} />);
      expect(input.value).toBe(second);
      expect(sendAct.mock.calls).toHaveLength(2);
    } finally {
      sendAct.mockRestore();
    }
  });
});

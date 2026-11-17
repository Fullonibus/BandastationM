import { afterEach, describe, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import * as actions from 'tgui/events/act';
import { gameDataAtom, resetStore, store } from 'tgui/events/store';

import type { Species } from '../types';
import { ServerPrefs, useServerPrefs } from '../useServerPrefs';
import { SpeciesPage } from './SpeciesPage';

function species(name: string, required_donator_level?: number): Species {
  return {
    name,
    desc: `Описание: ${name}`,
    lore: [],
    icon: name,
    required_donator_level,
    use_skintones: false,
    sexes: true,
    enabled_features: [],
    perks: { positive: [], negative: [], neutral: [] },
  };
}

function setData(selectedSpecies = 'human', donatorLevel = 5, slot = 1) {
  store.set(gameDataAtom, {
    active_slot: slot,
    donator_level: donatorLevel,
    character_preview_view: 'test-preview',
    character_preferences: { misc: { species: selectedSpecies } },
  });
}

function TestSpeciesPage() {
  const defaults = useServerPrefs();
  if (!defaults) {
    throw new Error('Preference context defaults are missing.');
  }
  return (
    <ServerPrefs.Provider
      value={{
        ...defaults,
        species: {
          drask: species('Драск', 2),
          human: species('Человек', 0),
          moth: species('Моль'),
          felinid: species('Фелинид', 5),
        },
      }}
    >
      <SpeciesPage closeSpecies={() => {}} />
    </ServerPrefs.Provider>
  );
}

function visibleSpecies() {
  return Array.from(document.querySelectorAll('.ImageButton__content')).map(
    (card) => card.textContent,
  );
}

afterEach(() => {
  resetStore();
  sessionStorage.clear();
});

describe('Species categories', () => {
  it('separates regular and premium species without selecting a species', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      setData();
      render(<TestSpeciesPage />);
      expect(visibleSpecies()).toEqual(['Человек', 'Моль']);

      fireEvent.click(screen.getByText('Премиальные расы'));
      expect(visibleSpecies()).toEqual(['Драск', 'Фелинид']);

      fireEvent.click(screen.getByText('Обычные расы'));
      expect(visibleSpecies()).toEqual(['Человек', 'Моль']);
      expect(sendAct).not.toHaveBeenCalled();
    } finally {
      sendAct.mockRestore();
    }
  });

  it('opens the selected species category and follows character changes', () => {
    setData('felinid');
    const view = render(<TestSpeciesPage />);
    expect(visibleSpecies()).toEqual(['Драск', 'Фелинид']);
    expect(
      document.querySelector('.ImageButton--selected')?.textContent,
    ).toContain('Фелинид');

    setData('human', 5, 2);
    view.rerender(<TestSpeciesPage />);
    expect(visibleSpecies()).toEqual(['Человек', 'Моль']);

    setData('drask', 5, 3);
    view.rerender(<TestSpeciesPage />);
    expect(visibleSpecies()).toEqual(['Драск', 'Фелинид']);
  });

  it('keeps tier labels and only sends selection for an unlocked species', () => {
    const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      setData('human', 2);
      render(<TestSpeciesPage />);
      fireEvent.click(screen.getByText('Премиальные расы'));
      expect(screen.getByText('T2')).toBeDefined();
      expect(screen.getByText('T5')).toBeDefined();

      fireEvent.click(screen.getByText('Фелинид'));
      expect(sendAct).not.toHaveBeenCalled();

      fireEvent.click(screen.getByText('Драск'));
      expect(sendAct).toHaveBeenCalledTimes(1);
      expect(sendAct).toHaveBeenCalledWith('set_preference', {
        preference: 'species',
        value: 'drask',
      });
    } finally {
      sendAct.mockRestore();
    }
  });
});

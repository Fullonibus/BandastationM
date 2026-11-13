import { afterEach, describe, expect, it } from 'bun:test';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { gameDataAtom, store } from '../events/store';

import { ExaminePanel } from './ExaminePanel';

const portraitUrl = 'https://i.gyazo.com/example.png';

function renderExamine(
  obscured: boolean,
  flavorText = 'Текст персонажа',
  portraitUrls = [portraitUrl],
) {
  store.set(gameDataAtom, {
    assigned_map: 'examine_test_map',
    character_name: 'Персонаж',
    flavor_text: flavorText,
    obscured,
    portrait_urls: portraitUrls,
  });
  return render(<ExaminePanel />);
}

afterEach(cleanup);

describe('ExaminePanel portrait', () => {
  it('shows the portrait and restores the sprite preview if it fails to load', () => {
    renderExamine(false);
    const portrait = screen.getByRole('img', { name: 'Портрет персонажа' });
    expect(portrait.getAttribute('src')).toBe(portraitUrl);
    expect(portrait.getAttribute('referrerpolicy')).toBe('no-referrer');
    expect(screen.getByText('Персонаж, описание:')).toBeDefined();
    expect(screen.getByText('Текст персонажа')).toBeDefined();
    expect(
      screen.queryByRole('button', { name: 'Следующий портрет' }),
    ).toBeNull();

    fireEvent.error(portrait);

    expect(screen.queryByRole('img')).toBeNull();
    expect(screen.getByText('Превью персонажа')).toBeDefined();
  });

  it('keeps a square portrait and omits the column when the description is blank', () => {
    renderExamine(false, ' \n');
    const portrait = screen.getByRole('img', { name: 'Портрет персонажа' });
    expect(portrait.getAttribute('width')).toBe('320');
    expect(portrait.getAttribute('height')).toBe('320');
    expect(screen.getByText('Подробное описание')).toBeDefined();
    expect(screen.queryByText('Персонаж, описание:')).toBeNull();
  });

  it('cycles through all portraits and can move past a failed image', () => {
    const secondUrl = 'https://i.gyazo.com/second.png';
    const thirdUrl = 'https://i.gyazo.com/third.png';
    renderExamine(false, 'Текст персонажа', [portraitUrl, secondUrl, thirdUrl]);

    expect(screen.getByText('1 / 3')).toBeDefined();
    fireEvent.click(screen.getByRole('button', { name: 'Следующий портрет' }));
    const secondPortrait = screen.getByRole('img');
    expect(secondPortrait.getAttribute('src')).toBe(secondUrl);
    fireEvent.error(secondPortrait);
    expect(screen.queryByRole('img')).toBeNull();
    expect(screen.getByText('2 / 3')).toBeDefined();

    fireEvent.click(screen.getByRole('button', { name: 'Следующий портрет' }));
    expect(screen.getByRole('img').getAttribute('src')).toBe(thirdUrl);
    fireEvent.click(screen.getByRole('button', { name: 'Следующий портрет' }));
    expect(screen.getByRole('img').getAttribute('src')).toBe(portraitUrl);
    fireEvent.click(screen.getByRole('button', { name: 'Предыдущий портрет' }));
    expect(screen.getByText('3 / 3')).toBeDefined();
  });

  it('hides the portrait and controls for an obscured character', () => {
    renderExamine(true, 'Текст персонажа', [portraitUrl, portraitUrl]);
    expect(screen.queryByRole('img')).toBeNull();
    expect(
      screen.queryByRole('button', { name: 'Следующий портрет' }),
    ).toBeNull();
  });
});

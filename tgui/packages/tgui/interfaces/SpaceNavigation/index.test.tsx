import { afterEach, expect, it, spyOn } from 'bun:test';
import { fireEvent, render, screen } from '@testing-library/react';
import fixture from 'tgui-dev-server/preview/fixtures/space-navigation.json';

import * as actions from '../../events/act';
import { gameDataAtom, resetStore, store } from '../../events/store';
import { SpaceNavigation } from './index';

afterEach(resetStore);

it('distinguishes throttle buttons from the lever and sounds local tabs', () => {
  const sendAct = spyOn(actions, 'sendAct').mockImplementation(() => {});
  try {
    store.set(gameDataAtom, { ...fixture.data, throttle: 0 });
    render(<SpaceNavigation />);

    fireEvent.click(screen.getByLabelText('Увеличить тягу'));
    expect(sendAct).toHaveBeenLastCalledWith('throttle', {
      value: 5,
      button: true,
    });

    fireEvent.keyDown(screen.getByRole('slider', { name: 'Тяга, проценты' }), {
      key: 'Home',
    });
    expect(sendAct).toHaveBeenLastCalledWith('throttle', {
      value: 0,
      button: false,
    });

    fireEvent.click(screen.getByLabelText('Уменьшить тягу'));
    expect(sendAct).toHaveBeenLastCalledWith('throttle', {
      value: -5,
      button: true,
    });

    fireEvent.click(screen.getByRole('tab', { name: 'КОНТАКТЫ' }));
    expect(sendAct).toHaveBeenLastCalledWith('interface_click');
  } finally {
    sendAct.mockRestore();
  }
});

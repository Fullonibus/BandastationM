import {
  afterAll,
  afterEach,
  beforeAll,
  beforeEach,
  describe,
  expect,
  it,
  mock,
  spyOn,
} from 'bun:test';
import { act, fireEvent, render } from '@testing-library/react';
import { storage } from 'common/storage';
import { Slider, Tabs } from 'tgui-core/components';
import { startKeyPassthrough, stopKeyPassthrough } from 'tgui-core/hotkeys';

import { Window } from './Window';

beforeAll(startKeyPassthrough);
afterAll(stopKeyPassthrough);
beforeEach(() => {
  spyOn(storage, 'get').mockResolvedValue(undefined);
  spyOn(storage, 'set').mockResolvedValue(undefined);
});
afterEach(() => {
  fireEvent.keyUp(document.body, { keyCode: 18, altKey: false });
  fireEvent.focus(window);
  mock.restore();
});

describe('Window content dragging', () => {
  it.each([
    'slider',
    'tab',
  ])('keeps the window stationary when using a %s after losing Alt keyup', async (control) => {
    const change = mock();
    const select = mock();
    const winset = spyOn(Byond, 'winset');
    const view = render(
      <Window.Content>
        <Slider
          value={30}
          minValue={20}
          maxValue={90}
          step={1}
          onChange={change}
        />
        <Tabs>
          <Tabs.Tab onClick={select}>Preferences</Tabs.Tab>
        </Tabs>
      </Window.Content>,
    );
    act(() => {
      fireEvent.keyDown(document.body, { keyCode: 18, altKey: true });
      fireEvent.blur(window);
    });
    const target = view.container.querySelector(
      control === 'slider' ? '.Slider' : '.Tabs__Tab',
    )!;
    Object.defineProperty(target, 'offsetWidth', { value: 200 });
    fireEvent.mouseDown(target, {
      screenX: 100,
      screenY: 100,
      buttons: 1,
      altKey: false,
    });
    if (control === 'slider') {
      await act(async () => {
        await new Promise((resolve) => setTimeout(resolve, 120));
      });
      fireEvent.mouseMove(document, { screenX: 160, screenY: 100 });
    }
    fireEvent.mouseUp(document, {
      screenX: control === 'slider' ? 160 : 102,
      screenY: 100,
    });
    fireEvent.click(target);

    if (control === 'slider') {
      expect(change.mock.calls[0][1]).toBeGreaterThan(30);
    } else {
      expect(select).toHaveBeenCalledTimes(1);
    }
    expect(winset).not.toHaveBeenCalled();
  });

  it('moves the window when Alt is held in the mouse event', () => {
    const winset = spyOn(Byond, 'winset');
    const view = render(<Window.Content>Drag window</Window.Content>);
    fireEvent.mouseDown(view.getByText('Drag window'), {
      screenX: 100,
      screenY: 100,
      altKey: true,
    });
    fireEvent.mouseUp(document, { screenX: 120, screenY: 100 });

    expect(winset).toHaveBeenCalledWith(Byond.windowId, { pos: '20,0' });
  });
});

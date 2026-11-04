import { normalizeFixture } from './fixture';

type Fixture = ReturnType<typeof normalizeFixture>;
type Listener = (type: string, payload: unknown) => void;

const origin = location.origin;

function errorText(error: unknown): string {
  return error instanceof Error ? error.stack || error.message : String(error);
}

function setupBridge() {
  const listeners: Listener[] = [];
  const send = (message: Record<string, unknown>) =>
    parent.postMessage(message, origin);

  window.addEventListener('error', (event) => {
    send({
      type: 'preview/error',
      message: event.error ? errorText(event.error) : event.message,
    });
  });
  window.addEventListener('unhandledrejection', (event) => {
    send({ type: 'preview/error', message: errorText(event.reason) });
  });
  window.addEventListener('message', (event) => {
    if (event.origin !== origin || event.source !== parent) return;
    if (event.data?.type !== 'preview/update') return;
    try {
      const fixture = normalizeFixture(event.data.payload);
      for (const listener of listeners) listener('update', fixture);
    } catch (error) {
      send({ type: 'preview/error', message: errorText(error) });
    }
  });

  // Use ephemeral storage so native storage and geometry promises settle.
  const memory = new Map<string, string>();
  window.hubStorage = {
    get length() {
      return memory.size;
    },
    key: (index: number) => Array.from(memory.keys())[index] ?? null,
    getItem: (key: string) => memory.get(key) ?? null,
    setItem: (key: string, value: string) => {
      memory.set(key, value);
    },
    removeItem: (key: string) => {
      memory.delete(key);
    },
    clear: () => {
      memory.clear();
    },
  };

  // Keep native geometry promises resolved, without moving browser windows.
  const bridge = {
    windowId: 'browser-preview',
    IS_BYOND: false,
    BLINK: true,
    strictMode: false,
    storageCdn: '',
    iconRefMap: {},
    call: () => ({}),
    callAsync: async () => ({}),
    topic: () => {},
    command: () => {},
    winget: async (_id: unknown, property: unknown) =>
      property === 'pos' ? { x: 0, y: 0 } : {},
    winset: () => {},
    parseJson: JSON.parse,
    loadCss: () => {},
    loadJs: () => {},
    saveBlob: () => {},
    subscribe: (listener: Listener) => {
      listeners.push(listener);
      send({ type: 'preview/ready' });
    },
    subscribeTo: (type: string, listener: (payload: unknown) => void) => {
      listeners.push((eventType, payload) => {
        if (eventType === type) listener(payload);
      });
    },
    sendMessage: (
      typeOrMessage: string | Record<string, unknown>,
      payload?: unknown,
    ) => {
      const message: Record<string, unknown> =
        typeof typeOrMessage === 'string'
          ? { type: typeOrMessage, payload }
          : typeOrMessage;
      const { type, ...fields } = message;
      send({
        type: 'preview/action',
        action: type,
        payload: 'payload' in message ? message.payload : fields,
      });
      if (
        type === 'setSharedState' &&
        typeof message.key === 'string' &&
        typeof message.value === 'string'
      ) {
        // Shared UI state uses a generic server echo, not gameplay logic.
        for (const listener of listeners) {
          listener('update', { shared: { [message.key]: message.value } });
        }
      }
    },
  };
  // The preview implements only the transport subset used by frontend code.
  (globalThis as unknown as { Byond: unknown }).Byond = bridge;
  const script = document.createElement('script');
  script.src = '/tgui.bundle.js';
  script.onerror = () =>
    send({
      type: 'preview/error',
      message: 'Failed to load tgui.bundle.js. Check the build output.',
    });
  document.body.append(script);
}

async function setupShell() {
  const element = <T extends HTMLElement>(id: string) =>
    document.getElementById(id) as T;
  const interfaceInput = element<HTMLInputElement>('interface');
  const fixtureSelect = element<HTMLSelectElement>('fixture');
  const editor = element<HTMLTextAreaElement>('fixture-json');
  const widthInput = element<HTMLInputElement>('width');
  const heightInput = element<HTMLInputElement>('height');
  const status = element<HTMLParagraphElement>('status');
  const log = element<HTMLPreElement>('log');
  const entries: string[] = [];
  let frame: HTMLIFrameElement | undefined;
  let currentFixture: Fixture | undefined;
  let fixtureRequest = 0;

  function setStatus(message: string, error = false) {
    status.textContent = message;
    status.dataset.error = String(error);
  }

  function record(message: string) {
    entries.push(`${new Date().toLocaleTimeString()} ${message}`);
    if (entries.length > 200) entries.shift();
    log.textContent = entries.join('\n');
    log.scrollTop = log.scrollHeight;
  }

  function report(error: unknown) {
    setStatus(errorText(error), true);
    record(`ERROR ${errorText(error)}`);
  }

  async function getJson<T>(path: string): Promise<T> {
    const response = await fetch(path);
    if (!response.ok)
      throw new Error(`${path}: ${response.status} ${await response.text()}`);
    return response.json();
  }

  function apply() {
    try {
      const fixture = normalizeFixture(
        JSON.parse(editor.value),
        interfaceInput.value.trim(),
      );
      const width = Number(widthInput.value);
      const height = Number(heightInput.value);
      if (
        ![width, height].every((value) => Number.isFinite(value) && value > 0)
      ) {
        throw new Error(
          'Viewport width and height must be positive finite numbers.',
        );
      }
      fixture.config.window.size = [width, height];
      normalizeFixture(fixture);
      currentFixture = fixture;
      const nextFrame = document.createElement('iframe');
      nextFrame.title = `${fixture.config.interface.name} preview`;
      nextFrame.width = String(width);
      nextFrame.height = String(height);
      nextFrame.src = '/ui';
      // A fresh document resets atoms and local component state between fixtures.
      frame = nextFrame;
      element('canvas').replaceChildren(nextFrame);
      const url = new URL(location.href);
      url.searchParams.set('interface', fixture.config.interface.name);
      if (fixtureSelect.value)
        url.searchParams.set('fixture', fixtureSelect.value);
      else url.searchParams.delete('fixture');
      history.replaceState(null, '', url);
      setStatus(`Loading ${fixture.config.interface.name}…`);
    } catch (error) {
      report(error);
    }
  }

  async function loadFixture(name: string) {
    const request = ++fixtureRequest;
    if (!name) return;
    try {
      setStatus('Loading fixture…');
      const value = await getJson<unknown>(
        `/api/fixtures/${encodeURIComponent(name)}`,
      );
      if (request !== fixtureRequest) return;
      const fixture = normalizeFixture(value);
      interfaceInput.value = fixture.config.interface.name;
      editor.value = JSON.stringify(value, null, 2);
      [widthInput.value, heightInput.value] =
        fixture.config.window.size.map(String);
      apply();
    } catch (error) {
      if (request === fixtureRequest) report(error);
    }
  }

  window.addEventListener('message', (event) => {
    if (event.origin !== origin || event.source !== frame?.contentWindow)
      return;
    const message = event.data;
    if (message?.type === 'preview/ready' && currentFixture) {
      frame?.contentWindow?.postMessage(
        { type: 'preview/update', payload: currentFixture },
        origin,
      );
      setStatus(
        `Previewing ${currentFixture.config.interface.name}. Actions do not run game logic.`,
      );
    } else if (message?.type === 'preview/action') {
      const action = String(message.action);
      if (action.startsWith('act/') || action === 'setSharedState') {
        record(`${action} ${JSON.stringify(message.payload ?? {})}`);
      } else if (action === 'oversizedPayloadRequest') {
        record(
          'ERROR Large action payload requires the native BYOND chunking transport.',
        );
      }
    } else if (message?.type === 'preview/error') {
      report(String(message.message));
    }
  });
  element<HTMLFormElement>('preview-form').addEventListener(
    'submit',
    (event) => {
      event.preventDefault();
      apply();
    },
  );
  fixtureSelect.addEventListener(
    'change',
    () => void loadFixture(fixtureSelect.value),
  );
  interfaceInput.addEventListener('input', () => {
    ++fixtureRequest;
    fixtureSelect.value = '';
  });
  editor.addEventListener('input', () => {
    ++fixtureRequest;
    fixtureSelect.value = '';
  });
  element('clear-log').addEventListener('click', () => {
    entries.length = 0;
    log.textContent = 'No actions recorded.';
  });

  const events = new EventSource('/events');
  events.onmessage = (event) => {
    try {
      const message = JSON.parse(event.data);
      if (message.type === 'built') {
        record('Build updated. Reloading preview with current JSON.');
        if (interfaceInput.value.trim()) apply();
      } else if (message.type === 'error') {
        report(String(message.message));
      }
    } catch (error) {
      report(error);
    }
  };
  events.onerror = () =>
    setStatus('Build event connection interrupted; reconnecting…', true);

  try {
    const [interfaces, fixtures] = await Promise.all([
      getJson<string[]>('/api/interfaces'),
      getJson<{ name: string; interface: string }[]>('/api/fixtures'),
    ]);
    element<HTMLDataListElement>('interfaces').replaceChildren(
      ...interfaces.map((name) => new Option(name, name)),
    );
    for (const fixture of fixtures) {
      fixtureSelect.add(
        new Option(`${fixture.name} — ${fixture.interface}`, fixture.name),
      );
    }
    const query = new URLSearchParams(location.search);
    const fixtureName = query.get('fixture');
    if (
      fixtureName &&
      fixtures.some((fixture) => fixture.name === fixtureName)
    ) {
      fixtureSelect.value = fixtureName;
      await loadFixture(fixtureName);
    } else {
      interfaceInput.value = query.get('interface') || '';
      setStatus('Choose an interface and supply its fixture data.');
      if (interfaceInput.value) apply();
    }
  } catch (error) {
    report(error);
  }
}

if (location.pathname === '/ui') {
  setupBridge();
} else {
  void setupShell();
}

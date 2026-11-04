import { readdir, stat } from 'node:fs/promises';
import path from 'node:path';
import rspack from '@rspack/core';
import { config } from '../../../rspack.config-dev';
import { normalizeFixture } from './fixture';

const publicDir = path.resolve(import.meta.dirname, '../../../public');
const bundleDir = path.join(publicDir, '.tmp/preview');

const fontAwesomeDir = path.resolve(publicDir, '../../html/font-awesome');
const tgfontDir = path.resolve(import.meta.dirname, '../../tgfont/dist');
const fontAssets: Record<string, string> = {
  '/fonts/font-awesome.css': path.join(fontAwesomeDir, 'css/all.min.css'),
  '/fonts/brands.min.css': path.join(fontAwesomeDir, 'css/brands.min.css'),
  '/fonts/tgfont.css': path.join(tgfontDir, 'tgfont.css'),
  '/fonts/tgfont.woff2': path.join(tgfontDir, 'tgfont.woff2'),
};
for (const name of [
  'fa-solid-900',
  'fa-regular-400',
  'fa-brands-400',
  'fa-v4compatibility',
]) {
  fontAssets[`/fonts/${name}.woff2`] = path.join(
    fontAwesomeDir,
    `webfonts/${name}.woff2`,
  );
}

const fixtureDir = path.join(import.meta.dirname, 'fixtures');
const interfacesDir = path.resolve(
  import.meta.dirname,
  '../../tgui/interfaces',
);
const portArg = process.argv.find((arg) => arg.startsWith('--port='));
const port = Number(portArg?.slice(7) ?? 5173);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('--port must be an integer between 1 and 65535');
}
const clientBuild = await Bun.build({
  entrypoints: [path.join(import.meta.dirname, 'client.ts')],
  target: 'browser',
});
if (!clientBuild.success)
  throw new AggregateError(clientBuild.logs, 'Preview client build failed');
const client = clientBuild.outputs[0];
const clients = new Set<ReadableStreamDefaultController<Uint8Array>>();
const encoder = new TextEncoder();
let buildState: { type: string; message?: string } = { type: 'building' };

function publish(state: typeof buildState) {
  buildState = state;
  for (const controller of clients) {
    try {
      controller.enqueue(encoder.encode(`data: ${JSON.stringify(state)}\n\n`));
    } catch {
      clients.delete(controller);
    }
  }
}

async function interfaceNames() {
  const names: string[] = [];
  for (const entry of await readdir(interfacesDir, { withFileTypes: true })) {
    if (
      entry.isFile() &&
      /\.(tsx|jsx)$/.test(entry.name) &&
      !entry.name.includes('.test.')
    ) {
      names.push(entry.name.replace(/\.(tsx|jsx)$/, ''));
    } else if (entry.isDirectory()) {
      for (const extension of ['tsx', 'jsx']) {
        if (
          await Bun.file(
            path.join(interfacesDir, entry.name, `index.${extension}`),
          ).exists()
        ) {
          names.push(entry.name);
          break;
        }
      }
    }
  }
  return names.sort();
}

async function readFixture(name: string) {
  if (!/^[\w-]+$/.test(name)) throw new Error('Invalid fixture name');
  return normalizeFixture(
    await Bun.file(path.join(fixtureDir, `${name}.json`)).json(),
  );
}

const headers = { 'Cache-Control': 'no-store' };
const server = Bun.serve({
  hostname: '127.0.0.1',
  port,
  idleTimeout: 0,
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== 'GET')
      return new Response('Method not allowed', { status: 405 });
    try {
      if (url.pathname === '/')
        return new Response(
          Bun.file(path.join(import.meta.dirname, 'shell.html')),
          { headers },
        );
      if (url.pathname === '/client.js')
        return new Response(client, {
          headers: { ...headers, 'Content-Type': 'text/javascript' },
        });
      if (url.pathname === '/api/interfaces')
        return Response.json(await interfaceNames(), { headers });
      if (url.pathname === '/api/fixtures') {
        const fixtures: { name: string; interface: string }[] = [];
        for (const file of await readdir(fixtureDir)) {
          if (!file.endsWith('.json')) continue;
          const name = file.slice(0, -5);
          const fixture = await readFixture(name);
          fixtures.push({ name, interface: fixture.config.interface.name });
        }
        return Response.json(fixtures, { headers });
      }
      if (url.pathname.startsWith('/api/fixtures/')) {
        return Response.json(
          await readFixture(decodeURIComponent(url.pathname.slice(14))),
          { headers },
        );
      }
      if (url.pathname === '/events') {
        let subscriber: ReadableStreamDefaultController<Uint8Array>;
        return new Response(
          new ReadableStream({
            start(controller) {
              subscriber = controller;
              clients.add(controller);
              controller.enqueue(
                encoder.encode(`data: ${JSON.stringify(buildState)}\n\n`),
              );
            },
            cancel() {
              clients.delete(subscriber);
            },
          }),
          { headers: { ...headers, 'Content-Type': 'text/event-stream' } },
        );
      }
      if (fontAssets[url.pathname]) {
        return new Response(Bun.file(fontAssets[url.pathname]), { headers });
      }
      if (url.pathname === '/ui') {
        return new Response(
          '<!doctype html><html lang="en"><meta charset="utf-8"><link rel="stylesheet" href="/tgui.bundle.css"><link rel="stylesheet" href="/fonts/font-awesome.css"><link rel="stylesheet" href="/fonts/brands.min.css"><link rel="stylesheet" href="/fonts/tgfont.css"><body><div id="react-root"></div><script type="module" src="/client.js"></script></body></html>',
          {
            headers: { ...headers, 'Content-Type': 'text/html; charset=utf-8' },
          },
        );
      }
      const pathname = decodeURIComponent(url.pathname);
      for (const root of [bundleDir, publicDir]) {
        const filename = path.resolve(root, `.${pathname}`);
        const relative = path.relative(root, filename);
        if (
          relative.startsWith('..') ||
          path.isAbsolute(relative) ||
          pathname.includes(':')
        )
          break;
        if (
          await stat(filename)
            .then((entry) => entry.isFile())
            .catch(() => false)
        ) {
          return new Response(Bun.file(filename), { headers });
        }
      }
      return new Response('Not found', { status: 404 });
    } catch (error) {
      return Response.json({ error: String(error) }, { status: 400, headers });
    }
  },
});

const compiler = rspack.rspack({
  ...config,
  entry: { tgui: './packages/tgui' },
  output: { ...config.output, path: bundleDir },
  plugins: config.plugins.filter(
    (plugin) => !(plugin instanceof rspack.HotModuleReplacementPlugin),
  ),
});
const watching = compiler.watch({}, (error, stats) => {
  if (error || stats?.hasErrors()) {
    const message =
      error?.message ??
      stats?.toString({ all: false, errors: true }) ??
      'Compilation failed';
    console.error(message);
    publish({ type: 'error', message });
  } else {
    console.log(`TGUI preview: http://127.0.0.1:${port} (ready)`);
    publish({ type: 'built' });
  }
});
process.once('SIGINT', () => {
  server.stop(true);
  watching?.close(() => process.exit(0));
});

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { z } from 'zod';
import { zodToJsonSchema } from 'zod-to-json-schema';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fs.realpathSync(process.env.BANDASTATION_WORKSPACE || process.cwd());
const python = process.env.BANDASTATION_MAPS_PYTHON;
const runner = fileURLToPath(new URL('./worker-runner.py', import.meta.url));
if (!python) throw new Error('Start maps MCP using the checkout maps-mcp.cjs launcher.');
const object = fields => z.object(fields).strict();
const text = z.string().min(1).max(4096).refine(value => !value.includes('\0'), 'NUL is not permitted');
const coord = z.tuple([z.number().int().min(1), z.number().int().min(1), z.number().int().min(1)]);
const region = object({ min: coord, max: coord });
const planId = text;
const source = z.union([object({ path: text }), object({ plan_id: planId, side: z.enum(['before', 'after']) })]);
const atom = z.string().min(1).max(65536).refine(value => !value.includes('\0'), 'NUL is not permitted');
const atoms = z.array(atom).min(2).max(10000);
const index = z.number().int().min(0).max(9999);
const operations = z.discriminatedUnion('op', [
  object({ op: z.literal('add_atom'), at: coord, atom, position: index.optional() }),
  object({ op: z.literal('remove_atom'), at: coord, atom_index: index, expected_atom: atom }),
  object({ op: z.literal('replace_atom'), at: coord, atom_index: index, expected_atom: atom, atom }),
  object({ op: z.literal('set_turf'), at: coord, expected_atom: atom, atom }),
  object({ op: z.literal('set_area'), at: coord, expected_atom: atom, atom }),
  object({ op: z.literal('set_tile'), at: coord, expected_atoms: atoms, atoms }),
  object({ op: z.literal('fill_region'), region, atoms }),
  object({ op: z.literal('copy_region'), source_region: region, at: coord })
]);
const page = { limit: z.number().int().min(1).max(1000).optional(), cursor: text.optional() };
const schemas = {
  dmm_capabilities: object({}),
  dmm_info: object({ path: text }),
  dmm_read: object({ source, region: region.optional(), coordinates: z.array(coord).min(1).max(10000).optional(), ...page }),
  dmm_find: object({ source, typepath: text, subtypes: z.boolean().optional(), region: region.optional(), ...page }),
  dmm_render: object({ requests: z.array(object({ source, region: region.optional(), view: z.enum(['appearance', 'power', 'atmos', 'areas']).optional(), context: z.number().int().min(0).max(8).optional(), scale: z.union([z.literal(1), z.literal(2), z.literal(4)]).optional(), max_size: z.number().int().min(64).max(2048).optional() })).min(1).max(8) }),
  dmm_prepare_patch: object({ path: text, expected_sha256: z.string().regex(/^[0-9a-f]{64}$/), operations: z.array(operations).max(10000) }),
  dmm_apply_patch: object({ plan_id: planId }),
  dmm_diff: object({ left: source, right: source, ...page }),
  dmm_validate: object({ source })
};
const descriptions = {
  dmm_capabilities: 'Report local TGM editing, validation and pinned renderer capabilities. No installation or network.',
  dmm_info: 'Inspect a checkout TGM map and return its content hash and BYOND dimensions.',
  dmm_read: 'Read bounded tiles with exact raw DM atoms and 0-based snapshot atom indices. Coordinates are 1-based BYOND [x,y,z]; Y points north.',
  dmm_find: 'Find exact typepaths or lexical path prefixes in bounded map tiles, not resolved DM inheritance; paginate using the returned cursor.',
  dmm_render: 'Render up to eight immutable map snapshots using the current checkout DM environment. Returns PNG images; previews are not runtime validation.',
  dmm_prepare_patch: 'Prepare an immutable, hash-checked map transaction and before/after previews without modifying the source. Every operation addresses the original snapshot.',
  dmm_apply_patch: 'Apply one prepared map transaction only if source, plan and current validation still match. Updates its source map atomically.',
  dmm_diff: 'Compare two map sources by coordinate and exact raw atom stacks with bounded pagination.',
  dmm_validate: 'Run map structural and existing YAML lint checks in the logical source path. Does not execute BYOND runtime.'
};
const tools = Object.entries(schemas).map(([name, schema]) => {
  const { $schema, ...inputSchema } = zodToJsonSchema(schema, { target: 'jsonSchema7', $refStrategy: 'none' });
  return { name, description: descriptions[name], inputSchema,
    annotations: { readOnlyHint: name !== 'dmm_apply_patch', destructiveHint: name === 'dmm_apply_patch', idempotentHint: name !== 'dmm_prepare_patch', openWorldHint: false } };
});

const activeWorkers = new Set();
const terminatingWorkers = new WeakSet();
let stopping = false;
function terminateWorker(child) {
  if (!activeWorkers.has(child) || terminatingWorkers.has(child)) return;
  terminatingWorkers.add(child);
  // The runner owns a kill-on-close JobObject before worker code can spawn.
  // Node retains this child handle; no PID enumeration or PID-based kills.
  child.kill();
}

function worker(tool, args) {
  if (stopping) throw new Error('Maps MCP is shutting down.');
  const input = JSON.stringify({ tool, arguments: args });
  if (Buffer.byteLength(input) > 1024*1024) throw new Error('Request exceeds the 1 MiB limit.');
  return new Promise((resolve, reject) => {
    const child = spawn(python, ['-B', '-X', 'utf8', runner, path.join(root, 'tools/agents/maps/worker.py')], { cwd: root, shell: false, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    activeWorkers.add(child);
    let output = [], bytes = 0, diagnostics = '', failure;
    const timeout = setTimeout(() => { failure = 'Map worker timed out after 210 seconds.'; terminateWorker(child); }, 210000);
    child.stdout.on('data', chunk => {
      bytes += chunk.length;
      if (bytes > 8*1024*1024) { failure = 'Map worker exceeded the 8 MiB output limit.'; terminateWorker(child); }
      else output.push(chunk);
    });
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', chunk => { diagnostics = (diagnostics+chunk).slice(-8192); });
    child.stdin.on('error', () => {}); // An early worker exit is reported by close/error below.
    child.on('error', error => { clearTimeout(timeout); activeWorkers.delete(child); reject(error); });
    child.on('close', code => {
      clearTimeout(timeout);
      activeWorkers.delete(child);
      if (failure) return reject(new Error(failure));
      if (code !== 0) return reject(new Error(`Map worker exited ${code}: ${diagnostics.trim()}`));
      try {
        const reply = JSON.parse(Buffer.concat(output).toString('utf8'));
        if (!reply || typeof reply !== 'object' || typeof reply.ok !== 'boolean') throw new Error('Invalid map worker envelope.');
        if (!reply.ok) throw new Error(`${reply.error?.code || 'worker_error'}: ${reply.error?.message || 'Map worker rejected request.'}`);
        if (!reply.result || typeof reply.result !== 'object' || Array.isArray(reply.result)) throw new Error('Invalid map worker result.');
        resolve(reply.result);
      } catch (error) { reject(new Error('Map worker response: '+error.message)); }
    });
    child.stdin.end(input);
  });
}

function trustedImages(result) {
  if (!Array.isArray(result.images) || result.images.length > 8) throw new Error('Invalid renderer image list.');
  let total = 0;
  return result.images.map(item => {
    if (typeof item.path !== 'string' || !path.isAbsolute(item.path)) throw new Error('Renderer image path is not absolute.');
    const filename = fs.realpathSync(item.path);
    const expectedRoot = path.join(root, 'task_state/map-tools');
    const owned = fs.realpathSync(expectedRoot);
    const same = (left, right) => process.platform === 'win32' ? left.toLowerCase() === right.toLowerCase() : left === right;
    if (!same(owned, expectedRoot) || !same(filename, path.resolve(item.path))) throw new Error('Redirected renderer cache path.');
    const relative = path.relative(owned, filename);
    if (!relative || path.isAbsolute(relative) || relative === '..' || relative.startsWith('..'+path.sep) || path.extname(filename).toLowerCase() !== '.png') throw new Error('Renderer image escapes the owned preview cache.');
    const stat = fs.statSync(filename);
    total += stat.size;
    if (!stat.isFile() || stat.size > 8*1024*1024 || total > 20*1024*1024) throw new Error('Renderer image exceeds the bounded image budget.');
    const image = fs.readFileSync(filename);
    if (!image.subarray(0,8).equals(Buffer.from('89504e470d0a1a0a', 'hex'))) throw new Error('Renderer did not return a PNG.');
    return { type: 'image', mimeType: 'image/png', data: image.toString('base64') };
  });
}

let applyQueue = Promise.resolve();
const server = new Server({ name: 'bandastation-maps', version: '1.0.0' }, { capabilities: { tools: {} } });
function shutdown() {
  if (stopping) return;
  stopping = true;
  for (const child of activeWorkers) terminateWorker(child);
  void server.close();
}
server.onclose = shutdown;
// SDK stdio transport does not forward stdin EOF to its onclose callback.
process.stdin.once('end', shutdown);
process.once('SIGINT', shutdown);
process.once('SIGTERM', shutdown);
process.once('exit', () => { for (const child of activeWorkers) terminateWorker(child); });
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools }));
server.setRequestHandler(CallToolRequestSchema, async request => {
  try {
    const { name, arguments: args = {} } = request.params;
    if (!Object.hasOwn(schemas, name)) throw new Error('Unknown map tool: '+name);
    const checked = schemas[name].parse(args);
    let result;
    if (name === 'dmm_apply_patch') {
      const pending = applyQueue.then(() => worker(name, checked));
      applyQueue = pending.catch(() => {});
      result = await pending;
    } else result = await worker(name, checked);
    const content = [{ type: 'text', text: JSON.stringify(result) }];
    if (name === 'dmm_render') content.push(...trustedImages(result));
    return { content, structuredContent: result };
  } catch (error) {
    return { isError: true, content: [{ type: 'text', text: error instanceof z.ZodError ? 'Invalid map arguments: '+error.issues.map(issue => `${issue.path.join('.')}: ${issue.message}`).join('; ') : error.message }] };
  }
});
await server.connect(new StdioServerTransport());

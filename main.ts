// BRAINROT BAZAAR — the entrypoint make.fun runs (Node 22, standard library only).
//
// It hands the entry in the way the bounty asks: it copies game.rbxl, src/, screenshots/ and PLAY.json
// from this directory to /output, and writes /output/dossier.json with vendor/makefun-roblox.ts, the
// kit's copy of the library, unchanged. The scorer builds the dossier again from the same three inputs
// and compares the two byte for byte, so this file adds no facts of its own: it only refuses to ship an
// entry the gate would refuse, and it says what it shipped.
//
//   MAKEFUN_OUTPUT_DIR=out node main.ts     (outside the grader's container)
//
// Every name under /output must start with a letter, a digit or _ and hold only letters, digits, . _ and
// -, so the copies below skip any name that starts with a dot (.gitkeep, .DS_Store) at any depth.

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier, readPlace, matchSources } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** The gate's own caps, as the scorer's gate.json holds them. */
const CAPS = {
  text_max_bytes: 65536,
  screenshots: { max: 4, max_bytes: 262144 },
  max_instances: 500000,
  scripts_max_source_bytes: 8388608,
  scripts_max_path_chars: 1048576,
};

/** A name /output may hold: a letter, a digit or _ first, then letters, digits, . _ -. */
const SAFE_NAME = /^[A-Za-z0-9_][A-Za-z0-9._-]*$/;
/** cpSync's filter: leave out every file and directory whose name starts with a dot. */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

function fail(why: string): never {
  console.error(`brainrot-bazaar: ${why}`);
  process.exit(1);
}

// A fresh /output, so a stale dossier from an earlier run can never be what gets compared.
rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, 'screenshots'), { recursive: true });

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
if (existsSync(join(here, 'screenshots'))) {
  cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// What the gate will read: refuse here what it would refuse there, with a clearer message.
const place = readPlace(new Uint8Array(readFileSync(join(out, 'game.rbxl'))), {
  max_instances: CAPS.max_instances,
  scripts_max_source_bytes: CAPS.scripts_max_source_bytes,
  scripts_max_path_chars: CAPS.scripts_max_path_chars,
});
const scripts = place.scripts.filter((script) => script.source !== null && script.source.length > 0);
if (scripts.length === 0) fail('game.rbxl holds no script with a source: rebuild it with rojo build');

const srcFiles: { path: string; bytes: Uint8Array }[] = [];
const walk = (rel: string): void => {
  for (const entry of readdirSync(join(out, 'src', rel), { withFileTypes: true })) {
    const next = rel === '' ? entry.name : `${rel}/${entry.name}`;
    if (entry.isDirectory()) walk(next);
    else if (entry.isFile() && /\.(luau|lua)$/.test(entry.name)) {
      srcFiles.push({ path: next, bytes: new Uint8Array(readFileSync(join(out, 'src', next))) });
    }
  }
};
walk('');
const match = matchSources(place, srcFiles);
if (match.coverage < 0.8) {
  fail(`src/ covers only ${(match.coverage * 100).toFixed(1)}% of the place's script bytes (80% needed): run rojo build`);
}

const shots = readdirSync(join(out, 'screenshots')).filter((name) => !name.startsWith('.'));
if (shots.length < 3 || shots.length > CAPS.screenshots.max) {
  fail(`screenshots/ holds ${shots.length} images: the gate wants 3 or 4`);
}
for (const name of shots) {
  if (!SAFE_NAME.test(name)) fail(`screenshots/${name} is not a name the gate accepts`);
  const bytes = statSync(join(out, 'screenshots', name)).size;
  if (bytes > CAPS.screenshots.max_bytes) fail(`screenshots/${name} is ${bytes} bytes, over 256 KiB`);
}

for (const entry of readdirSync(out, { withFileTypes: true })) {
  if (!SAFE_NAME.test(entry.name)) fail(`/output holds ${entry.name}, a name the gate refuses`);
}

const dossier = buildDossier(out, CAPS);
writeFileSync(join(out, 'dossier.json'), dossier);

console.log(
  [
    `brainrot-bazaar: ${place.instances} instances, ${place.scripts.length} scripts`,
    `src/: ${srcFiles.length} files, ${(match.coverage * 100).toFixed(1)}% of the place's script bytes matched`,
    `screenshots: ${shots.sort().join(', ')}`,
    `dossier.json: ${dossier.length} bytes`,
  ].join('\n'),
);

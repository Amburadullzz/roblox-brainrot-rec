// Writes default.project.json, the Rojo project `rojo build` turns into game.rbxl.
//
//   node tools/gen-project.mjs
//
// The world's parts come from tools/world.mjs, so the place and the screenshot renderer never disagree
// about where the bazaar is. The scripts are mounted from src/: shared modules to ReplicatedStorage,
// the server's to ServerScriptService, the client's to StarterPlayerScripts.

import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { workspaceParts, lighting, PALETTE } from './world.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');

/** A Part node for the Rojo tree. */
function partNode(p) {
  const props = {
    Anchored: true,
    CanCollide: p.collide !== false,
    Color: p.color,
    Material: p.material ?? 'SmoothPlastic',
    Shape: p.shape ?? 'Block',
    Size: p.size,
    CFrame: [p.pos[0], p.pos[1], p.pos[2], 1, 0, 0, 0, 1, 0, 0, 0, 1],
    TopSurface: 'Smooth',
    BottomSurface: 'Smooth',
  };
  if (p.transparency !== undefined) props.Transparency = p.transparency;
  return { $className: 'Part', $properties: props };
}

const workspace = {
  $properties: { FilteringEnabled: true, Gravity: 196.2 },
};

for (const p of workspaceParts()) workspace[p.name] = partNode(p);

// The spawn pad: the player lands on the south deck facing the bazaar.
workspace.SpawnPad = {
  $className: 'SpawnLocation',
  $properties: {
    Anchored: true,
    Color: PALETTE.white,
    Duration: 0,
    Neutral: true,
    Size: [12, 1, 12],
    CFrame: [0, 1.5, 160, 1, 0, 0, 0, 1, 0, 0, 0, 1],
    TopSurface: 'Smooth',
    Transparency: 0.15,
  },
};

const project = {
  name: 'brainrot-bazaar',
  tree: {
    $className: 'DataModel',
    ReplicatedStorage: {
      Shared: { $path: 'src/shared' },
    },
    ServerScriptService: {
      Server: { $path: 'src/server' },
    },
    StarterPlayer: {
      $properties: { CharacterWalkSpeed: 20, EnableMouseLockOption: false },
      StarterPlayerScripts: {
        Client: { $path: 'src/client' },
      },
      StarterCharacterScripts: {},
    },
    Workspace: workspace,
    Lighting: { $properties: lighting() },
    SoundService: { $properties: { RespectFilteringEnabled: true } },
    Players: { $properties: { CharacterAutoLoads: true, RespawnTime: 3 } },
  },
};

writeFileSync(join(root, 'default.project.json'), `${JSON.stringify(project, null, 2)}\n`);
console.log(`wrote default.project.json with ${Object.keys(workspace).length - 1} workspace children`);

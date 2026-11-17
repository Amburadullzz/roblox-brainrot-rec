// The world of BRAINROT BAZAAR, as data: every part the place ships with, generated the same way every
// time so that `rojo build` and the screenshot renderer both read one description of the island.
//
// A part here is { name, pos: [x, y, z], size: [x, y, z], color: [r, g, b] (0..1), shape?, material?,
// transparency?, collide? }. Everything is axis aligned on purpose: no rotation is needed anywhere in the
// bazaar, and axis aligned parts keep the renderer and the place in agreement.

const MAP = 420;
const PLOT_RADIUS = 100;

/** The colours the island is painted with, so the HUD, the props and the pods agree. */
export const PALETTE = {
  grass: [0.29, 0.55, 0.24],
  grassDark: [0.22, 0.44, 0.2],
  stone: [0.72, 0.71, 0.68],
  stoneDark: [0.45, 0.45, 0.48],
  slate: [0.18, 0.2, 0.28],
  cyan: [0.1, 0.95, 0.95],
  gold: [1.0, 0.76, 0.2],
  wood: [0.45, 0.3, 0.18],
  leaf: [0.16, 0.62, 0.3],
  trunk: [0.38, 0.26, 0.15],
  rock: [0.52, 0.52, 0.55],
  water: [0.16, 0.55, 0.85],
  pink: [0.95, 0.3, 0.6],
  white: [0.95, 0.95, 0.95],
};

/** The six base plots, in a ring around the bazaar: x and z of each plot's centre. */
export const PLOTS = [
  [0, -PLOT_RADIUS],
  [-PLOT_RADIUS, -50],
  [PLOT_RADIUS, -50],
  [-PLOT_RADIUS, 60],
  [PLOT_RADIUS, 60],
  [0, 105],
];

/** Where the spawn pad sits, and where the tsunami enters the map. */
export const SPAWN = [0, 160];
export const WAVE_START_Z = -205;

/** A seeded generator, so the props land in the same place on every build. */
function lcg(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

/** One Part as the place holds it. */
export function part(name, pos, size, color, extra = {}) {
  return { name, pos, size, color, ...extra };
}

/** The Workspace tree: ground, bazaar, pods, plots, props and the tsunami wall's home. */
export function workspaceParts() {
  const rand = lcg(20261118);
  const parts = [];

  parts.push(part('Ground', [0, -0.5, 0], [MAP, 1, MAP], PALETTE.grass, { material: 'Grass' }));
  parts.push(part('Shoreline', [0, -0.6, -MAP / 2 + 12], [MAP, 1, 24], PALETTE.water, { material: 'Water' }));

  // The bazaar: a raised stone deck with a neon trim, the vault pedestal in the middle, an arch over it.
  parts.push(part('BazaarDeck', [0, 1.5, 0], [64, 3, 64], PALETTE.stone, { material: 'Slate' }));
  parts.push(part('BazaarTrim', [0, 3.1, 0], [66, 0.4, 66], PALETTE.cyan, { material: 'Neon' }));
  parts.push(part('VaultPedestal', [0, 6, 0], [12, 6, 12], PALETTE.slate, { material: 'Concrete' }));
  parts.push(part('VaultGlow', [0, 9.2, 0], [13, 0.4, 13], PALETTE.gold, { material: 'Neon' }));
  parts.push(part('VaultCore', [0, 11, 0], [5, 5, 5], PALETTE.cyan, { material: 'Neon', transparency: 0.15 }));

  // The arch: two pillars and a beam, with the island's name across the top.
  for (const sx of [-1, 1]) {
    parts.push(part(`ArchPillar${sx < 0 ? 'W' : 'E'}`, [sx * 27, 11, -30], [3, 16, 3], PALETTE.stoneDark, { material: 'Concrete' }));
    parts.push(part(`ArchLamp${sx < 0 ? 'W' : 'E'}`, [sx * 27, 19.5, -30], [4, 2, 4], PALETTE.pink, { material: 'Neon' }));
  }
  parts.push(part('ArchBeam', [0, 21, -30], [57, 2.5, 3], PALETTE.stoneDark, { material: 'Concrete' }));
  parts.push(part('ArchSign', [0, 24, -30], [40, 5, 1.2], PALETTE.slate, { material: 'SmoothPlastic' }));
  parts.push(part('ArchSignGlow', [0, 24, -29.2], [40.6, 5.6, 0.4], PALETTE.cyan, { material: 'Neon' }));

  // Twelve pod pads, two rings of six, one pod per brainrot on the ladder: the inner ring sells the
  // cheap half of the cast, the outer ring the expensive half. The pad's colour is its rarity's colour,
  // the same seven colours src/shared/Config.luau gives the HUD.
  const RARITY_COLORS = [
    [0.66, 0.67, 0.71], // Common
    [0.38, 0.84, 0.42], // Uncommon
    [0.34, 0.6, 1.0], // Rare
    [0.73, 0.42, 1.0], // Epic
    [1.0, 0.77, 0.25], // Legendary
    [1.0, 0.36, 0.36], // Mythic
    [0.25, 0.96, 0.88], // Secret
  ];
  const RARITY_OF_POD = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 6];
  for (let i = 0; i < 12; i++) {
    const ring = i < 6 ? 18 : 28;
    const a = ((i % 6) / 6) * Math.PI * 2;
    const x = Math.sin(a) * ring;
    const z = Math.cos(a) * ring;
    const color = RARITY_COLORS[RARITY_OF_POD[i]];
    parts.push(part(`PodPad${i + 1}`, [x, 3.3, z], [7, 0.6, 7], color, { material: 'Neon' }));
    parts.push(part(`PodPost${i + 1}`, [x + 3.2, 5.5, z + 3.2], [0.8, 4, 0.8], PALETTE.stoneDark, { material: 'Concrete' }));
    parts.push(part(`PodLamp${i + 1}`, [x + 3.2, 7.8, z + 3.2], [1.6, 1.6, 1.6], color, { material: 'Neon' }));
  }

  // The rebirth altar, on the bazaar's south edge, where a base is given back for a bigger multiplier.
  parts.push(part('RebirthAltar', [0, 3.9, 30], [12, 1.6, 12], PALETTE.gold, { material: 'Neon' }));
  parts.push(part('RebirthPlinth', [0, 5, 30], [4, 2.4, 4], PALETTE.slate, { material: 'Concrete' }));

  // The six base plots: a deck, six slot markers in two rows, low fences, and a sign post.
  PLOTS.forEach(([px, pz], index) => {
    const n = index + 1;
    parts.push(part(`Plot${n}Deck`, [px, 0.5, pz], [34, 1, 34], PALETTE.stone, { material: 'Slate' }));
    parts.push(part(`Plot${n}Trim`, [px, 1.1, pz], [35, 0.3, 35], PALETTE.stoneDark, { material: 'SmoothPlastic' }));
    for (let s = 0; s < 6; s++) {
      const col = s % 3;
      const row = Math.floor(s / 3);
      const sx = px - 10 + col * 10;
      const sz = pz - 5 + row * 10;
      parts.push(part(`Plot${n}Slot${s + 1}`, [sx, 1.2, sz], [7, 0.4, 7], PALETTE.slate, { material: 'SmoothPlastic' }));
      parts.push(part(`Plot${n}SlotGlow${s + 1}`, [sx, 1.45, sz], [7.6, 0.2, 0.4], PALETTE.cyan, { material: 'Neon', transparency: 0.35 }));
    }
    parts.push(part(`Plot${n}FenceW`, [px - 17, 2, pz], [1, 4, 34], PALETTE.wood, { material: 'Wood' }));
    parts.push(part(`Plot${n}FenceE`, [px + 17, 2, pz], [1, 4, 34], PALETTE.wood, { material: 'Wood' }));
    parts.push(part(`Plot${n}FenceN`, [px, 2, pz - 17], [34, 4, 1], PALETTE.wood, { material: 'Wood' }));
    parts.push(part(`Plot${n}SignPost`, [px + 14, 4, pz + 14], [1, 8, 1], PALETTE.wood, { material: 'Wood' }));
    parts.push(part(`Plot${n}Sign`, [px + 14, 8.6, pz + 14], [7, 3, 0.6], PALETTE.slate, { material: 'SmoothPlastic' }));
  });

  // The spawn pad, on the island's south side, facing the bazaar.
  parts.push(part('SpawnDeck', [SPAWN[0], 0.5, SPAWN[1]], [30, 1, 30], PALETTE.stoneDark, { material: 'Slate' }));
  parts.push(part('SpawnGateW', [-13, 6, SPAWN[1] - 12], [2, 12, 2], PALETTE.stone, { material: 'Concrete' }));
  parts.push(part('SpawnGateE', [13, 6, SPAWN[1] - 12], [2, 12, 2], PALETTE.stone, { material: 'Concrete' }));
  parts.push(part('SpawnGateTop', [0, 12.5, SPAWN[1] - 12], [28, 2, 2], PALETTE.stone, { material: 'Concrete' }));

  // The tsunami's wall waits off the north shore until a wave is called; the wave script moves it south.
  parts.push(part('TsunamiWall', [0, 14, WAVE_START_Z], [MAP, 30, 6], PALETTE.water, { material: 'Glass', transparency: 0.35 }));
  parts.push(part('TsunamiCrest', [0, 30, WAVE_START_Z], [MAP, 3, 6], PALETTE.white, { material: 'Neon', transparency: 0.2 }));

  // Props: palms, rocks, lamps and crates, placed clear of the decks.
  const busy = (x, z) => {
    if (Math.abs(x) < 46 && Math.abs(z) < 46) return true;
    if (Math.abs(x - SPAWN[0]) < 26 && Math.abs(z - SPAWN[1]) < 26) return true;
    return PLOTS.some(([px, pz]) => Math.abs(x - px) < 30 && Math.abs(z - pz) < 30);
  };
  let placed = 0;
  let guard = 0;
  while (placed < 26 && guard++ < 400) {
    const x = Math.round((rand() * 2 - 1) * 190);
    const z = Math.round((rand() * 2 - 1) * 190);
    if (busy(x, z)) continue;
    placed++;
    if (placed % 3 === 0) {
      parts.push(part(`Rock${placed}`, [x, 1.2, z], [5, 2.6, 4], PALETTE.rock, { material: 'Slate', shape: 'Ball' }));
    } else if (placed % 3 === 1) {
      parts.push(part(`PalmTrunk${placed}`, [x, 5, z], [1.8, 10, 1.8], PALETTE.trunk, { material: 'Wood' }));
      parts.push(part(`PalmLeaves${placed}`, [x, 11, z], [9, 4, 9], PALETTE.leaf, { material: 'Grass', shape: 'Ball' }));
    } else {
      parts.push(part(`LampPole${placed}`, [x, 6, z], [0.6, 12, 0.6], PALETTE.stoneDark, { material: 'Metal' }));
      parts.push(part(`LampGlobe${placed}`, [x, 12.6, z], [2.4, 2.4, 2.4], PALETTE.gold, { material: 'Neon', shape: 'Ball' }));
    }
  }
  for (let c = 0; c < 4; c++) {
    const x = -34 + c * 6;
    parts.push(part(`Crate${c + 1}`, [x, 4.2, 26], [4, 4, 4], PALETTE.wood, { material: 'Wood' }));
  }
  return parts;
}

/** The Lighting and atmosphere the place opens with: a bright cartoon noon. */
export function lighting() {
  return {
    Ambient: [0.28, 0.3, 0.36],
    OutdoorAmbient: [0.42, 0.45, 0.52],
    Brightness: 2.4,
    ClockTime: 14.5,
    GlobalShadows: true,
    EnvironmentDiffuseScale: 0.4,
    EnvironmentSpecularScale: 0.35,
    FogColor: [0.62, 0.78, 0.92],
    FogStart: 260,
    FogEnd: 620,
    Technology: 'Future',
    ColorShift_Top: [1, 0.95, 0.85],
    ColorShift_Bottom: [0.35, 0.4, 0.5],
  };
}

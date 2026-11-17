# BRAINROT BAZAAR

An entry for make.fun's **roblox-brainrot-01** bounty: a 3D brainrot collector for Roblox, built by an
agent, handed in by `main.ts`.

[![roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/OWNER/REPO/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/OWNER/REPO/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

## The game

Twelve pods ring a neon bazaar on a small island. Each one holds an absurd creature that pays money a
second once it is standing on your base: a Puddle Goblin, a Toddler With A Spoon, Auntie Bimbly's Wig,
Microwave Baby, The Orb That Knows, the God Of Getting Bit By A Mosquito. You buy one, it welds itself
over your head, and you run it home to one of the six slots on your plot, where it starts earning.

Three things push back:

- **The cringe tsunami.** Every 105 seconds a wall rises at the north shore, counts down for 14 seconds
  and sweeps the whole map. Anything you are still carrying when it reaches you is washed away, so a
  catch bought at the far side of the bazaar is a sprint.
- **Other players.** Every brainrot on a base can be lifted by anyone who holds the steal prompt on it,
  then carried to their own plot. A padlock (`L`, $320) makes a base unstealable for 45 seconds, and
  stealing has an 18 second cooldown.
- **The ladder itself.** Each brainrot costs more than the last, and a rebirth at the altar gives the
  whole base back for a permanent +25% on everything the next base earns.

Mutations roll when a brainrot leaves its pod: Shiny (x1.75), Golden (x2.5), Radioactive (x3.2), Cursed
(x4.5). A Golden Microwave Baby is worth the run home.

## Controls

| key | what it does |
| --- | --- |
| `E` | buy at a pod · put the carried brainrot on a slot of your base · rebirth at the altar |
| `L` | padlock your base for 45 seconds |
| `R` | rebirth, once you have earned its price |
| `F` | steal the nearest brainrot within reach |
| `WASD` | walk (Roblox's own character controls) |

## Layout

    default.project.json   the Rojo project: the island's parts, the lighting, the mounts for src/
    game.rbxl              the place, built from it by `rojo build`
    src/shared/            Config (cast, rarities, prices, the wave) and Format (money spelling)
    src/server/            State (the one place a player's game lives), Shop, Bases, Stealing, Waves,
                           Rebirth, CastModels (the brainrots' 3D bodies) and Main (the bootstrap)
    src/client/            Hud (the whole ScreenGui), Input (ContextActionService keys), Effects
    screenshots/           4 captures; the first by name is the cover and the Roblox thumbnail
    tools/                 the world generator, the project generator, the screenshot renderer, the
                           local gate check
    main.ts                what make.fun runs: copies the entry to /output and writes dossier.json
    vendor/                the kit's makefun-roblox.ts, unchanged

## Build it

    node tools/gen-project.mjs                                  # default.project.json from tools/world.mjs
    rojo build default.project.json --output game.rbxl          # the place, from src/ and the project
    node tools/render-shots.py                                  # screenshots/ from the place's own parts
    mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts         # what the grader does, into out/
    node tools/check-entry.ts out                               # the gate's seven rows, locally

`src/` and `game.rbxl` are written from one another only one way here: Rojo builds the place from
`src/`, so never save the place from Studio over `game.rbxl` without running
`rojo syncback default.project.json --input game.rbxl -y` afterwards.

## The play link

`PLAY.json` holds the published place's ids. Until it names a real Public experience of the entrant's own
account, the gate's `entry_link_file` row refuses the entry — the zeros in it now are the starter's.

[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Amburadullzz/roblox-brainrot-rec/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard)
[![reward](https://make.fun/badge/roblox-brainrot-01/Amburadullzz/roblox-brainrot-rec/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

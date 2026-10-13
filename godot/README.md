# SGS Card Engine (Godot 4)

A reusable engine for turn-based card games in the style of **Sanguosha / 三国杀**,
with built-in multiplayer and an iPhone-ready client. Sanguosha is the first
game module; the kernel knows nothing about it.

```
godot/
  core/              engine kernel: cards, zones, prompts, triggers, determinism
  games/sanguosha/   first game module: rules, cards, heroes, deck data
  net/               sessions: local (bots), authoritative host, ENet client
  ui/                main menu + table scene (touch friendly, built in code)
  tests/             headless test runner and tests
```

## Run it

Open `godot/` in Godot **4.7** (or newer 4.x). `ui/main_menu.tscn` is the main
scene: play against bots, host a game, or join one by address.

Headless tests (no display needed):

```
cd godot
godot --headless --path . --import          # once, or after adding class_name scripts
godot --headless --path . -s tests/run_tests.gd
godot --headless --path . -s tests/run_tests.gd sanguosha   # name filter
GODOT=/path/to/godot tests/run.sh                            # same, but also fails on script errors
```

## iPhone

The project is configured for the Mobile renderer, landscape orientation and
touch emulation. `export_presets.cfg` has an **iOS** preset: set your bundle
identifier and team id in Project → Export, then export the Xcode project and
build/sign from Xcode (Apple's signing step cannot be done from Godot alone).
GDScript was chosen over C# because its iOS export path is the mature one.

## Multiplayer

Server-authoritative. The host (a player's phone, or the headless
`Linux Server` export) runs the engine; clients only receive per-viewer
filtered snapshots and send prompt responses, which the server validates.
Players on different networks need a reachable host: run the dedicated
server export somewhere with a public IP, or add a relay later. See
`ARCHITECTURE.md`.

## Status

Working: kernel, deterministic replay, Sanguosha roles/turns/distance/damage/
dying/win, all basic cards, 10 tricks, 3 delayed tricks, 17 equipment cards
(6 weapon skills + 4 armors active), 10 heroes with skills, local bots, ENet
host/client, a functional table UI. See `ARCHITECTURE.md` for what is
intentionally not done yet.

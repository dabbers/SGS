# Architecture

## The one idea

A card game is a **sequential program that occasionally asks a player a
question**. The kernel runs the game module as a GDScript coroutine; whenever
the rules need input they `await engine.ask(prompt)`, the coroutine suspends,
and `engine.respond(player, prompt_id, response)` resumes it. Nothing else in
the system has to know about turn structure, phases or timing: the rules are
written top to bottom as they would be in a rulebook.

```
CardEngine.start(rules, config, seed)
   └─ rules.play(engine)            # coroutine
        └─ run_turn(...)             # await engine.ask(...)   ← suspends here
             └─ use_card(...)        # await engine.fire(timing, ctx)  ← triggers may ask too
```

Everything below that sits in `core/` and is game-agnostic.

| Piece | File | Role |
|---|---|---|
| `CardEngine` | `core/engine.gd` | state owner, coroutine driver, prompts, triggers, event log |
| `GameState` | `core/game_state.gd` | players, cards, zones; `snapshot(viewer)` filters hidden info |
| `Zone` | `core/zone.gd` | ordered card ids + owner + visibility (public / owner / hidden) |
| `Card` / `CardDef` | `core/card.gd`, `core/card_def.gd` | instance vs definition; defs carry behaviour hooks |
| `Prompt` | `core/prompt.gd` | serialisable question + the only response validator |
| `Trigger` | `core/trigger.gd` | reacts to a timing point, may ask prompts, mutates a ctx dict |
| `GameRules` | `core/game_rules.gd` | the module interface: defs, setup, play, bot policy |
| `CardRng` | `core/rng.gd` | the only random source |
| `SimpleBot` | `core/simple_bot.gd` | answers prompts for bot seats (module policy first, then fallback) |

### Determinism and replay

All randomness goes through the seeded `CardRng`; all input arrives through
`respond`. `(seed, config, inputs)` therefore reproduces a game exactly
(`CardEngine.replay`). The tests assert the event log is byte-identical on
replay. This is what makes server crash recovery, spectating and bug reports
("here is the seed and the inputs") cheap.

### Hidden information

Zones have a visibility. `GameState.snapshot(viewer)` includes card faces only
for zones the viewer may see (or face-up cards). `CardEngine.event_for_viewer`
attaches card data to a `cards_moved` event only when the destination is
visible to that viewer. Clients therefore keep a "known cards" map that grows
as cards are revealed; they never receive other hands.

### Timings and triggers

`engine.fire(timing, ctx)` runs every registered `Trigger` that listens to
that timing, ordered by priority then by seat order from the current player.
Triggers communicate by mutating `ctx` (`cancelled`, `amount`, `provided`, …).
Equipment and hero skills are just triggers tagged with their source card /
player, so removing a card or killing a player unregisters them.

### Prompt kinds

`choose_cards`, `choose_players`, `choose_option`, `confirm`, and `play`
(the action-phase prompt: a card, a skill option, or pass). Responses are
dictionaries: `{"cards": [...], "players": [...], "option": id, "pass": bool}`.
Validation lives in one place (`Prompt.validate`) and runs on the server.

## Sanguosha module (`games/sanguosha/`)

- `sgs_rules.gd` – roles, heroes, the turn loop, distance / range, the Strike
  pipeline, damage → dying → death → win check, Negate chains, bot policy.
- `cards_*.gd` – card definitions. A trick overrides `effect(e, source,
  target, card)`; `SgsRules.trick_effect` handles armor immunity and Negate.
- `heroes.gd` – heroes with passive triggers, "virtual card" rules (red card
  counts as Strike…) and active skills offered as play-prompt options.
- `data/deck_*.json` – printed decks (generated from the old CSV card lists).

Timings used (all `Sgs.T_*`): turn/phase start/end, draw count, card used,
trick targeted, strike used / dodged / hit, provide card (armor), damage
before/after, dying, death, judge after.

Implemented: Strike (normal/fire/thunder), Dodge, Peach, Wine; Negate,
Dismantle, Snatch, Something for Nothing, Peach Garden, Bountiful Harvest,
Barbarians, Arrow Barrage, Duel, Borrowed Sword, Blaze; Lightning,
Contentment, Starvation; horses, all weapons (ranges) with skills for
Crossbow, Black Pommel, Ice Sword, Axe, Green Dragon Blade, Kylin Bow,
Ancient Scimitar; Eight Trigrams, Black Shield, Wooden Armor, Silver Helmet;
10 heroes (Liu Bei, Guan Yu, Zhang Fei, Zhao Yun, Cao Cao, Zhou Yu, Lü Meng,
Sun Quan, Diao Chan, Hua Tuo).

Not yet: Iron Chain (and chained damage), Serpent Spear / Sky Scorcher /
Double Swords / Fire Fan weapon skills, hero *selection* (heroes are dealt
randomly), card timeouts for absent players, a hero gender/faction model
beyond data.

## Sessions and multiplayer (`net/`)

`GameSession` is the UI's only dependency. It emits `synced(snapshot)`,
`event_received`, `prompt_received` (my seat), `waiting_for` (someone else),
`game_over`, and takes `submit(prompt_id, response)`.

- `GameHost` – runs the engine; after every suspension it sends each human
  seat its filtered snapshot + pending prompt + new events. Bots answer in
  process. `resync(seat)` replays everything for a reconnecting client.
- `LocalSession` – `GameHost` in-process, every other seat a bot.
- `NetSession` – one script for both roles over `ENetMultiplayerPeer`.
  Client → server: `_rpc_submit(prompt_id, response)` only.
  Server → client: lobby, seat, start, `_rpc_sync(snapshot, prompt, events)`,
  game over, error.

Because the host sends a complete filtered snapshot on every suspension, the
client needs no state replication logic and a reconnect is just a resync.
The event stream is for the log and animations.

### Internet play

ENet is UDP; phones behind NAT cannot host for each other. Options, in order
of effort: (1) host the `Linux Server` export on a VPS and have everyone join
it; (2) add a tiny relay; (3) swap the peer for `WebRTCMultiplayerPeer`
(same RPC code) with a signalling server. The session API does not change.

## Adding a new game

1. Subclass `GameRules`: build defs, set up zones/players, write `play`.
2. Subclass `CardDef` for card behaviour; use `engine.ask`, `engine.fire`,
   `engine.move_cards`.
3. Register triggers for anything that reacts to timings you define.
4. Provide a `bot_answer` policy (optional; the fallback picks valid answers).
5. Swap `SgsRules.new()` in `GameHost.start` (or pass rules in) and give the
   table scene display data for your defs.

## Testing

`tests/run_tests.gd` is a ~50-line headless runner: every `tests/test_*.gd`
extending `TestCase` has its `test_*` methods run (they may `await`).
`test_sanguosha.gd` includes a fuzz test that plays twelve full bot games of
2–8 players, checks card conservation, and replays each from its input log.
`test_session.gd` drives the real table scene and a host + client ENet game
inside one process.

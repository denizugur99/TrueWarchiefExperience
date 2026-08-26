# True Warchief Experience (TWE)

A Warrior class voice pack addon for WoW Midnight (12.x). It plays contextual
voice/sound lines when your Warrior casts key abilities and on ambient events
like entering combat, mounting, dying, reviving, going AFK, logging in, and
self-targeting. The addon only loads for the Warrior class (`classId == 1`) —
it is a no-op for every other class.

## Installation

1. Copy the `TrueWarchiefExperience` folder into your `Interface/AddOns/`
   directory so the layout is:
   ```
   Interface/AddOns/TrueWarchiefExperience/
       TrueWarchiefExperience.toc
       TWE_main.lua
       sounds/...
   ```
2. The folder name must match `TrueWarchiefExperience.toc` exactly, and the
   `.toc` loads a single file, `TWE_main.lua`.
3. Enabled by default (`## DefaultState: enabled` in the `.toc`) — no
   additional setup required. Restart WoW or reload your UI (`/reload`) after
   installing.

## SavedVariables

The addon persists its settings in `TWE_settings` (declared via
`## SavedVariables: TWE_settings` in the `.toc`):

| Key | Meaning | Default |
|-----|---------|---------|
| `soundEnabled` | Master on/off switch | `true` |
| `debugEnabled` | Verbose debug logging to chat | `false` |
| `globalCD` | Minimum seconds between any two sound plays | `0` |

## Slash commands

All commands are under `/twe`:

| Command | Effect |
|---------|--------|
| `/twe on` | Enable sounds |
| `/twe off` | Disable sounds |
| `/twe debug` | Toggle debug output (prints gate/decision info to chat) |
| `/twe cd <seconds>` | Set the global cooldown between sound plays |

Running `/twe` with no argument (or an unrecognized one) prints this command
list.

## How sound selection works

Every spell cast or ambient state change is checked against a table of rules
(`SpellToSound` for spells; direct calls for ambient states) that says which
**category** of sound to play, at what **probability**, and under what
**priority tier**. Each category is a pool of one or more `.ogg`/`.mp3` files
in `sounds/<category>/`; when a category has multiple files, one is picked at
random (with a repeat-penalty so the same line doesn't play twice in a row).

Spell sounds are **not restricted to combat** — a mapped spell plays its line
whether it's cast in or out of combat.

### Three-tier priority system

Sounds are grouped into three tiers, each of which can cut itself and every
tier below it, but never a tier above it:

- **Force** — always plays regardless of cooldown or lock state; cuts
  whatever is currently playing (force or not). Used for major cooldowns,
  death, revive, and login — events that should never be silently dropped.
- **Normal** (default) — the everyday case for rotational/utility spells.
  Blocked while a protect lock or the global cooldown is active; otherwise
  cuts any other currently playing normal sound, but never a force sound.
- **Low-priority** — reserved for very high-frequency filler abilities (none
  are currently mapped in this pack, but the system supports it). Only cuts
  another low-priority sound; never interrupts a normal or force sound.

### Protect locks and the low-priority grace window

A sound can carry a **protect duration** — a number of seconds after it
starts during which no normal sound is allowed to cut it off early. This is
usually a *measured* value (the file's actual runtime plus a small buffer)
stored per-file in `TWE_Sounds`, so long lines play out fully and short lines
don't hold an unnecessarily long lock. Force sounds ignore protect locks
entirely.

Because low-priority sounds are never allowed to cut a normal/force sound —
even one with no protect lock of its own — there's a separate, fixed
**grace window** (`TWE_LOWPRIORITY_GRACE`, 1.5s) that starts whenever any
non-low-priority sound plays. A low-priority sound attempted during that
window is simply blocked from starting, so it can't sneak in over the top of
something that just started playing.

For the full mechanical breakdown (exact gating order, `StopSound` fadeout
handling, etc.) see the comments in `TWE_main.lua` itself; for the
category-by-category and spell-by-spell reference, see `sounds_list.md`.

## Detection method

Spell sounds trigger off `UNIT_SPELLCAST_SUCCEEDED` (instant/off-GCD spells)
or `UNIT_SPELLCAST_START` (for entries marked `onCastStart = true`). Buff/aura
based detection is not used — the relevant Blizzard APIs are unreliable or
throw errors on secret (protected) auras during combat in Midnight, so this
pack is cast-event driven only.

Ambient states (combat, mount, AFK, self-target, death/revive) are polled
every 0.2s in an `OnUpdate` handler rather than driven by dedicated events,
since some of those states (e.g. `UnitIsAFK`) require careful handling of
Midnight's "secret value" restrictions.

### AFK loop

Going AFK plays `AFK_START` (`afkStart_1.mp3`), then keeps re-playing it on a
timer (`AFK_STINGER_DURATION`, its own measured runtime) for as long as
`UnitIsAFK("player")` stays true, using a single shared timer handle reused
across every replay. Returning from AFK cancels that timer and stops whatever
is currently playing with an explicit `0` fadeout — no separate return-from-AFK
line.

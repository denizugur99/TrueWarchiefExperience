# TWE Sound Reference

Developer reference for every category in `TWE_Sounds` and every spell wired
to it in `SpellToSound`, both in `TWE_main.lua`. Protect durations marked
"measured" are the file's actual runtime + a small buffer, stored as the
per-file `s[3]` value in `TWE_Sounds`; "n/a" means no protect is set (the
sound is short/unimportant enough, or multi-file with playback naturally
short).

## Ambient categories

| Category | Files | Force | Protect | Notes |
|----------|-------|-------|---------|-------|
| `LOGIN` | 1 | yes | 9.1s (measured) | Fires on `PLAYER_ENTERING_WORLD`, gated to once per hour via a timestamp so it doesn't replay on every zone/loading-screen transition. |
| `SELECT` | 6 | no | n/a | Plays when the player targets themself. |
| `AGGRO` | 3 | no | n/a | Plays on entering combat; gated by its own separate 20s cooldown (`AGGRO_CD`), independent of the protect-lock system. |
| `DEATH` | 2 | yes | 14.1s / 15.8s (measured, per file) | Cuts through everything, same tier as major cooldowns. |
| `REVIVE` | 6 | yes | 4.6s–11.2s (measured, per file) | Cuts through everything. File name translated from Turkish `canlandirma` and camelCased to `revive`. |
| `MOUNT` | 6 | no | n/a | Plays on mounting up; suppressed on login via `prevMounted` seeded from `IsMounted()` on `PLAYER_ENTERING_WORLD`. |
| `AFK_START` | 1 (`.mp3`) | n/a — played via direct `pcall(PlaySoundFile, ...)`, not through `PlayRandom` | 166.98s (measured, `AFK_STINGER_DURATION` constant) | Plays immediately on going AFK, then reschedules itself via a shared `C_Timer` handle (`afkMusicTimer`) every `AFK_STINGER_DURATION`, re-checking `UnitIsAFK` via `IsStillAFK()` before each replay, for as long as the player stays AFK. On AFK end the addon cancels the shared timer and stops `afkSoundHandle` with an explicit `0` fadeout — no return-from-AFK voice line. |

## Spell categories

Every category below is triggered from `SpellToSound` via
`UNIT_SPELLCAST_SUCCEEDED` unless noted otherwise. `prob` is the chance the
sound plays at all once the entry is reached. Spell sounds are **not**
gated by combat state — they play whether the cast happens in or out of
combat (the `anyCombat` field/gate was removed; every entry behaves as
`anyCombat` used to).

### Major cooldowns (all `force = true`)

| Category | Spell ID(s) | Spell name | Protect | Notes |
|----------|-------------|-----------|---------|-------|
| `RECKLESSNESS` | 1719 | Recklessness | 5.9s (measured) | |
| `AVATAR` | 107574 | Avatar | 4.9s (measured) | |
| `SHIELD_WALL` | 871 | Shield Wall | 5.7s (measured) | |
| `BLADESTORM` | 227847 | Bladestorm | 2.9s (measured) | |
| `ODYNS_FURY` | 385059 | Odyn's Fury | 4.8s (measured) | |
| `RAVAGER` | 228920 | Ravager | 4.4s (measured) | |
| `DEMOLISH` | 436358 | Demolish | 2.6s (measured) | Protection capstone. |
| `DEATH_WISH` | 12292 | Death Wish | 6.5s (measured) | |
| `KILL_OR_BE_KILLED` | 1265361 | Kill or Be Killed | 4.2s (measured) | Fury death-prevention proc. |
| `RETALIATION_ENRAGED_REGEN` | 264085, 184364 | Retaliation, Enraged Regeneration | 5.0s (measured) | **Shared bucket by deliberate judgment call** — see below. |

### Core rotational / offense

| Category | Spell ID(s) | Spell name | Prob | Notes |
|----------|-------------|-----------|------|-------|
| `EXECUTE` | 163201, 5308 | Execute (Arms), Execute (Fury/Protection) | 0.4 | Both spec variants share the same sound. Protect: 2.2s (measured, own runtime 1.959s + buffer) — prevents a rapid re-trigger from cutting the line off mid-playback. |
| `COLOSSUS_SMASH` | 167105 | Colossus Smash | 1.0 | |
| `DRAGON_CHARGE` | 206572 | Dragon Charge | 1.0 | |
| `STORM_BOLT` | 107570 | Storm Bolt | 1.0 | |
| `CHAMPIONS_SPEAR` | 376079 | Champion's Spear | 1.0 | |
| `SHATTERING_THROW` | 64382 | Shattering Throw | 1.0 | |

### Movement

| Category | Spell ID(s) | Spell name | Prob | Notes |
|----------|-------------|-----------|------|-------|
| `CHARGE` | 100 | Charge | 0.5 | |
| `HEROIC_LEAP` | 6544 | Heroic Leap | 1.0 | |
| `HEROIC_THROW` | 57755 | Heroic Throw | 0.6 | |
| `INTERVENE` | 3411 | Intervene | 1.0 | |

### Control / utility

| Category | Spell ID(s) | Spell name | Prob | Notes |
|----------|-------------|-----------|------|-------|
| `INTERRUPT` | 6552 | Pummel | 1.0 | |
| `HAMSTRING` | 1715 | Hamstring | 0.3 | |
| `DISARM` | 676 | Disarm | 1.0 | |
| `INTIMIDATING_SHOUT` | 5246 | Intimidating Shout | 1.0 | |
| `PIERCING_HOWL` | 12323 | Piercing Howl | 1.0 | |
| `SHOCKWAVE` | 46968 | Shockwave | 1.0 | |
| `DISRUPTING_SHOUT` | 386071 | Disrupting Shout | 1.0 | |
| `OPPRESSOR` | 205800 | Oppressor | 1.0 | Protection PvP talent. |
| `TAUNT` | 355 | Taunt | 1.0 | |

### Defensive / sustain

| Category | Spell ID(s) | Spell name | Prob | Notes |
|----------|-------------|-----------|------|-------|
| `SHIELD_BLOCK` | 2565 | Shield Block | 0.5 | |
| `SPELL_REFLECTION` | 23920 | Spell Reflection | 1.0 | |
| `IMPENDING_VICTORY` | 202168 | Impending Victory | 1.0 | |

### Shouts

| Category | Spell ID(s) | Spell name | Prob | Notes |
|----------|-------------|-----------|------|-------|
| `BATTLE_SHOUT` | 6673 | Battle Shout | 0.5 | |
| `COMMANDING_SHOUT` | 225998 | Commanding Shout | 0.5 | |
| `DEMORALIZING_SHOUT` | 1160 | Demoralizing Shout | 1.0 | |
| `BERSERKER_RAGE` | 18499 | Berserker Rage | 1.0 | |

### Stances — TODO, unverified spell IDs

| Category | Spell ID | Spell name | Prob | Notes |
|----------|----------|-----------|------|-------|
| `STANCE` | 386164 | Battle Stance | 1.0 | **Unverified.** |
| `STANCE` | 386196 | Berserker Stance | 1.0 | **Unverified.** |
| `STANCE` | 1270826 | Defensive Stance | 1.0 | **Unverified**, and the ID pattern looks like a Midnight NPC-ability-style ID rather than a normal player spell ID — not confirmed as player-castable. |

These three IDs are placeholders based on best current knowledge, not
independently confirmed against live Midnight (12.x) spell data. A Wowhead
lookup was attempted in a prior session to verify them and returned HTTP 403
on every fetch, so verification never completed. All three currently share
the single `STANCE` sound file (`stance/stance_1.ogg`). Re-verify these IDs
(via Wowhead or in-game `/dump`) before relying on them, and update this
table plus the TODO comments in `TWE_main.lua` once confirmed.

### Defined but currently unwired

| Category | Files | Status |
|----------|-------|--------|
| `DUEL` | 1 (`duel/duel_1.ogg`) | **No `SpellToSound` entry maps to it.** |

The `DUEL` category and its sound file exist in `TWE_Sounds`, but nothing in
`SpellToSound` triggers it. The addon's spell detection is entirely
cast-event driven (`UNIT_SPELLCAST_SUCCEEDED` / `_START`), and there is no
Warrior spell cast associated with *entering* a duel — a duel starts via a
target-frame right-click / `DuelRequested`-style UI flow, not a spell cast,
so it doesn't fit the existing detection mechanism without adding a new,
currently-unlisted event. Per this project's convention of not wiring up an
event/API that hasn't been explicitly discussed and approved, `DUEL` is left
as a deliberate placeholder — the asset is in place for whenever duel-start
detection is added, but no firm decision has been made on which event to use
for it. Treat this as "pending a future decision," not a confirmed design
choice.

## Shared-bucket judgment calls

### `RETALIATION_ENRAGED_REGEN`

Retaliation (264085) and Enraged Regeneration (184364) intentionally share
one sound bucket/file rather than getting separate lines. Both are
situational, defensively/rage-flavored cooldowns a Warrior reaches for at a
similar kind of moment (avoiding death / stabilizing health), so treating
them as one thematic "emergency cooldown" voice line was a deliberate
judgment call to avoid needing two near-duplicate recordings for two
cooldowns that play similarly in practice — not an oversight or a bug.

## Misc

- `InterruptFailSpells` (in `TWE_main.lua`) is currently empty — the pack
  ships no dedicated "interrupt missed" sound file, so no spell IDs are
  registered there. The table and its `UNIT_SPELLCAST_FAILED` /
  `UNIT_SPELLCAST_INTERRUPTED` handling are kept for architectural parity /
  future expansion, not because anything currently uses them.

# Zynx Ramp Helper

A World of Warcraft addon that reminds healers of every step of their raid ramps. Write a plan per boss with when each ramp or cooldown should land, and the addon shows and speaks the steps leading up to it. Built for Midnight (patch 12.1, The Venomous Abyss).

## Installing

Put this folder in `World of Warcraft/_retail_/Interface/AddOns/` and name it exactly `ZynxRampHelper`, otherwise WoW won't load it. Open the settings with `/zrh`.

## Plans

The Plan tab has a plan for each spec, difficulty and boss. One line per timing, naming one or more ramps or spells:

```
01:25 - Evangelism
00:50 p2 - Ultimate Penitence
@Spectral Coils #2 -3 - Power Word: Barrier
02:10 - Rewind, Time Dilation
-- lines starting with -- are comments
```

| Timing | Meaning |
| --- | --- |
| `01:25` or `85` | after the pull |
| `00:50 p2` | after your boss mod shows stage 2, intermissions are stages like `p1.5` |
| `@Spectral Coils` | at every cast of a boss ability |
| `@Spectral Coils #2,4` | only the 2nd and 4th cast, the number in brackets on the boss mod bar |
| `@Spectral Coils #2 -3` | 3 seconds before the ability, `+3` is after |
| `@1299010 #2` | a spell id instead of the ability name |

A name is either a ramp from the Ramps tab, or any spell by name or spell id, which gets a countdown and a reminder at its time.

- Phases follow the stages BigWigs or DBM detect. Without a boss mod, start a phase with `/zrh phase 2` from a macro. When a boss returns to a stage, its reminders run again.
- Ability lines follow the bars BigWigs or DBM show. A ramp is timed so its last step lands with the ability, and moves when the boss mod corrects the bar. Steps that should have started before the bar appeared show as soon as it does. The Plan tab lists the abilities your boss mod showed on each boss. With both boss mods installed, the first one to show a matching bar is followed for that pull.
- An MRT note can be pasted on the Plan tab to take your times from it, and a plan can be copied out as note lines. With the MRT options on the Display tab, the times are read from your active notes at the pull instead. Ability lines stay in the plan either way.
- When a pull starts on a raid boss that isn't in [Config/Bosses.lua](Config/Bosses.lua), its encounter id is printed in chat.

## Ramps

The Ramps tab has the ramps of each spec. They start from a few starter ramps and can be changed, added or deleted. The starter ramps follow the Midnight 12.1 healing guides: Evangelism and Ultimate Penitence for Discipline, Stasis for Preservation, Tranquility and Tree of Life for Restoration Druid, and Spirit Link Totem for Restoration Shaman. Holy Priest and Holy Paladin don't ramp, their cooldowns go in the plan as spells. A ramp has the spell MRT notes use for it and one step per line:

```
charges 194509 | Save Radiance charges | setup
6gcd | Start ramp: Pain, Shield, Flash Heal | setup | icon 17 | say Start ramp
3gcd | Evangelism
2gcd | Radiance twice | icon 194509
0 | Mind Blast, Penance | icon 47540 | say Penance
```

| Part | Meaning |
| --- | --- |
| `20` | 20 seconds before the ramp lands |
| `12gcd` | 12 global cooldowns before it, shortened by haste |
| `charges <spell>` | once that spell's charges need all the time left to come back |
| `setup` | a setup step, the only steps shown with Only Setup Steps on |
| `countdown` | counts down on the icon |
| `icon <spell>` | the icon to show, by spell id or name |
| `say <text>` | what text to speech says instead of the text |

Without an icon option, a step shows the icon of the spell in its text, or else the ramp's spell.

## Midnight notes

Addons can't read the combat log any more, and spell charges and haste can be secret during encounters. When charges can't be read, charges steps assume both charges are spent and show early. Haste and recharge times use the last values read outside the encounter.

## Code

| Folder | Contents |
| --- | --- |
| [Config](Config/) | `Bosses.lua` raid bosses and difficulties, `Specs.lua` the healer specs and their starter ramps |
| [Core](Core/) | `Database.lua` saved settings, `Ramps.lua` the ramp format and reminder steps, `PlanText.lua` the plan format and MRT notes, `Plan.lua` building a fight's reminders, `Fight.lua` the fight timer and phases, `BossMods.lua` BigWigs and DBM stages and bars, `Spec.lua` the player's spec and haste, `Util.lua` small helpers |
| [UI](UI/) | `Display.lua` the on-screen reminders and text to speech, `Options.lua` the settings window |
| `main.lua` | Starts and stops the fight on encounter events |
| [libs](libs/) | [Ace3](https://www.wowace.com/projects/ace3) for the settings window |

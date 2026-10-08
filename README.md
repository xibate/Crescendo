# Zynx Ramp Helper

A World of Warcraft addon that reminds healers of every step of their raid ramps. You enter when a ramp should land, and the addon shows and speaks the setup steps leading up to it, like "Save Radiance", "Ramp for Evang" and "Evangelism". Built for Midnight (patch 12.1, The Venomous Abyss).

Supported specs: Discipline Priest, Preservation Evoker, Restoration Druid and Restoration Shaman ramps, plus cooldown and utility reminders for Holy Priest and Holy Paladin.

## Installing

Put this folder in `World of Warcraft/_retail_/Interface/AddOns/` and name it exactly `ZynxRampHelper`, otherwise WoW won't load it. Open the settings with `/zrh`.

## Timings

Each spec has a page per boss and difficulty with a box for every ramp, cooldown and utility. One entry per line:

| Line | Meaning |
| --- | --- |
| `01:25` or `85` | seconds after the pull |
| `00:50, p2` | seconds after your boss mod switches to stage 2, intermissions are stages like `p1.5` |
| `@Spectral Coils` | every cast of a boss ability |
| `@Spectral Coils #2,4` | only the 2nd and 4th cast, the number in brackets on the boss mod bar |
| `@Spectral Coils #2 -3` | 3 seconds before the ability, `+3` is after |
| `@1299010 #2` | a spell id instead of the ability name |

- Phases follow the stages BigWigs or DBM detect. Without a boss mod, start a phase with `/zrh phase 2` from a macro. When a boss returns to a stage, its reminders run again.
- Ability lines follow the bars BigWigs or DBM show. The ramp is timed so its last step lands with the ability and moves when the boss mod corrects the bar. Steps that should have started before the bar appeared show as soon as it does. The Boss Abilities tab of each boss lists the abilities your boss mod showed on it. With both boss mods installed, the first one to show a matching bar is followed for that pull.
- Times can also come from MRT notes (`{time:01:30,p2} - Name {spell:472433}`), either imported on the Import/Export tab or read from the active note at the pull. Ability lines stay in the addon either way.
- When a pull starts on a raid boss that isn't in [Config/Data.lua](Config/Data.lua), its encounter id is printed in chat.

## Midnight notes

Addons can't read the combat log any more, and spell charges and haste can be secret during encounters. When charges can't be read, "Save Radiance" and "Save Engulfs" reminders assume both charges are spent and show early. Haste uses the last value read outside the encounter.

## Code

| Folder | Contents |
| --- | --- |
| [Config](Config/) | Supported specs, raid bosses and difficulties in `Data.lua`, and a file per spec in `Specs/` with its spells and ramp steps. The format is described at the top of `Data.lua`. |
| [Core](Core/) | `Database.lua` saved settings, `Spec.lua` cooldowns and reminder steps, `Timings.lua` reading and writing timings and MRT notes, `Plan.lua` building a fight's reminders, `Fight.lua` the fight timer and phases, `BossMods.lua` BigWigs and DBM stages and bars, `Util.lua` small helpers. |
| [UI](UI/) | `Display.lua` the on-screen reminders and text to speech, `Options.lua` the settings window. |
| `main.lua` | Starts and stops the fight on encounter events. |
| [libs](libs/) | [Ace3](https://www.wowace.com/projects/ace3) for the settings window. |

To change how a spec ramps, edit its file in `Config/Specs`. Everything else reads the ramp steps from there.

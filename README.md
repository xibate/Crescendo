# Crescendo

A World of Warcraft addon that reminds healers of every step of their raid ramps. Write a plan per boss with when each ramp or cooldown should land, and the addon shows and speaks the steps leading up to it. Built for Midnight: The Venomous Abyss, The Unbinding of Kith'ix and the Midnight lair boss Nymrissa Wavecaller, plus the season 1 raids (The Voidspire, The Dreamrift, March on Quel'Danas).

## Installing

Put this folder in `World of Warcraft/_retail_/Interface/AddOns/` and name it exactly `Crescendo`, otherwise WoW won't load it.

Coming from Zynx Ramp Helper, the addon's old name: delete the old `ZynxRampHelper` folder, and to keep your plans and ramps rename `WTF/Account/<account>/SavedVariables/ZynxRampHelper.lua` to `Crescendo.lua` while the game is closed. Crescendo moves them over at the next login.

## The window

`/cres` (or `/crescendo`, or the addon button on the minimap) opens the window, styled after EllesmereUI and using its font when it is installed. Its accent colour is EllesmereUI's, Crescendo's aqua or one you pick (General page, Look). The side bar on the left has the five pages (Plans, Timeline, Ramps, Display and General) and every raid with its bosses; the number next to a boss is how many lines its plan has for your spec and the difficulty. Click a raid's name to fold it away (the season 1 raids start folded). **<<** folds the side bar down to the page icons and a boss button, which opens the raids and bosses as a menu; **>>** opens it again. Drag the bottom right corner to resize the window; the size is saved, and right-clicking the corner goes back to the normal size. In a narrow window the previews on Plans and Next up on Timeline make room for the assignments. The header shows the selected boss with Heroic or Mythic and your spec, which Plans and Timeline share. `/cres timeline`, `/cres ramps`, `/cres display` and `/cres general` open a page directly, `/cres review` shows the last pull's review, `/cres stop` stops a test. In a raid, the window opens on the boss you target, or else the next boss that isn't dead this lockout, on that difficulty and for your spec.

### Plans

1. Pick the boss in the side bar, and the difficulty and your spec in the header.
2. For a boss with stages, the tabs over the list pick what is listed:
   - **All stages**: every ability once. What you assign there triggers in every stage.
   - **Stage 1**, **Intermission** and so on: the abilities of that stage. An ability that comes back in a later stage, like Spectral Coils in Ula'tek's intermission, is on the tab of every stage it happens in. What you assign there only triggers in that stage. Hover a tab for the stage's full name.

   Pick one of the boss's abilities on the left. Click a group's name to fold it away. On Heroic, abilities that are only on Mythic are left out. Hover an ability for its spell tooltip, the stages it happens in and what is assigned to it. The number next to it is how many assignments trigger there; without any, it shows the other stages it happens in. Abilities without a stage, and ones your boss mod showed bars for or only named in the plan, are listed under Any stage.
3. On the right, click **+ Add assignment** and pick what to cast: one of your ramps, cooldowns or equipped on-use trinkets, or type any spell or item. Each assignment reads like a sentence: *what* lands *3* sec before *every cast*.
   - Use **-** and **+** (or type a number) for how many seconds before the ability the ramp lands (its last step) or the spell is cast.
   - Pick which casts, shown by their numbers: all casts, odd casts (1, 3, 5...), even casts (2, 4, 6...), every 3rd from the 1st, 2nd or 3rd, only the 1st, or **Pick casts...** to list casts like `2,4` or write a pattern like `every 4 from 2`. BigWigs and DBM number each cast of an ability on their bars, like `Spectral Coils (2)`.

   - **Audio** picks how this assignment is heard: **Default** follows the General page, **Speak** says its messages, **Countdown** counts down to its press instead of saying Soon, **Silent** only shows it.

   The line under an assignment says when its first message shows. A ramp's first message comes as far ahead of its landing as its steps say (for Evangelism, its setup step 6 global cooldowns before), a spell's countdown as long as the Spell countdown on the Display page. Hover the line for every message and its time.
4. On the right, the selected ability's first assignment shows in each reminder style (icon, bar and text, with the one in use named), Next up shows the first presses of the recorded pull (or of the plan's times), and the ready check line shows what Crescendo would say about this boss's plan.

Assignments are saved as ability lines in the boss's plan (`@Spectral Coils p2.5 #2,4 -3 - Power Word: Barrier`, where `p2.5` is the stage; `!speak`, `!countdown` or `!silent` at the end is how it is heard, on timed lines too). **Plan text**, under the assignments, shows and edits the whole plan, including times after the pull and stages. Its **Copy to...** copies the plan to the other difficulty of the boss or to another boss of the raid; a plan that was there is replaced, and **Undo** brings it back. **History** keeps the last ten versions of each plan, saved before an import, a copy over it, taking times from a note, saving the plan text and editing assignments (one every ten minutes); pick one to put it back.

### Sharing

**Share**, next to Plan text, has two modes. **Crescendo string** exports the selected plan, or every plan of the raid on Heroic and Mythic, as text to paste to another Crescendo user, with the ramps the plans use. Pasting a string shows what importing it does; **Import** (click twice) replaces the plans for those bosses and adds the ramps you don't have, keeping your own ramps with the same name. **MRT note** takes your times from an MRT note, or copies the plan out as note lines.

### General

- **Open on the boss I'm at**: in a raid the planner opens on the boss you're about to pull.
- **Check my plan at a ready check**: a line in chat with your plan for the boss you're about to pull, and what is wrong with it: no plan, names that aren't a ramp, spell or equipped trinket, spells you don't have talented, trinkets without a use effect, and uses that won't be ready in time on the recorded pull.
- **Review each pull**: after a pull, a window lists what was left out because it was on cooldown and what never triggered, with why (a stage that didn't come, no boss mod bar for it, none of its casts came). When everything showed, a line in chat says so.
- **Show what's next**: a strip with your next presses and how long until each, moved with Unlock like the reminders.
- **Before a press, say**: **Soon** says a spell's or trinket's Soon message a few seconds before it; **A countdown** says 5, 4, 3, 2, 1 instead (**Count down from** sets the first number), faster than the reminders and each number cutting off the one before so they can't fall behind. **Say each number early by** makes up for the moment speech takes to start: raise it when the numbers come late. The Soon message still shows on screen. A number is left out while another step of a ramp is spoken.
- **Profile**: plans, plan history, ramps and settings are kept in profiles, like other addons. Every character uses **Default** until you pick another, so characters can share one or each have their own. **Create** starts a new profile with the default settings and starter ramps, **Copy** (click twice) replaces the profile in use with another one, **Delete** removes one nobody needs, **Reset this profile** puts it back to the defaults. Recorded pulls and learned cooldowns are kept for every profile. A character that saved its own plans before gets a profile named after it.
- **Look**: the accent colour (EllesmereUI's, Crescendo's aqua or your own) and the window's scale.

### Testing

Every pull of a boss with BigWigs or DBM is recorded, wipes too: the stages and ability bars they showed. Without a pull of the selected difficulty, the Timeline uses your pull of the other difficulty and says so. Boss mods in Midnight only learn the timers during the fight, so there is no way to know them before a first pull, but someone who has pulled the boss can share it: **Share** on the Plans page with **With recorded pulls** ticked puts the pulls in the string, and importing it keeps a pull when you have none of that boss or a shorter one. The **Timeline** page shows the longest recorded pull of the selected boss and difficulty as a chart: a time bar with a tick every 10 seconds and the time every 30, the stages as bands with intermissions striped and named in an outlined box in the accent colour, a lane for every ability with each cast numbered like your boss mod counts them, and a **You** lane with a diamond where each of your assignments lands. A ramp, spell or trinket used again before its cooldown is back has a red diamond; hover it for when it is back. The cooldowns are the ones the addon saw in the game with your talents; a spell it hasn't seen yet goes by its base cooldown until you cast it once out of combat.

Hover an ability's name for the same tooltip as on the Plans page (the stages it happens in and what is assigned to it), and click it to select its first cast. Click a cast to select it. Below the chart you see what is assigned to it, as the same cards as on the Plans page, and **Next up**: your presses coming from 5 seconds before the cast, with the seconds until each, and the next reminder. Pick how far a new assignment reaches, **This cast**, its **stage** or **All stages**, and click **+ Assign** to add one. The Plans page follows along: going back there shows the same ability on its stage.

Drag along the time bar to move the line through the pull: Next up follows it, and **Replay pull** starts where you drop it. While a replay runs, dragging the line jumps the replay there, to fast forward or go back.

**Replay pull**, or **Replay from** a selected cast (5 seconds before it), runs the pull again with your plan, so its reminders show and speak as they would in the raid, anywhere, also while hitting a target dummy. A line on the chart follows along with the time on the time bar, and Next up follows the line. **Test cast** on the Plans page pretends a cast of the selected ability is coming in a number of seconds, which works without a recorded pull.

### Ramps and Display

The Ramps page edits the ramps of each spec, see below. The Display page sets where and how big the reminders show, and their style: **Icon** (the icon with the text below), **Bar** (a bar with the icon, text and countdown that runs out while it shows) or **Text** (only the text). **Unlock** (or `/cres unlock`) works like EllesmereUI's unlock mode: the screen dims under a grid and the reminders show with a box to drag them, and a toolbar has the exact position, nudge buttons, snap to grid and Lock. Escape or entering combat locks them too. The page also sets the voice, a sound for every reminder or only the press (from the game's sounds, or sounds other addons share through LibSharedMedia), the reminder options and reading MRT notes.

**Hide reminders while the spell or trinket is on cooldown** leaves out the reminders of a ramp, spell or trinket that won't be ready by the time it should land. A ramp goes by the spell set for it on the Ramps page. During boss fights the game can hide cooldowns from addons; then the addon goes by your last cast of the spell and the cooldown it saw when it could read it, and when it can't tell, the reminder shows.

## Plans

Each spec, difficulty and boss has a plan, which the Plan text tab edits. One line per timing, naming one or more ramps or spells:

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
| `@Spectral Coils #every 2` | every other cast, `#every 3 from 2` is the 2nd, 5th, 8th... |
| `@Spectral Coils p2.5` | only casts in stage 2.5 (the intermission), `p1,3` is stages 1 and 3 |
| `@Spectral Coils #2 -3` | 3 seconds before the ability, `+3` is after |
| `@1299010 #2` | a spell id instead of the ability name |

A name is a ramp from the Ramps page, any spell by name or spell id, or a trinket, which get a countdown and a reminder at their time. A trinket is named by its item name when it is equipped, `Trinket 1` or `Trinket 2` for whatever is in the top or bottom trinket slot at the pull, or `item:<id>`. MRT notes name trinkets by the spell of their use effect, which works both ways for equipped trinkets.

- Phases follow the stages BigWigs or DBM detect. Without a boss mod, start a phase with `/cres phase 2` from a macro. When a boss returns to a stage, its reminders run again.
- Ability lines follow the bars BigWigs or DBM show. A ramp is timed so its last step lands with the ability, and moves when the boss mod corrects the bar. Steps that should have started before the bar appeared show as soon as it does. The Plans page lists the abilities your boss mod showed on each boss. With both boss mods installed, the first one to show a matching bar is followed for that pull.
- An MRT note can be pasted on the MRT note tab to take your times from it, and a plan can be copied out as note lines. With the MRT options on the Display page, the times are read from your active notes at the pull instead. Ability lines stay in the plan either way.
- When a pull starts on a raid boss that isn't in [Config/Bosses.lua](Config/Bosses.lua), its encounter id is printed in chat.

## Ramps

The Ramps page has the ramps of each spec. They start from a few starter ramps and can be changed, added or deleted. The starter ramps follow the Midnight 12.1 healing guides: Evangelism and Ultimate Penitence for Discipline, Stasis for Preservation, Tranquility and Tree of Life for Restoration Druid, and Spirit Link Totem for Restoration Shaman. Holy Priest and Holy Paladin don't ramp, their cooldowns go in the plan as spells. A ramp has the spell MRT notes use for it and one step per line:

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
| [Config](Config/) | `Bosses.lua` raids, bosses and difficulties (generated from BigWigs), `Specs.lua` the healer specs, their starter ramps and cooldowns, `Abilities.lua` each boss's abilities and stages, from BigWigs |
| [Core](Core/) | `Database.lua` saved settings, `Ramps.lua` the ramp format and reminder steps, `Trinkets.lua` trinkets in plans, `PlanText.lua` the plan format and MRT notes, `Plan.lua` building a fight's reminders, `Fight.lua` the fight timer and phases, `Cooldowns.lua` whether a spell or trinket is ready, `BossMods.lua` BigWigs and DBM stages and bars, `Test.lua` recording pulls and tests, `Timeline.lua` what happens in a recorded pull, `Share.lua` plan strings, `Location.lua` the raid and boss the player is at, `ReadyCheck.lua` the ready check summary, `Review.lua` the pull review, `Spec.lua` the player's spec and haste, `Util.lua` small helpers |
| [UI](UI/) | `Display.lua` the on-screen reminders, styled like the window, and text to speech, `Theme.lua` the EllesmereUI style colours and widgets, `Window.lua` the window, its side bar and header, and `/cres`, `Planner.lua` the Plans page and the assignment cards, `TimelinePage.lua` the Timeline page, `RampsPage.lua`, `DisplayPage.lua` and `GeneralPage.lua` the other pages, `NextUp.lua` the Next up strip, `Review.lua` the review window, `Unlock.lua` moving the reminders and the strip |
| `main.lua` | Starts and stops the fight on encounter events |
| [tools](tools/) | `gen_bosses.py` regenerates `Config/Bosses.lua` and `Config/Abilities.lua` from a BigWigs checkout, `gen_icons.py` draws the side bar icons in `Media`, not part of the addon |

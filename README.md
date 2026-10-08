<h1>
  Zynx Ramp Helper
</h1>

> Zynx Ramp Helper is a tool designed to help healers manage their cooldowns in order to properly execute ramps. It works similarly to assigning every part of a ramp's instructions as warnings or reminders but facilitates this process by automatically creating reminders for all the steps based on the best recommended practices for the spec.

Zynx Ramp Helper is based on [Harrek's Healer Ramp Helper](https://www.curseforge.com/wow/addons/harreks-healer-ramp-helper) by Harrek ([source](https://github.com/Harreks/HarreksHealerRampHelper)). The ramp recipes, the options window and most of the addon are his work. This version updates it for Midnight and is not an official release by Harrek, so please don't send him questions about it.

<h2>
  Installing
</h2>

Put this folder in `World of Warcraft/_retail_/Interface/AddOns/` and name it exactly `ZynxRampHelper`, otherwise WoW won't load it. Remove Harrek's Healer Ramp Helper if you have it, both use the same reminders. Settings are opened with `/zrh`.

Your settings and timings from Harrek's addon don't carry over by themselves. To keep them, log out and in `WTF/Account/<account>/SavedVariables/` copy `HarreksHealerRampHelper.lua` to `ZynxRampHelper.lua`, then open the copy and change `HarreksRampHelperDB` on its first line to `ZynxRampHelperDB`.

<h2>
  Midnight update
</h2>

This version loads and runs on Midnight (patch 12.1, The Venomous Abyss).

- The boss list in [Config/Data.lua](Config/Data.lua) is now The Venomous Abyss. Encounter ids for the Season 1 raids are listed in a comment there. When you pull a boss that isn't set up, the addon prints its encounter id in chat.
- Addons can't read the combat log anymore, so phases now follow the stages BigWigs or DBM detect. Write phase timings as `00:50, p2` (or `{time:00:50,p2}` in an MRT note) and they start counting when your boss mod switches to stage 2. Intermissions use the boss mod's numbering, like `p1.5`. If the boss goes back to a stage, its reminders run again. Without a boss mod, start a phase with `/zrh phase 2` from a macro.
- Ramps can follow boss abilities instead of fixed times, so you don't need an MRT note. Add a line starting with `@` to a timings box, using the ability name as it shows on your BigWigs or DBM bar:
  - `@Spectral Coils` every cast
  - `@Spectral Coils #2,4` only the 2nd and 4th cast, counted like the number in brackets on the bar
  - `@Spectral Coils #2 -3` lands 3 seconds before the ability (`+3` is after)
  - `@1299010 #2` a spell id instead of the name

  The ramp is timed so its last step lands when the ability does, and moves when the boss mod adjusts the bar. Steps that should have started before the bar appeared show as soon as it does. The Boss Abilities tab of each boss lists the abilities your boss mod showed bars for. With both BigWigs and DBM installed, the first one to show a matching bar is followed for that pull. `@` lines are kept when you import an MRT note, and still work when the addon reads times from the MRT note.
- Spell charges and haste can be hidden from addons during encounters. When charges can't be read, "Save Radiance"/"Save Engulfs" reminders assume both charges are spent and show early. Haste uses the last value read outside the encounter.
- Text to speech uses the new `C_VoiceChat.SpeakText` arguments, and spec and talent checks use `C_SpecializationInfo` and `C_SpellBook`.
- The built-in Preservation default plans are for Manaforge Omega bosses and won't show for the new raid.

<h2>
  How does it work
</h2>

[main.lua](main.lua) has the frames that handle the encounter events and start the timers, the functions that make the addon work are in the [App folder](App/). [App/Options.lua](App/Options.lua) has the code for the in-game options window, and manages all the settings and savedVariables for the addon. The options window uses AceGUI and AceConfig. [App/BossMods.lua](App/BossMods.lua) follows the stages and ability bars of BigWigs and DBM.
[Config/Data.lua](Config/Data.lua) contains predefined data about the specs the addon supports, the boss fights of the current tier and the difficulty IDs. And the spec files in [the Config folder](Config/) have all the information to make a specific spec and their ramps work with the rest of the addon

<h2>
  Contributing
</h2>

The main way to contribute is to edit the appropriate spec file for the specialization you want to change to make their ramps better reflect reality. The rest of the addon automatically pulls the information from the RampTypes function in each class' spec file, so changing the information there would change how the addon plays for that spec

<h2>
  Credits
</h2>

Original addon, ramp recipes and default assignments by Harrek. Harrek's healer community is the [Spiritbloom.Pro discord](https://discord.gg/MMjNrUTxQe). Bundled libraries are [Ace3](https://www.wowace.com/projects/ace3).

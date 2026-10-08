<h1>
  Harrek's Healer Ramp Helper
</h1>

> The Healer Ramp Helper is a tool designed to help healers manage their cooldowns in order to properly execute ramps. It works similarly to assigning every part of a ramp's instructions as warnings or reminders but facilitates this process by automatically creating reminders for all the steps based on the best recommended practices for the spec.

[CurseForge Addn Page](https://www.curseforge.com/wow/addons/harreks-healer-ramp-helper)
[Wago Addon Page](https://addons.wago.io/addons/harreks-healer-ramp-helper)

<h2>
  Midnight update (unofficial)
</h2>

This copy is updated to load and run on Midnight (patch 12.1, The Venomous Abyss). It is not an official release by Harrek.

- The boss list in [Config/Data.lua](Config/Data.lua) is now The Venomous Abyss. Encounter ids for the Season 1 raids are listed in a comment there. When you pull a boss that isn't set up, the addon prints its encounter id in chat.
- Addons can't read the combat log anymore, so phases now follow the stages BigWigs or DBM detect. Write phase timings as `00:50, p2` (or `{time:00:50,p2}` in an MRT note) and they start counting when your boss mod switches to stage 2. Intermissions use the boss mod's numbering, like `p1.5`. If the boss goes back to a stage, its reminders run again. Without a boss mod, start a phase with `/hrh phase 2` from a macro.
- Spell charges and haste can be hidden from addons during encounters. When charges can't be read, "Save Radiance"/"Save Engulfs" reminders assume both charges are spent and show early. Haste uses the last value read outside the encounter.
- Text to speech uses the new `C_VoiceChat.SpeakText` arguments, and spec and talent checks use `C_SpecializationInfo` and `C_SpellBook`.
- The built-in Preservation default plans are for Manaforge Omega bosses and won't show for the new raid.

<h2>
  How does it work
</h2>

[The main file](HarreksHealerRampHelper.lua) contains the functions that make the addon work, the frames that handle all the events and their associated calls are here. [The Options file](Options.lua) has the code for the in-game options window, and manages all the settings and savedVariables for the addon. The options window uses AceGUI and AceConfig,
[The Data file](Data.lua) containes predefined data about the specs the addon supports, the boss fights of the current tier and the difficuly IDs. And the spec files in [the ClassData folder](ClassData/) have all the information to make a specific spec and their ramps work with the rest of the addon

<h2>
  Contribuing
</h2>

The main way to contribue is to edit the apropiate spec file for the specialization you want to change to make their ramps better reflect reality. The rest of the addon automatically pulls the information from the RampTypes function in each class' spec file, so changing the information there would change how the addon plays for that spec

<h2>
  Contact
</h2>

If you have any problem with the addon feel free to open an issue, or you can contact me directly in the [Spiritbloom.Pro discord](https://discord.gg/MMjNrUTxQe)

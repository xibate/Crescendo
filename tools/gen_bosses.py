"""Usage: python3 tools/gen_bosses.py <BigWigs checkout> Config

Builds Config/Bosses.lua and Config/Abilities.lua from BigWigs' boss modules: the raids and their bosses in journal
order, and each boss's abilities with their English names, the group BigWigs lists them under, the stages they happen
in and whether they are Mythic only. BigWigs lists an ability once, under the stage it first shows up in, repeats its
name as a comment under every later stage it comes back in, and lists Mythic only abilities under a Mythic header."""
import os
import re
import sys

bigwigs, config = sys.argv[1], sys.argv[2]
RAIDS = [  # folder, raid name, collapsed at first
    ("TheVenomousAbyss", "The Venomous Abyss", False),
    ("TheUnbindingOfKithix", "The Unbinding of Kith'ix", False),
    ("MidnightLairs", "Midnight Lairs", False),
    ("TheVoidspire", "The Voidspire", True),
    ("TheDreamrift", "The Dreamrift", True),
    ("MarchOnQuelDanas", "March on Quel'Danas", True),
]
NUMBERS = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5}


def stage_of(label, last_stage):
    m = re.match(r"^Stage (One|Two|Three|Four|Five|\d)\b", label, re.I)
    if m:
        word = m.group(1).lower()
        return float(NUMBERS.get(word, word))
    if re.match(r"^Intermission\b", label, re.I):
        return (last_stage or 1) + 0.5
    return None


def fmt(stage):
    return str(int(stage)) if stage == int(stage) else str(stage)


def mythic_only(text):
    return text is not None and re.search(r"\bMythic\b", text) is not None and not re.search(r"Heroic|Normal", text)


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def parse_module(path):
    text = open(path, encoding="utf-8").read()
    boss = re.search(r'BigWigs:NewBoss\("([^"]+)",\s*-?\d+,\s*(\d+)\)', text)
    encounter = re.search(r"mod:SetEncounterID\((\d+)\)", text)
    if not boss or not encounter:
        return None
    body = re.search(r"function mod:GetOptions\(\)\s*return \{(.*?)\n\t\}", text, re.S).group(1)
    group, stage, last_stage, group_mythic = None, None, None, False
    entries, by_name, stages = [], {}, []
    for raw in body.splitlines():
        line = raw.strip()
        if not line:
            continue
        m = re.match(r"^\{?\s*(\d+)\s*[,}].*?--\s*(.+?)\s*(\(.*\))?,?\s*$", line)
        if m:
            spell, name, note = int(m.group(1)), m.group(2).split(",")[0].strip(), m.group(3)
            entry = {"spell": spell, "name": name, "group": group, "phases": [stage] if stage else [],
                     "mythic": group_mythic or mythic_only(note)}
            entries.append(entry)
            by_name.setdefault(name, entry)
            continue
        header = re.match(r"^--\s*([A-Z][^0-9].*?)\s*,?\s*$", line)
        if header and not re.match(r"^--\s*\d", line):
            label = header.group(1)
            if label in by_name:
                # an ability listed earlier that comes back in this stage
                entry = by_name[label]
                if stage and stage not in entry["phases"]:
                    entry["phases"].append(stage)
                continue
            new_stage = stage_of(label, last_stage)
            if new_stage:
                stage = last_stage = new_stage
                stages.append((new_stage, label))
            group = label
            group_mythic = mythic_only(label)
    return {"name": boss.group(1), "journal": int(boss.group(2)), "encounter": int(encounter.group(1)),
            "entries": entries, "stages": stages}


raids = []
for folder, raid_name, collapsed in RAIDS:
    bosses = []
    for file in sorted(os.listdir(os.path.join(bigwigs, folder))):
        if file.endswith(".lua") and not file.startswith("!"):
            parsed = parse_module(os.path.join(bigwigs, folder, file))
            if parsed:
                bosses.append(parsed)
    bosses.sort(key=lambda b: b["journal"])
    raids.append((raid_name, collapsed, bosses))

head = open(os.path.join(config, "Bosses.lua"), encoding="utf-8").read()
difficulties = head[head.index("ns.difficulties"):]
out = ["local _, ns = ...", "",
       "--Raids and their bosses in journal order, by encounter id as BigWigs uses them. Generated from BigWigs' boss modules.",
       "--Pulling a raid boss that isn't listed prints its encounter id in chat. collapsed: the raid starts folded in the planner",
       "ns.raids = {"]
for raid_name, collapsed, bosses in raids:
    out.append(f"    {{ name = {lua_string(raid_name)}{', collapsed = true' if collapsed else ''}, bosses = {{")
    for b in bosses:
        out.append(f"        {{ encounterId = {b['encounter']}, name = {lua_string(b['name'])} }},")
    out[-1] = out[-1].rstrip(",")
    out.append("    } },")
out[-1] = out[-1].rstrip(",")
out += ["}", "", "--Bosses by encounter id: { name, raid = the raid's name, order = its place in the raid list }", "ns.bosses = {}",
        "for _, raid in ipairs(ns.raids) do",
        "    for order, boss in ipairs(raid.bosses) do",
        "        ns.bosses[boss.encounterId] = { name = boss.name, raid = raid.name, order = order }",
        "    end",
        "end", "", difficulties.rstrip() + "\n"]
open(os.path.join(config, "Bosses.lua"), "w", encoding="utf-8").write("\n".join(out))

lines = ["local _, ns = ...", "",
         "--Abilities of each boss, by encounter id, in the order and groups BigWigs uses, with the stages they happen in",
         "--(BigWigs' stage numbers, an intermission is the stage before it plus 0.5) and mythic = true for abilities only on",
         "--Mythic. Generated from BigWigs' boss modules. Abilities a boss mod shows bars for that aren't listed here are added",
         "--in the planner after a pull",
         "ns.bossAbilities = {"]
stage_lines = ["", "--The stages of each boss, with their names, for bosses BigWigs splits into stages", "ns.bossStages = {"]
for _, _, bosses in raids:
    for b in bosses:
        lines.append(f"    [{b['encounter']}] = {{ -- {b['name']}")
        staged = len(b["stages"]) > 1
        for e in b["entries"]:
            parts = [f"spellId = {e['spell']}", f"name = {lua_string(e['name'])}"]
            if e["group"]:
                parts.append(f"group = {lua_string(e['group'])}")
            if e["phases"] and staged:
                parts.append("phases = { " + ", ".join(fmt(s) for s in e["phases"]) + " }")
            if e["mythic"]:
                parts.append("mythic = true")
            lines.append("        { " + ", ".join(parts) + " },")
        lines[-1] = lines[-1].rstrip(",")
        lines.append("    },")
        if staged:
            stage_lines.append(f"    [{b['encounter']}] = {{ -- {b['name']}")
            for s, label in b["stages"]:
                stage_lines.append(f"        {{ stage = {fmt(s)}, name = {lua_string(label)} }},")
            stage_lines[-1] = stage_lines[-1].rstrip(",")
            stage_lines.append("    },")
lines[-1] = "    }"
lines.append("}")
stage_lines[-1] = "    }"
stage_lines.append("}")
open(os.path.join(config, "Abilities.lua"), "w", encoding="utf-8").write("\n".join(lines + stage_lines) + "\n")
print("raids:", [(r[0], [b["name"] for b in r[2]]) for r in raids])

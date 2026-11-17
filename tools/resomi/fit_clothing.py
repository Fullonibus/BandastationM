"""Build Resomi worn sprites from the BYOND clothing audit and native DMI sheets."""

import argparse
from collections import Counter, defaultdict
from copy import copy
from functools import cache
import csv
import json
from math import floor
from pathlib import Path
import re
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.dmi import Dmi


def frame_pixels(image):
    get_pixels = getattr(image, "get_flattened_data", image.getdata)
    return list(get_pixels())


ASSETS = Path("icons/bandastation/mob/species/resomi/clothing/generated")
DM = Path("modular_bandastation/species/code/clothing/resomi_generated.dm")
SLOTS = {
    "under": "ICLOTHING", "suit": "OCLOTHING", "shoes": "FEET", "gloves": "GLOVES",
    "head": "HEAD", "eyes": "EYES", "mask": "MASK", "neck": "NECK", "back": "BACK",
    "belt": "BELT", "ear_left": "EAR_LEFT", "ear_right": "EAR_RIGHT", "suit_storage": "SUITSTORE",
}
PRESERVE = {
    ("head", "icons/mob/clothing/head/hats.dmi", "secsoft_flipped"),
    *(("mask", "icons/mob/clothing/mask.dmi", name)
      for name in ("mime", "sexymime", "sadmime", "scaredmime")),
}
CONFIG = "/datum/greyscale_config/"
SHAKO = "icons/mob/large-worn-icons/64x64/head.dmi"
SOMBRERO = CONFIG + "sombrero/worn"
SOMBRERO_RECIPE = Path("code/datums/greyscale/json_configs/resomi_sombrero_worn.json")
ENVIROHELMETS = "icons/mob/clothing/head/plasmaman_head.dmi"
MOD_MODULES = "icons/mob/clothing/modsuit/mod_modules.dmi"
FRONT = ((7, 9), (11, 12), (15, 15), (16, 16), (20, 19), (23, 22))
TORSO_COLUMNS = (FRONT, FRONT, ((9, 10), (13, 13), (17, 17), (21, 20)),
                 ((10, 11), (14, 14), (18, 18), (22, 21)))

# Bridge thin details where a skipped row splits the original line.
# Each entry is (target x, target y, source x, source y).
UNIFORM_DETAILS = {
    ("gladiator", 3): ((12, 17, 12, 14),),
    ("henchmen", 0): ((13, 6, 13, 2), (18, 5, 18, 1)),
    ("henchmen", 1): ((13, 5, 13, 2), (18, 4, 18, 1)),
    ("evening_gown", 0): ((18, 15, 18, 11),),
    ("stripeddress_base", 2): ((18, 16, 19, 12),),
    ("stripeddress_base", 3): ((13, 16, 12, 12),),
}
GHOST_SHEET_EDGES = (
    ((11, 9, 12, 9), (19, 9, 18, 9), (20, 9, 18, 9)),
    ((11, 9, 12, 9), (20, 9, 19, 9)),
    ((20, 10, 19, 10),),
    ((11, 10, 12, 10),),
)


def inverse_axis(anchors, start, stop, half_up=False):
    coordinates = []
    for target in range(start, stop):
        if target <= anchors[0][1]:
            source = target + anchors[0][0] - anchors[0][1]
        elif target >= anchors[-1][1]:
            source = target + anchors[-1][0] - anchors[-1][1]
        else:
            for (a, x), (b, y) in zip(anchors, anchors[1:]):
                if x <= target < y:
                    source = a + (target - x) * (b - a) / (y - x)
                    break
        coordinates.append(floor(source + 0.5) if half_up else round(source))
    return coordinates


@cache
def pixel_map(slot, direction, mod, skirt, long_hem=False, low_shoe=False,
              full_head=False, full_uniform=False):
    """Map output coordinates to source pixels, preserving directional anchors."""
    shoulder = (14, 13, 14, 14)[direction]
    y = ((0, 0), (31, 31))
    x = ((0, 0), (31, 31))
    if slot in ("under", "suit"):
        x = TORSO_COLUMNS[direction]
        if skirt:
            hem = ((24, 25), (31, 31)) if long_hem else ((24, 27), (28, 31))
            y = ((0, shoulder - 10), (10, shoulder), (16, 19), (19, 22)) + hem
        else:
            y = ((0, shoulder - 10), (10, shoulder), (16, 19), (20, 24), (26, 29), (31, 31))
            if full_uniform:
                # Envirosuits include their footwear. Keep the ankle and sole rows.
                y = ((0, shoulder - 10), (10, shoulder), (16, 19), (20, 23), (29, 29), (31, 31))
        if slot == "suit":
            x = tuple((a, a + (b - a) * 0.5) for a, b in x)
    elif slot == "neck":
        x = TORSO_COLUMNS[direction]
        y = ((8, shoulder - 1), (16, 19), (22, 25), (30, 31))
    elif slot == "back":
        x = (((8, 10), (23, 21)), ((8, 10), (23, 21)),
             ((5, 8), (19, 19)), ((12, 12), (26, 23)))[direction]
        y = ((8, 12), (11, 15), (17, 21), (23, 25), (31, 31))
    elif slot in ("belt", "suit_storage"):
        x = (((9, 11), (22, 20)), ((9, 11), (22, 20)),
             ((9, 11), (21, 20)), ((10, 11), (22, 20)))[direction]
        y = ((0, 0), (18, 22), (23, 26), (31, 31))
    elif slot == "gloves":
        x = (((7, 9), (11, 12), (15, 15), (16, 16), (20, 19), (23, 22)),
             ((7, 9), (11, 12), (15, 15), (16, 16), (20, 19), (23, 22)),
             ((12, 13 if mod else 15), (20, 21)), ((11, 10), (19, 18 if mod else 16)))[direction]
        y = ((0, 0), (14, 16), (18, 20 if direction < 2 else 21), (21, 24), (31, 31))
    elif slot == "shoes":
        x = (((9, 11), (13, 14), (15, 15), (16, 16), (18, 18), (21, 20)),
             ((9, 11), (13, 14), (15, 15), (16, 16), (18, 18), (21, 20)),
             ((12, 12), (20, 19)), ((11, 12), (19, 19)))[direction]
        # The flat novelty shoes carry their toe colors and markings in the final rows.
        y = ((19, 20), (26, 27), (28, 28), (31, 31)) if low_shoe else (
            (19, 21), (25, 27), (29, 30), (31, 31),
        )
    else:
        delta_x = (0, 0, 1, -1)[direction]
        delta_y = {"head": 4 if mod else 5, "mask": 5, "eyes": 5,
                   "ear_left": 5, "ear_right": 5}[slot]
        x = ((0, delta_x), (31, 31 + delta_x))
        y = ((0, delta_y), (31, 31 + delta_y))
        if full_head:
            # The cueball animation includes the wearer and sparks around its feet.
            y = ((2, 7), (7, 12), (10, shoulder), (18, 21), (22, 25), (26, 29), (31, 31))

    pixels = []
    for source_y in inverse_axis(y, 0, 32):
        columns = x
        if full_head and source_y > 10:
            columns = TORSO_COLUMNS[direction]
        if skirt:
            squeeze = max(0, min(1, (24 - source_y) / 5))
            columns = tuple((a, a + (b - a) * squeeze) for a, b in x)
        # With half-pixel anchors, ties-to-even drops alternate columns along
        # wide wings and capes, including outside the compressed torso.
        for source_x in inverse_axis(columns, 0, 32, half_up=slot == "suit"):
            inside = 0 <= source_x < 32 and 0 <= source_y < 32
            pixels.append(source_y * 32 + source_x if inside else 1024)
    return pixels


def fit(state, slot, mod, skirt, long_hem=False, low_shoe=False, full_uniform=False):
    result = copy(state)
    result.frames = []
    for index, frame in enumerate(state.frames):
        direction = index % state.dirs
        colors = frame_pixels(frame) + [(0, 0, 0, 0)]
        mapping = pixel_map(slot, direction, mod, skirt, long_hem, low_shoe,
                            full_head=slot == "head" and state.name == "cueball",
                            full_uniform=full_uniform)
        output_colors = [colors[pixel] for pixel in mapping]
        if slot == "back" or (slot == "suit" and state.name == "football_number"):
            preserve_small_details(colors, mapping, output_colors,
                                   max_neighbors=3 if slot == "suit" else 2)
        if slot == "suit" and state.name == "football_number" and direction == 0:
            output_colors[16 * 32 + 12:16 * 32 + 19] = colors[13 * 32 + 12:13 * 32 + 19]
        if slot == "suit" and state.name == "ghost_sheet":
            # Cover the wider head at the edge of the sheet, outside the eye holes.
            for x, y, near_x, near_y in GHOST_SHEET_EDGES[direction]:
                output_colors[y * 32 + x] = output_colors[near_y * 32 + near_x]
        if slot == "under":
            for x, y, source_x, source_y in UNIFORM_DETAILS.get((state.name, direction), ()):
                if not output_colors[y * 32 + x][3]:
                    output_colors[y * 32 + x] = colors[source_y * 32 + source_x]
        if frame.getbbox() and not any(pixel[3] for pixel in output_colors):
            # Badges and jewelry can occupy a single skipped source column.
            # Project the detail onto the closest sampled pixel.
            for source, color in enumerate(colors[:-1]):
                if not color[3]:
                    continue
                closest = min((target for target, pixel in enumerate(mapping) if pixel < 1024),
                              key=lambda target: (abs(mapping[target] // 32 - source // 32),
                                                  abs(mapping[target] % 32 - source % 32)))
                output_colors[closest] = color
        output = Image.new("RGBA", (32, 32))
        output.putdata(output_colors)
        if slot in ("ear_left", "ear_right") and state.name.startswith("justice_headset_"):
            offsets = ((-1, -1), (1, -1), (0, 0), (1, -1)) if slot == "ear_left" else (
                (1, -1), (-1, -1), (-1, -1), (0, 0),
            )
            placed = Image.new("RGBA", (32, 32))
            placed.paste(output, offsets[direction])
            output = placed
        if bool(frame.getbbox()) != bool(output.getbbox()):
            return None
        result.frames.append(output)
    return result


def preserve_small_details(colors, mapping, output, max_neighbors):
    sampled = set(mapping)
    for source in range(1024):
        if source in sampled or not colors[source][3]:
            continue
        x, y = source % 32, source // 32
        adjacent = [row * 32 + column for row in range(max(0, y - 1), min(32, y + 2))
                    for column in range(max(0, x - 1), min(32, x + 2))]
        # Preserve dropped tips and small detached buckles, not solid edges.
        if sum(bool(colors[pixel][3]) for pixel in adjacent) > max_neighbors:
            continue
        nearest = min((target for target, pixel in enumerate(mapping) if pixel < 1024),
                      key=lambda target: (abs(mapping[target] // 32 - y), abs(mapping[target] % 32 - x)))
        if not output[nearest][3]:
            output[nearest] = colors[source]


def fit_shako(state):
    result = copy(state)
    result.frames = []
    for index, frame in enumerate(state.frames):
        direction = index % state.dirs
        output = Image.new("RGBA", frame.size)
        output.paste(frame, ((0, 0, 1, -1)[direction], 5))
        result.frames.append(output)
    return result


def config_definitions():
    declarations = re.compile(r"^(/datum/greyscale_config/[^\s(]+)\n((?:[ \t].*\n|\n)*)", re.M)
    attributes = re.compile(r"^\t(icon_file|json_config) = '([^']+)'", re.M)
    return {
        name: dict(attributes.findall(body))
        for directory in ("code/datums/greyscale", "modular_bandastation")
        for file in (ROOT / directory).rglob("*.dm")
        for name, body in declarations.findall(file.read_text(encoding="utf-8-sig"))
    }


def resolve_config(name, definitions):
    properties = {}
    while name.startswith(CONFIG):
        for key, value in definitions.get(name, {}).items():
            properties.setdefault(key, value)
        name = name.rsplit("/", 1)[0]
    return properties


@cache
def source_states(path):
    if path.startswith("tmp/gags/") or not (ROOT / path).is_file():
        return {}
    sheet = Dmi.from_file(ROOT / path)
    if (sheet.width, sheet.height) != (32, 32) and path != SHAKO:
        return {}
    return {state.name: state for state in reversed(sheet.states) if not state.movement}


def skirt_shape(state, rows):
    return any(re.search(r"skirt|dress|seifuku|maid|robe", value, re.I)
               for row in rows for value in (state, row["type"], row["name"]))


def related_states(states, name):
    related = {state for state in states if state.startswith((name + "-", name + "_"))}
    if name == "facehugger":
        # These positions belong to corgi equipment, not to a humanoid face.
        related -= {"facehugger_corgi", "facehugger_corgipuppy"}
    if re.fullmatch(r"monkeymind[123]", name):
        related |= {state for state in states if state.startswith("monkeymind")}
    return related


@cache
def brief_masks():
    human = source_states("icons/mob/clothing/underwear.dmi")["male_briefs"]
    resomi = source_states("icons/bandastation/mob/species/resomi/clothing/underwear.dmi")["male_briefs"]
    return tuple(
        [tuple((i % 32, i // 32) for i, color in enumerate(frame_pixels(frame)) if color[3])
         for frame in state.frames]
        for state in (human, resomi)
    )


def preserve_hip_coverage(originals, fitted, groups):
    """Extend cloth over the wider hip only if the native layers cover the briefs."""
    human_masks, resomi_masks = brief_masks()
    for names in groups:
        originals_group = [originals[name] for name in names]
        fitted_group = [fitted[name] for name in names]
        if any(not state or state.dirs != 4 for state in fitted_group):
            continue
        # A separate GAGS belt can sit between the trousers and the exposed row.
        reach = 2 if any(name in {"belt", "belt_d"} for name in names) else 1
        frame_count = max(state.framecount for state in fitted_group)
        for index in range(frame_count * 4):
            direction = index % 4
            source = [state.frames[index % len(state.frames)] for state in originals_group]
            result = [state.frames[index % len(state.frames)] for state in fitted_group]
            if any(not any(frame.getpixel(point)[3] for frame in source) for point in human_masks[direction]):
                continue
            fitted_pixels = [frame.copy() for frame in result]
            for x, y in resomi_masks[direction]:
                if any(frame.getpixel((x, y))[3] for frame in result):
                    continue
                neighbors = [
                    (abs(near_y - y), abs(near_x - x), -layer, near_x, near_y)
                    for layer, (name, frame) in enumerate(zip(names, fitted_pixels))
                    if name not in {"buckle", "belt", "belt_d"}
                    for near_y in range(y, y + reach + 1)
                    for near_x in range(max(11, x - 2), min(21, x + 3))
                    if frame.getpixel((near_x, near_y))[3]
                ]
                if neighbors:
                    _, _, priority, near_x, near_y = min(neighbors)
                    result[-priority].putpixel((x, y), fitted_pixels[-priority].getpixel((near_x, near_y)))


def generate(audit, destination):
    with audit.open(encoding="utf-8-sig", newline="") as stream:
        rows = [row for row in csv.DictReader(stream) if row["result"] in {"fallback", "missing_native"}]
    candidates = defaultdict(list)
    for row in rows:
        native_icon = row["native_icon"]
        if row["type"] == "/obj/item/tank/jetpack/improvised":
            native_icon = "icons/mob/clothing/back.dmi"
        candidates[row["slot"], native_icon, row["state"]].append(row)

    definitions = config_definitions()
    sheets = defaultdict(dict)
    configs = {}
    sombrero_recipe = None
    selected = set()
    skipped = Counter()
    for (slot, source, name), group in sorted(candidates.items()):
        if (slot, source, name) in PRESERVE:
            skipped["cap and mime"] += len(group)
            continue
        if source != SHAKO and any(
            (row["width"], row["height"]) != ("32", "32") for row in group
        ):
            skipped["nonstandard dimensions"] += len(group)
            continue
        is_config = source.startswith(CONFIG)
        if is_config:
            properties = resolve_config(source, definitions)
            if not {"icon_file", "json_config"} <= properties.keys():
                skipped["unresolved GAGS config"] += len(group)
                continue
            path = properties["icon_file"]
            recipe = json.loads((ROOT / properties["json_config"]).read_text(encoding="utf-8"))
            if source == SOMBRERO:
                base = resolve_config(CONFIG + "sombrero/base_worn", definitions)
                assert base["icon_file"] == path
                layers = json.loads((ROOT / base["json_config"]).read_text(encoding="utf-8"))[""]
                assert all(parts[0] == {
                    "type": "reference", "reference_type": CONFIG + "sombrero/base_worn",
                    "blend_mode": "overlay", "color_ids": [1, 2],
                } for parts in recipe.values())
                recipe = sombrero_recipe = {state: layers + parts[1:] for state, parts in recipe.items()}
            if name not in recipe or any(layer.get("type") != "icon_state"
                                         for layers in recipe.values() for layer in layers):
                skipped["GAGS recipe or state"] += len(group)
                continue
            names = {layer["icon_state"] for layers in recipe.values() for layer in layers}
        else:
            path = source
            names = {name}

        originals = source_states(path)
        if not names <= originals.keys():
            skipped["missing or nonstandard DMI"] += len(group)
            continue
        if not is_config:
            names |= related_states(originals, name)
            names |= {state for state in ("gas_dirt", "gas_atmos_dirt", "helm_dirt",
                                         "wreath_emissive", "carved_pumpkin-emissive")
                      if state in originals}
            if slot == "head" and path.endswith("/plasmaman_head.dmi"):
                shared = {state: sprite for state, sprite in source_states(ENVIROHELMETS).items()
                          if state.endswith(("envisor", "_smile"))}
                originals = shared | originals
                names |= shared.keys()
        mod = any(row["mod_skin"] for row in group)
        skirt = slot == "under" and skirt_shape(name, group)
        if is_config:
            skirt = slot == "under" and skirt_shape(source, group)
        long_hem = skirt and any(frame.getbbox() and frame.getbbox()[3] > 29
                                 for state in names for frame in originals[state].frames)
        low_shoe = slot == "shoes" and path == "icons/mob/clothing/feet.dmi" and (
            name in {"moffers", "meown_shoes", "clown_prototype_on", "clown_prototype_off"}
        )
        full_uniform = slot == "under" and not skirt and any(
            frame.getbbox() and frame.getbbox()[3] == 32
            for state in names for frame in originals[state].frames
        )
        if path == SHAKO:
            fit_states = {state: fit_shako(originals[state]) for state in names}
        else:
            fit_states = {state: fit(originals[state], slot, mod, skirt, long_hem, low_shoe, full_uniform)
                          for state in names}
        if slot == "under":
            groups = ([layer["icon_state"] for layer in layers] for layers in recipe.values()) if is_config else (
                [state] for state in names
            )
            preserve_hip_coverage(originals, fit_states, groups)
        if any(fit_states[state] is None for state in (names if is_config else {name})):
            skipped["empty transformed direction"] += len(group)
            continue
        sheet_key = (slot, path, source if is_config else "")
        for state, result in fit_states.items():
            if result is None or (state in sheets[sheet_key] and state != name):
                continue
            sheets[sheet_key][state] = result
        if is_config:
            configs[source] = sheet_key
        selected.add((slot, source, name))

    # Modules attach to different parts, including the portable suit's eyewear.
    # Fit their overlays with the same slot map as the part that draws them.
    module_states = Dmi.from_file(ROOT / MOD_MODULES).states
    for slot in ("back", "head", "mask", "eyes", "suit", "gloves", "shoes"):
        sheet = sheets[slot, MOD_MODULES, ""]
        for original in module_states:
            fitted = fit(original, slot, mod=True, skirt=False)
            if fitted:
                sheet[original.name] = fitted

    output = destination / ASSETS
    output.mkdir(parents=True, exist_ok=True)
    files = {}
    for index, (key, states) in enumerate(sorted(sheets.items()), start=1):
        slot, _, _ = key
        name = f"{slot}_{index:03}.dmi"
        files[key] = ASSETS / name
        dmi = Dmi(*next(iter(states.values())).frames[0].size)
        for state in sorted(states.values(), key=lambda state: state.name):
            state.dmi = dmi
            dmi.states.append(state)
        dmi.to_file(output / name)
        written = Dmi.from_file(output / name)
        for expected, actual in zip(dmi.states, written.states, strict=True):
            fields = ("name", "dirs", "framecount", "movement", "loop", "rewind", "delays", "hotspots")
            assert all(getattr(expected, field) == getattr(actual, field) for field in fields), name
            assert [f.tobytes() for f in expected.frames] == [f.tobytes() for f in actual.frames], name
    lines = ["// Generated by tools/resomi/fit_clothing.py.", "",
             "/// Find the generated sheet for the actual worn source and equipment slot.",
             "/proc/get_generated_resomi_worn_icon(slot, native_icon, state, greyscale_config, colors)",
             "\tif(greyscale_config)",
             "\t\tvar/static/list/configs = list("]
    lines += [f"\t\t\t{source} = {source}/resomi_generated," for source in sorted(configs)]
    lines += ["\t\t)", "\t\tvar/config = configs[greyscale_config]",
              "\t\tif(!config || !colors)", "\t\t\treturn null",
              "\t\tvar/generated_icon = SSgreyscale.GetColoredIconByType(config, colors)",
              "\t\treturn icon_exists(generated_icon, state) ? generated_icon : null",
              "\tvar/static/list/sheets = list("]
    for slot, constant in SLOTS.items():
        sources = [(path, files[key]) for key in sorted(files) for sheet_slot, path, config in (key,)
                   if slot == sheet_slot and not config]
        if not sources:
            continue
        lines.append(f'\t\t"[ITEM_SLOT_{constant}]" = list(')
        lines += [f"\t\t\t'{source}' = '{path.as_posix()}'," for source, path in sources]
        lines.append("\t\t),")
    lines += ["\t)", "\tvar/generated_icon = sheets[\"[slot]\"]?[native_icon]",
              "\treturn icon_exists(generated_icon, state) ? generated_icon : null", ""]
    for source, key in sorted(configs.items()):
        lines += [f"{source}/resomi_generated",
                  f'\tname = "Resomi {source.removeprefix(CONFIG)} (Generated)"',
                  f"\ticon_file = '{files[key].as_posix()}'"]
        if source == SOMBRERO:
            recipe_file = destination / SOMBRERO_RECIPE
            recipe_file.parent.mkdir(parents=True, exist_ok=True)
            recipe_file.write_text(json.dumps(sombrero_recipe, indent="\t") + "\n", encoding="utf-8")
            lines.append(f"\tjson_config = '{SOMBRERO_RECIPE.as_posix()}'")
        lines.append("")
    dm_path = destination / DM
    dm_path.parent.mkdir(parents=True, exist_ok=True)
    dm_path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"Generated {len(files)} sheets, {sum(map(len, sheets.values()))} states and {len(configs)} GAGS configs.")
    print(f"Candidates covered: {sum(len(candidates[key]) for key in selected)}/{len(rows)} audit rows.")
    print(f"Skipped: {dict(skipped)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit", type=Path)
    parser.add_argument("--output-root", type=Path, default=ROOT)
    args = parser.parse_args()
    generate(args.audit, args.output_root)

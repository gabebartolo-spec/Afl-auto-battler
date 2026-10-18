"""The offline promise, enforced (P-70): the Android preset may ask for vibrate and nothing else.

The menu says "Plays offline. No ads, no account. Your career stays on this device." This reads
export_presets.cfg and fails if any Android preset requests a permission other than
vibrate (the internet permission above all), asks for a custom permission, or turns on a
Gradle plugin (a billing or ads library arrives that way).

    python3 tools/check_android_permissions.py [path/to/export_presets.cfg]
"""
import pathlib
import re
import sys

ALLOWED = {"vibrate"}


def android_options(text):
    """Yield (preset name, option key, raw value) for every Android preset's options."""
    presets = {}
    names = {}
    for block in re.split(r"(?m)^(?=\[preset\.\d+(?:\.options)?\]\s*$)", text):
        head = re.match(r"\[preset\.(\d+)(\.options)?\]", block)
        if not head:
            continue
        index, is_options = head.group(1), bool(head.group(2))
        for line in block.splitlines()[1:]:
            key, sep, value = line.partition("=")
            if not sep:
                continue
            key, value = key.strip(), value.strip()
            if is_options:
                presets.setdefault(index, []).append((key, value))
            elif key == "platform":
                names[index] = value.strip('"')
            elif key == "name":
                names.setdefault(index + "_name", value.strip('"'))
    for index, options in presets.items():
        if names.get(index) == "Android":
            for key, value in options:
                yield names.get(index + "_name", "preset." + index), key, value
    return


def android_preset_count(text):
    return len(re.findall(r'(?m)^platform="Android"\s*$', text))


def problems(text):
    found = []
    if android_preset_count(text) == 0:
        found.append("no Android preset found: the check would pass without looking at anything")
    for preset, key, value in android_options(text):
        if key.startswith("permissions/"):
            name = key.split("/", 1)[1]
            if name == "custom_permissions":
                if re.search(r'"[^"]+"', value):
                    found.append(f'{preset}: custom permissions requested ({value})')
            elif value == "true" and name not in ALLOWED:
                found.append(f"{preset}: permission '{name}' is requested; the promise allows only vibrate")
        elif key.startswith("plugins/") and value == "true":
            found.append(f"{preset}: Android plugin '{key.split('/', 1)[1]}' is switched on")
    return found


def check(path):
    text = pathlib.Path(path).read_text(encoding="utf-8")
    return problems(text)


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "export_presets.cfg"
    errors = check(target)
    for e in errors:
        print("FAIL:", e)
    if errors:
        print("The menu promises: Plays offline. No ads, no account. Your career stays on this device.")
        sys.exit(1)
    print("Android preset requests vibrate only: the offline promise holds.")

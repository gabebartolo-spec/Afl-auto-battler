"""Bump the patch number of the build: 0.1.13 -> 0.1.14.

Edits project.godot config/version and keeps the Android version code in export_presets.cfg
level with the version (major*10000 + minor*100 + patch, so it only rises). Run it in its own one-line PR before each ship, then
tools/check_version.py confirms nothing else holds a copy.

    python3 -I tools/bump_version.py [repo root]
"""
import pathlib
import re
import sys


def version_code(version):
    """Android version code for major.minor.patch: 1.0.0 -> 10000. Rises with every bump."""
    major, minor, patch = (int(x) for x in version.split("."))
    return major * 10000 + minor * 100 + patch


def bump(project_text, presets_text):
    """Return (new project text, new presets text, new version)."""
    m = re.search(r'(?m)^config/version="(\d+)\.(\d+)\.(\d+)"', project_text)
    if not m:
        raise SystemExit('project.godot has no config/version="major.minor.patch"')
    new = "%s.%s.%d" % (m.group(1), m.group(2), int(m.group(3)) + 1)
    project_text = project_text[:m.start()] + 'config/version="%s"' % new + project_text[m.end():]
    presets_text = re.sub(r"(?m)^version/code=\d+", "version/code=%d" % version_code(new), presets_text)
    return project_text, presets_text, new


def main(argv):
    root = pathlib.Path(argv[1]) if len(argv) > 1 else pathlib.Path(__file__).resolve().parent.parent
    project, presets = root / "project.godot", root / "export_presets.cfg"
    # newline="" keeps each file's own line endings.
    with open(project, encoding="utf-8", newline="") as f:
        p_old = f.read()
    with open(presets, encoding="utf-8", newline="") as f:
        e_old = f.read()
    p_text, e_text, new = bump(p_old, e_old)
    with open(project, "w", encoding="utf-8", newline="") as f:
        f.write(p_text)
    with open(presets, "w", encoding="utf-8", newline="") as f:
        f.write(e_text)
    print(new)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

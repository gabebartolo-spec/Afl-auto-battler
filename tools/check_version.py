"""One source of truth for the build number: project.godot config/version.

The Settings sheet and the main menu read it (BuildInfo.label). This fails if a second copy
of the number appears: a hard-coded version in scripts/, or one in export_presets.cfg (the
Android version name and the Windows file/product version must be empty so Godot uses
config/version), or an Android version code that has drifted from the patch number.

    python3 -I tools/check_version.py [repo root]
"""
import pathlib
import re
import sys

SEMVER = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def project_version(text):
    m = re.search(r'(?m)^config/version="([^"]*)"\s*$', text)
    return m.group(1) if m else ""


def problems(project_text, presets_text, script_texts):
    """script_texts: {path: text}. Returns a list of problem strings."""
    out = []
    version = project_version(project_text)
    m = SEMVER.match(version)
    if not m:
        return ["project.godot config/version is %r, not major.minor.patch" % version]
    major, minor, patch = m.group(1), m.group(2), int(m.group(3))
    stray = re.compile(r"(?<![\w.])%s\.%s\.\d+(?:\.\d+)?(?![\w.])" % (major, minor))
    for path, text in script_texts.items():
        for n, line in enumerate(text.splitlines(), 1):
            hit = stray.search(line)
            if hit:
                out.append("%s:%d hard-codes a version (%s); read config/version" % (path, n, hit.group(0)))
    for key in ("version/name", "application/file_version", "application/product_version"):
        for m2 in re.finditer(r'(?m)^%s="([^"]*)"\s*$' % re.escape(key), presets_text):
            if m2.group(1) != "":
                out.append("export_presets.cfg %s=%r must be empty (Godot then uses config/version)"
                           % (key, m2.group(1)))
    for m2 in re.finditer(r"(?m)^version/code=(\d+)\s*$", presets_text):
        if int(m2.group(1)) != patch:
            out.append("export_presets.cfg version/code=%s but the patch number is %d (tools/bump_version.py keeps them level)"
                       % (m2.group(1), patch))
    return out


def main(argv):
    root = pathlib.Path(argv[1]) if len(argv) > 1 else pathlib.Path(__file__).resolve().parent.parent
    scripts = {str(p.relative_to(root)).replace("\\", "/"): p.read_text(encoding="utf-8", errors="replace")
               for p in sorted((root / "scripts").rglob("*.gd"))}
    found = problems((root / "project.godot").read_text(encoding="utf-8"),
                     (root / "export_presets.cfg").read_text(encoding="utf-8"), scripts)
    for line in found:
        print("VERSION: " + line)
    if found:
        return 1
    print("Version: ok (%s)" % project_version((root / "project.godot").read_text(encoding="utf-8")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

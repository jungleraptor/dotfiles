"""Keep Codex shell startup live so OAuth exports are refreshed per command."""

import pathlib
import re
import shutil
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
if not path.exists():
    # Do not create a Codex installation on machines that do not use it.
    sys.exit(0)

original = path.read_text()
config = tomllib.loads(original)
if config.get("features", {}).get("shell_snapshot") is False:
    sys.exit(0)

table = re.search(r"(?m)^\[features\][ \t]*(?:#.*)?$", original)
if table:
    remainder = original[table.end():]
    next_table = re.search(r"(?m)^\[", remainder)
    end = table.end() + next_table.start() if next_table else len(original)
    section = original[table.end():end]
    setting = re.compile(r"(?m)^[ \t]*shell_snapshot[ \t]*=.*$")
    if setting.search(section):
        section = setting.sub("shell_snapshot = false", section)
    else:
        section = "\nshell_snapshot = false" + section
    updated = original[:table.end()] + section + original[end:]
else:
    updated = original + "\n[features]\nshell_snapshot = false\n"

# Fail before writing if an unusual TOML layout needs manual integration.
expected = {**config, "features": {**config.get("features", {}), "shell_snapshot": False}}
assert tomllib.loads(updated) == expected, "Unexpected change to Codex configuration"
backup = path.with_name(path.name + ".before-buildkite-oauth")
if not backup.exists():
    shutil.copy2(path, backup)
path.write_text(updated)

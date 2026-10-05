#!/usr/bin/env python3
"""Refresh the single-file installer's embedded upgrade helper."""
from pathlib import Path
root = Path(__file__).resolve().parent.parent
path = root / "install_script.sh"
text = path.read_text()
start, end = "# BEGIN EMBEDDED SAFE UPGRADE\n", "# END EMBEDDED SAFE UPGRADE\n"
embedded = ("  python3 - \"$@\" <<'TP_SAFE_UPGRADE_PY'\n" +
            (root / "scripts/safe_upgrade.py").read_text() + "TP_SAFE_UPGRADE_PY\n")
path.write_text(text.split(start)[0] + start + embedded + end + text.split(end)[1])

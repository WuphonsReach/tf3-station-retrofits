#!/usr/bin/env python3
"""Check what must not ship from a test session: settings.tl's logLevel is "summary".

A test value is a warning, so the check passes locally while the staging copy runs at "full". With --strict (CI,
.github/workflows/checks.yml) a warning fails it, so a test value cannot reach main. Exit code 1 on a failure.
"""
import argparse
import re
import sys
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("--strict", action="store_true", help="fail on warnings (CI)")
args = parser.parse_args()

settings_file = Path(__file__).resolve().parent.parent / "station_retrofits_1" / "content" / "settings.tl"
settings = dict(re.findall(r"^\s*(\w+)\s*=\s*(.+?),?\s*$", settings_file.read_text(), re.M))
warnings = []

level = settings.get("logLevel")
if level == '"summary"':
    print('PASS  settings.tl logLevel is "summary"')
else:
    warnings.append(f'settings.tl logLevel is {level}, the shipped value is "summary"')

for warning in warnings:
    print(f"{'FAIL' if args.strict else 'WARN'}  {warning}")
if warnings and args.strict:
    sys.exit(1)

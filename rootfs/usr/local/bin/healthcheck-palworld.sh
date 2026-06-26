#!/usr/bin/env bash
set -euo pipefail

if pgrep -f 'PalServer-Win64.*Cmd\.exe' >/dev/null 2>&1; then
  exit 0
fi

if pgrep -f 'PalServer-Win64' >/dev/null 2>&1; then
  exit 0
fi

exit 1

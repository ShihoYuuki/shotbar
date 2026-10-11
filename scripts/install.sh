#!/bin/bash
# 組んで ~/Applications/ShotBar.app に入れ、起動する。動いていれば入れ替える。
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build.sh
DEST="$HOME/Applications/ShotBar.app"
mkdir -p "$HOME/Applications"
if pgrep -x ShotBar >/dev/null; then pkill -x ShotBar; sleep 0.5; fi
rm -rf "$DEST"
cp -R dist/ShotBar.app "$DEST"
open "$DEST"
echo "installed $DEST"

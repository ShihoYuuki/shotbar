#!/bin/bash
# 止めて ~/Applications/ShotBar.app を消す。ログイン項目はアプリが無くなれば消える。
set -euo pipefail
pkill -x ShotBar 2>/dev/null || true
rm -rf "$HOME/Applications/ShotBar.app"
echo "removed ~/Applications/ShotBar.app"

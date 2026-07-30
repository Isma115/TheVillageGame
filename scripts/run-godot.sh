#!/bin/sh

set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin="$repo_dir/tools/godot/Godot.app/Contents/MacOS/Godot"

if [ ! -x "$godot_bin" ]; then
  echo "No se encuentra el Godot local: $godot_bin" >&2
  exit 1
fi

exec "$godot_bin" --path "$repo_dir/godot" "$@"

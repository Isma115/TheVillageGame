#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
godot_bin="$repo_dir/godot-engine/Godot.app/Contents/MacOS/Godot"
output_dir="$repo_dir/build/android"
output_apk="$output_dir/Pradera-debug.apk"

if [ ! -x "$godot_bin" ]; then
  echo "No se encuentra el Godot local: $godot_bin" >&2
  exit 1
fi

mkdir -p "$output_dir"
exec "$godot_bin" --path "$repo_dir/game" --headless --export-debug Android "$output_apk"

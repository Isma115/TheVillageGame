#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
godot_bin="$repo_dir/godot-engine/Godot.app/Contents/MacOS/Godot"
game_dir="$repo_dir/game"
task_tmp_dir="${TMPDIR:-/tmp}"
task_log_file="$task_tmp_dir/pradera-godot-$$.log"

if [ ! -x "$godot_bin" ]; then
  echo "No se encuentra el Godot local: $godot_bin" >&2
  exit 1
fi

# Godot no importa siempre los recursos nuevos cuando se lanza en modo juego.
# Si la caché del proyecto está ausente o quedó por detrás de algún archivo del
# juego, hacemos una importación corta igual que la que realiza el editor.
filesystem_cache=""
for candidate in "$game_dir"/.godot/editor/filesystem_cache*; do
  if [ -f "$candidate" ] && {
    [ -z "$filesystem_cache" ] || [ "$candidate" -nt "$filesystem_cache" ]
  }; then
    filesystem_cache="$candidate"
  fi
done

needs_import=0
if [ -z "$filesystem_cache" ]; then
  needs_import=1
else
  newer_file=$(find "$game_dir" \
    -type f \
    ! -path "$game_dir/.godot/*" \
    -newer "$filesystem_cache" \
    -print -quit)
  if [ -n "$newer_file" ]; then
    needs_import=1
  fi
fi

if [ "$needs_import" -eq 1 ]; then
  echo "Importando recursos de Godot..." >&2
  "$godot_bin" \
    --path "$game_dir" \
    --editor \
    --headless \
    --rendering-method gl_compatibility \
    --audio-driver Dummy \
    --log-file "${task_log_file}.import" \
    --quit-after 300
fi

# El backend Vulkan/MoltenVK del binario macOS puede fallar en --headless.
# El proyecto ya usa Compatibility, así que lo hacemos explícito también en
# el lanzador y evitamos inicializar audio cuando no hay dispositivo.
is_headless=0
has_rendering_method=0
has_audio_driver=0
has_log_file=0
for argument in "$@"; do
  case "$argument" in
    --headless)
      is_headless=1
      ;;
    --rendering-method|--rendering-method=*)
      has_rendering_method=1
      ;;
    --audio-driver|--audio-driver=*)
      has_audio_driver=1
      ;;
    --log-file|--log-file=*)
      has_log_file=1
      ;;
  esac
done

if [ "$has_rendering_method" -eq 0 ]; then
  set -- --rendering-method gl_compatibility "$@"
fi

if [ "$is_headless" -eq 1 ] && [ "$has_audio_driver" -eq 0 ]; then
  set -- --audio-driver Dummy "$@"
fi

if [ "$has_log_file" -eq 0 ]; then
  set -- --log-file "$task_log_file" "$@"
fi

exec "$godot_bin" --path "$game_dir" "$@"

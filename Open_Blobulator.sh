#!/bin/sh
# Open a fresh graphical VMD session, keeping the user's normal startup file.
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
vmd_executable=${BLOBULATOR_VMD_EXECUTABLE:-vmd}
if ! command -v "$vmd_executable" >/dev/null 2>&1 && [ -z "${BLOBULATOR_VMD_EXECUTABLE:-}" ]; then
    for candidate in /usr/local/bin/vmd /usr/bin/vmd; do
        if [ -x "$candidate" ]; then vmd_executable=$candidate; break; fi
    done
fi
if ! command -v "$vmd_executable" >/dev/null 2>&1 && [ -z "${BLOBULATOR_VMD_EXECUTABLE:-}" ] && [ "$(uname -s)" = Darwin ]; then
    for bundle in /Applications/VMD*.app "$HOME"/Applications/VMD*.app; do
        candidate="$bundle/Contents/Resources/VMD.app/Contents/MacOS/VMD"
        if [ -x "$candidate" ]; then vmd_executable=$candidate; break; fi
    done
fi
if ! command -v "$vmd_executable" >/dev/null 2>&1; then
    printf '%s\n' 'VMD was not found. Install VMD or set BLOBULATOR_VMD_EXECUTABLE to its executable path.' >&2
    exit 1
fi
export BLOBULATOR_PLUGIN_FILE="$project_dir/VMD_scripts/blobulator_plugin.tcl"
if [ ! -t 0 ]; then
    # Desktop launches have no console. Keep stdin open while VMD's normal
    # event loop runs, then release it when VMD exits. No helper daemon remains.
    input_dir=$(mktemp -d "${TMPDIR:-/tmp}/blobulator-input.XXXXXX")
    mkfifo "$input_dir/input"
    exec 3<>"$input_dir/input"
    exec 4<"$input_dir/input"
    rm "$input_dir/input"
    rmdir "$input_dir"
    "$vmd_executable" -e "$project_dir/VMD_scripts/start_blobulator.tcl" "$@" <&4 3<&- 4<&- &
    vmd_pid=$!
    trap 'kill "$vmd_pid" 2>/dev/null || true; exit 130' INT TERM
    set +e
    wait "$vmd_pid"
    result=$?
    exit "$result"
fi
exec "$vmd_executable" -e "$project_dir/VMD_scripts/start_blobulator.tcl" "$@"

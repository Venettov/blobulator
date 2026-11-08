#!/bin/sh
# Run from any directory. --portable-only explicitly omits VMD integration.
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
portable_only=0
if [ "${1:-}" = --portable-only ]; then portable_only=1; shift; fi
log_dir=${1:-"$PWD/blobulator-check-logs"}
mkdir -p "$log_dir"
log_dir=$(CDPATH= cd -- "$log_dir" && pwd)
cd "$script_dir/.."
run_check() {
    name=$1
    marker=$2
    shift 2
    if ! "$@" >"$log_dir/$name.log" 2>&1; then
        cat "$log_dir/$name.log"
        return 1
    fi
    if ! grep -Eq "$marker.*failed=0" "$log_dir/$name.log" ||
       grep -Eq 'skipped=[1-9]' "$log_dir/$name.log"; then
        cat "$log_dir/$name.log"
        return 1
    fi
    grep "$marker" "$log_dir/$name.log"
}
run_check portable BLOB_PORTABLE_TEST_RESULT tclsh "$script_dir/portable_exports.test"
run_check menu BLOB_MENU_TEST_RESULT tclsh "$script_dir/menu_install.test"
run_check tk BLOB_TK_SMOKE_RESULT xvfb-run -a tclsh "$script_dir/tk_widgets_smoke.tcl"
run_check tk_smoothing BLOB_SMOOTHING_TK_RESULT xvfb-run -a tclsh "$script_dir/tk_smoothing_smoke.tcl"
run_check gui_actions BLOB_GUI_ACTIONS_RESULT xvfb-run -a tclsh "$script_dir/gui_actions.test"
run_check help BLOB_HELP_TEST_RESULT xvfb-run -a tclsh "$script_dir/help.test"
if [ "$portable_only" -eq 1 ]; then
    printf '%s\n' 'Portable helpers and Tk checked. VMD integration was NOT run.'
    exit 0
fi
vmd_executable=${BLOBULATOR_VMD_EXECUTABLE:-vmd}
if ! command -v "$vmd_executable" >/dev/null 2>&1; then
    printf '%s\n' 'Linux VMD is required. Install it or set BLOBULATOR_VMD_EXECUTABLE.' >&2
    exit 2
fi
run_check smoothing BLOB_SMOOTHING_TEST_RESULT timeout 180 "$vmd_executable" -dispdev text -eofexit -e "$script_dir/trajectory_smoothing.test"
run_check loader BLOB_LOADER_TEST_RESULT timeout 180 "$vmd_executable" -dispdev text -e "$script_dir/blob_loader.test"
run_check exports BLOB_EXPORT_TEST_RESULT timeout 180 "$vmd_executable" -dispdev text -e "$script_dir/blob_exports.test"
run_check video BLOB_VIDEO_TEST_RESULT timeout 180 "$vmd_executable" -dispdev text -e "$script_dir/blob_video.test"
printf 'All checks passed without skips. Logs: %s\n' "$log_dir"

#!/bin/sh
launcher_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$launcher_dir/Open_Blobulator.sh" "$@"

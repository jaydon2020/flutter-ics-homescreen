#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

flutter pub get
dart run tool/bootstrap_native_dependencies.dart

# Toyota's custom runner does not put the PipeWire plugin beside its executable.
# Build the native plugin once when launching from a clean checkout.
native_lib="$project_dir/build/linux/x64/debug/bundle/lib/libpipewire_telephony_native.so"
if [ ! -f "$native_lib" ]; then
    flutter build linux --debug
fi
export PWT_NATIVE_LIB="$native_lib"

exec flutter run -d desktop-homescreen "$@"

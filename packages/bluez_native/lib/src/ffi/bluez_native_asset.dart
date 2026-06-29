// Asset-id anchor for the native build hook.
//
// `hook/build.dart` emits libbluez_nc.so as a CodeAsset whose `name` field
// points at this file. The library is intentionally empty — it exists so
// that `@Native` annotations (if added in the future) can resolve against
// this package's asset id. Today's bindings use DynamicLibrary.open via
// `lib/src/internal/library_loader.dart`.
library;

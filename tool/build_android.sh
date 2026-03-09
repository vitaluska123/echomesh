#!/usr/bin/env sh
set -eu

# Build Rust cdylib for Android ABIs and copy into Flutter jniLibs.
#
# Usage:
#   ./tool/build_android.sh                # debug build
#   ./tool/build_android.sh --release      # release build
#   ./tool/build_android.sh --abi arm64-v8a --abi x86_64
#
# Requirements:
#   - Rust toolchain installed (stable)
#   - Android NDK installed (via Android Studio or sdkmanager)
#   - ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) set to the NDK directory
#   - cargo-ndk installed: `cargo install cargo-ndk`
#
# Output:
#   android/app/src/main/jniLibs/<abi>/libechomesh.so

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
RUST_DIR="$ROOT_DIR/rust"
JNI_LIBS_DIR="$ROOT_DIR/android/app/src/main/jniLibs"
LIB_NAME="libechomesh.so"

MODE="debug"
CARGO_ARGS=""
ABIS_DEFAULT="arm64-v8a armeabi-v7a x86_64"
ABIS="$ABIS_DEFAULT"

log() { printf '%s\n' "$*" >&2; }
die() { log "ERROR: $*"; exit 1; }

usage() {
  cat >&2 <<EOF
Usage: $0 [--release|--debug] [--abi <abi>]...

Builds Rust library for Android and copies to:
  android/app/src/main/jniLibs/<abi>/libechomesh.so

Options:
  --release         Build with --release
  --debug           Build debug (default)
  --abi <abi>       Build only specific ABI(s). Can be repeated.
                    Supported: arm64-v8a, armeabi-v7a, x86_64

Examples:
  $0
  $0 --release
  $0 --abi arm64-v8a --abi x86_64

Env:
  ANDROID_NDK_HOME or ANDROID_NDK_ROOT must point to Android NDK directory.
EOF
}

# Parse args
# You can pass multiple --abi flags; if any are passed, they replace defaults.
USER_SET_ABIS="0"
while [ $# -gt 0 ]; do
  case "$1" in
    --release)
      MODE="release"
      CARGO_ARGS="--release"
      shift
      ;;
    --debug)
      MODE="debug"
      CARGO_ARGS=""
      shift
      ;;
    --abi)
      [ $# -ge 2 ] || die "--abi requires a value"
      if [ "$USER_SET_ABIS" = "0" ]; then
        ABIS="$2"
        USER_SET_ABIS="1"
      else
        ABIS="$ABIS $2"
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1 (use --help)"
      ;;
  esac
done

# Detect NDK path
NDK_HOME="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
[ -n "$NDK_HOME" ] || die "Set ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) to your Android NDK path"
[ -d "$NDK_HOME" ] || die "Android NDK path does not exist: $NDK_HOME"

command -v cargo >/dev/null 2>&1 || die "cargo not found (install Rust)"
command -v cargo-ndk >/dev/null 2>&1 || die "cargo-ndk not found. Install with: cargo install cargo-ndk"

[ -d "$RUST_DIR" ] || die "Rust directory not found: $RUST_DIR"
[ -d "$ROOT_DIR/android/app" ] || die "Flutter android/app not found under: $ROOT_DIR/android/app"

log "==> EchoMesh Rust Android build"
log "Root: $ROOT_DIR"
log "Rust: $RUST_DIR"
log "JNI libs: $JNI_LIBS_DIR"
log "Mode: $MODE"
log "NDK: $NDK_HOME"
log "ABIs: $ABIS"

mkdir -p "$JNI_LIBS_DIR"

# Optional: ensure rust targets exist (ignore failures if rustup not installed)
if command -v rustup >/dev/null 2>&1; then
  # arm64-v8a -> aarch64-linux-android
  # armeabi-v7a -> armv7-linux-androideabi
  # x86_64 -> x86_64-linux-android
  rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android >/dev/null 2>&1 || true
fi

# Build with cargo-ndk and copy outputs into jniLibs.
# Note: Your Cargo.toml must have crate-type including "cdylib".
(
  cd "$RUST_DIR"

  # shellcheck disable=SC2086
  cargo ndk \
    $(for abi in $ABIS; do printf '%s %s ' "-t" "$abi"; done) \
    -o "$JNI_LIBS_DIR" \
    build $CARGO_ARGS
)

# Sanity check: ensure expected libs exist for each ABI
missing=""
for abi in $ABIS; do
  out="$JNI_LIBS_DIR/$abi/$LIB_NAME"
  if [ ! -f "$out" ]; then
    missing="$missing $out"
  else
    log "OK: $out"
  fi
done

[ -z "$missing" ] || die "Missing output libraries:$missing"

log "==> Done."
if [ "$MODE" = "release" ]; then
  log "Next: flutter run -d android --release"
else
  log "Next: flutter run -d android"
fi

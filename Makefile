# EchoMesh Makefile
#
# Convenience targets for Flutter + Rust (FRB) workflow.
#
# Requirements:
# - Flutter SDK available in PATH
# - Rust toolchain (cargo) available in PATH
# - For Android native build: cargo-ndk + ANDROID_NDK_HOME (or ANDROID_NDK_ROOT)
#
# Examples:
#   make linux
#   make win
#   make android
#   make android-release
#   make rust
#   make clean

SHELL := /bin/sh

# ---- Config ----
APP_NAME        ?= echomesh
RUST_DIR        ?= rust
ANDROID_DEVICE  ?=
LINUX_DEVICE    ?= linux
WIN_DEVICE      ?= windows
ANDROID_DEVICE_ID ?= android

# If you want to force specific Android ABIs (space-separated), override:
#   make android ANDROID_ABIS="arm64-v8a x86_64"
ANDROID_ABIS ?= arm64-v8a armeabi-v7a x86_64

# ---- Helpers ----
.PHONY: help
help:
	@echo "EchoMesh targets:"
	@echo ""
	@echo "  General:"
	@echo "    make clean                - flutter clean"
	@echo "    make pub                  - flutter pub get"
	@echo "    make doctor               - flutter doctor -v"
	@echo ""
	@echo "  Rust (host desktop):"
	@echo "    make rust                 - cargo build (debug)"
	@echo "    make rust-release         - cargo build --release"
	@echo ""
	@echo "  Flutter run:"
	@echo "    make linux                - build rust(debug) + flutter run -d linux"
	@echo "    make linux-release        - build rust(release) + flutter run -d linux --release"
	@echo "    make win                  - build rust(debug) + flutter run -d windows"
	@echo "    make win-release          - build rust(release) + flutter run -d windows --release"
	@echo ""
	@echo "  Android (build Rust .so + run Flutter):"
	@echo "    make android              - build android rust(debug) + flutter run -d android"
	@echo "    make android-release      - build android rust(release) + flutter run -d android --release"
	@echo ""
	@echo "  Rust Android only:"
	@echo "    make rust-android         - ./tool/build_android.sh (debug)"
	@echo "    make rust-android-release - ./tool/build_android.sh --release"
	@echo ""
	@echo "Notes:"
	@echo "  - Android native build requires cargo-ndk and ANDROID_NDK_HOME/ANDROID_NDK_ROOT."
	@echo "  - You can pass a specific device id, e.g.: make android ANDROID_DEVICE=emulator-5554"

.PHONY: doctor
doctor:
	flutter doctor -v

.PHONY: pub
pub:
	flutter pub get

.PHONY: clean
clean:
	flutter clean

# ---- Rust (host) ----
.PHONY: rust
rust:
	@echo "==> Rust (debug)"
	cd $(RUST_DIR) && cargo build

.PHONY: rust-release
rust-release:
	@echo "==> Rust (release)"
	cd $(RUST_DIR) && cargo build --release

# ---- Rust (Android) ----
.PHONY: rust-android
rust-android:
	@echo "==> Rust Android (debug) -> android/app/src/main/jniLibs/"
	@# If you want to restrict ABIs, run:
	@#   ./tool/build_android.sh --abi arm64-v8a --abi x86_64
	./tool/build_android.sh $(foreach abi,$(ANDROID_ABIS),--abi $(abi))

.PHONY: rust-android-release
rust-android-release:
	@echo "==> Rust Android (release) -> android/app/src/main/jniLibs/"
	./tool/build_android.sh --release $(foreach abi,$(ANDROID_ABIS),--abi $(abi))

# ---- Flutter run wrappers ----
.PHONY: linux
linux: pub rust
	@echo "==> Flutter run (linux, debug)"
	flutter run -d $(LINUX_DEVICE)

.PHONY: linux-release
linux-release: pub rust-release
	@echo "==> Flutter run (linux, release)"
	flutter run -d $(LINUX_DEVICE) --release

.PHONY: win
win: pub rust
	@echo "==> Flutter run (windows, debug)"
	flutter run -d $(WIN_DEVICE)

.PHONY: win-release
win-release: pub rust-release
	@echo "==> Flutter run (windows, release)"
	flutter run -d $(WIN_DEVICE) --release

.PHONY: android
android: pub rust-android
	@echo "==> Flutter run (android, debug)"
	@if [ -n "$(ANDROID_DEVICE)" ]; then \
		flutter run -d "$(ANDROID_DEVICE)"; \
	else \
		flutter run -d "$(ANDROID_DEVICE_ID)"; \
	fi

.PHONY: android-release
android-release: pub rust-android-release
	@echo "==> Flutter run (android, release)"
	@if [ -n "$(ANDROID_DEVICE)" ]; then \
		flutter run -d "$(ANDROID_DEVICE)" --release; \
	else \
		flutter run -d "$(ANDROID_DEVICE_ID)" --release; \
	fi

# ---- Build artifacts (optional) ----
.PHONY: build-linux
build-linux: pub rust
	flutter build linux

.PHONY: build-linux-release
build-linux-release: pub rust-release
	flutter build linux --release

.PHONY: build-win
build-win: pub rust
	flutter build windows

.PHONY: build-win-release
build-win-release: pub rust-release
	flutter build windows --release

.PHONY: build-android
build-android: pub rust-android
	flutter build apk

.PHONY: build-android-release
build-android-release: pub rust-android-release
	flutter build apk --release

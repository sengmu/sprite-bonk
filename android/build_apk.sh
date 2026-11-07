#!/usr/bin/env bash
# SpriteBonk — reproducible Android release build (Phase B).
# Godot exports the APK unsigned (no release keystore in the preset, by
# design: credentials live only in android/keystore_credentials.txt);
# this script then zipalign-checks and signs it with the project keystore
# and verifies the signature.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-$HOME/workspace/tools/godot/Godot_v4.3-stable_linux.x86_64}"
# apksigner needs a JRE: the system JDK was wiped in a VM replacement;
# the persistent Temurin 17 lives in the workspace (see TOOLS.md).
export PATH="$HOME/workspace/tools/jdk/bin:$PATH"
BT="$HOME/workspace/tools/android-sdk/build-tools/34.0.0"
APK="build/android/SpriteBonk.apk"
mkdir -p build/android

# Editor settings must point at the SDK/JDK (one-time setup, see PHASES.md):
#   export/android/android_sdk_path = $HOME/workspace/tools/android-sdk
#   export/android/java_sdk_path    = /usr/lib/jvm/java-17-openjdk-amd64
# Project setting rendering/textures/vram_compression/import_etc2_astc=true
# is REQUIRED for Android export validation (silent failure without it).

# Export gate (hotfix 2026-10-25): a poisoned global class cache or a
# stray class_name outside scripts/ ships an APK that boots to the
# clear color on device while the editor stays green. Never export
# without it.
bash Test/check_class_cache.sh

"$GODOT" --headless --export-release "Android" "$APK" || true
# Godot exits non-zero because its own signing step finds no keystore;
# the unsigned APK is still written. Fail loudly if it is missing.
test -s "$APK" || { echo "ERROR: export produced no APK"; exit 1; }

PW="$(sed -n 's/^store_password: //p' android/keystore_credentials.txt)"
"$BT/zipalign" -f -p 4 "$APK" build/android/SpriteBonk-aligned.apk
"$BT/apksigner" sign \
  --ks android/spritebonk.keystore \
  --ks-pass "pass:$PW" --key-pass "pass:$PW" \
  --out "$APK" build/android/SpriteBonk-aligned.apk
rm -f build/android/SpriteBonk-aligned.apk
"$BT/apksigner" verify --print-certs "$APK" | head -3
"$BT/aapt2" dump badging "$APK" | grep -E "^package|targetSdkVersion" || true
echo "OK: signed release APK at $APK"

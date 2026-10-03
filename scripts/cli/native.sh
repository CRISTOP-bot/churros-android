#!/usr/bin/env bash
# Compila los binarios nativos de ChurrOS con el NDK de AOSP y los deja en
# prebuilts/bin/<abi>/, que es donde churros_base_init.mk los busca.
#
#   ./scripts/cli/native.sh
#   NDK=~/android/churros/prebuilts/ndk ./scripts/cli/native.sh
#
# No necesita compilar AOSP entero: con el NDK de la release vale. Si no hay
# NDK local, se puede usar el NDK standalone de Google.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"

SRC_DIR="${SRC_DIR:-$HOME/android/churros}"
NDK="${NDK:-$SRC_DIR/prebuilts/ndk}"
API="${API:-34}"
ABIS=(arm64-v8a armeabi-v7a)

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -d "$NDK" ] || die "no encuentro el NDK en $NDK (define NDK=/ruta/al/ndk)"

case "$(uname -m)" in
  x86_64)  HOST_TAG=linux-x86_64 ;;
  aarch64) HOST_TAG=linux-arm64 ;;
  *) die "host no soportado: $(uname -m)" ;;
esac

TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/$HOST_TAG"
[ -d "$TOOLCHAIN" ] || die "toolchain del NDK no encontrada en $TOOLCHAIN"

declare -A TRIPLE=(
  [arm64-v8a]=aarch64-linux-android
  [armeabi-v7a]=armv7a-linux-androideabi
)

info "NDK: $NDK (API $API)"

for abi in "${ABIS[@]}"; do
  t="${TRIPLE[$abi]}"
  cc="$TOOLCHAIN/bin/${t}${API}-clang"
  [ -x "$cc" ] || die "compilador no encontrado: $cc"

  out="$REPO_DIR/prebuilts/bin/$abi"
  mkdir -p "$out"

  for src in churros_lmkd_tuner churros_zramd; do
    "$cc" -O2 -Wall -Wextra -static-libstdc++ \
           -o "$out/$src" "$REPO_DIR/native/$src.c"
    info "  $abi/$src"
  done

  # Los binarios de /system no pueden depender de linker dynamic de la NDK
  "$TOOLCHAIN/bin/llvm-strip" "$out"/* 2>/dev/null || true
done

info "Binarios listos en prebuilts/bin/"
./churros check
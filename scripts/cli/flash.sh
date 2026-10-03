#!/usr/bin/env bash
# Empaqueta y flashea una build existente. Por defecto sólo dice qué haría;
# hay que pasar --yes para que escriba en el dispositivo.
#
#   ./churros flash --lunch churros            # plan
#   ./churros flash --lunch churros --yes      # flashea de verdad
#   ./churros flash --lunch churros --yes --wipe

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SRC_DIR="${SRC_DIR:-$HOME/android/churros}"
TARGET="${TARGET:-aosp_arm64}"
LUNCH=""
BUILD_TYPE="userdebug"
CONFIRM=0
WIPE=0
SKIP_SUPER=0

while [ $# -gt 0 ]; do
  case "$1" in
    --lunch) LUNCH="$2"; shift 2 ;;
    --src) SRC_DIR="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --user) BUILD_TYPE="user"; shift ;;
    --userdebug) BUILD_TYPE="userdebug"; shift ;;
    --yes|-y) CONFIRM=1; shift ;;
    --wipe) WIPE=1; shift ;;
    --no-super) SKIP_SUPER=1; shift ;;
    *) echo "flash: opción desconocida $1" >&2; exit 2 ;;
  esac
done

YELLOW=$'\033[1;33m'
OFF=$'\033[0m'

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "$LUNCH" ] || die "falta --lunch (churros | churros-lite | churros-pro)"
[ -d "$SRC_DIR/out/target/product/$TARGET" ] || die "no hay builds en $SRC_DIR/out/target/product/$TARGET (¿./churros build?)"

BUILD_NAME="${LUNCH}-${TARGET}-${BUILD_TYPE#user}"
IMG_DIR="$SRC_DIR/out/target/product/$TARGET/$BUILD_NAME"
[ -d "$IMG_DIR" ] || die "no encuentro la build $BUILD_NAME en $IMG_DIR"

for tool in adb fastboot; do
  command -v "$tool" >/dev/null 2>&1 || die "falta $tool (android-tools / android-platform-tools)"
done

# Imágenes presentes en la build
IMAGES=()
for img in super.img boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img \
           system.img system_ext.img product.img vendor.img odm.img; do
  [ -f "$IMG_DIR/$img" ] && IMAGES+=("$img")
done

[ "${#IMAGES[@]}" -gt 0 ] || die "la build $BUILD_NAME no contiene imágenes flasheables"

# Orden: primero las de arranque, luego super, luego el resto
ORDERED=()
for img in vbmeta.img vbmeta_system.img boot.img vendor_boot.img dtbo.img super.img; do
  [ -f "$IMG_DIR/$img" ] && ORDERED+=("$img")
done
for img in "${IMAGES[@]}"; do
  skip=0
  for done_img in "${ORDERED[@]}"; do
    [ "$done_img" = "$img" ] && skip=1
  done
  [ "$skip" -eq 0 ] && ORDERED+=("$img")
done

info "Build: $BUILD_NAME"
info "Imágenes a flashear (${#ORDERED[@]}):"
for img in "${ORDERED[@]}"; do
  printf '    %-22s %s\n' "$img" "$(du -h "$IMG_DIR/$img" | cut -f1)"
done

if ! adb devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  info "No hay ningún dispositivo en modo ADB."
fi

if [ "$CONFIRM" -eq 0 ]; then
  echo
  info "Planonly: no se ha escrito nada. Repite con --yes para flashear."
  if [ "$WIPE" -eq 1 ]; then
    printf '        %s--wipe borrara los datos del usuario.%s\n' "$YELLOW" "$OFF"
  fi
  exit 0
fi

[ "$WIPE" -eq 1 ] && { info "Borrando datos del usuario"; adb shell pm clear-all 2>/dev/null || fastboot -w; }

if adb devices | awk 'NR>1 && $2=="device"' | grep -q .; then
  info "Reiniciando a bootloader"
  adb reboot bootloader
  for _ in $(seq 1 30); do
    fastboot devices | grep -q . && break
    sleep 1
  done
fi

fastboot devices | grep -q . || die "fastboot no ve el dispositivo (¿está en bootloader?)"

for img in "${ORDERED[@]}"; do
  if [ "$SKIP_SUPER" -eq 1 ] && [ "$img" = "super.img" ]; then
    info "omitiendo super.img (--no-super)"
    continue
  fi
  info "flasheando $img"
  fastboot flash "$img" "$IMG_DIR/$img"
done

[ "$SKIP_SUPER" -eq 0 ] && info "AVB: si el dispositivo se queda en bootloop, repite con fastboot --disable-verity flash vbmeta vbmeta.img"
info "Reiniciando"
fastboot reboot
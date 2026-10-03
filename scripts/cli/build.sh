#!/usr/bin/env bash
# Compila AOSP para uno de los flavors de ChurrOS.
#
#   ./churros build --lunch churros-lite --tier lowend
#   ./churros build --lunch churros-pro --tier high --release
#   ./churros build --lunch churros --src ~/android/churros --jobs 64

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"

SRC_DIR="${SRC_DIR:-$HOME/android/churros}"
LUNCH=""
BUILD_TYPE="userdebug"
CHURROS_TIER="${CHURROS_TIER:-mid}"
BUILD_TARGET=""
BUILD_JOBS="${BUILD_JOBS:-$(nproc)}"
CHURROS_TARGET="${CHURROS_TARGET:-aosp_arm64}"
SKIP_PATCHES=0
EXTRA_MAKE_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --lunch) LUNCH="$2"; shift 2 ;;
    --src) SRC_DIR="$2"; shift 2 ;;
    --tier) CHURROS_TIER="$2"; shift 2 ;;
    --jobs|-j) BUILD_JOBS="$2"; shift 2 ;;
    --eng) BUILD_TYPE="eng"; shift ;;
    --userdebug) BUILD_TYPE="userdebug"; shift ;;
    --user) BUILD_TYPE="user"; shift ;;
    --debug) BUILD_TARGET="eng"; BUILD_TYPE="eng"; shift ;;
    --target) BUILD_TARGET="$2"; shift 2 ;;
    --make-arg) EXTRA_MAKE_ARGS+=("$2"); shift 2 ;;
    --skip-patches) SKIP_PATCHES=1; shift ;;
    *) echo "build: opción desconocida $1" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

case "$CHURROS_TIER" in
  lowend|mid|high) ;;
  *) die "tier inválido: $CHURROS_TIER (lowend|mid|high)" ;;
esac

[ -d "$SRC_DIR" ] || die "no existe el workspace: $SRC_DIR (¿./churros sync?)"
[ -f "$SRC_DIR/envsetup.sh" ] || die "$SRC_DIR no es un árbol AOSP válido (falta envsetup.sh)"

[ -n "$LUNCH" ] || die "falta --lunch (churros-lite | churros | churros-pro)"

# El producto de ChurrOS vive en este repo; se sincroniza al workspace antes
# de cada build para que los cambios en product/ se reflejen al momento.
info "Sincronizando product/ al workspace"
mkdir -p "$SRC_DIR/product"
rsync -a --delete "$REPO_DIR/product/" "$SRC_DIR/product/"

if [ -d "$REPO_DIR/prebuilts" ]; then
  rsync -a --exclude 'README.md' "$REPO_DIR/prebuilts/" "$SRC_DIR/prebuilts/"
fi

# Parches de plataforma. Se aplican con `repo apply`, que sabe resolver el
# proyecto correcto dentro del multi-repo de AOSP. Un parche que no aplica
# (porque la rama de AOSP cambió) se avisa y se salta: no se rompe el build.
APPLY_PATCHES=1
if [ "$SKIP_PATCHES" -eq 1 ]; then
  APPLY_PATCHES=0
  info "Saltando la aplicación de parches (--skip-patches)"
fi

if [ "$APPLY_PATCHES" -eq 1 ] && compgen -G "$REPO_DIR/patches/*.patch" >/dev/null; then
  info "Aplicando parches de patches/"
  for p in "$REPO_DIR"/patches/*.patch; do
    [ -e "$p" ] || continue
    name=$(basename "$p")
    if (cd "$SRC_DIR" && repo apply --check "$p" >/dev/null 2>&1); then
      (cd "$SRC_DIR" && repo apply "$p") && info "  aplicado $name"
    elif (cd "$SRC_DIR" && repo apply --reverse-check "$p" >/dev/null 2>&1); then
      info "  ya aplicado: $name"
    else
      printf '  \033[1;33m[omitido]\033[0m %s no aplica contra esta rama de AOSP\n' "$name"
    fi
  done
fi

[ -n "$BUILD_TARGET" ] || BUILD_TARGET="$CHURROS_TARGET"

info "Lunch: $LUNCH_${BUILD_TARGET}-${BUILD_TYPE#user}"
info "Jobs: $BUILD_JOBS"
info "cCache: $(ccache -s 2>/dev/null | awk '/Hits|hit rate/ {print}' | head -1 || echo 'no disponible')"

export CHURROS_BUILD_TYPE="$BUILD_TYPE"
export CHURROS_TIER
export CHURROS_TARGET

set +e
(
  cd "$SRC_DIR"
  source envsetup.sh
  setarch "$(uname -m)" lunch "${LUNCH}_${BUILD_TARGET}-${BUILD_TYPE#user}"
  export BUILD_JOBS USE_CCACHE=1
  export CHURROS_BUILD_TYPE="$BUILD_TYPE" CHURROS_TIER="$CHURROS_TIER" CHURROS_TARGET="$CHURROS_TARGET"
  make -j"$BUILD_JOBS" "${EXTRA_MAKE_ARGS[@]}"
)
STATUS=$?
set -e

if [ "$STATUS" -eq 0 ]; then
  ART="$SRC_DIR/out/target/product/$BUILD_TARGET/$LUNCH-$BUILD_TARGET-${BUILD_TYPE#user}"
  info "Build OK -> $ART"
  info "Para flashear: fastboot flash --all <los archivos de $ART>"
else
  die "build falló (código $STATUS); revisa out/error.log o repite con -j$((BUILD_JOBS / 2))"
fi
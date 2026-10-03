#!/usr/bin/env bash
# Sincroniza el árbol de fuentes AOSP con repo(1).
#
#   ./churros sync                 # rama por defecto, tier por defecto
#   ./churros sync --branch android14-release --tier mid
#   ./churros sync --device pixel7 # usa manifests/devices/high.xml

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"
SRC_DIR="${SRC_DIR:-$HOME/android/churros}"

RELEASE_BRANCH="${RELEASE_BRANCH:-android15-release}"
CHURROS_TIER="${CHURROS_TIER:-mid}"
DEVICE_MANIFEST=""
JOBS="${JOBS:-8}"

while [ $# -gt 0 ]; do
  case "$1" in
    --branch) RELEASE_BRANCH="$2"; shift 2 ;;
    --tier)   CHURROS_TIER="$2"; shift 2 ;;
    --device)
      DEVICE_MANIFEST="manifests/devices/$2.xml"
      [ -f "$REPO_DIR/$DEVICE_MANIFEST" ] || {
        echo "sync: no existe el manifest $DEVICE_MANIFEST" >&2
        echo "      disponibles:" >&2
        ls "$REPO_DIR/manifests/devices" >&2
        exit 2
      }
      shift 2 ;;
    --src)    SRC_DIR="$2"; shift 2 ;;
    --jobs|-j) JOBS="$2"; shift 2 ;;
    *) echo "sync: opción desconocida $1" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

command -v repo >/dev/null 2>&1 || { echo "falta 'repo' (instala con ./churros env)" >&2; exit 1; }

MANIFESTS=("$REPO_DIR/manifests/default.xml" "$REPO_DIR/manifests/churros-opt.xml")
case "$CHURROS_TIER" in
  lowend) MANIFESTS+=("$REPO_DIR/manifests/devices/lowend.xml") ;;
  mid)    MANIFESTS+=("$REPO_DIR/manifests/devices/mid.xml") ;;
  high)   MANIFESTS+=("$REPO_DIR/manifests/devices/high.xml") ;;
  *) echo "tier inválido: $CHURROS_TIER (lowend|mid|high)" >&2; exit 2 ;;
esac
if [ -n "$DEVICE_MANIFEST" ]; then
  MANIFESTS+=("$REPO_DIR/$DEVICE_MANIFEST")
  info "Device tree: $DEVICE_MANIFEST"
fi

info "Rama AOSP: $RELEASE_BRANCH"
info "Gama: $CHURROS_TIER"
info "Destino: $SRC_DIR"

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

info "Inicializando repo"
repo init -u "$REPO_DIR/manifests/default.xml" \
          -b "android-${RELEASE_BRANCH#android-}" \
          --depth=1

for m in "${MANIFESTS[@]:1}"; do
  info "Añadiendo manifest $(basename "$m")"
  repo init -m "${m#$REPO_DIR/}" --depth=1
done

info "Sincronizando (esto descarga ~250 GB la primera vez)"
repo sync -c -j"$JOBS" --no-clone-bundle --current-branch --fail-fast

info "Copiando el árbol de producto de ChurrOS al workspace"
mkdir -p "$SRC_DIR/product"
for d in common flavors; do
  rm -rf "$SRC_DIR/product/$d"
  cp -a "$REPO_DIR/product/$d" "$SRC_DIR/product/$d"
done
mkdir -p "$SRC_DIR/prebuilts/bin"
cp -a "$REPO_DIR/prebuilts/." "$SRC_DIR/prebuilts/" 2>/dev/null || true

info "Estableciendo enlace de desarrollo"
ln -sfn "$REPO_DIR" "$SRC_DIR/churros-src"

cat <<EOF

Árbol sincronizado en $SRC_DIR

  ./churros build --lunch churros-lite --src $SRC_DIR
EOF
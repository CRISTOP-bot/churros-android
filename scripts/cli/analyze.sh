#!/usr/bin/env bash
# Analiza el peso y el tiempo de una build existente.
#
#   ./churros analyze                      # resumen
#   ./churros analyze --lunch churros      # una build concreta
#   ./churros analyze --compare            # esta build vs la anterior
#   ./churros analyze --big 30             # los 30 ficheros mayores de /system
#
# No compila nada: sólo lee out/. Es la herramienta de referencia para saber si
# un ajuste de optimización ha servido de algo.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

SRC_DIR="${SRC_DIR:-$HOME/android/churros}"
LUNCH=""
BUILD_TYPE="userdebug"
TARGET=""
BIG=15
COMPARE=0
MOUNTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --lunch) LUNCH="$2"; shift 2 ;;
    --src) SRC_DIR="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --user) BUILD_TYPE="user"; shift ;;
    --userdebug) BUILD_TYPE="userdebug"; shift ;;
    --big) BIG="$2"; shift 2 ;;
    --compare) COMPARE=1; shift ;;
    --mounts) MOUNTS=1; shift ;;
    *) echo "analyze: opción desconocida $1" >&2; exit 2 ;;
  esac
done

GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[1;36m'; DIM=$'\033[2m'; OFF=$'\033[0m'
info() { printf '%s==>%s %s\n' "$BLUE" "$OFF" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YELLOW" "$OFF" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$YELLOW" "$OFF" "$*" >&2; exit 1; }

human() {
  # human <bytes> -> "1.2 GiB"
  awk -v b="${1:-0}" 'BEGIN{
    split("B KiB MiB GiB TiB", u, " "); i = 1
    while (b >= 1024 && i < 5) { b /= 1024; i++ }
    printf (i == 1 ? "%d %s\n" : "%.1f %s\n"), b, u[i]
  }'
}

size_of() { [ -f "$1" ] && stat -c %s "$1" || echo 0; }

# ---------------------------------------------------------------------------
# Localiza la build
# ---------------------------------------------------------------------------
PRODUCT_DIR="$SRC_DIR/out/target/product"
[ -d "$PRODUCT_DIR" ] || die "no hay builds en $PRODUCT_DIR (¿./churros build?)"

if [ -z "$TARGET" ]; then
  TARGET=$(ls -1 "$PRODUCT_DIR" 2>/dev/null | head -1)
  [ -n "$TARGET" ] || die "$PRODUCT_DIR está vacío"
fi

if [ -n "$LUNCH" ]; then
  BUILD_DIR="$PRODUCT_DIR/$TARGET/${LUNCH}-${TARGET}-${BUILD_TYPE#user}"
else
  BUILD_DIR=$(find "$PRODUCT_DIR/$TARGET" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)
  [ -n "$BUILD_DIR" ] || die "no encuentro builds para el target $TARGET"
  LUNCH=$(basename "$BUILD_DIR")
  LUNCH=${LUNCH%-${TARGET}-*}
fi

[ -d "$BUILD_DIR" ] || die "no existe la build $BUILD_DIR"

echo "${BLUE}ChurrOS Android — análisis${OFF}"
info "Build: $LUNCH  ($(basename "$BUILD_DIR"))"
[ -f "$SRC_DIR/out/churros-build-stats.tsv" ] && info "Stats: $SRC_DIR/out/churros-build-stats.tsv"
echo

# ---------------------------------------------------------------------------
# 1. Tiempo de compilación (del histórico que escribe build.sh)
# ---------------------------------------------------------------------------
STATS="$SRC_DIR/out/churros-build-stats.tsv"
if [ -f "$STATS" ]; then
  info "Tiempo de compilación (últimas 10)"
  printf '  %-18s %-16s %-8s %-9s %-5s %-9s %s\n' \
    "FECHA" "PRODUCTO" "RESULTADO" "DURACIÓN" "JOBS" "HIT CCACHE" "AJUSTES"
  tail -10 "$STATS" | while IFS=$'\t' read -r date lunch target type result secs jobs hits sha dex opt; do
    d=$(( ${secs:-0} / 3600 ))h$(( ${secs:-0} % 3600 / 60 ))m
    printf '  %-18s %-16s %-8s %-9s %-5s %-9s %s\n' \
      "$date" "$lunch" "$result" "$d" "$jobs" "${hits:-?}" "dex=${dex:-?} -O${opt:-?}"
  done
  echo
else
  warn "sin histórico: compila una vez con ./churros build para generar out/churros-build-stats.tsv"
  echo
fi

# ---------------------------------------------------------------------------
# 2. Peso de las imágenes
# ---------------------------------------------------------------------------
info "Peso de las imágenes"
total=0
printf '  %-24s %12s\n' "IMAGEN" "TAMAÑO"
for img in system.img system_ext.img product.img odm.img vendor.img \
           super.img boot.img vendor_boot.img dtbo.img vbmeta.img \
           system_dtb.img init_boot.img; do
  s=$(size_of "$BUILD_DIR/$img")
  if [ "$s" -gt 0 ]; then
    printf '  %-24s %12s\n' "$img" "$(human "$s")"
    total=$((total + s))
  fi
done
printf '  %-24s %12s\n' "${DIM}TOTAL${OFF}" "$(human "$total")"
echo

if [ "$MOUNTS" -eq 1 ] && [ -f "$BUILD_DIR/system.img" ]; then
  SIMG=$(find "$SRC_DIR/out/host" -name simg2img -type f 2>/dev/null | head -1)
  RAW="$BUILD_DIR/system.raw.analyze"
  if [ -n "$SIMG" ]; then
    info "Convirtiendo system.img para inspeccionarlo"
    "$SIMG" "$BUILD_DIR/system.img" "$RAW"
    if command -v debugfs >/dev/null 2>&1; then
      debugfs -R "stats" "$RAW" 2>/dev/null | grep -iE "Block count|Free blocks|Block size" | sed 's/^/    /'
    fi
    rm -f "$RAW"
  else
    warn "sin simg2img; no se puede inspeccionar system.img"
  fi
  echo
fi

# ---------------------------------------------------------------------------
# 3. Qué ocupa el sitio dentro de /system
# ---------------------------------------------------------------------------
info "Ficheros mayores en $LUNCH (limitado a $BIG)"
found=0
if command -v 7z >/dev/null 2>&1 && [ -f "$BUILD_DIR/system.img" ]; then
  TMPD=$(mktemp -d)
  # 7z no lee imágenes sparse: primero las convertimos si hay simg2img
  SRC_IMG="$BUILD_DIR/system.img"
  SIMG=$(find "$SRC_DIR/out/host" -name simg2img -type f 2>/dev/null | head -1)
  if [ -n "$SIMG" ]; then
    "$SIMG" "$SRC_IMG" "$TMPD/system.raw" 2>/dev/null && SRC_IMG="$TMPD/system.raw"
  fi
  if 7z l -ba "$SRC_IMG" >"$TMPD/list.txt" 2>/dev/null; then
    awk '{ size = $(NF-2); name = $NF }
         size ~ /^[0-9]+$/ && size > 1048576 { printf "%12d  %s\n", size, name }' "$TMPD/list.txt" \
      | sort -rn | head -"$BIG" | while IFS=$'\t' read -r bytes name; do
        printf '  %12s  %s\n' "$(human "$bytes")" "$name"
      done
    found=1
  fi
  rm -rf "$TMPD"
fi

if [ "$found" -eq 0 ]; then
  # Fallback: los intermedios de lo que se instala dan una idea fiable
  OBJ="$BUILD_DIR/obj"
  if [ -d "$OBJ" ]; then
    warn "sin 7z para inspeccionar la imagen; se listan los intermedios"
    find "$OBJ/ALL_APPS" "$OBJ/APEX" "$OBJ/APPS" -type f -size +2M 2>/dev/null \
      -printf '%s\t%p\n' | sort -rn | head -"$BIG" \
      | while IFS=$'\t' read -r bytes name; do
          printf '  %12s  %s\n' "$(human "$bytes")" "${name#$BUILD_DIR/}"
        done
  else
    warn "no hay obj/ para analizar"
  fi
fi
echo

# ---------------------------------------------------------------------------
# 4. Comparación con la build anterior
# ---------------------------------------------------------------------------
if [ "$COMPARE" -eq 1 ]; then
  info "Comparando con la build anterior"
  prev=$(ls -1d "$PRODUCT_DIR/$TARGET"/*/ 2>/dev/null | grep -v "$(basename "$BUILD_DIR")/\\$" | tail -1)
  if [ -z "$prev" ]; then
    warn "sólo hay una build de $TARGET; no hay con qué comparar"
  else
    printf '  %-24s %12s %12s %10s\n' "IMAGEN" "ANTERIOR" "ACTUAL" "CAMBIO"
    for img in system.img super.img vendor.img boot.img vendor_boot.img; do
      a=$(size_of "${prev}$img"); b=$(size_of "$BUILD_DIR/$img")
      [ "$a" -eq 0 ] && continue
      pct=$(awk -v a="$a" -v b="$b" 'BEGIN{ if (a==0) {print "n/d"} else {printf "%+.1f%%", (b-a)*100/a} }')
      printf '  %-24s %12s %12s %10s\n' "$img" "$(human "$a")" "$(human "$b")" "$pct"
    done
  fi
  echo
fi

info "Siguiente paso"
echo "  Los APKs más pesados son los candidatos naturales a PRODUCT_PACKAGES -= ;"
echo "  ver docs/10-peso-y-tiempos.md para qué quita cada cosa y cuánto pesa."
echo "  Después de tocar el producto, rebuild y repite: ./churros analyze --compare"
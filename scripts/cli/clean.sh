#!/usr/bin/env bash
# Limpia artefactos de build.
#
#   ./churros clean          # borra out/ del workspace
#   ./churros clean --full   # además borra intermediates de Soong y ccache

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"

SRC_DIR="${SRC_DIR:-$HOME/android/churros}"
FULL=0
[ "${1:-}" = "--full" ] && FULL=1

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }

if [ -d "$SRC_DIR/out" ]; then
  if [ "$FULL" -eq 1 ]; then
    info "Borrando intermediates (build completo desde cero)"
    rm -rf "$SRC_DIR/out/soong" "$SRC_DIR/out/apex" "$SRC_DIR/out/obj" "$SRC_DIR/out/.module_paths"
  else
    info "Borrando out/"
    rm -rf "$SRC_DIR/out"
  fi
else
  info "No hay out/ en $SRC_DIR"
fi

if [ "$FULL" -eq 1 ]; then
  if command -v ccache >/dev/null 2>&1; then
    info "Limpiando ccache"
    ccache -C >/dev/null 2>&1 || true
  fi
  info "Limpiando product/ copiado al workspace"
  rm -rf "$SRC_DIR/product"
fi

info "Hecho"
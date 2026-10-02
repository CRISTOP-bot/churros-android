#!/usr/bin/env bash
# Comprueba que este host puede compilar AOSP.
# No modifica nada.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

OK=0
WARN=0
FAIL=0

pass() { printf '  \033[1;32mOK\033[0m    %s\n' "$*"; OK=$((OK + 1)); }
warn() { printf '  \033[1;33mAVISO\033[0m %s\n' "$*"; WARN=$((WARN + 1)); }
fail() { printf '  \033[1;31mFALLO\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }

echo "ChurrOS Android — doctor"

echo
echo "Hardware"
CORES=$(nproc)
[ "$CORES" -ge 8 ] && pass "$CORES cores" || warn "$CORES cores (recomendado: 16+)"
RAM_GB=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo) / 1024 / 1024 ))
[ "$RAM_GB" -ge 32 ] && pass "${RAM_GB} GB RAM" || fail "${RAM_GB} GB RAM (mínimo 32 GB, recomendado 64)"
DISK_GB=$(( $(df --output=avail -BG "$HOME" | tail -1 | tr -dc '0-9') ))
[ "$DISK_GB" -ge 300 ] && pass "${DISK_GB} GB libres" || fail "${DISK_GB} GB libres (se necesitan ~300 GB)"

echo
echo "Herramientas"
for t in git make clang lld python3 rsync bc ccache zip zstd repo; do
  if command -v "$t" >/dev/null 2>&1; then pass "$t"; else fail "$t ausente"; fi
done

if command -v clang >/dev/null 2>&1; then
  V=$(clang --version | head -1)
  echo "         $V"
fi

echo
echo "Sistema"
[ "$(uname -s)" = "Linux" ] && pass "$(uname -s) $(uname -r)" || fail "no es Linux"
if [ -f /etc/os-release ]; then
  echo "         $(awk -F= '/^NAME=/ {print $2}' /etc/os-release | tr -d '"')"
fi
case "$(ldd --version 2>&1 | head -1)" in
  *GLIBC_2.3[4-9]*) pass "glibc $(ldd --version | head -1 | awk '{print $NF}')" ;;
  *) warn "glibc antiguo: AOSP moderna requiere 2.34+" ;;
esac

FD=$(ulimit -n)
[ "$FD" -ge 4096 ] && pass "ulimit -n = $FD" || warn "ulimit -n = $FD (AOSP pide 8192)"

echo
printf 'Resumen: %d OK, %d avisos, %d fallos\n' "$OK" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
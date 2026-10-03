#!/usr/bin/env bash
# Mediciones sobre el dispositivo conectado por adb. Sin dependencias extra:
# sólo adb shell. Pensado para comparar un ajuste contra el mismo commit.
#
#   ./scripts/measure/boot.sh       tiempo de arranque (boot_progress_enable_screen)
#   ./scripts/measure/idle.sh [h]   consumo en reposo durante h horas (por defecto 2)
#   ./scripts/measure/mem.sh        instantánea de memoria
#   ./scripts/measure/gfx.sh <pkg>  frames de una app

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

adb_() { adb shell "$@"; }

require_device() {
  command -v adb >/dev/null 2>&1 || die "falta adb"
  adb devices | awk 'NR>1 && $2=="device"' | grep -q . || die "no hay dispositivo conectado"
}

# Espera a que el boot termine y devuelve los milisegundos desde el arranque.
boot_ms() {
  adb logcat -b events -d 2>/dev/null \
    | awk '/boot_progress_enable_screen/ {ms = $(NF-1) + 0} END {print ms}'
}

cmd_boot() {
  require_device
  info "Esperando a que termine el arranque..."
  adb wait-for-device
  # El evento sólo se ve si logcat no se ha limpiado; espera activa a la señal.
  for _ in $(seq 1 120); do
    MS=$(boot_ms)
    [ -n "$MS" ] && [ "$MS" -gt 0 ] 2>/dev/null && break
    sleep 2
  done
  MS=$(boot_ms)
  if [ -z "${MS:-}" ] || [ "${MS:-0}" -eq 0 ]; then
    die "no encuentro boot_progress_enable_screen (¿el buffer events se limpió al arrancar?)"
  fi
  printf 'Arranque hasta pantalla encendida: %d ms (%.1f s)\n' "$MS" "$(echo "$MS" / 1000 | bc -l)"
  adb_ getprop ro.churros.tier | sed 's/^/tier: /'
  adb_ cat /proc/swaps | sed 's/^/swaps: /'
}

cmd_idle() {
  require_device
  HOURS="${1:-2}"
  info "Midiendo consumo en reposo durante $HOURS h (pantalla apagada)"
  adb shell dumpsys batterystats --reset >/dev/null
  adb_ input keyevent KEYCODE_SLEEP
  LEVEL_START=$(adb_ dumpsys battery | awk '/level/ {print $2; exit}')
  printf 'Battery level inicial: %s%%\n' "$LEVEL_START"
  sleep "${HOURS}h"
  LEVEL_END=$(adb_ dumpsys battery | awk '/level/ {print $2; exit}')
  printf 'Battery level final:   %s%%\n' "$LEVEL_END"
  info "Consumo: $(echo "scale=3; ($LEVEL_START - $LEVEL_END) / $HOURS" | bc -l) %%/h"
  adb shell dumpsys batterystats | grep -E '^(  )?Wake lock|Wifi|SCREEN' | head -20
}

cmd_mem() {
  require_device
  info "Memoria"
  adb_ cat /proc/meminfo | grep -E 'MemTotal|MemAvailable|Cached|Slab|SReclaimable|SwapTotal|SwapFree'
  echo
  adb shell dumpsys meminfo | grep -E 'Total RAM|Free RAM|Used RAM|Lost RAM|Zygote' | head
  echo
  info "zRAM"
  adb_ cat /sys/block/zram0/mm_stat 2>/dev/null || info "sin zram"
  adb_ cat /sys/block/zram0/comp_algorithm 2>/dev/null || true
  echo
  adb_ cat /proc/sys/vm/pressure_low /proc/sys/vm/pressure_high 2>/dev/null
}

cmd_gfx() {
  require_device
  PKG="${1:-com.android.systemui}"
  info "Reseteando framestats de $PKG"
  adb_ dumpsys gfxinfo "$PKG" reset >/dev/null
  info "Abre la app en el dispositivo durante 30 s y vuelve aquí"
  sleep 30
  adb shell dumpsys gfxinfo "$PKG" framestats | tail -20
}

case "${1:-}" in
  boot) cmd_boot ;;
  idle) shift; cmd_idle "${1:-2}" ;;
  mem)  cmd_mem ;;
  gfx)  shift; cmd_gfx "${1:-}" ;;
  *) die "uso: $(basename "$0") boot|idle [horas]|mem|gfx <paquete>" ;;
esac
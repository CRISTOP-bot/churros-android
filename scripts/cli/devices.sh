#!/usr/bin/env bash
# Lista los dispositivos/flavors soportados y el estado de sus device trees.
# No necesita el árbol AOSP.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"

GREEN=$'\033[1;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[1;36m'; BOLD=$'\033[1m'; OFF=$'\033[0m'

echo "${BOLD}ChurrOS Android — dispositivos${OFF}"
echo

printf '%-14s %-9s %-34s %s\n' "FLAVOR" "TIER" "DEVICE TREE" "ESTADO"
printf '%-14s %-9s %-34s %s\n' "churros-lite" "lowend" "manifests/devices/lowend.xml" "plantilla"
printf '%-14s %-9s %-34s %s\n' "churros" "mid" "manifests/devices/mid.xml" "plantilla"
printf '%-14s %-9s %-34s %s\n' "churros-pro" "high" "manifests/devices/high.xml" "plantilla"
printf '%-14s %-9s %-34s %s\n' "churros-taipei" "mid" "manifests/devices/taipei.xml" "sin portar"

echo
echo "${BLUE}Dispositivos declarados en los manifests:${OFF}"
for m in "$REPO_DIR"/manifests/devices/*.xml; do
  name=$(basename "$m" .xml)
  echo "  $name"
  while IFS= read -r line; do
    path=$(printf '%s' "$line" | sed -n 's/.*path="\([^"]*\)".*/\1/p')
    [ -n "$path" ] && printf '    %b%s%b\n' "$BOLD" "$path" "$OFF"
  done <"$m"
done

echo
echo "${YELLOW}moto g55 5G (taipei)${OFF}: antes de tocar nada, lee"
echo "  ${BLUE}docs/08-moto-g55-taipei.md${OFF}. El bloqueante no es el codigo:"
echo "  Motorola no da claves de unlock para ese modelo."
echo
echo "${YELLOW}Nota${OFF}: los device trees son punteros a repos externos. Que un"
echo "manifest exista no significa que el repositorio de al lado tenga el"
echo "dispositivo; revisa ${BLUE}docs/04-dispositivos.md${OFF} antes de flashear."
echo
echo "Para usar uno:"
echo "  ./churros sync --device mid --tier mid"
echo "  ./churros build --lunch churros --tier mid"
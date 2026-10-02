#!/usr/bin/env bash
# Instala las dependencias del host para compilar AOSP.
# Pensado para Arch Linux (usa pacman); en Ubuntu úsalo sólo como referencia.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"

PACKAGES=(
  git
  gnupg
  flex
  bison
  gperf
  build-essential
  zip
  zlib
  zstd
  lz4
  libssl-dev
  libncurses-dev
  lib32z1
  lib32ncurses5
  lib32readline8
  lib32z1-dev
  bc
  ccache
  clang
  llvm
  lld
  make
  repo
  ccache
  openjdk-17-jdk
  procps-ng
  python
  python2
  rsync
  bc
)

info() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }

if ! command -v pacman >/dev/null 2>&1; then
  warn "Este script espera pacman (Arch). Los paquetes están documentados en docs/01-entorno-arch.md"
  exit 1
fi

info "Instalando paquetes base del sistema (necesita sudo)"
sudo pacman -S --needed --noconfirm "${PACKAGES[@]}"

info "Limitando el número de processos de git (evita 'too many open files')"
git config --global pack.threads 4
git config --global core.packedGitLimit 32m
git config --global core.packedGitWindowSize 32m

info "Ajustando file descriptor limit"
CURRENT=$(ulimit -n)
if [ "$CURRENT" != "unlimited" ] && [ "$CURRENT" -lt 8192 ]; then
  warn "ulimit -n = $CURRENT; AOSP recomienda 8192 o más"
  warn "Añade 'DefaultLimitNOFILE=16384' a /etc/systemd/system.conf si ves errores de git"
fi

info "Habilitando ccache para compilaciones incrementales"
sudo mkdir -p /etc/ccache.conf.d
printf 'max_size = 20G\ncompression = true\n' | sudo tee /etc/ccache.conf.d/churros.conf >/dev/null
sudo systemctl enable ccache.service 2>/dev/null || true

cat <<EOF

Entorno listo. Siguiente paso:

  ./churros sync                  # descarga el árbol (250 GB, necesita red)
  ./churros build --lunch churros-lite
EOF
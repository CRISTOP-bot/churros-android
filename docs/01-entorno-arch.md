# 01 — Entorno de build en Arch Linux

AOSP está pensado para Ubuntu 22.04, pero compila en Arch. Lo que hay que
ajustar es el nombre de las librerías y el shell por defecto de `bash` (Arch
usa 5.2+, AOSP espera 4.x con algunas diferencias menores en `sh`).

## Paquetes

```bash
sudo pacman -S --needed git gnupg flex bison gperf build-essential \
  zip zlib zstd lz4 libssl-dev libncurses-dev bc ccache clang llvm lld \
  make repo openjdk-17-jdk procps-ng python rsync
```

O directamente: `./churros env`.

## Limit del sistema

AOSP usa git con muchísimos ficheros en paralelo. Con el límite por defecto de
Arch (1024) falla con `Too many open files`:

```bash
echo 'DefaultLimitNOFILE=16384' | sudo tee -a /etc/systemd/system.conf
# cierra sesión o ejecuta: sudo systemctl daemon-reexec
```

## ccache

```bash
sudo mkdir -p /etc/ccache.conf.d
printf 'max_size = 20G\ncompression = true\n' | sudo tee /etc/ccache.conf.d/churros.conf
sudo systemctl enable ccache
```

AOSP detecta `ccache` si está en el PATH, pero es más rápido exportarlo:

```bash
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache
```

## Ninja y `sh`

Para evitar problemas con `dash` como `/bin/sh`, la imagen de Ubuntu usa bash.
En Arch esto funciona, pero conviene exportarlo:

```bash
export BUILD_BROKEN_SHELL_SYMLINKS=1
```

Sólo si aparecen errores raros de `mk` o `soong`.

## Memoria y swap

Con 32 GB de RAM basta, pero el enlazador y `ninja` pueden llegar a comerse
varios GB por link grande. Sin swap el OOM killer puede matar el build:

```bash
sudo fallocate -l 32G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

## Almacenamiento

Usa NVMe o un disco con la partición de 250 GB+ montada en `$HOME/android`. Un
build en disco mecánico puede triplicar el tiempo de enlace.

```bash
mkdir -p ~/android
# Si el workspace va en otro disco:
export SRC_DIR=/mnt/nvme/churros
```

## Verificación

```bash
./churros doctor
```

## Máquina remota de build

Si este host no da la talla, lo normal es compilar en un servidor y bajar los
artefactos. El flujo del proyecto ya lo contempla:

```bash
# En el servidor
./churros sync && ./churros build --lunch churros-pro

# Local: bajar out/target/product/<target>/
rsync -avP servidor:~/android/churros/out/target/product/aosp_arm64/ ./out/
```
# ChurrOS Android

ROM Android basada en AOSP puro, optimizada y organizada en tres gamas para
cubrir dispositivos viejos, medios y nuevos con la misma base de código.

| Flavor | Gama | Dispositivos objetivo | RAM |
|---|---|---|---|
| `churros-lite` | Baja | 2015-2019, Snapdragon 4xx/6xx | 1-2 GB |
| `churros` | Media | 2019-2022, SD 7xx / 8 Gen 1 | 4-6 GB |
| `churros-pro` | Alta | 2022+, Tensor G2/G3, SD 8 Gen 2/3 | 8-12 GB |

## Qué es y qué no es

- **Es**: AOSP vanilla (sin GAPPS, sin telemetría de terceros), un árbol de
  producto propio, tres flavors, una capa de init de tuning, dos binarios
  nativos con NDK, y scripts para sincronizar y compilar en Arch Linux.
- **No es todavía**: una ROM instalable. Falta el device tree del dispositivo
  concreto (kernel, blobs de vendor, bootloader) y un build completo, que
  requiere una máquina de build dedicada.

## Requisitos del host

| | Mínimo | Recomendado |
|---|---|---|
| CPU | 8 cores | 32-64 cores |
| RAM | 32 GB | 64-128 GB |
| Disco | 300 GB NVMe | 500 GB NVMe |
| OS | Linux (glibc 2.34+) | Ubuntu 22.04 LTS / Arch |

`./churros doctor` dice si el host vale. **Una máquina de escritorio normal no
sirve**: un build completo de AOSP tarda entre 4 y 12 horas.

## Uso

```bash
./churros doctor                    # ¿puede este host compilar?
./churros env                       # dependencias del host (Arch)
./churros sync --tier mid           # descarga el árbol (~250 GB)
./churros native                    # binarios NDK (native/ -> prebuilts/)
./churros build --lunch churros     # compila
./churros check                     # comprobaciones estáticas del repo
./churros clean --full              # borra out/ y ccache
```

Ejemplos de iteración:

```bash
# build rápido de un solo módulo
./churros build --lunch churros --make-arg m SystemUI

# gama baja, sin parches de plataforma
./churros build --lunch churros-lite --tier lowend --skip-patches -j32
```

## Documentación

| Documento | Contenido |
|---|---|
| [docs/01-entorno-arch.md](docs/01-entorno-arch.md) | Preparar el host para compilar AOSP |
| [docs/02-arquitectura.md](docs/02-arquitectura.md) | Cómo encaja cada pieza |
| [docs/03-optimizacion.md](docs/03-optimizacion.md) | Cada ajuste y su porqué |
| [docs/04-dispositivos.md](docs/04-dispositivos.md) | Añadir un dispositivo nuevo |
| [docs/05-flashing.md](docs/05-flashing.md) | Compilar, flashear y recuperar |
| [docs/06-roadmap.md](docs/06-roadmap.md) | Estado real y decisiones pendientes |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Dónde va cada tipo de cambio |

## Layout

```
churros                 dispatcher CLI
manifests/              AOSP + fragmento de optimización + device trees por gama
product/common/         producto base común a los tres flavors
product/flavors/        churros-lite | churros | churros-pro
native/                 fuentes C de los binarios de runtime (NDK)
prebuilts/bin/<abi>/    binarios generados por ./churros native
patches/                parches a la plataforma AOSP (repo apply)
scripts/cli/            env, sync, build, native, doctor, check, clean
.github/workflows/      CI con ./churros check
```

## Optimización en resumen

Todo lo que se toca está justificado en
[docs/03-optimizacion.md](docs/03-optimizacion.md): flags nativos (`-O3`,
ThinLTO), R8 en modo completo, recorte de apps de AOSP, props de ART y
`ro.config.low_ram` en gama baja, y una capa de init que ajusta I/O, zRAM con
zstd, vm tuning, umbrales de lmkd y governor de CPU.

Lo que deliberadamente **no** se hace: parchear el kernel en caliente, tocar
flags de CTS/VTS, ni nada que rompa la estabilidad del arranque.

## Estado

| Componente | Estado |
|---|---|
| Manifests AOSP + por gama | hecho |
| Árbol de producto (3 flavors) | hecho |
| Capa de init / props de optimización | hecho |
| Fuentes nativas + script de build NDK | hecho |
| Scripts de sync/build/native/check | hecho |
| CI | hecho |
| Device trees concretos | pendiente |
| Primer build completo | pendiente de máquina de build |

Ver [docs/06-roadmap.md](docs/06-roadmap.md).

## Licencia

El código de este repo es Apache-2.0 ([LICENSE](LICENSE)). AOSP conserva sus
propias licencias; cualquier distro derivada debe cumplir también los avisos
de cada componente de la plataforma.
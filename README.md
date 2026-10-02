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
  producto propio, tres flavors, una capa de init de tuning, y scripts para
  sincronizar y compilar en Arch Linux.
- **No es todavía**: una ROM instalable. Falta el device tree del dispositivo
  concreto (kernel, blobs de vendor, bootloader) y compilar el árbol AOSP, que
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
./churros doctor                 # ¿puede este host compilar?
./churros env                    # dependencias del host (Arch)
./churros sync --tier mid        # descarga el árbol (~250 GB)
./churros build --lunch churros  # compila
./churros check                  # comprobaciones estáticas del repo
```

## Documentación

- [docs/01-entorno-arch.md](docs/01-entorno-arch.md) — preparar el host
- [docs/02-arquitectura.md](docs/02-arquitectura.md) — cómo encaja todo
- [docs/03-optimizacion.md](docs/03-optimizacion.md) — cada ajuste y su porqué
- [docs/04-dispositivos.md](docs/04-dispositivos.md) — añadir un dispositivo

## Estado

| Componente | Estado |
|---|---|
| Manifests AOSP + por gama | hecho |
| Árbol de producto (3 flavors) | hecho |
| Capa de init / props de optimización | hecho |
| Scripts de sync/build/check | hecho |
| Device trees concretos | pendiente |
| Binarios NDK (lmkd tuner, zramd) | pendiente de compilar |
| Primer build completo | pendiente de máquina de build |
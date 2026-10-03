# 02 — Arquitectura

## Capas

```
manifests/
  default.xml            AOSP puro de una release concreta
  churros-opt.xml        proyectos extra de bajo riesgo
  devices/lowend.xml     device tree gama baja
  devices/mid.xml        device tree gama media
  devices/high.xml       device tree gama alta

product/
  common/
    AndroidProducts.mk   identidad común (se incluye desde los flavors)
    churros_base.mk      producto base: hereda AndroidDefaults
    churros_base_vars.mk flags de compilación, props, tuning por gama
    churros_base_init.mk copia init rc + binarios de runtime a la imagen
    init/churros.rc      tuning de runtime (memoria, I/O, governor)
  flavors/
    churros-lite/        device.mk + product.mk
    churros/             device.mk + product.mk
    churros-pro/         device.mk + product.mk

scripts/cli/
  env.sh      dependencias del host
  sync.sh     repo init + repo sync + copia de product/
  build.sh    lunch + make, con aplicación de parches
  native.sh   compila native/*.c con el NDK -> prebuilts/bin/<abi>/
  check.sh    comprobaciones estáticas
  doctor.sh   requisitos del host
  clean.sh    limpieza

native/                 fuentes C de los binarios de runtime
  churros_lmkd_tuner.c  umbrales de presión de memoria (gama baja)
  churros_zramd.c       registra zRAM con zstd y activa el swap
prebuilts/bin/<abi>/    binarios que product/common/churros_base_init.mk copia
                        a /system/bin
patches/                parches a la plataforma, aplicados con `repo apply`
```

## Flujo de un cambio

1. Editas `product/...` o `manifests/...` en este repo.
2. `./churros build --lunch churros-lite` hace `rsync` de `product/` al
   workspace y compila. No hace falta re-sincronizar 250 GB.
3. Si el cambio es de plataforma (no de producto), va como parche en
   `patches/*.patch`; `build.sh` los aplica con `repo apply` antes de compilar.
   Un parche que ya está aplicado se reconoce y se salta; uno que no aplica
   contra la rama actual se avisa y se omite, para no romper el build. Con
   `--skip-patches` se desactivan.
4. Los cambios en `native/` necesitan `./churros native` para regenerar los
   binarios; `build.sh` los copia al workspace, pero no los recompila.

## Por qué `CHURROS_TIER` es una variable de entorno

El mismo árbol de producto sirve para las tres gamas. `build.sh` exporta
`CHURROS_TIER`, `CHURROS_BUILD_TYPE` y `CHURROS_TARGET`, y
`churros_base_vars.mk` los lee con `ifeq`. Así no hay que mantener tres copias
de los ajustes: sólo la rama de "gama baja" y la de "gama alta" divergen, y
todo lo demás se hereda una sola vez.

El rc de init distingue gamas en runtime con la prop
`ro.churros.tier`, que el flavor declara en su `device.mk`.

## Dónde tocar para cambiar el comportamiento

| Quiero… | Archivo |
|---|---|
| Añadir/quitar una app | `churros_base_vars.mk` (bloque bloat) |
| Cambiar el tamaño de /system | `churros_base.mk` |
| Ajustar memoria o ART | `churros_base_vars.mk` (bloque 4 y 6) |
| Cambiar algo en arranque | `init/churros.rc` |
| Añadir un dispositivo | `manifests/devices/*.xml` + `product/flavors/<flavor>/device.mk` |
| Parchear la plataforma | `patches/*.patch` |
| Añadir un binario de runtime | `native/*.c` + `scripts/cli/native.sh` + servicio en `init/churros.rc` + `PRODUCT_COPY_FILES` en `churros_base_init.mk` |
| Parchear la plataforma | `patches/*.patch` (se aplican con `repo apply`) |
| Cambiar la potencia de build | `scripts/cli/build.sh` |
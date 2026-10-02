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
  check.sh    comprobaciones estáticas
  doctor.sh   requisitos del host
  clean.sh    limpieza

prebuilts/bin/<arch>/   binarios NDK que se copian a /system/bin
```

## Flujo de un cambio

1. Editas `product/...` o `manifests/...` en este repo.
2. `./churros build --lunch churros-lite` hace `rsync` de `product/` al
   workspace y compila. No hace falta re-sincronizar 250 GB.
3. Si el cambio es de plataforma (no de producto), va como parche en
   `patches/*.patch`; `build.sh` los aplica en orden antes de compilar, y
   salta los que ya no apliquen.

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
| Cambiar la Potencia de build | `scripts/cli/build.sh` |
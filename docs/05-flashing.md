# 05 — Compilar, flashear y recuperar

## Compilar

```bash
./churros sync --tier mid                  # una vez por rama de AOSP
./churros native                           # una vez (binarios NDK)
./churros build --lunch churros --tier mid
```

El resultado queda en:

```
~/android/churros/out/target/product/aosp_arm64/churros-aosp_arm64-debug/
  system.img super.img vendor_boot.img vbmeta.img boot.img userdata.img
```

Para un dispositivo con partición `super`, lo normal es flashear `super.img`
completo. Si tu device tree tiene particiones clásicas A/B, flashea
`system.img` + `vendor_boot.img` a los slots que uses.

## Iterar rápido

Un build completo son horas. Para cambios de producto (que es el 90 % de lo
que se toca aquí), el rebuild es incremental:

```bash
# Sólo un módulo y sus dependientes
./churros build --lunch churros --make-arg m SystemUI

# Cambiar sólo product/*.mk y re-empaquetar (minutos)
./churros build --lunch churros --make-arg m
```

Si tocaste `product/common/churros_base_vars.mk`, el rebuild toca **todos** los
módulos, así que no esperes que sea rápido. Los `.rc` y las props, en cambio,
sólo requieren re-empaquetar.

## Flashear

Hay un atajo que calcula el orden correcto (arranque → super → resto) y por
defecto **no escribe nada** hasta que se pasa `--yes`:

```bash
./churros flash --lunch churros            # sólo muestra el plan
./churros flash --lunch churros --yes      # flashea
```

A mano, el orden es:

```bash
cd ~/android/churros/out/target/product/aosp_arm64/churros-aosp_arm64-debug/

adb reboot bootloader
fastboot devices                       # debe listar el dispositivo

# Desbloquear (sólo una vez, borra los datos)
fastboot flashing unlock

# Super (A/B con super)
fastboot flash super super.img
fastboot flash boot boot.img
fastboot flash vendor_boot vendor_boot.img
fastboot flash vbmeta vbmeta.img

# Particiones clásicas
fastboot flash system system.img
fastboot flash vendor vendor.img
fastboot flash boot boot.img

fastboot reboot
```

Si el dispositivo pide `--disable-verity`, es que la imagen no está firmada con
una clave propia y AVB lo bloquea:

```bash
fastboot --disable-verity flash vbmeta vbmeta.img
fastboot --disable-verity flash vbmeta_system vbmeta_system.img 2>/dev/null || true
```

## Instalar con recovery (sin bootloader)

Algunos dispositivos con recovery desbloqueable (y sin root) permiten flashear
un paquete:

```bash
sideload churros-*.zip   # desde el recovery stock
```

El paquete se genera con:

```bash
./churros build --lunch churros --make-arg droid dist
```

## Primer arranque

Es lento la primera vez: `pm` optimiza las apps del sistema (dex2oat). Es
normal que tarde varios minutos con el launcher y Settings sin abrir. La
segunda onwards es normal.

Para ver qué hace:

```bash
adb logcat -b all | grep -E 'churros|lmkd|ActivityManager'
adb shell getprop ro.churros.tier     # lowend | mid | high
adb shell getprop ro.churros.lite     # 1 en el flavor lite
```

## Verificar que el tuning está activo

```bash
adb shell cat /proc/swaps              # debe listar /dev/zram0
adb shell cat /sys/block/zram0/comp_algorithm
adb shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
adb shell cat /proc/sys/vm/pressure_high
```

Si `swaps` está vacío, `churros_zramd` no arrancó: mira
`adb logcat -s churros_zramd` y `adb shell getprop init.svc.churros-zram`.

## Recuperar de un brick

Casi siempre se salva, porque el bootloader es independiente de /system:

```bash
fastboot flash super super.img     # sin wipe
```

Si ni así:

```bash
fastboot flashing format_cache
fastboot flash super super.img
```

Último recurso: volver al firmware stock y volver a flashear. Los blobs de
vendor están en el paquete original del fabricante.
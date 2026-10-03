# 07 — Medición

Sin cifras, `docs/03-optimizacion.md` es opinión. Este documento describe cómo
medir para que cada ajuste future se justifique (o se borre).

## Principios

1. **Mismo hardware, misma build base.** Todo ajuste se compara contra el mismo
   commit, flasheando dos veces la misma build con/sin el ajuste.
2. **La build de comparación es AOSP vanilla**, no el flavor completo. Si no,
   no sabes qué parte del cambio hizo qué.
3. **Mide lo que el usuario nota**: arranque hasta desbloqueo, fluidez al abrir
   apps, consumo en reposo, y calor. Todo lo demás es secundario.
4. **Repite y descarta el primer intento.** La primera ejecución tras flashear
   tiene las páginas de dex cold y el almacenamiento en estado raro.

## Antes / después de una build

```bash
# 1. Baseline: AOSP vanilla del mismo commit
#    lunch aosp_arm64-userdebug; make; ./churros flash --lunch aosp_arm64 --yes

# 2. Medir
./churros measure boot          # tiempo hasta primer frame con icono
./churros measure idle          # consumo en reposo durante 2 h
```

Alternativa sin herramientas: `scripts/measure/` con `adb shell` puro, para no
depender de perfetto en máquinas de build.

## Arranque

Mide el tiempo desde el pulso de power hasta que la pantalla muestra algo
usable:

```bash
adb shell cat /sys/kernel/debug/tracing/trace_pipe | grep -m1 'tracing_mark_write: B|'
adb logcat -b events | grep -E 'am_proc_start|am_proc_bound|boot_progress_enable_screen'
```

El evento `boot_progress_enable_screen` es el punto de referencia estándar.
Objetivos realistas en gama media: 25-35 s en AOSP vanilla; el margen que
aporta R8 + recorte de bloat está en el orden de 2-5 s. En gama baja el
arranque suele mejorar más por `ro.config.low_ram` que por compilación.

## Fluidez

```bash
adb shell dumpsys gfxinfo <paquete> framestats > frames.txt
```

Métricas: janky frames, p95/p99 del frame time, número de frames perdidos.
Objetivo: p99 por debajo de 16.6 ms en scroll, cero frames > 100 ms.

## Memoria

```bash
adb shell dumpsys meminfo | grep -A5 'Total RAM'
adb shell dumpsys meminfo com.android.systemui
adb shell cat /proc/meminfo | grep -E 'MemAvailable|Slab|SReclaimable'
```

En gama baja, lo que importa es `MemAvailable` tras 30 min de uso normal: si
cae por debajo de 150 MB, el sistema está a punto de matar apps visibles.

## Consumo en reposo

```bash
adb shell dumpsys batterystats --reset
# ... 2 h de reposo ...
adb shell dumpsys batterystats | grep -E 'level|SCREEN_BRIGHT|Wifi|Network'
```

Objetivo: < 1 %/h en reposo con la pantalla apagada. Si no se cumple, mira
qué wakelock:

```bash
adb shell dumpsys batterystats | grep -A20 'Wake lock'
```

Los sospechosos habituales en AOSP sin ajustes: `NetworkManagement`, `Wifi`
(el escaneo de redes constantly) y los jobs de `CalendarProvider`.

## zRAM

```bash
adb shell cat /proc/swaps                 # /dev/zram0 montado
adb shell cat /sys/block/zram0/mm_stat    # orig_data_size / compr_data_size / mem_used_total
adb shell cat /sys/block/zram0/comp_algorithm
```

Ratio de compresión sano: `mem_used_total / orig_data_size` entre 0.25 y 0.45
con zstd. Si es > 0.6, el problema no es zRAM sino que hay demasiados bytes
vivos.

## I/O

```bash
adb shell cat /proc/diskstats
```

Compara `read_bytes` + `write_bytes` antes/después de abrir la misma app. En
gama baja, la métrica que más se nota es el tiempo hasta que la app pinta su
primera pantalla en arranque en frío (con `pm clear <app>`).

## Qué registrar

Cada PR que toque optimización debe incluir en su descripción:

```
Dispositivo: <modelo> (<SoC>, <RAM>)
Build: <commit> con/sin el ajuste
Métrica: <nombre> antes → después, n repeticiones
```

Sin esas tres líneas, el ajuste no entra.
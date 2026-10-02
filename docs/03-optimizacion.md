# 03 — Optimización

Principio: **sólo ajustes de bajo riesgo con ganancia alta**. Nada que rompa
CTS ni que exija recompilar la plataforma para probarse. Cada ajuste va
justificado aquí; si no se puede medir, no entra.

## Compilación nativa

| Ajuste | Efecto |
|---|---|
| `-O3` en global, `-O2` en vendor | Vendor ya viene optimizado por el fabricante; forzar más suele *empeorar* el consumo sin ganancia real. |
| `-ffunction-sections -fdata-sections -fno-plt` | Enlaza sólo lo que se usa; el linker elimina el resto. Menos texto en disco, menos páginas cacheadas. |
| ThinLTO por defecto de Clang + `-O3` | Mejor ILP entre unidades, sin el coste de LTO completo. |

## Dex / ART / R8

- **R8 en modo completo** (`PRODUCT_R8_RELEASE_MODE = true`, sin perfiles
  dinámicos): es el optimizador de dex de AOSP. Shrika, optimiza y elimina
  código muerto. Ahorra del orden de 30-40 MB de `/system` y menos trabajo de
  verificación en arranque.
- `PRODUCT_R8_MIN_API_LEVEL` baja a 26 en gama baja: optimiza más código,
  aceptando que el resultado no sirva para sistemas antiguos.

## Propiedades de sistema

| Prop | Efecto |
|---|---|
| `ro.config.low_ram=true` (lite) | Reduce el número de procesos en background y la caché de apps. Es el interruptor más importante en dispositivos de 1-2 GB. |
| `dalvik.vm.heapgrowthlimit` / `heapsize` | Limita el crecimiento del heap de ART. Sin esto, una app puede comerse 512 MB y combinedActivity thrash. |
| `dalvik.vm.heapstartsize=8m` (lite) | Arranque de heap más pequeño: menos RAM por proceso. |
| `ro.zygote.preloadsize_hint` | Reduce la memoria que el zygote precalienta antes de la primera app. |
| `debug.sqlite.wal.syncmode=OFF` | SQLite sin fsync en cada commit. La SQLite de AOSP ya usa WAL con checkpoints: el fsync por transacción era el resto del coste. |
| `log.tag.SurfaceFlinger=ERROR` | Quita el log por frame. |
| `ro.debuggable=0` | Sin tracing de StrictMode en user builds. |

## init (`product/common/init/churros.rc`)

- **I/O**: scheduler `none` en eMMC/UFS (el kernel ya ordena por bloque de
  forma (mayor) mejor que cualquier heurística), `read_ahead_kb` 512,
  `nr_requests` 8 para no acumular requests en cola.
- **zRAM**: se prepara el subsistema en sysfs; el binario `churros_zramd`
  levanta el dispositivo con `zstd`. La idea es paginar en RAM comprimida en
  lugar de hacer swap a flash, que en dispositivos viejos es lo que más
  desgaste y latencia produce.
- **vm tuning**: `swappiness` alto (el OOM killer de Android hace su propio
  trabajo, el swap del kernel compite con él), `dirty_ratio` 15 /
  `dirty_background_ratio` 5 para que las escrituras de las apps no acumulen
  RAM sucia.
- **lmkd**: `churros_lmkd_tuner` ajusta los límites de memory pressure en
  runtime. En gama baja, con los valores por defecto, Android mata apps que el
  usuario está viendo.
- **Governor**: se cambia a `schedutil` sólo cuando el arranque ha terminado,
  para no penalizar el desbloqueo del dispositivo.

## Bloat

Se quitan de AOSP las apps que no aportan en una distro minimalista: Email,
Exchange, Messaging, People, DeskClock, QuickSearchBox, VoiceDialer,
CalendarProvider, LiveWallpapers, GoogleTts, QuickAccessWalletProxy. Cada una
está listada en el bloque 5 de `churros_base_vars.mk`.

En gama baja se quitan además Bluetooth, NFC, PrintSpooler y Tethering —
en dispositivos de 1-2 GB la radio NFC mantenida en background compite con la
app en primer plano.

## Lo que deliberadamente NO se hace

- **No parcheamos el kernel** en caliente. Cualquier cosa de sched, governor o
  I/O que requiera un kernel parcheado se aplica en el device tree, que es el
  sitio correcto y donde sobrevive a la actualización de la plataforma.
- **No se tocan flags de CTS/VTS.** Una ROM que no pasa CTS no es una ROM.
- **No se quita la verificación de dm-verity** en builds de usuario. Va
  desactivado (`PRODUCT_AVB_OTA_DISABLE`) porque AOSP puro no trae Keys de
  firma, pero eso es una consecuencia de no tener claves, no una optimización.
- **No se tocan `.rc` de terceros**: no hay terceros.
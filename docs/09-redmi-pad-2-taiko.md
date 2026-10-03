# 09 — Xiaomi Redmi Pad 2 (taiko)

Documento de referencia para portar ChurrOS Android al Redmi Pad 2. Todo lo
verificable está verificado contra fuentes públicas; lo que no, está marcado.

Fecha de la investigación: 2026-10. Re-verifica antes de empezar.

## 1. Hardware

| Campo | Valor |
|---|---|
| Nombre comercial | Redmi Pad 2 |
| Codename | `taiko` |
| Modelos | 25040RP0AG (global WiFi) · 25040RP0AI (`taiko_id`, Indonesia, 4G) · variante "Redmi Pad 2 4G" |
| SoC | MediaTek Helio **G100-Ultra** = `MT6789H` (plataforma `mt6789`) |
| CPU | 2x Cortex-A76 2.2 GHz + 6x Cortex-A55 2.0 GHz (arm64) |
| GPU | ARM **Mali-G57 MC2** (2 cores, ~1000 MHz) |
| RAM | 4 / 6 / 8 GB · UFS 2.2 + microSD |
| Pantalla | 11" IPS, **1600x2560**, 90 Hz, 600 nits (HBM) |
| Cámara | 8 MP trasera + 5 MP frontal, vídeo 1080p30 |
| Audio | 4 altavoces con Dolby Atmos, jack 3.5 mm, Hi-Res 24/192 |
| Batería | 9000 mAh, 18 W |
| SO de fábrica | Android 15 + HyperOS 2 |
| Conectividad | WiFi 802.11 a/b/g/n/ac dual band, BT 5.3, USB-C 2.0 OTG |
| Ausencias | **Sin NFC**, sin radio (variante WiFi), sin lector de huella |

Importante: **no confundir con el Redmi Pad original** (`yunluo`, Helio G99,
2000x1200) ni con el **Redmi Pad 2 SE** (que es Snapdragon, no MediaTek).

## 2. Por qué este dispositivo es mucho más viable que el moto g55

Tres diferencias que cambian el proyecto:

| | moto g55 (taipei) | Redmi Pad 2 (taiko) |
|---|---|---|
| Bootloader | **Motorola no da claves** | **Mi Unlock oficial**, con espera de 168 h |
| GPU | PowerVR sin driver abierto | Mali, HAL estándar en AOSP |
| Device tree público | No existe | **Sí**: el de `yunluo`, misma plataforma mt6789, con LineageOS 23.0 |

Además, el Redmi Pad (`yunluo`) tiene un device tree mantenido por
`xiaomi-mt6789-devs` con LineageOS 23.0 (Android 16) y SELinux enforcing: es
decir, alguien ya resolvió VINTF, SELinux, RIL y cámara para esta plataforma
exactamente. Eso convierte el port de "desde cero" en "adaptar".

## 3. Bloqueantes y trampas

### 3.1 Desbloqueo: funciona, pero con cuenta y espera

Xiaomi tiene programa oficial (Mi Unlock). Requisitos:

1. Cuenta Mi registrada en un teléfono, **vinculada al dispositivo hace al
   menos 168 h (7 días)**. Este es el paso que mata las prisas.
2. Esperar además el periodo de espera real tras registrar el token: puede
   ser mayor que 168 h según región.
3. El dispositivo **no** puede tener FRP activo (cuenta Google con verificación
   de fábrica) ni MDM.
4. Desbloquear **borra todos los datos**.

Comprobación previa:

```bash
adb reboot bootloader
fastboot oem get_unlock_data > /tmp/taiko.txt   # pegar en miui.com/unlock
```

Si la cuenta se acaba de crear o el token se acaba de registrar, arranca con
los blobs y el port en paralelo: la espera es de días, no de minutos.

### 3.2 Las dos variantes de firmware no son intercambiables

`taiko` (25040RP0AG, global WiFi) y `taiko_id` (25040RP0AI, Indonesia, 4G)
tienen builds de HyperOS distintos. El `/vendor` de uno no vale para el otro:
telephony, fstab y la lista de blobs cambian. Extrae **del firmware de tu
unidad concreta**, no de una descarga cualquiera.

### 3.3 El panel es distinto al del Redmi Pad

El `yunluo` monta 2000x1200; el `taiko` monta **1600x2560**. Reutilizar el
device tree del Redmi Pad sin tocar el panel da pantalla en blanco o con
distorsión, y el touch no coincide. El device tree del `taiko` tiene que
traer su propio `lcd`/`timing` y su `ueventd`/`fstab`.

## 4. Qué hay que construir

| # | Pieza | Origen | Dificultad |
|---|---|---|---|
| 1 | Mi Unlock tras 168 h | — | esperado |
| 2 | `device/churros/taiko`: BoardConfig + extract_files | adaptar de `yunluo` | media |
| 3 | `proprietary-files.txt` del firmware HyperOS 2 del taiko | extraer | media |
| 4 | Panel 1600x2560 + touch | device tree | media |
| 5 | VINTF + SELinux | **copiar de `yunluo`** | baja (resuelto) |
| 6 | RIL / IMS / eSIM (variante 4G) | blobs del 4G | media-alta |
| 7 | Cámara | blobs + Camera2 | media |
| 8 | Overlays de recursos (densidad 320, 90 Hz) | flavor | baja |

El orden importa: no gastes tiempo en cámara ni radio hasta que arranque y
pinte bien.

## 5. Qué AOSP compilar

El stock es **Android 15 (API 35)** → compila `android15-release` y usa los
blobs del vendor del HyperOS 2 del taiko.

```bash
./churros sync --branch android15-release --device taiko
./churros build --lunch churros-taiko --tier mid --src ~/android/churros
```

A diferencia del G55, aquí sí hay vendor de API 35, así que `android15-release`
es lo natural. Si apareciera fricción de VTS, la salida es bajar a blobs de
API 34, no subir la plataforma.

## 6. Flavor y props

`product/flavors/taiko/device.mk` hereda de `churros` (gama media) y declara:

```makefile
ro.hardware.egl=mali          # obligatorio. mal = pantalla negra sin panic
dalvik.vm.heapgrowthlimit=384m
dalvik.vm.heapsize=512m
ro.sf.lcd_density=320
ro.boot.hardware=mt6789
```

Matiz sobre `ro.hardware.egl`: en Mali el valor lo declara el driver del
vendor y puede ser `mali` o `mtk` según el blob. `mali` es el valor por defecto
correcto, pero **confírmalo contra tu firmware** antes de flashear:

```bash
adb shell getprop | grep -i egl     # en el stock, con HyperOS
```

Lo que **no** se declara y por qué: `ro.hardware.vulkan` (el ICD llega con el
driver), y ninguna `ro.miui.*` (son de HyperOS y AOSP no las lee).

## 7. Variantes de RAM

La de 4 GB es la que más nota ChurrOS. Si tu unidad es de 4 GB, el device tree
puede subir el tratamiento de gama baja (`ro.config.low_ram=true`) sin tocar el
flavor. No se declara aquí porque la variante de 4 GB y la de 8 GB comparten
el mismo codename y el mismo device tree; decide con un
`ifneq ($(TARGET_VARIANT),...)` en BoardConfig.

## 8. Orden de trabajo

1. Registra el token de Mi Unlock y **espera las 168 h**. Es el camino crítico.
2. Descarga el firmware HyperOS 2 **de tu variante** y extrae los blobs.
3. Clona el device tree de `yunluo` como esqueleto y sustituye panel, blobs y
   `fstab`.
4. Compila sin cámara ni radio. Pantalla negra ⇒ problema de `ro.hardware.egl`.
5. Con pantalla, revisa `avc: denied` en `logcat`. Al ser la misma plataforma
   que `yunluo`, muchos dominios ya existen y puedes copiar sus reglas.
6. Sólo entonces cámara, radio (variante 4G) y sobremesas.

## 9. Comprobación de estado en el dispositivo

```bash
adb shell getprop ro.product.device      # taiko
adb shell getprop ro.churros.tier        # mid
adb shell getprop ro.hardware.egl        # mali
adb shell dumpsys SurfaceFlinger | grep -i gles   # debe decir Mali
adb shell wm size                         # 1600x2560
adb shell wm density                      # 320
adb shell ls /vendor/lib64/ | grep -i mali
```

## 10. Fuentes

- Device tree y kernel del Redmi Pad: `github.com/xiaomi-mt6789-devs`
  (`android_device_xiaomi_yunluo`, `kernel_xiaomi-yunluo`, y los
  `vendor-mediatek-kernel_modules-connectivity-*`).
- Releases de LineageOS para `yunluo`: `github.com/xiaomi-mt6789-devs/releases`
  (23.0 = Android 16, SELinux enforcing).
- Desbloqueo: `miui.com/unlock` (Mi Unlock, oficial).

## 11. Estado

Manifest, flavor y este documento son el esqueleto. No compilado ni flasheado.
Falta `device/churros/taiko`, cuyo trabajo real es adaptar el de `yunluo` al
panel y a los blobs del `taiko`.
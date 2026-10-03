# 08 — Motorola moto g55 5G (taipei)

Documento de referencia para portar ChurrOS Android al moto g55 5G. Todo lo
que hay aquí está verificado contra fuentes públicas; lo que no lo está, está
marcado como tal.

Fecha de la investigación: 2026-10. **Re-verifica antes de empezar**: tanto el
estado del desbloqueo de bootloader como las versiones de LineageOS cambian.

## 1. Hardware

| Campo | Valor |
|---|---|
| Nombre comercial | moto g55 5G |
| Codename | `taipei` |
| Modelos | XT2435-1 (US, AVACO) · XT2435-2 (EU, RETEU/RETEPAC) · XT2435-3 (CN, CMCC) |
| SoC | MediaTek Dimensity 7025 = **MT6855V/ATZA**, plataforma `mt6855` |
| CPU | 2x Cortex-A78 2.5 GHz + 6x Cortex-A55 2.0 GHz (arm64) |
| GPU | **IMG PowerVR BXM-8-256** (B-Series), 390-950 MHz, Vulkan 3.2 |
| RAM | 8 GB LPDDR4X |
| Pantalla | 2400x1080, panel `tm_nt36672c_vid_649_1080`, táctil `NVT-ts` |
| Kernel | 5.10.218-android12-9 (rama Android 12), revisión distinta por firmware |
| Android de fábrica | 14 (API 34), ya actualizado a 15 (API 35) y 16 |
| Sensores | `icm45621_acc`, `mmc5603`, `icm45621_gyro`, goodix_fp, NVT-ts |
| Cámara | `s5kjns_mipiraw_mot_taipei*`, MAIN2AF / MAIN3AF / MAINAF |
| PMIC | mt6375 · cargador `bq25980-charger`, `sm5109c` |
| Audio | `mt6855mt6369`, PA `aw87xxx` |

Producto de build de fábrica: `motorola/taipei_g_sys{e,n}` (varía por región
y por versión de Android). Baseband: `MT6855D_TC2.PR7...`.

## 2. Los tres bloqueantes, en orden de gravedad

### 2.1 No hay bootloader desbloqueable (bloqueante total)

**Motorola no da claves de desbloqueo para este dispositivo.** Motorola tiene
una web de unlock, pero:

- Excluye los modelos de operadora (Verizon, AT&T, Tracfone) por CID.
- Desde ~2023 el programa está prácticamente cerrado: hay reportes de que
  **ningún Motorola lanzado desde 2020 califica**, y los dispositivos de más
  de 3 años ya no reciben código.
- El XT2435 se lanzó en **septiembre de 2024**. Es muy probable que no
  califique.

Cómo comprobarlo (5 minutos, hazlo ANTES de descargar 250 GB):

```bash
adb reboot bootloader
fastboot oem get_unlock_data 2>/dev/null > /tmp/unlock.txt
# pega /tmp/unlock.txt entero en UNA SOLA LÍNEA en
# https://en-us.support.motorola.com/app/standalone/bootloader/unlock-your-device-a
```

Si responde "not eligible", el proyecto entero para este teléfono se detiene
aquí. Sin bootloader desbloqueado no hay `fastboot flash`, no hay custom
recovery, no hay nada. Opciones: un servicio de desbloqueo de pago de terceros
(no recomendado:ogal, potencialmente malware; y en un Motorola nuevo
normalmente tampoco funciona), o cambiar de dispositivo objetivo a otro con
bootloader desbloqueable (Pixel, Nokia, Xiaomi con unlock oficial).

Alternativa que **no** es un bootloader desbloqueado: Magisk y parcheo de
`boot.img`. No sirve para una ROM con `system` propio; sólo para root.

### 2.2 PowerVR no tiene driver abierto en AOSP

La GPU es IMG PowerVR B-Series. **AOSP no incluye un driver abierto de
PowerVR**: el HAL de EGL/GLES de este dispositivo son
`libGLESv2_POWERVR.so` y el driver de IMG (PowerVR SDK closed-source), que
viven en `/vendor`.

Consecuencias para el port:

- Hay que reutilizar el `/vendor` del firmware stock tal cual. No se puede
  reconstruir.
- `ro.hardware.egl=powervr` (o el valor que el vendor HAL declare) es
  **obligatorio**. Con el valor equivocado (típico: dejarlo en `adreno`) el
El síntoma es el peor posible: **arranca, llega al launcher, pantalla negra,
  sin panic en el log**. Es el fallo clásico al portar a MediaTek+PowerVR.
  Por eso `ro.hardware.egl` se quitó del producto común: es dato del
  dispositivo, y está en `product/flavors/taipei/device.mk`.
- `libPVROCL.so` y el de Vulkan van igual en vendor. `ro.hardware.vulkan=false`
  mientras el vendor no declare elICD de Vulkan.

### 2.3 El kernel es 5.10, no GKI

El kernel de fábrica es `5.10.218-android12-9`. No es GKI, así que:

- **No hay `vendor_boot` con `modules.load`**: los módulos vienen en la propia
  imagen del kernel.
- La imagen del kernel hay que **reutilizarla del firmware stock** o
  reconstruirla desde `MotorolaMobilityLLC/kernel-mtk` (rama MT6855). Es un
  repositorio real y público.
- El init rc del proyecto escribe en `/sys/devices/system/cpu/.../scaling_governor`
  y en sysfs de zRAM. En este kernel puede que no exista ninguno de los dos
  paths; por eso el rc usa `2>/dev/null` y no falla. Si más adelante quieres
  governor, el nombre en MediaTek suele ser `schedutil` también, pero
  confírmalo con `adb shell cat /sys/.../available_governors`.

## 3. Qué hay que construir (el port real)

Un AOSP completo sobre MediaTek no es un device tree, es un port. Las piezas,
en orden de dificultad:

| # | Pieza | Dificultad | Nota |
|---|---|---|---|
| 1 | Desbloqueo del bootloader | — | Sin esto, nada de lo demás sirve |
| 2 | `device/churros/taipei`: BoardConfig, extract_files, proprietary-files | media | Los blobs salen del firmware stock de ~4.8 GB |
| 3 | `vendor` reutilizado + `PRODUCT_SHIPPING_API_LEVEL` coherente | alta | Ver §4 |
| 4 | VINTF: `vendor/etc/vintf/*.xml` + overlays de framework | alta | El manifest del vendor es de MTK, con HALs que AOSP no espera |
| 5 | SELinux: política de MTK (`hal_*`, `vendor_*`, `mtk_*`) | **muy alta** | Es la mayor parte del trabajo real |
| 6 | RIL/telephony MTK (MtkRil, IMS, eSIM) | muy alta | Con `persist.radio.multisim.config=dsds` declarado |
| 7 | Cámara (`s5kjns_mipiraw_mot_taipei`) | media-alta | |
| 8 | Overlays de recursos (2400x1080, 120 Hz, biometrics) | baja | |
| 9 | SELinux + permisos de particiones | baja | Al final, cuando ya arranca |

## 4. La decisión más importante: qué AOSP compilar

Los blobs de `/vendor` del firmware **API 34** (Android 14) y del firmware
**API 35** no son intercambiables. Elegir mal esto cuesta días.

**Recomendación: compilar `android14-release` (SDK 34) y usar los blobs de
vendor del firmware Android 14** (`U3UTS34.44-11-2-1` para XT2435-2, o
`V1UTS34.44` para el -1). Razón: `PRODUCT_SHIPPING_API_LEVEL := 34` en el
producto base, y un VTS de API 34 sobre vendor de API 34 tiene Much menos
fricción que uno de API 35 sobre vendor de API 34.

```bash
./churros sync --branch android14-release --device taipei
./churros build --lunch churros-taipei --tier mid --src ~/android/churros
```

No saltes a API 35 hasta tener un build que arranque. API 35 cambia el
formato de `vendor_apis` y `VINTF` de forma incompatible.

## 5. Extracción de blobs

Del paquete de firmware oficial de tu modelo exacto (los tres XT2435 tienen
firmware distinto):

```bash
# 1. Descomprime el firmware (los .xml son los scripts de flash de Motorola)
# 2. Los blobs de vendor están en la imagen super/odm del paquete, o en
#    *.img sueltos. Extrae:
python3 payload_dumper.py super.img
# 3. Copia lo que falte a device/churros/taipei/vendor/ y lista cada fichero en
#    proprietary-files.txt con su ruta exacta en /vendor
```

Puntos donde no te puedes equivocar:

- `proprietary-files.txt` es **case-sensitive** y las rutas deben ser exactas.
  Un `lib` en vez de `lib64` rompe en runtime, no en build.
- Los directorios que ya existen en el árbol AOSP (binarios de AOSP) **no**
  deben ir en proprietary-files.txt: AOSP gana y el blob del vendor se ignora
  silenciosamente.
- Los permisos de cada blob van en `profiledef.sh` (`file_permissions`).
  Sin permisos correctos el build falla con `failed to install file`.

## 6. Flavors y props de este dispositivo

`product/flavors/taipei/device.mk` declara, y son los que importan:

```makefile
ro.hardware.egl=powervr          # OBLIGATORIO (pantalla negra si no)
ro.hardware.vulkan=false         # el ICD de Vulkan no viene
dalvik.vm.heapgrowthlimit=512m   # 8 GB de RAM: más margen que gama media
dalvik.vm.heapsize=768m
ro.boot.hardware=mt6855
ro.sf.lcd_density=320
```

Y lo que **no** se declara a propósito (está comentado en el flavor):
`gsm.version.baseband`, `gsm.version.ril-impl`, `ro.radio.libpath`. Un valor
inventado deja la radio en "sin registro" aunque el módem esté perfectamente
funcionando. Se leen del `/vendor` stock.

## 7. Orden de trabajo recomendado

1. **Confirma el desbloqueo** (§2.1). Es binario: sí o no.
2. Consigue el firmware stock de **tu** XT2435 exacto y extrae los blobs.
3. Monta `device/churros/taipei` y pon `PRODUCT_SHIPPING_API_LEVEL := 34`.
4. Compila **sin** telephony/cámara: quita los `PRODUCT_PACKAGES` de radio
   y arranca. Pantalla negra ⇒ problema de PowerVR (§2.2).
5. Con pantalla, mete SELinux permissive (`ro.boot.selinux=permissive`, que
   ChurrOS ya pone en builds user) y ve leyendo `avc: denied` del `logcat`.
   Cada `denied` es una política que hay que escribir.
6. Cuando el arranque sea limpio, pasa a enforcing y cierra los denials.
7. Sólo entonces cámara, luego radio, luego biometrics.

## 8. Comprobación de estado rápido en el dispositivo

```bash
adb shell getprop ro.product.device        # taipei
adb shell getprop ro.churros.tier          # mid
adb shell getprop ro.hardware.egl          # powervr
adb shell dumpsys SurfaceFlinger | grep -i gles   # debe decir PowerVR, no Mali/Adreno
adb shell ls /vendor/lib64/ | grep -i pvr        # los blobs del driver
```

## 9. Fuentes

- Wiki de LineageOS: **taipei no está soportado oficialmente** (no aparece en
  wiki.lineageos.org/devices). No hay device tree pública que reutilizar: el
  port es desde cero.
- Kernel: `github.com/MotorolaMobilityLLC/kernel-mtk` (monorepo de kernels
  para SoCs MediaTek).
- Módulos de conectividad: repos `vendor-mediatek-kernel_modules-connectivity-*`
  bajo la misma organización.
- Portal de código abierto de Motorola: `motorolamobilityllc.github.io`.
- Desbloqueo: página oficial de bootloader de Motorola (en el §2.1).

## 10. Estado

Nada de este dispositivo está compilado ni flasheado. El manifest, el flavor
y este documento son el esqueleto; falta el device tree y, antes que nada, el
desbloqueo del bootloader.
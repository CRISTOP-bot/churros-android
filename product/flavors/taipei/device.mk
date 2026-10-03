# ChurrOS Android — Motorola moto g55 5G (taipei)
#
# Hereda del flavor de gama media y añade SOLO lo específico del dispositivo.
# Nada de esto podría vivir en product/common: son datos del hw.
#
# Documentación del dispositivo: docs/08-moto-g55-taipei.md

$(call inherit-product, $(SRC)/product/flavors/churros/device.mk)

PRODUCT_NAME := churros-taipei
PRODUCT_DEVICE := taipei
PRODUCT_MODEL := moto g55 5G
PRODUCT_BRAND := motorola
PRODUCT_MANUFACTURER := motorola

# -----------------------------------------------------------------------------
# GPU: PowerVR IMG BXM-8-256 (B-Series)
# -----------------------------------------------------------------------------
# Éste es el ajuste que más fácilmente se olvida: el base ya no pone
# ro.hardware.egl porque es dato del dispositivo. En un SoC MediaTek con
# PowerVR el valor NO es "adreno" ni "mali", y el userspace de gráficos
# (libGLESv2_POWERVR.so, libEGL_mtk.so) vive en /vendor.
#
# Si esto se deja mal, el síntoma es: boot hasta el launcher y pantalla negra,
# sin panic. Es EL fallo más común al portar a PowerVR.
#
# ro.hardware.vulkan=false porque el ICD de Vulkan no viene en el vendor de
# este dispositivo. ro.opengles.version NO se declara a proposito: lo publica
# el driver de IMG desde /vendor y declararlo aqui genera conflicto.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.hardware.egl=powervr \
    ro.hardware.vulkan=false

# -----------------------------------------------------------------------------
# Memoria: 8 GB LPDDR4X
# -----------------------------------------------------------------------------
# El flavor de gama media limita heapgrowthlimit a 256m, pero con 8 GB hay
# margen para apps de 64 bits con JVM grande. Sin esto, apps como las de
# cámara o edición de vídeo matan por falta de contiguous memory.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.heapgrowthlimit=512m \
    dalvik.vm.heapsize=768m \
    dalvik.vm.heapstartsize=16m

# -----------------------------------------------------------------------------
# Kernel 5.10 (no GKI)
# -----------------------------------------------------------------------------
# El kernel de taipei es 5.10.218-android12-9: NO es GKI, así que no hay
# modules.load y los módulos del kernel vienen en la propia imagen del kernel.
# El init rc del proyecto escribe en sysfs de governors y zRAM; ambos pueden
# no existir en este kernel, por eso todo va con 2>/dev/null y sin fallar.
# ro.vndk.version NO se declara: la pone el propio /vendor al compilar
# (BOARD_VNDK_VERSION en el device tree). Declararla desde system crea
# discrepancias en VTS sin ganancia.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.boot.hardware=mt6855

# -----------------------------------------------------------------------------
# Radio MediaTek
# -----------------------------------------------------------------------------
# El RIL de MTK (MtkRil) vive en /vendor y se autoconfigura a partir del
# propio vendor: no se declaran aquí ro.radio.libpath ni las versiones de
# baseband, porque un valor inventado deja la radio en "sin registro".
# Ver product/flavors/taipei/product.mk.

# -----------------------------------------------------------------------------
# Pantalla
# -----------------------------------------------------------------------------
# tm_nt36672c_vid_649_1080, 120 Hz. El panel y el timing vienen del driver
# del vendor; aquí sólo se declara la densidad que espera el framework.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.sf.lcd_density=320

# -----------------------------------------------------------------------------
# Particiones
# -----------------------------------------------------------------------------
# Los XT2435 usan A/B con super y dynamic partitions: el device tree debe
# declarar BOARD_SUPER_PARTITION_SIZE y el flasheado va con super.img
# (ver scripts/cli/flash.sh).
#
# PRODUCT_AVB_OTA_DISABLE lo pone ya product/common/churros_base.mk: AOSP puro
# no trae claves de firma, así que verity y OTA firmado no pueden funcionar.

# -----------------------------------------------------------------------------
# Orden de herencia (importante para saber quién gana)
# -----------------------------------------------------------------------------
# En make, la última asignación gana. Como el inherit-product del flavor de
# gama está al principio de este fichero, TODO lo de aquí sobrescribe a lo
# del padre: los heapgrowthlimit de abajo pisan los del bloque "mid" de
# churros_base_vars.mk, que es exactamente lo que se quiere en un dispositivo
# de 8 GB.
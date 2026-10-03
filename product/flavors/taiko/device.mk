# ChurrOS Android — Xiaomi Redmi Pad 2 (taiko)
#
# Hereda del flavor de gama media y añade SOLO lo específico del dispositivo.
# Nada de esto puede vivir en product/common: son datos del hardware.
#
# Documentación del dispositivo: docs/09-redmi-pad-2-taiko.md
#
# Orden de herencia: en make la última asignación gana. El inherit-product del
# flavor de gama está al principio, así que TODO lo de aquí pisa lo del padre.

$(call inherit-product, $(SRC)/product/flavors/churros/device.mk)

PRODUCT_NAME := churros-taiko
PRODUCT_DEVICE := taiko
PRODUCT_MODEL := Redmi Pad 2
PRODUCT_BRAND := xiaomi
PRODUCT_MANUFACTURER := xiaomi

# -----------------------------------------------------------------------------
# GPU: ARM Mali-G57 MC2
# -----------------------------------------------------------------------------
# Dato del dispositivo, por eso está aquí y no en el producto común. El HAL de
# gráficos (libGLES_mali.so) vive en /vendor, como en cualquier Mali.
#
# ro.hardware.egl mal puesto = pantalla negra sin panic. Y aquí hay un matiz
# importante: en Mali el valor correcto lo declara el propio driver del vendor
# y suele ser "mali" o "mtk" según el blob. Hay que confirmarlo contra el
# device tree antes de flashear; "mali" es el valor por defecto correcto para
# un Mali-G57 de MediaTek.
#
# ro.hardware.vulkan NO se declara a propósito: el ICD de Vulkan llega con el
# driver de Mali en /vendor y declararlo aquí genera conflicto.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.hardware.egl=mali

# -----------------------------------------------------------------------------
# Memoria: 4 / 6 / 8 GB según variante
# -----------------------------------------------------------------------------
# La gama media limita heapgrowthlimit a 256m. Una tablet de 4 GB con pantalla
# grande usa más por app (decodificación de vídeo, navegador con muchas
# pestañas), y con 8 GB hay margen de sobra.
PRODUCT_SYSTEM_PROPERTIES += \
    dalvik.vm.heapgrowthlimit=384m \
    dalvik.vm.heapsize=512m

# -----------------------------------------------------------------------------
# Pantalla: 11" 1600x2560 IPS 90 Hz
# -----------------------------------------------------------------------------
# ~274 ppi: la densidad que espera el framework para tablets de 11" es 320
# (xhdpi). El modo 2560x1600 viene del driver del panel en /vendor.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.sf.lcd_density=320 \
    ro.boot.hardware=mt6789

# -----------------------------------------------------------------------------
# Tablet sin cellular ni sensores de biometría
# -----------------------------------------------------------------------------
# Las variantes WiFi (25040RP0AG) no tienen radio. Para ellas hay que quitar el
# paquete de telephony del producto; la variante 4G (25040RP0AI, taiko_id) sí
# lo tiene. Descomenta si el device tree declara el flavour correcto:
# PRODUCT_PACKAGES -= Telephony
# PRODUCT_PACKAGES -= Mms

# -----------------------------------------------------------------------------
# Particiones
# -----------------------------------------------------------------------------
# A/B con super, como en el Redmi Pad (yunluo). El device tree debe declarar
# BOARD_SUPER_PARTITION_SIZE; el flasheado va con super.img (scripts/cli/flash.sh).
# PRODUCT_AVB_OTA_DISABLE ya lo pone product/common/churros_base.mk.
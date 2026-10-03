# ChurrOS Android — build del flavor de dispositivo taipei.
#
# Se incluye desde product/common/churros_base.mk cuando
# PRODUCT_NAME == churros-taipei. Aquí sólo van cosas que NO deben estar en un
# build user de producción.

PRODUCT_RELEASE_NAME := churros-taipei
PRODUCT_BUILD_PROP_OVERRIDES += PRODUCT_NAME

# Doble SIM activo-dual: el XT2435-1/-2 lo soportan por hardware.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.radio.multisim.config=dsds

# El fingerprint va al Secure Element; el valor por defecto (0) deja el
# primer arranque esperando. El firmware de taipei usa 15 s.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.fingerprint.timeout=15000

# ---------------------------------------------------------------------------
# Deliberadamente NO activado
# ---------------------------------------------------------------------------
# Las siguientes props las espera el RIL de MediaTek con valores concretos
# (baseband, ril-impl, IMS). Ponerlas vacías o inventadas desde el producto
# hace que la radio entre en "sin registro" aunque el módem esté bien. Los
# valores correctos los lee el RIL del /vendor del firmware stock; no se
# declaran aquí:
#
#   gsm.version.baseband
#   gsm.version.ril-impl
#   ro.radio.libpath
#
# Si el puerto acaba sin red, el primer sitio donde mirar es
# `adb shell getprop | grep -E 'baseband|ril-impl'` contra un build que sí
# funcione, y comparar con el /vendor stock. Ver docs/08-moto-g55-taipei.md.
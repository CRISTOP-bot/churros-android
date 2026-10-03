# ChurrOS Android — build del flavor de dispositivo taiko (Redmi Pad 2).
#
# Se incluye desde product/common/churros_base.mk cuando
# PRODUCT_NAME == churros-taiko. Aquí sólo va lo que NO debe estar en un build
# user de producción.

PRODUCT_RELEASE_NAME := churros-taiko
PRODUCT_BUILD_PROP_OVERRIDES += PRODUCT_NAME

# ---------------------------------------------------------------------------
# Deliberadamente NO activado
# ---------------------------------------------------------------------------
# ro.radio.libpath, gsm.version.baseband y gsm.version.ril-impl NO se declaran:
# las lee el RIL de MediaTek desde /vendor, y un valor inventado deja la radio
# en "sin registro" aunque el módem esté bien.
#
# Las props ro.miui.* tampoco: son específicas de HyperOS y no las lee nada en
# un build AOSP. No hay equivalente que "desactivar" porque AOSP no trae las
# funciones que HyperOS activa con ellas (división de pantalla, wildfire, screen
# mirror). Si en algún momento apareciesen con otro nombre, el sitio correcto
# sería el device tree, no aquí.
#
# ro.miui.low_memory_device y similares sólo aplican a la variante de 4 GB, y
# el device tree debe decidirlo (ver docs/09-redmi-pad-2-taiko.md, §7).
#
# Si el puerto acaba sin red, el primer sitio donde mirar es
# `adb shell getprop | grep -E 'baseband|ril-impl'` contra el stock y comparar.
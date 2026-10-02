# ChurrOS Android — base común de todos los flavors.
#
# Este archivo es el único punto de entrada de producto. Los flavors
# (churros-lite / churros / churros-pro) heredan de aquí y sólo añaden o
# quitan lo específico de su gama.
#
# Regla del proyecto: cualquier cosa que se pueda decidir con variables de
# entorno o props va en variables, no en ifeq. Ver churros_base_vars.mk.

$(call inherit-product, $(SRC)/build/make/target/product/AndroidDefaults.mk)

PRODUCT_USE_SOONG_NOTICE := true

# -----------------------------------------------------------------------------
# Heredado de plataforma — AOSP puro
# -----------------------------------------------------------------------------
# Nada de GAPPS, nada de apps de terceros. Si más adelante se añade un
# microGMS, se hace con un fragmento aparte, nunca aquí.

# -----------------------------------------------------------------------------
# Reloj y zona horaria
# -----------------------------------------------------------------------------
PRODUCT_SYSTEM_PROPERTIES += \
    persist.sys.timezone=Europe/Madrid

# -----------------------------------------------------------------------------
# Particiones: 16 MB de reserva extra para /system reduce el riesgo de
# "no space left on device" en dispositivos viejos.
# -----------------------------------------------------------------------------
PRODUCT_SYSTEM_SIZE := 2147483648
PRODUCT_VENDOR_SIZE := 2147483648
PRODUCT_USERDATA_SIZE := 2147483648

# Sin verificación de dm-verity en user builds de AOSP ya viene así; se
# documenta aquí para que nadie lo cambie sin querer.
PRODUCT_AVB_OTA_DISABLE := true

# -----------------------------------------------------------------------------
# Envs de build — se rellenan desde scripts/cli/build.sh
# -----------------------------------------------------------------------------
# CHURROS_BUILD_TYPE   := eng | user | userdebug
# CHURROS_TARGET       := aosp_arm64 | aosp_arm
# CHURROS_TIER         := lowend | mid | high

# -----------------------------------------------------------------------------
# Variables de optimización (ver churros_base_vars.mk)
# -----------------------------------------------------------------------------
$(call inherit-product, $(SRC)/product/common/churros_base_vars.mk)
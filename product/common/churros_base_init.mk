# ChurrOS Android — registro de init y binarios de runtime.
#
# Este archivo transforma product/common/init/churros.rc en algo que AOSP
# entiende: lo copia a /system/etc/init y despliega el binario de ajuste de
# lmkd compilado con NDK.

CHURROS_ARCH_arm64 := arm64-v8a
CHURROS_ARCH_arm := armeabi-v7a

ifeq ($(CHURROS_TARGET),aosp_arm)
  CHURROS_ARCH := $(CHURROS_ARCH_arm)
else
  CHURROS_ARCH := $(CHURROS_ARCH_arm64)
endif

# El rc del producto, tal cual
PRODUCT_COPY_FILES += \
    $(SRC)/product/common/init/churros.rc:$(TARGET_COPY_OUT_PRODUCT)/etc/init/churros.rc

# Ajuste de lmkd (evita que el OOM killer mate apps visibles con poca RAM
# disponible; crítico en gama baja)
PRODUCT_COPY_FILES += \
    $(SRC)/prebuilts/bin/$(CHURROS_ARCH)/churros_lmkd_tuner:$(TARGET_COPY_OUT_PRODUCT)/bin/churros_lmkd_tuner

# Gestión de zram en userspace (el rc sólo prepara sysfs)
PRODUCT_COPY_FILES += \
    $(SRC)/prebuilts/bin/$(CHURROS_ARCH)/churros_zramd:$(TARGET_COPY_OUT_PRODUCT)/bin/churros_zramd
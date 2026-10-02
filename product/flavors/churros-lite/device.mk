# ChurrOS Lite — gama baja (2015-2019, 1-2 GB RAM)
#
# Hereda todo de product/common. Este archivo sólo define identidad y
# diferencias frente a churros.
$(call inherit-product, $(SRC)/product/common/AndroidProducts.mk)

PRODUCT_NAME := churros-lite
PRODUCT_MODEL := ChurrOS Lite
PRODUCT_DEVICE := churros_lite

# 32 o 64 bits según el device tree; el manifest por defecto asume 64 bits.
PRODUCT_SYSTEM_PROPERTIES += \
    ro.churros.tier=lowend
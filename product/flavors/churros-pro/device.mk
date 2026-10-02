$(call inherit-product, $(SRC)/product/common/AndroidProducts.mk)

PRODUCT_NAME := churros-pro
PRODUCT_MODEL := ChurrOS Pro
PRODUCT_DEVICE := churros_pro

PRODUCT_SYSTEM_PROPERTIES += \
    ro.churros.tier=high
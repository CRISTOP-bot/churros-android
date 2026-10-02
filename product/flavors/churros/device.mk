$(call inherit-product, $(SRC)/product/common/AndroidProducts.mk)

PRODUCT_NAME := churros
PRODUCT_MODEL := ChurrOS
PRODUCT_DEVICE := churros

PRODUCT_SYSTEM_PROPERTIES += \
    ro.churros.tier=mid
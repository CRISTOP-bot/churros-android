# ChurrOS Android — producto común
#
# Se incluye desde todos los flavors (lite / estándar / pro).
# Aquí vive SOLO lo que es idéntico en todos los dispositivos.
# Nada específico de dispositivo: eso va en product/flavors/<flavor>/device.mk.

$(call inherit-product, $(SRC)/product/common/churros_base.mk)

# -----------------------------------------------------------------------------
# Identidad
# -----------------------------------------------------------------------------
PRODUCT_BRAND := ChurrOS
PRODUCT_MANUFACTURER := ChurrOS
PRODUCT_MODEL := ChurrOS

# Nivel de API mínimo que reconoce el código del producto
PRODUCT_SHIPPING_API_LEVEL := 34
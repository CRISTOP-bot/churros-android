# ChurrOS Android — descubrimiento de producto para taipei
#
# El sistema de build de AOSP SÓLO encuentra productos leyendo ficheros
# llamados AndroidProducts.mk en cualquier directorio del árbol. Sin este
# fichero, `lunch taipei` da "no build target found".
#
# Motorola moto g55 5G (codename taipei). Hereda del flavor churros.
#
# Ojo: aquí sólo vive PRODUCT_NAME. El resto de la definición del producto
# está en device.mk (y product.mk para los overrides de flavor).

PRODUCT_NAME := taipei

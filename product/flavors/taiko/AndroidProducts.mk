# ChurrOS Android — descubrimiento de producto para taiko
#
# El sistema de build de AOSP SÓLO encuentra productos leyendo ficheros
# llamados AndroidProducts.mk en cualquier directorio del árbol. Sin este
# fichero, `lunch churros-taiko` da "no build target found".
#
# Xiaomi Redmi Pad 2. Hereda del flavor de gama media y sólo declara aquí lo
# propio del hardware.
#
# Ojo: aquí sólo vive PRODUCT_NAME. El resto de la definición del producto
# está en device.mk (y product.mk para los overrides de flavor).

PRODUCT_NAME := churros-taiko
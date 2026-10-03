# ChurrOS Android — descubrimiento de producto para churros-lite
#
# El sistema de build de AOSP SÓLO encuentra productos leyendo ficheros
# llamados AndroidProducts.mk en cualquier directorio del árbol. Sin este
# fichero, `lunch churros-lite` da "no build target found".
#
# Gama baja (1-2 GB RAM). Dispositivos de 2015-2019.
#
# Ojo: aquí sólo vive PRODUCT_NAME. El resto de la definición del producto
# está en device.mk (y product.mk para los overrides de flavor).

PRODUCT_NAME := churros-lite

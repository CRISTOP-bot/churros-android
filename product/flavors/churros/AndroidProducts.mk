# ChurrOS Android — descubrimiento de producto para churros
#
# El sistema de build de AOSP SÓLO encuentra productos leyendo ficheros
# llamados AndroidProducts.mk en cualquier directorio del árbol. Sin este
# fichero, `lunch churros` da "no build target found".
#
# Gama media (4-6 GB RAM). Dispositivos de 2019-2022.
#
# Ojo: aquí sólo vive PRODUCT_NAME. El resto de la definición del producto
# está en device.mk (y product.mk para los overrides de flavor).

PRODUCT_NAME := churros

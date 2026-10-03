# ChurrOS Android — descubrimiento de producto para churros-pro
#
# El sistema de build de AOSP SÓLO encuentra productos leyendo ficheros
# llamados AndroidProducts.mk en cualquier directorio del árbol. Sin este
# fichero, `lunch churros-pro` da "no build target found".
#
# Gama alta (8+ GB RAM). Dispositivos de 2022 en adelante.
#
# Ojo: aquí sólo vive PRODUCT_NAME. El resto de la definición del producto
# está en device.mk (y product.mk para los overrides de flavor).

PRODUCT_NAME := churros-pro

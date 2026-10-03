# Cómo contribuir

## Antes de abrir un PR

```bash
./churros check    # debe salir con 0 fallos
shellcheck scripts/cli/*.sh churros
```

`check` valida el árbol de producto, la coherencia flavor ↔ init, el XML de los
manifests, la sintaxis de los scripts y que no haya props duplicadas dentro de
la misma rama condicional. Es lo mismo que corre en CI.

## Ramas

- Nunca commitees directamente en `main`.
- Una rama por tema: `feat/xxx`, `fix/xxx`, `docs/xxx`.
- Commits pequeños y con mensaje en español o inglés, pero en imperativo y
  explicando el porqué cuando no sea obvio.

## Dónde va cada cambio

| Cambio | Ubicación |
|---|---|
| Ajuste de compilación / props / bloat | `product/common/churros_base_vars.mk` |
| Tamaño de particiones | `product/common/churros_base.mk` |
| Comportamiento en arranque | `product/common/init/churros.rc` |
| Binario nativo nuevo | `native/*.c` + `scripts/cli/native.sh` + servicio en el rc |
| Dispositivo nuevo | `manifests/devices/*.xml` + `product/flavors/<flavor>/device.mk` |
| Parche de plataforma | `patches/*.patch` (un parche por fichero, nombre `<proyecto>-<qué>.patch`) |
| Script de CLI | `scripts/cli/<cmd>.sh` + entrada en `churros` + sección en `docs/02-arquitectura.md` |
| Documentación | `docs/`, en español |

## Reglas de los ajustes de optimización

Cada ajuste nuevo en `churros_base_vars.mk` o en el `init.rc` debe:

1. Estar justificado en `docs/03-optimizacion.md` con su efecto esperado.
2. Ser idempotente y no romper el arranque si falla (init: `2>/dev/null`,
   `some()` en vez de `on <ruta>`).
3. Ser specific de gama cuando el problema lo sea (`ifeq ($(CHURROS_TIER),...)`).
4. No tocar flags de CTS/VTS.
5. No requerir recompilar la plataforma para verificarse, salvo que el
   ajuste lo sea inherentemente — en cuyo caso va en `patches/`.

## Sobre device trees

Un device tree con blobs proprietary de otro fabricante tiene sus propias
licencias. Súbelo sólo si tienes derecho a redistribuirlo; si no, publica
`extract_files.sh` (el script que los extrae) y no los blobs.

## Spanish / inglés

Documentación en español. Código, nombres de función y comentarios de código
en inglés o español, pero consistentes dentro del archivo.
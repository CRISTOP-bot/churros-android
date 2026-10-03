#!/usr/bin/env bash
# Comprobaciones estáticas del repo. No necesita el árbol AOSP ni compilar.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."
REPO_DIR="$PWD"

OK=0
FAIL=0
ok()   { printf '  \033[1;32mOK\033[0m    %s\n' "$*"; OK=$((OK + 1)); }
bad()  { printf '  \033[1;31mFALLO\033[0m %s\n' "$*"; FAIL=$((FAIL + 1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$*"; }

echo "ChurrOS Android — check"

# --- Bash -----------------------------------------------------------------
head_ "Sintaxis bash"
while IFS= read -r f; do
  bash -n "$f" 2>/dev/null && ok "$f" || bad "$f"
done < <(find "$REPO_DIR/scripts" -name '*.sh' 2>/dev/null)
bash -n "$REPO_DIR/churros" && ok "churros" || bad "churros"

if command -v shellcheck >/dev/null 2>&1; then
  head_ "shellcheck (error)"
  while IFS= read -r f; do
    if shellcheck -S error -e SC1091 "$f" 2>/dev/null; then ok "$f"; else bad "$f"; fi
  done < <(find "$REPO_DIR/scripts" -name '*.sh' 2>/dev/null; printf '%s\n' "$REPO_DIR/churros")
fi

# --- XML ------------------------------------------------------------------
head_ "XML bien formado"
while IFS= read -r f; do
  if command -v xmllint >/dev/null 2>&1; then
    xmllint --noout "$f" 2>/dev/null && ok "$(basename "$f")" || bad "$(basename "$f")"
  else
    python3 -c "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])" "$f" 2>/dev/null \
      && ok "$(basename "$f")" || bad "$(basename "$f")"
  fi
done < <(find "$REPO_DIR/manifests" -name '*.xml')

# --- Árvore de producto ---------------------------------------------------
head_ "Árbol de producto"
for f in product/common/AndroidProducts.mk \
         product/common/churros_base.mk \
         product/common/churros_base_vars.mk \
         product/common/churros_base_init.mk; do
  [ -f "$REPO_DIR/$f" ] && ok "$f existe" || bad "$f falta"
done

for tier in churros-lite churros churros-pro; do
  for f in device.mk product.mk; do
    p="$REPO_DIR/product/flavors/$tier/$f"
    [ -f "$p" ] && ok "$tier/$f" || bad "$tier/$f falta"
  done
  grep -q 'inherit-product.*AndroidProducts.mk' "$REPO_DIR/product/flavors/$tier/device.mk" \
    && ok "$tier hereda de common" || bad "$tier no hereda de product/common"
  grep -q "PRODUCT_NAME := $tier" "$REPO_DIR/product/flavors/$tier/device.mk" \
    && ok "$tier PRODUCT_NAME coherente" || bad "$tier PRODUCT_NAME incoherente"
done

head_ "Coherencia flavor ↔ init"
for tier in churros-lite churros churros-pro; do
  want=$(case "$tier" in churros-lite) echo lowend ;; churros) echo mid ;; churros-pro) echo high ;; esac)
  grep -q "ro.churros.tier=$want" "$REPO_DIR/product/flavors/$tier/device.mk" \
    && ok "$tier declara tier=$want" || bad "$tier no declara ro.churros.tier=$want"
  grep -q "ifeq (\$(CHURROS_TIER),$want)" "$REPO_DIR/product/common/churros_base_vars.mk" \
    && ok "$want optimizaciones en churros_base_vars.mk" || bad "falta bloque de optimización para $want"
done

# --- Props duplicadas -----------------------------------------------------
head_ "Propiedades de sistema duplicadas"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$REPO_DIR/product" <<'PY' && ok "sin props duplicadas" || bad "props duplicadas (ver arriba)"
import re, sys, pathlib
# Las ramas ifeq de los flavors son excluyentes entre sí: sólo se consideran
# duplicadas dos props dentro de la MISMA rama condicional.
cond = re.compile(r'^\s*(ifeq|ifneq|ifdef|ifndef|else|endif)\b')
prop = re.compile(r'^\s*([a-z][a-z0-9._]+)\s*=\s*\S+')
dup = []
for f in pathlib.Path(sys.argv[1]).rglob('*.mk'):
    scope, seen = 0, set()
    for line in f.read_text().splitlines():
        if cond.match(line):
            scope += 1
            seen = set()
            continue
        m = prop.match(line)
        if m and '.' in m.group(1):
            key = m.group(1)
            if key in seen:
                dup.append(f"{key} repetido en {f} (rama {scope})")
            seen.add(key)
print("\n".join(dup))
sys.exit(1 if dup else 0)
PY
else
  ok "omitido (sin python3)"
fi

# --- init rc --------------------------------------------------------------
head_ "init rc"
RC="$REPO_DIR/product/common/init/churros.rc"
[ -f "$RC" ] && ok "churros.rc existe" || bad "churros.rc falta"
if [ -f "$RC" ]; then
  grep -q 'churros.rc:$(TARGET_COPY_OUT_PRODUCT)/etc/init/churros.rc' "$REPO_DIR/product/common/churros_base_init.mk" \
    && ok "churros.rc se copia a /system/etc/init" || bad "churros.rc no se copia a la imagen"
  awk '/^service /{print $2}' "$RC" | sort -u >/tmp/churros-svc.$$ 2>/dev/null || true
  ok "services: $(tr '\n' ' ' </tmp/churros-svc.$$ 2>/dev/null)"
  rm -f /tmp/churros-svc.$$
fi

# --- Nativo ---------------------------------------------------------------
head_ "Binarios nativos"
for f in "$REPO_DIR"/native/*.c; do
  [ -e "$f" ] || continue
  if command -v gcc >/dev/null 2>&1; then
    gcc -fsyntax-only -Wall "$f" 2>/dev/null && ok "$(basename "$f")" || bad "$(basename "$f") no compila"
  else
    ok "$(basename "$f") (omitido: sin gcc)"
  fi
done
# Cada servicio del rc debe tener un binario o ser un script del sistema
if [ -f "$RC" ]; then
  for svc in $(awk '/^service /{print $3}' "$RC"); do
    [ -n "$svc" ] || continue
    bin=$(basename "$svc")
    grep -q "$bin" "$REPO_DIR/product/common/churros_base_init.mk" \
      && ok "servicio $bin declarado en churros_base_init.mk" \
      || printf '  \033[1;33mAVISO\033[0m servicio %s sin binario declarado\n' "$bin"
  done
fi

# --- Prebuilts referenciados ---------------------------------------------
head_ "Binarios referenciados por PRODUCT_COPY_FILES"
for arch in arm64-v8a armeabi-v7a; do
  for b in churros_lmkd_tuner churros_zramd; do
    p="$REPO_DIR/prebuilts/bin/$arch/$b"
    [ -f "$p" ] && ok "$arch/$b" || printf '  \033[1;33mPENDIENTE\033[0m %s (./churros native)\n' "$arch/$b"
  done
done

# --- No UTF-8-NC en código ------------------------------------------------
head_ "Codificación"
if grep -rlP '[\x{3000}-\x{9FFF}\x{FF00}-\x{FFEF}]' "$REPO_DIR/scripts" "$REPO_DIR/product" "$REPO_DIR/docs" "$REPO_DIR/native" "$REPO_DIR/churros" 2>/dev/null | grep -q .; then
  bad "caracteres CJK fuera de lugar en el código:"
  grep -rlP '[\x{3000}-\x{9FFF}\x{FF00}-\x{FFEF}]' "$REPO_DIR/scripts" "$REPO_DIR/product" "$REPO_DIR/native" "$REPO_DIR/churros" 2>/dev/null | sed 's/^/        /'
else
  ok "sin caracteres CJK en código"
fi

# --- Docs -----------------------------------------------------------------
head_ "Documentación"
for d in README.md \
         CONTRIBUTING.md \
         docs/01-entorno-arch.md \
         docs/02-arquitectura.md \
         docs/03-optimizacion.md \
         docs/04-dispositivos.md \
         docs/05-flashing.md \
         docs/06-roadmap.md; do
  [ -f "$REPO_DIR/$d" ] && ok "$d" || bad "$d falta"
done

# Todos los documentos del índice deben existir
head_ "Índice del README"
if [ -f "$REPO_DIR/README.md" ]; then
  while IFS= read -r link; do
    [ -f "$REPO_DIR/$link" ] && ok "README -> $link" || bad "README enlaza a $link pero no existe"
  done < <(grep -oP '\]\(\K[^)#]+(?=\))' "$REPO_DIR/README.md" | grep -v '^https\?://')
fi

# --- Repo ----------------------------------------------------------------
head_ "Higiene del repo"
for f in LICENSE .editorconfig .github/workflows/check.yml; do
  [ -f "$REPO_DIR/$f" ] && ok "$f" || bad "$f falta"
done
if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)
  [ "$BRANCH" = "main" ] && printf '  \033[1;33mAVISO\033[0m estás en main; usa una rama\n' \
                        || ok "rama actual: $BRANCH"
else
  printf '  \033[1;33mAVISO\033[0m no es un repositorio git\n'
fi

echo
printf 'Resumen: %d OK, %d fallos\n' "$OK" "$FAIL"
[ "$FAIL" -eq 0 ]
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

# Cada subcomando del dispatcher debe tener su script
head_ "Dispatcher"
# Cada línea "cmd|alias)  exec bash <ruta>" debe apuntar a un script existente.
while read -r cmd script; do
  [ -n "$cmd" ] || continue
  target="$REPO_DIR/$script"
  if [ ! -f "$target" ]; then
    bad "$cmd no tiene $script"
  elif bash -n "$target" 2>/dev/null; then
    ok "$cmd -> $script"
  else
    bad "$script no es bash válido"
  fi
done < <(awk '/exec bash/ {
    match($0, /^[[:space:]]*[a-z|]+/); cmds = substr($0, RSTART, RLENGTH)
    match($0, /scripts\/[a-zA-Z0-9\/._-]+/); script = substr($0, RSTART, RLENGTH)
    n = split(cmds, a, /[|[:space:]]+/)
    for (i = 1; i <= n; i++) if (a[i] != "") print a[i], script
  }' "$REPO_DIR/churros")

if command -v shellcheck >/dev/null 2>&1; then
  head_ "shellcheck (error)"
  while IFS= read -r f; do
    if shellcheck -S error -e SC1091 "$f" 2>/dev/null; then ok "$f"; else bad "$f"; fi
  done < <(find "$REPO_DIR/scripts" -name '*.sh' 2>/dev/null)
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

head_ "Manifests: proyectos y remotos"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$REPO_DIR/manifests" <<'PY' && ok "proyectos sin path duplicado y remotos declarados" || bad "manifests con problemas (ver arriba)"
import sys, pathlib, xml.etree.ElementTree as ET
base = pathlib.Path(sys.argv[1])
main = ET.parse(base / 'default.xml').getroot()
remotes = {r.get('name') for r in main.findall('remote')}
problems = []
seen_paths = {}
for f in sorted(base.rglob('*.xml')):
    root = ET.parse(f).getroot()
    for pr in root.findall('project'):
        path, name = pr.get('path'), pr.get('name')
        remote = pr.get('remote')
        if not path or not name:
            problems.append(f"{f.name}: <project> sin path/name")
        # El mismo path puede aparecer en manifests de gamas distintas (sólo
        # se sincroniza uno de ellos). Lo raro es que apunte a otro repo.
        if path in seen_paths and seen_paths[path][0] != name:
            problems.append(f"{path} apunta a {seen_paths[path][0]} y a {name}")
        seen_paths[path] = (name, f.name)
        if remote and remote not in remotes:
            problems.append(f"{f.name}: remote '{remote}' no declarado en default.xml")
print("\n".join(problems))
sys.exit(1 if problems else 0)
PY
else
  ok "omitido (sin python3)"
fi

# --- Árvore de producto ---------------------------------------------------
head_ "Árbol de producto"
for f in product/common/AndroidProducts.mk \
         product/common/churros_base.mk \
         product/common/churros_base_vars.mk \
         product/common/churros_base_init.mk; do
  [ -f "$REPO_DIR/$f" ] && ok "$f existe" || bad "$f falta"
done

# Sin AndroidProducts.mk AOSP no encuentra el producto y `lunch` falla.
head_ "Descubrimiento de productos (AndroidProducts.mk)"
while IFS= read -r fdir; do
  name=$(basename "$fdir")
  ap="$fdir/AndroidProducts.mk"
  if [ ! -f "$ap" ]; then
    bad "$name no tiene AndroidProducts.mk (lunch $name no lo encontraría)"
    continue
  fi
  # Un flavor de gama se llama igual que su directorio; uno de dispositivo
  # lleva el prefijo churros- (churros-taiko para el directorio taiko).
  if grep -qE "^PRODUCT_NAME := ($name|churros-$name)$" "$ap"; then
    ok "$name declara PRODUCT_NAME en AndroidProducts.mk"
  else
    bad "$name: PRODUCT_NAME no coincide con el directorio (ni $name ni churros-$name)"
  fi
done < <(find "$REPO_DIR/product/flavors" -mindepth 1 -maxdepth 1 -type d | sort)

# Cada manifest de dispositivo debe tener su flavor, y viceversa.
head_ "Manifests de dispositivo ↔ flavors"
for m in "$REPO_DIR"/manifests/devices/*.xml; do
  base=$(basename "$m" .xml)
  [ -d "$REPO_DIR/product/flavors/$base" ] \
    && ok "manifest $base -> product/flavors/$base" \
    || printf '  \033[1;33mAVISO\033[0m manifest %s sin flavor propio (puede usar un flavor de gama)\n' "$base"
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

# Flavors de dispositivo: heredan de un flavor de gama y deben acabar
# declarando ro.churros.tier en algún punto de la cadena.
head_ "Herencia de flavors de dispositivo"
for fdir in "$REPO_DIR"/product/flavors/*/; do
  name=$(basename "$fdir")
  case "$name" in churros-lite|churros|churros-pro) continue ;; esac
  dk="$fdir/device.mk"
  if ! grep -qE 'inherit-product.*product/flavors/[a-z-]+/device\.mk' "$dk"; then
    bad "$name no hereda de un flavor de gama"
    continue
  fi
  parent=$(sed -n 's|.*product/flavors/\([a-z0-9-]*\)/device\.mk.*|\1|p' "$dk" | head -1)
  [ -f "$REPO_DIR/product/flavors/$parent/device.mk" ] \
    && ok "$name hereda de $parent" || bad "$name hereda de $parent, que no existe"

  # ro.churros.tier puede estar en el propio device.mk o heredado
  if grep -q "ro.churros.tier=" "$dk" \
     || grep -rq "ro.churros.tier=" "$REPO_DIR/product/flavors/$parent/"; then
    ok "$name declara ro.churros.tier (propio o heredado)"
  else
    bad "$name no termina declarando ro.churros.tier"
  fi
done

head_ "Coherencia flavor ↔ init"
for tier in churros-lite churros churros-pro; do
  want=$(case "$tier" in churros-lite) echo lowend ;; churros) echo mid ;; churros-pro) echo high ;; esac)
  grep -q "ro.churros.tier=$want" "$REPO_DIR/product/flavors/$tier/device.mk" \
    && ok "$tier declara tier=$want" || bad "$tier no declara ro.churros.tier=$want"
  grep -q "ifeq (\$(CHURROS_TIER),$want)" "$REPO_DIR/product/common/churros_base_vars.mk" \
    && ok "$want optimizaciones en churros_base_vars.mk" || bad "falta bloque de optimización para $want"
done

# --- Flavors de dispositivo ----------------------------------------------
head_ "Flavors de dispositivo"
for d in "$REPO_DIR"/product/flavors/*/; do
  name=$(basename "$d")
  case "$name" in
    churros-lite|churros|churros-pro) continue ;;  # ya validados arriba
  esac
  [ -f "$d/device.mk" ]   && ok "$name/device.mk"   || bad "$name/device.mk falta"
  [ -f "$d/product.mk" ]  && ok "$name/product.mk"  || bad "$name/product.mk falta"
  [ -f "$d/AndroidProducts.mk" ] \
    && ok "$name/AndroidProducts.mk" || bad "$name sin AndroidProducts.mk (lunch no lo encuentra)"

  # Hereda de un flavor de gama existente
  parent=$(sed -n 's|.*product/flavors/\([a-z0-9-]*\)/device\.mk.*|\1|p' "$d/device.mk" | head -1)
  if [ -n "$parent" ] && [ -f "$REPO_DIR/product/flavors/$parent/device.mk" ]; then
    ok "$name hereda del flavor $parent"
  else
    bad "$name no hereda de un flavor de gama existente (parent='${parent:-ninguno}')"
  fi

  grep -q "^PRODUCT_NAME := churros-$name$" "$d/device.mk" \
    && ok "$name PRODUCT_NAME coherente" || bad "$name PRODUCT_NAME incoherente"

  # ro.churros.tier puede declararse aquí o heredarse del flavor de gama
  if grep -q "ro.churros.tier=" "$d/device.mk" \
     || { [ -n "$parent" ] && grep -rq "ro.churros.tier=" "$REPO_DIR/product/flavors/$parent/"; }; then
    ok "$name resuelve ro.churros.tier"
  else
    bad "$name no termina declarando ro.churros.tier"
  fi

  # Un dispositivo sin documento de referencia es la via a horas perdidas.
  # Se busca docs/<NN>-*-<name>.md para no tener una lista hardcodeada aqui.
  doc=$(find "$REPO_DIR/docs" -maxdepth 1 -name "*-$name.md" | sort | head -1)
  if [ -n "$doc" ]; then
    ok "$name documentado en docs/$(basename "$doc")"
  else
    printf '  \033[1;33mAVISO\033[0m %s sin documento en docs/*-%s.md (se pierde el contexto del hw)\n' "$name" "$name"
  fi
done

# Nada de datos de GPU en el producto comun: eso depende del dispositivo.
head_ "El producto comun no declara datos de GPU"
if grep -v '^[[:space:]]*#' "$REPO_DIR/product/common/churros_base_vars.mk" | grep -q 'ro.hardware.egl'; then
  bad "ro.hardware.egl esta en churros_base_vars.mk; es dato del dispositivo (PowerVR/Adreno/Mali)"
else
  ok "ro.hardware.egl solo en flavors de dispositivo"
fi

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
         docs/06-roadmap.md \
         docs/07-medicion.md; do
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
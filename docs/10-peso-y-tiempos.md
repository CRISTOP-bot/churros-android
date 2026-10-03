# 10 — Peso y tiempos de compilación

Los dos objetivos cuantificables del proyecto. Este documento lista cada
ajuste, qué cuesta y cómo se mide.

## Cómo se mide (no te lo creas si no lo has medido)

```bash
./churros build --lunch churros --tier mid    # build 1 (con ajustes)
./churros analyze                              # peso y tiempos
./churros build --lunch churros --tier mid --make-arg m
./churros analyze --compare                    # build 2 vs build 1
```

`build.sh` anota cada build en `out/churros-build-stats.tsv` con fecha,
producto, resultado, segundos, jobs, aciertos de ccache, commit y los valores
de `dex` y `-O`. `analyze.sh` lee ese histórico y el peso de las imágenes. Para
ver qué ocupa el sitio dentro de `/system` usa `./churros analyze --big 30`
(convierte la imagen sparse con el `simg2img` del propio árbol y la lista con
`7z`; si no hay `7z`, cae a listar los intermedios de `obj/`).

**Toda cifra de este documento es una estimación con nombre hasta que haya un
build real detrás.** La columna "medido" se rellena con `./churros analyze`.

## 1. Peso de la imagen

### 1.1 Recorte de bloat — el bloque que más pesa

Quitar una app no sólo borra su APK: borra su dex optimizado, su `idmap`, sus
recursos, sus permisos en `framework-res`, sus entradas en los manifiestos y su
trabajo de `aapt2`. La lista está en el bloque 5 de
`churros_base_vars.mk`, agrupada por motivo:

| Grupo | Paquetes | Por qué |
|---|---|---|
| 5.1 Apps que AOSP trae y nadie usa | Email, Exchange2, Messaging, People, QuickSearchBox, VoiceDialer, DeskClock, Calendar, CalendarProvider, DataUsage, DataRestore, DocumentsUI, WallpaperPicker, PhotoTable, QuickAccessWalletProxy, EmergencyInfo2, GoogleTts, LiveWallpapers, SoundRecorder, Simulator, SafetyCenter, Wellbeing, BackupRestoreConfirmation | Es el mayor bloque quitable. En AOSP puro, Email y Exchange sonapps vacías: el cliente IMAP real está en Gmail, que no existe aquí. |
| 5.2 Ingeniería | CtsShim, CtsPackageVerifier, CtsPackageVerifierSetup, VtsHalVerifier, SyntheticLauncher, TraceLauncherApp, DevelopmentSettings | Sólo existen para CTS/VTS y desarrollo. En un build de usuario son peso muerto. |
| 5.3 Impresión | PrintSpooler, PrintFramework, BuiltInPrintService | Tres paquetes para una función opcional que compite por memoria con la radio. |
| 5.4 Red | FusedLocationProvider | Mantiene un servicio permanente y wakelocks. El GPS puro sigue funcionando. |

El bloque 5.5 deja commented lo más agresivo (`Bluetooth`, `Tethering`,
`SoftwareRenderer`, `WallpaperManager`, `VpnDialogs`) con una instrucción
explícita: **quitar de uno en uno y midiendo, nunca de golpe**.

El bloque 5.6 explica por qué **no** se tocan los APEX: son dependencias
declaradas de otros módulos y quitar uno a mano rompe el grafo de build. Los
que de verdad sobran (`sdksandbox`, `virt`) se quitan desde el device tree.

### 1.2 R8 en modo completo

```makefile
PRODUCT_R8_MIN_API_LEVEL := 30     # 26 en gama baja: optimiza más código
PRODUCT_R8_DEFAULT_DEBUG_MODE := false
PRODUCT_R8_RELEASE_MODE := true
```

R8 shrika, optimiza y elimina código muerto. Sin perfiles de arranque por
defecto, porque en una distro sin GAPPS no hay apps de terceros que intentar
abarcar. Ahorra del orden de 30-40 MB y reduce el trabajo de verificación en
arranque.

### 1.3 Modo de preoptimización de dex

```makefile
CHURROS_DEX_MODE ?= speed   # o verify, con ./churros build --dex-mode verify
PRODUCT_DEX_PREOPT_IMAGE_MODE := $(CHURROS_DEX_MODE)
```

- `speed`: precompila las apps del sistema con perfil de arranque. Arranque más
  rápido, **5-8 MB más** de imagen.
- `verify`: sólo verifica. Imagen más pequeña, arranque algo más lento.

Se elige `speed` por defecto porque el arranque es lo que nota el usuario. En
gama baja con 4 GB de RAM el criterio puede ser el otro; se cambia con
`--dex-mode verify`, sin tocar el repo.

### 1.4 Tamaño de las particiones

`PRODUCT_SYSTEM_SIZE = 2 GiB` en `churros_base.mk`. Es holgado para un AOSP
puro ya recortado (el uso real ronda 1 GiB), y se deja así a propósito:
`mkuserimg` reserva espacio para el growth del OTA y los device trees pueden
añadir APEX del fabricante. Bajarlo ahorra unos cientos de MB en el
`super.img`, pero el primer `lunch` que se pase por poco es una tarde perdida.
Si el espacio es el problema real, se baja; no antes de tener una build que
arranque.

## 2. Tiempo de compilación

### 2.1 Lo que de verdad cuesta tiempo

Por orden de impacto en un build completo:

1. **Los locales.** `PRODUCT_LOCALES := en es` en lugar de los ~90 de AOSP. Cada
   idioma son varios MB de traducciones en `framework-res.apk`, `Settings`,
   SystemUI, y una copia por app. Es el ahorro más grande y más fácil de este
   bloque.
2. **Las apps que no se instalan.** El bloque 5 de arriba. Una app que se quita
   no se compila: no hay `aapt2`, ni `javac`, ni `d8`, ni `dex2oat`, ni enlazado.
3. **Sin dex por módulo** (`PRODUCT_DEX_PREOPT_FOR_MODULE := false`): por módulo
   significa lanzar `dex2oat` una vez por app; la imagen lo hace de una vez.
4. **Sin Baseline Profiles** (`PRODUCT_BASELESS_PROFILE := true`): R8 y `dex2oat`
   no arrancan la JVM del perfil por app.
5. **`-O2` en vez de `-O3`** (`CHURROS_OPT_LEVEL`, por defecto 2). El nivel se
   define **una sola vez**, en el bloque 7. Compilar miles de unidades de
   traducción en `-O3` cuesta tiempo y el margen frente a `-O2` en código ya
   pequeño es pequeño. El build de rendimiento final se hace con
   `--opt-level 3` y se mide.
6. **Sin imagen ART** (`PRODUCT_ART_USE_APEX_PORT_IMAGE`): es de las piezas más
   caras de producir. Está **comentado** porque su ganancia sólo se ve en gama
   baja con muchas apps instaladas, que no es el caso de una distro sin GAPPS.
   Descomentar sólo con una medición detrás.

### 2.2 CTS/VTS fuera del build de usuario

```makefile
PRODUCT_PACKAGES -= CtsShimPriv VtsHalTest
```

Las pruebas en Java son una porción grande del build. Se quitan por producto,
no parcheando la plataforma. Si necesitas correr CTS, quita esas dos líneas:
sin ellas no hay forma de validar que el port sigue siendo correcto.

### 2.3 Lo que no se toca, y por qué

- **`-flto=thin` / ThinLTO**: ya es el default de Clang en Soong. Activarlo a
  mano sólo crea conflictos.
- **`BUILD_BROKEN_*`**: ninguno de esos flags existe hoy; todos fueron
  workarounds de ramas antiguas que ya no aplican.
- **`-Wno-*` para silenciar avisos**: no acelera nada; sólo esconde
  información.
- **`ccache`**: ya lo usa `build.sh` (`USE_CCACHE=1`). Es la palanca más
  rentable que existe: la segunda build con el mismo código es varias veces más
  rápida. `analyze.sh` muestra los aciertos por build.

## 3. Los tres compromisos que asumo

1. **Un build de desarrollo no es un build de rendimiento.** El producto por
   defecto optimiza para ciclo de trabajo rápido. Para medir rendimiento real
   hay que compilar con `--opt-level 3` y comparar contra el mismo código con
   `--opt-level 2`.
2. **Menos locales es menos ROM.** `en es` es una decisión de producto, no una
   optimización técnica. Si hace falta, el finés se añade a `PRODUCT_LOCALES`
   con el coste correspondiente.
3. **Cero apps de terceros es cero funciones.** Quitar `Email` es ganar 60 MB
   y perder leer correo IMAP. En una distro minimalista es el trato, pero es un
   trato: `PRODUCT_PACKAGES +=` lo devuelve.

## 4. Verificación de los nombres de variable

Desde AOSP 10 aproximadamente `build/make` dejó de registrar cada variable
`PRODUCT_*`: sólo las que tienen semántica especial (herencia, valor único o
lista). El resto se leen directamente en el módulo que las usa. La consecuencia
es incómoda: **un nombre mal escrito no rompe el build, se ignora en
silencio**. El ajuste no hace nada y nadie se entera hasta que se buscan los
efectos y no aparecen.

Por eso `check.sh` valida cada `PRODUCT_*` del producto contra el árbol AOSP
real:

```bash
./churros check                              # sin árbol: dice que se omite
SRC_DIR=~/android/churros ./churros check    # con árbol: las valida una a una
```

Las 29 variables que usa el producto ahora mismo son:

```
PRODUCT_AVB_OTA_DISABLE, PRODUCT_BASELESS_PROFILE, PRODUCT_BRAND,
PRODUCT_BUILD_PROP_OVERRIDES, PRODUCT_COMPRESS_EXECUTABLES, PRODUCT_COPY_FILES,
PRODUCT_DEVICE, PRODUCT_DEX_PREOPT_ART_IMAGE, PRODUCT_DEX_PREOPT_FOR_MODULE,
PRODUCT_DEX_PREOPT_IMAGE_MODE, PRODUCT_GLOBAL_CFLAGS, PRODUCT_GLOBAL_CXXFLAGS,
PRODUCT_LOCALES, PRODUCT_MANUFACTURER, PRODUCT_MODEL, PRODUCT_NAME,
PRODUCT_PACKAGES, PRODUCT_R8_DEFAULT_DEBUG_MODE, PRODUCT_R8_MIN_API_LEVEL,
PRODUCT_R8_RELEASE_MODE, PRODUCT_RELEASE_NAME, PRODUCT_SHIPPING_API_LEVEL,
PRODUCT_SYSTEM_PROPERTIES, PRODUCT_SYSTEM_SIZE, PRODUCT_USERDATA_SIZE,
PRODUCT_USE_SOONG_NOTICE, PRODUCT_VENDOR_CFLAGS, PRODUCT_VENDOR_CXXFLAGS,
PRODUCT_VENDOR_SIZE
```

Las dos con más riesgo de estar mal escritas, por ser las menos conocidas,
son `PRODUCT_BASELESS_PROFILE` y `PRODUCT_DEX_PREOPT_ART_IMAGE`. Si el check
las marca contra el árbol real, se quitan o se sustituyen por su equivalente
verificado. Este documento no las da por buenas: por eso existe el check.

## 5. Cómo añadir un ajuste nuevo

1. Añádelo en el bloque que corresponda (3 peso / 7 tiempo).
2. Anota aquí el efecto esperado y por qué es seguro.
3. `./churros check` (los checks de bloat y de props duplicados cubren la
   mayoría de los errores de este tipo).
4. Build, `analyze --compare`, y rellena la columna "medido".
5. Si no se puede medir, no entra: se queda en un parche en `patches/` para
   cuando haya máquina de build.
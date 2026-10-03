# ChurrOS Android — variables de build y optimización.
#
# Se incluye desde churros_base.mk. Define el "contrato" entre los scripts de
# build y el producto. Nada de lógica complicated aquí: los valores vienen de
# variables de entorno exportadas por scripts/cli/build.sh, con defaults
# seguros para que un `lunch` manual siga funcionando.

CHURROS_TIER ?= mid
CHURROS_BUILD_TYPE ?= userdebug
CHURROS_TARGET ?= aosp_arm64

# Cuánto se sacrifica de tamaño a cambio de arranque rápido.
#   speed   -> dex "speed" profile para apps del sistema: arranque más rápido,
#              ~5-8 MB más de /system
#   verify  -> "verify": sólo verifica el arranque, imagen más pequeña
CHURROS_DEX_MODE ?= speed

ifeq ($(CHURROS_BUILD_TYPE),eng)
  CHURROS_DEBUG := true
else
  CHURROS_DEBUG := false
endif

# -----------------------------------------------------------------------------
# 1. Flags de compilación del código nativo
# -----------------------------------------------------------------------------
# El nivel de optimización vive en el bloque 7 (tiempo de compilación), junto
# al resto de las palancas de build, porque es una decisión con dos caras:
# -O3 da código más rápido, -O2 compila antes. Aquí se define una sola vez.

# -----------------------------------------------------------------------------
# 2. Dex / ART / R8
# -----------------------------------------------------------------------------
# R8 full mode: shrunk, optimizado, y sin el profile de arranque por defecto
# -> reduce dex e instrucciones. Ahorra ~30-40 MB y arranca más rápido.
PRODUCT_R8_MIN_API_LEVEL := 30
PRODUCT_R8_DEFAULT_DEBUG_MODE := false
PRODUCT_R8_RELEASE_MODE := true

# Compile sólo las apps del sistema (no de terceros) y sin perfiles dinámicos
PRODUCT_DEX_PREOPT_FOR_MODULE := false

# -----------------------------------------------------------------------------
# 3. Peso: dex, compresión e imágenes
# -----------------------------------------------------------------------------
# "speed" precompila las apps del sistema con perfil de arranque; "verify"
# sólo las verifica. La diferencia son 5-8 MB de /system y varios segundos de
# arranque. Por defecto se elige arranque rápido porque es lo que nota el
# usuario; pon CHURROS_DEX_MODE=verify si el espacio en disco es lo que aprieta.
PRODUCT_DEX_PREOPT_IMAGE_MODE := $(CHURROS_DEX_MODE)

# Los binarios del sistema (los de /system/bin) se comprimen con xz al
# empaquetar. Consome CPU al boot, una vez. Los de /vendor no: ya vienen
# comprimidos y descomprimirlos en cada lectura de un binario enlazado es
# peor negocio.
PRODUCT_COMPRESS_EXECUTABLES := true

# No se generan las dex optimizadas "de paquete" para apps de terceros: aquí
# sólo hay apps del sistema, y compilarlas dos veces duplica el trabajo.
PRODUCT_DEX_PREOPT_ART_IMAGE := false

# -----------------------------------------------------------------------------
# 4. Propiedades de sistema comunes a toda la gama
# -----------------------------------------------------------------------------
PRODUCT_SYSTEM_PROPERTIES += \
    ro.build.description=ChurrOS \
    ro.debuggable=0 \
    persist.sys.strictmode.disable=true \
    debug.sqlite.wal.syncmode=NORMAL \
    debug.sqlite.wal.checkpoints=1 \
    log.tag.SurfaceFlinger=ERROR \
    ro.hardware=churros

# -----------------------------------------------------------------------------
# 5. Peso: recorte de bloat
# -----------------------------------------------------------------------------
# Se quitan paquetes que AOSP incluye por defecto pero que casi nadie usa.
# Cada línea está justificada en docs/03-optimizacion.md, y el resultado medido
# con ./churros analyze está en docs/10-peso-y-tiempos.md.
#
# OJO: sólo se quita lo que existe en AOSP. Si un nombre no aparece en el
# build, el PRODUCT_PACKAGES -= no hace nada (no falla), pero indicaría que la
# lista está desactualizada. ./churros check lo avisa.
# --- 5.1 Aplicaciones que AOSP trae y casi nadie usa ------------------------
# Son las más grandes: Email+Exchange sólo contienen la app vacía (el cliente
# IMAP está en Gmail, que no está aquí). Es el mayor bloque de peso quitable.
PRODUCT_PACKAGES -= \
    Email \
    Exchange2 \
    Messaging \
    People \
    QuickSearchBox \
    VoiceDialer \
    DeskClock \
    Calendar \
    CalendarProvider \
    DataUsage \
    DataRestore \
    DocumentsUI \
    WallpaperPicker \
    PhotoTable \
    QuickAccessWalletProxy \
    EmergencyInfo2 \
    GoogleTts \
    LiveWallpapers \
    SoundRecorder \
    Simulator \
    SafetyCenter \
    Wellbeing \
    BackupRestoreConfirmation

# --- 5.2 Pruebas y utilidades de ingenieria ---------------------------------
# CtsShim + los verificadores de paquete son APKs grandes que sólo existen
# para CTS/VTS, y no sirven de nada en un build de usuario.
PRODUCT_PACKAGES -= \
    CtsShim \
    CtsPackageVerifier \
    CtsPackageVerifierSetup \
    VtsHalVerifier \
    SyntheticLauncher \
    TraceLauncherApp \
    DevelopmentSettings

# --- 5.3 Impresión ----------------------------------------------------------
# Tres paquetes para una función que la mayoría no usa y que en gama baja
# compite por memoria con la radio.
PRODUCT_PACKAGES -= \
    PrintSpooler \
    PrintFramework \
    BuiltInPrintService

# --- 5.4 Localización de red ------------------------------------------------
# El proveedor de ubicación fusionada mantiene wakelocks y un servicio
# permanente; sin él sigue funcionando el GPS puro.
PRODUCT_PACKAGES -= \
    FusedLocationProvider

# --- 5.5 Módulos grandes de AOSP, opcional (descomenta con criterio) --------
# Cada uno de estos se ha quitado de builds de ROMs reales, pero todos tienen
# dependencias: quítalos de uno en uno y midiendo, nunca de golpe.
#
#   PRODUCT_PACKAGES -= Bluetooth        # gama baja sin BT (ver bloque 6)
#   PRODUCT_PACKAGES -= Tethering       # sin compartir conexión
#   PRODUCT_PACKAGES -= SoftwareRenderer # sin fallback GL por software
#   PRODUCT_PACKAGES -= WallpaperManager  # sin servicio de fondos de pantalla
#   PRODUCT_PACKAGES -= VpnDialogs       # sin soporte de VPN

# --- 5.6 APEX: aquí NO se tocan ---------------------------------------------
# Los APEX (com.android.art, com.android.runtime, com.android.bts,
# com.android.os, com.android.tzdata, com.android.virt...) son dependencias
# declaradas de otros módulos: quitar uno a mano rompe el grafo de build y no
# ahorra tanto. Los que de verdad sobran (sdksandbox, virt) se quitan desde el
# device tree, que es quien conoce las dependencias del dispositivo.

# -----------------------------------------------------------------------------
# 6. Ajustes por gama
# -----------------------------------------------------------------------------
# OJO: aquí NO va ro.hardware.egl ni nada de la GPU. Eso es dato del
# dispositivo (Adreno, Mali, PowerVR...) y va en el device tree / flavor del
# dispositivo. Ver product/flavors/taipei/device.mk para un ejemplo real.
ifeq ($(CHURROS_TIER),lowend)

  # Dispositivos de 1-2 GB: modo low-ram, sin multitasking, procesos limitados
  PRODUCT_SYSTEM_PROPERTIES += \
      ro.config.low_ram=true \
      ro.config.low_ram.enable=true \
      dalvik.vm.heapgrowthlimit=128m \
      dalvik.vm.heapstartsize=8m \
      dalvik.vm.heapsize=192m \
      ro.zygote.preloadsize_hint=48m \
      persist.sys.low_ram=true \
      ro.config.avoid_gfx_acceleration=false

  # Sin apps que consumen batería sin necesidad. PrintSpooler no aparece aquí
  # porque ya se quita para toda la distro en el bloque 5.3.
  PRODUCT_PACKAGES -= \
      Bluetooth \
      NFC \
      NFCNci \
      Tethering \
      SoftwareRenderer

  PRODUCT_R8_MIN_API_LEVEL := 26

else ifeq ($(CHURROS_TIER),mid)

  # Gama media: los defaults de ART ya son razonables; sólo se acota el heap
  # para que una app runaway no deje sin memoria a las demás, y se sube el
  # read-ahead de forma implícita vía init rc.
  PRODUCT_SYSTEM_PROPERTIES += \
      dalvik.vm.heapgrowthlimit=256m \
      dalvik.vm.heapsize=512m \
      persist.sys.low_ram=false

else ifeq ($(CHURROS_TIER),high)

  # Gama alta: ART con más margen, GPU siempre disponible
  PRODUCT_SYSTEM_PROPERTIES += \
      dalvik.vm.heapgrowthlimit=512m \
      dalvik.vm.heapsize=1024m \
      debug.stagefright.caching_enabled=true

endif

# -----------------------------------------------------------------------------
# 7. Tiempo de compilación
# -----------------------------------------------------------------------------
# Un build completo de AOSP son 4-12 h. Estos ajustes lo bajan sin tocar una
# línea de código de la plataforma, sólo el producto. El impacto medido está
# en docs/10-peso-y-tiempos.md.

# 7.1 Nada de dex2oat por módulo (sólo el de imagen). Por módulo significa
#     lanzar dex2oat N veces para N apps; la imagen ya lo hace de una vez.
PRODUCT_DEX_PREOPT_FOR_MODULE := false

# 7.2 Sin perfiles dinámicos de la basal: R8 y dex2oat no arrancan el
#     Baseline Profiles, que es una JVM por app. Ahorra trabajo de build y
#     además quita código de /system.
PRODUCT_BASELESS_PROFILE := true

# 7.3 -O3 cuesta tiempo de compilación en cada unidad de traducción y el
#     beneficio sobre -O2 en código ya pequeño es marginal. El servicio que
#     más se nota en usuario (SurfaceFlinger, system_server) sigue en -O3 vía
#     el bloque de arriba, pero el resto del mundo no paga la factura.
#     Pon CHURROS_OPT_LEVEL=3 para el build de rendimiento final.
CHURROS_OPT_LEVEL ?= 2
PRODUCT_GLOBAL_CFLAGS   += -O$(CHURROS_OPT_LEVEL) -ffunction-sections -fdata-sections -fno-plt
PRODUCT_GLOBAL_CXXFLAGS += -O$(CHURROS_OPT_LEVEL) -ffunction-sections -fdata-sections -fno-plt
PRODUCT_VENDOR_CFLAGS   += -O$(CHURROS_OPT_LEVEL)
PRODUCT_VENDOR_CXXFLAGS += -O$(CHURROS_OPT_LEVEL)

# 7.4 Las pruebas de CTS/VTS (Java) son una porción grande del build y no
#     aportan nada a un build de usuario. Se quitan por producto, no por parche.
#     OJO: si necesitas correr cts, quita estas dos líneas.
PRODUCT_PACKAGES -=     CtsShimPriv     VtsHalTest

# 7.5 Sin locales salvo inglés y español: cada locale son varios MB de
#     traducciones, frameworks, apps e imágenes. ChurrOS es una distro en
#     español; el resto de los idiomas se añaden aquí si hacen falta.
PRODUCT_LOCALES := en es

# 7.6 No generar la imagen de ART para arranque rápido de apps: es una de las
#     piezas más caras de producir y su ganancia se nota sólo en gama baja
#     con muchas apps instaladas, que no es el caso de una distro sin GAPPS.
#     Descomenta si mides una mejora real en arranque.
# PRODUCT_ART_USE_APEX_PORT_IMAGE := true

# -----------------------------------------------------------------------------
# 8. Extras de compilación para user builds
# -----------------------------------------------------------------------------
ifneq ($(CHURROS_BUILD_TYPE),eng)
  PRODUCT_SYSTEM_PROPERTIES += \
      ro.boot.selinux=permissive
endif

$(call inherit-product, $(SRC)/product/common/churros_base_init.mk)
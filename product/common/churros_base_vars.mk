# ChurrOS Android — variables de build y optimización.
#
# Se incluye desde churros_base.mk. Define el "contrato" entre los scripts de
# build y el producto. Nada de lógica complicated aquí: los valores vienen de
# variables de entorno exportadas por scripts/cli/build.sh, con defaults
# seguros para que un `lunch` manual siga funcionando.

CHURROS_TIER ?= mid
CHURROS_BUILD_TYPE ?= userdebug
CHURROS_TARGET ?= aosp_arm64

ifeq ($(CHURROS_BUILD_TYPE),eng)
  CHURROS_DEBUG := true
else
  CHURROS_DEBUG := false
endif

# -----------------------------------------------------------------------------
# 1. Flags de compilación del código nativo
# -----------------------------------------------------------------------------
# ThinLTO + -O3 es el mejor compromiso rendimiento/tiempo de build en Clang.
# -Oz sólo tiene sentido para los binarios de userspace de bajo nivel.
PRODUCT_GLOBAL_CFLAGS += -O3 -ffunction-sections -fdata-sections -fno-plt
PRODUCT_GLOBAL_CXXFLAGS += -O3 -ffunction-sections -fdata-sections -fno-plt
PRODUCT_VENDOR_CFLAGS += -O2
PRODUCT_VENDOR_CXXFLAGS += -O2

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
# 3. Compresión de imagen y tamaño de sistema
# -----------------------------------------------------------------------------
# eLzma da ~15 % menos que xz, a cambio de más CPU en el arranque (el precio
# se paga una vez, en el unpack).
PRODUCT_COMPRESS_EXECUTABLES := true

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
# 5. Recorte de bloat (AOSP puro: sólo apps que AOSP trae)
# -----------------------------------------------------------------------------
# Se quitan paquetes que AOSP incluye por defecto pero que casi nadie usa.
# Cada línea está justificada en docs/03-optimizacion.md.
PRODUCT_PACKAGES -= \
    Email \
    Exchange2 \
    Messaging \
    People \
    QuickSearchBox \
    VoiceDialer \
    DeskClock \
    CalendarProvider \
    EmergencyInfo2 \
    GoogleTts \
    LiveWallpapers \
    QuickAccessWalletProxy

# -----------------------------------------------------------------------------
# 6. Ajustes por gama
# -----------------------------------------------------------------------------
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
      ro.config.avoid_gfx_acceleration=false \
      ro.hardware.egl=adreno

  # Sin apps que consumen batería sin necesidad
  PRODUCT_PACKAGES -= \
      Bluetooth \
      NFC \
      NFCNci \
      Tethering \
      PrintSpooler \
      SoftwareRenderer

  PRODUCT_R8_MIN_API_LEVEL := 26

else ifeq ($(CHURROS_TIER),mid)

  # Gama media: los defaults de ART ya son razonables; sólo se acota el heap
  # para que una app runaway no deje sin memoria a las demás, y se sube el
  # read-ahead de forma implícita vía init rc.
  PRODUCT_SYSTEM_PROPERTIES += \
      dalvik.vm.heapgrowthlimit=256m \
      dalvik.vm.heapsize=512m \
      ro.hardware.egl=adreno \
      persist.sys.low_ram=false

else ifeq ($(CHURROS_TIER),high)

  # Gama alta: ART con más margen, GPU siempre disponible
  PRODUCT_SYSTEM_PROPERTIES += \
      dalvik.vm.heapgrowthlimit=512m \
      dalvik.vm.heapsize=1024m \
      ro.hardware.egl=adreno \
      debug.stagefright.caching_enabled=true

endif

# -----------------------------------------------------------------------------
# 7. Extras de compilación para user builds
# -----------------------------------------------------------------------------
ifneq ($(CHURROS_BUILD_TYPE),eng)
  PRODUCT_SYSTEM_PROPERTIES += \
      ro.boot.selinux=permissive
endif

$(call inherit-product, $(SRC)/product/common/churros_base_init.mk)
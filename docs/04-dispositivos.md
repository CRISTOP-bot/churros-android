# 04 — Dispositivos

AOSP puro **no arranca en un teléfono real** por sí solo. Falta el device
tree: kernel, blobs de vendor (modem, cámara, GPU), tablas de partición,
ramdisk y bootloader. Eso es lo que hay que añadir para cada dispositivo.

## Qué necesita un device tree

```
device/churros/<nombre>/
  AndroidProducts.mk     lista de productos y variables a exportar
  BoardConfig.mk          path del kernel, particiones, RAM
  device.mk               heredero del flavour
  extract_files.sh        qué blobs se sacan del firmware
  proprietary-files.txt   lista de blobs con su ruta en /vendor
  Android.bp, *.rc, *.xml
```

## Añadir un dispositivo

1. **Elige el flavor** según la gama (`churros-lite`, `churros`,
   `churros-pro`). Determina `ro.churros.tier` y el bloque de optimización.

2. **Copia un manifest de device**:
   ```bash
   cp manifests/devices/mid.xml manifests/devices/mi9t.xml
   ```
   y cambia `path` y `name` de cada `<project>`.

3. **Crea `product/flavors/<nombre>/`** si el flavor no existe, o reutiliza
   uno de los tres. Lo normal es un `device.mk` por dispositivo que hereda del
   flavor:

   ```make
   $(call inherit-product, $(SRC)/product/flavors/churros/device.mk)

   PRODUCT_NAME := churros-mi9t
   PRODUCT_DEVICE := mi9t
   PRODUCT_BRAND := ChurrOS
   $(call inherit-product, device/churros/mi9t/device.mk)
   ```

4. **Los blobs de vendor**: extrae del firmware original
   (`extract_files.sh` de LineageOS sirve de plantilla). Sin modem no hay
   llamadas; sin blobs de GPU no hay interfaz gráfica.

5. **Compila y flash**:
   ```bash
   ./churros sync --device mi9t --tier mid
   ./churros build --lunch churros-mi9t --tier mid
   cd ~/android/churros/out/target/product/aosp_arm64/
   fastboot flash super churros-*.img     # o los slots que corresponda
   fastboot flashall
   ```

## Notas por gamas

### Gama baja (1-2 GB, 2015-2019)

Es la más delicada. Los device trees viejos ya no están mantenidos en
TheMuppets: hay que extraer los blobs a mano del firmware stock y el kernel
suele necesitar parches de vendor para los SoC Qualcomm antiguos. Aquí el
`ro.config.low_ram` y el ajuste de lmkd hacen casi todo el trabajo.

**Herramienta**: revisa si el kernel soporta zRAM y si el bootloader acepta
una imagen de super partición (los dispositivos pre-2019 usan
`system/` + `userdata` enRecovery, no super). En ese caso
`PRODUCT_SYSTEM_SIZE` debe ignorar el diseño de particiones del dispositivo.

### Gama media (4-6 GB, 2019-2022)

Lo más cómodo: los device trees de LineageOS funcionan casi sin cambios.
Snapdragon 855/865, Adreno 6xx, los blobs de vendor están bien soportados.

### Gama alta (8+ GB, 2022+)

Requiere DEVICE_TREE de Qualcomm más reciente y los blobs del vendor
originales (con*)(keys de firma proprietary). Ojo: los dispositivos con
**Android Verified Boot** obligatorio y bootloader bloqueado (Titan M,
StrongBox) no son flasheables sin exploiting. El proyecto apunta a los que sí
lo son.

## Soporte genérico (emulador)

Para probar el producto sin device tree:

```bash
lunch churros-userdebug
m selinux && m && ./churros build --lunch churros --target sdk_gphone64_x86_64
```

Necesita los manifests de `prebuilts/clang/host/linux-x86` y el módulo
`device/generic_goldfish` que ya viene en AOSP.

## Dispositivos que no van a funcionar

- Los que usan Only-S (Samsung), porque el bootloader Samsung es de
  pago con un partner de pago: no hay desbloqueo sin exploit.
- Los Titan M / StrongBox con AVB obligatorio (buena parte de la gama alta
  reciente).
- Cualquiera con repartición en vivo.
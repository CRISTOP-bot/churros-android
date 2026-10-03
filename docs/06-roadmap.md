# 06 — Roadmap

Estado real del proyecto, en orden de lo que desbloquea lo siguiente.

## Hecho

- [x] Manifest AOSP por release, con fragmento de optimización y remotos.
- [x] Árbol de producto común + tres flavors (`churros-lite`, `churros`,
      `churros-pro`) con `ro.churros.tier` por flavor.
- [x] Capa de optimización: flags de compilación, props de ART/low-ram,
      recorte de bloat, init rc (I/O, zRAM, vm tuning, lmkd, governor).
- [x] Fuentes C de los binarios de runtime + `./churros native`.
- [x] CLI: `doctor`, `env`, `sync`, `build`, `native`, `devices`, `flash`, `measure`,
      `check`, `clean`.
- [x] Guía de medición (`docs/07-medicion.md`) para justificar cada ajuste.
- [x] CI con `./churros check` y shellcheck.

## Siguiente — desbloquea todo lo demás

- [ ] **Elegir el primer dispositivo** y traer su device tree. Sin esto no hay
      ROM instalable. Candidatos: un Pixel 6/7 (device trees públicos, blobs de
      vendor ya extraídos) para validar la cadena completa, y después un
      Snapdragon de gama media.
- [ ] **Primer build completo** en máquina de build. Hasta que no haya un
      `boot.img` arrancando, todo lo demás es teoría.
- [ ] Compilar `native/` con el NDK de la release y committing los binarios
      (o el `.c` ya basta si se compila en CI).

## Después del primer arranque

- [ ] Medir antes/después con `perfetto` y `adb shell dumpsys meminfo`.
      Sin cifras, `docs/03-optimizacion.md` es opinión.
- [ ] Perfilado de arranque: `logcat -b events` y `atrace` para ver dónde se
      va el tiempo en los primeros 10 s.
- [ ] Consumo en reposo: `dumpsys batterystats`, objetivo < 1 %/h en reposo.
- [ ] Decidir la política de apps preinstaladas: AOSP puro no trae GAPPS, así
      que el out-of-the-box es un dispositivo sin navegador ni Play Store. Hay
      que decidir si eso es aceptable o si se ofrece microG como variante.

## Decisiones pendientes

| Decisión | Opciones | Nota |
|---|---|---|
| MicroG | sí / no / variante aparte | Afecta a la versión y a la licencia de las apps |
| Nombre del launcher | Launcher3 de AOSP / uno propio | Launcher3 es ligero pero anticuado |
| Actualizaciones | sin OTA / delta desde el device tree | Sin claves de firma propias no hay OTA firmado |
| Kernel | stock del device tree / parcheado | Un kernel propio multiplica el trabajo por 10 |

## Fuera de alcance (a propósito)

- Servicios de Google / Play Protect.
- Compilar blobs de vendor proprietary (sus licencias no lo permiten).
- Dispositivos con bootloader bloqueado sin exploit.
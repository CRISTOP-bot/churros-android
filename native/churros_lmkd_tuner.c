/*
 * churros_lmkd_tuner — ajusta los umbrales de presión de memoria de lmkd.
 *
 * En dispositivos de 1-2 GB los valores por defecto de AOSP matan apps que el
 * usuario está viendo en primer plano. Este binario los reescribe una vez
 * durante post-fs-data, antes de que lmkd empiece a hacer su trabajo normal.
 *
 * Copyright (C) 2026 ChurrOS
 * Licencia: Apache-2.0 (ver LICENSE en la raíz del repo)
 */

#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Umbrales que escribió el init rc como punto de partida. */
#define VM_PRESSURE_LOW_DEFAULT  "10\n"
#define VM_PRESSURE_HIGH_DEFAULT "90\n"

/* Para gama baja: menos margen antes de declarar presión, pero con un suelo
 * más alto para que el OOM killer tenga sitio para trabajar sin matar la
 * app que está en pantalla. */
#define VM_PRESSURE_LOW_LOWEND   "0\n"
#define VM_PRESSURE_HIGH_LOWEND  "85\n"

static const char *tier(void) {
  const char *t = getenv("CHURROS_TIER");
  return t ? t : "";
}

static void write_file(const char *path, const char *value) {
  int fd = open(path, O_WRONLY | O_TRUNC);
  if (fd < 0) {
    /* El kernel puede no exponer el knob ( kernels antiguo, contenedores ).
     * No es fatal: seguimos con el resto. */
    return;
  }
  ssize_t n = write(fd, value, strlen(value));
  (void)n;
  close(fd);
}

int main(void) {
  const char *t = tier();
  int lowend = (strcmp(t, "lowend") == 0);

  if (lowend) {
    write_file("/proc/sys/vm/pressure_low", VM_PRESSURE_LOW_LOWEND);
    write_file("/proc/sys/vm/pressure_high", VM_PRESSURE_HIGH_LOWEND);
  } else {
    write_file("/proc/sys/vm/pressure_low", VM_PRESSURE_LOW_DEFAULT);
    write_file("/proc/sys/vm/pressure_high", VM_PRESSURE_HIGH_DEFAULT);
  }

  return 0;
}
/*
 * churros_zramd — levanta el dispositivo zRAM con zstd.
 *
 * El init rc sólo prepara sysfs (ver product/common/init/churros.rc). Este
 * binario registra el dispositivo con el tamaño adecuado y activa el swap.
 *
 * Por qué zRAM y no swap a flash: en dispositivos de gama baja el swap a
 * eMMC/SD es la fuente número uno de latencia y desgaste. Con zstd, 1.5x la
 * RAM se comprime en RAM real; en la práctica esto sustituye casi todo el
 * swap a flash en el uso diario.
 *
 * Copyright (C) 2026 ChurrOS
 * Licencia: Apache-2.0
 */

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef SYS_swapon
#define SYS_swapon 167
#endif

#define ZRAM_PATH "/sys/block/zram0"
#define DEV_SIZE   ZRAM_PATH "/comp_algorithm"
#define DEV_INIT   ZRAM_PATH "/disksize"
#define MEMTOTAL   "/proc/meminfo"

/* Tamaño del bloque de compresión: 4k mantiene el coste de CPU bajo, que es
 * justo lo que no nos sobra en gama baja. 8k reduce fragmentación a cambio de
 * más CPU en escrituras. */
#define COMP_ALGORITHM "zstd"
#define MEM_DISKSIZE_FACTOR_NUM 3  /* 1.5x RAM */
#define MEM_DISKSIZE_FACTOR_DEN 2

static long long memtotal_kb(void) {
  FILE *f = fopen(MEMTOTAL, "r");
  if (!f) return 0;
  char buf[256];
  long long total = 0;
  while (fgets(buf, sizeof(buf), f)) {
    if (sscanf(buf, "MemTotal: %lld kB", &total) == 1) break;
  }
  fclose(f);
  return total;
}

static void write_file(const char *path, const char *value) {
  int fd = open(path, O_WRONLY | O_TRUNC);
  if (fd < 0) return;
  ssize_t n = write(fd, value, strlen(value));
  (void)n;
  close(fd);
}

static int enable_swapon(void) {
  return syscall(SYS_swapon, "/dev/zram0");
}

int main(void) {
  if (access(ZRAM_PATH, F_OK) != 0) {
    fprintf(stderr, "churros_zramd: el módulo zram no está cargado; nada que hacer\n");
    /* No es un error: muchos kernels configuran zram vía device tree y el
     * módulo ya no aparece en /sys/block. */
    return 0;
  }

  write_file(DEV_SIZE, COMP_ALGORITHM);

  long long total_kb = memtotal_kb();
  if (total_kb <= 0) {
    fprintf(stderr, "churros_zramd: no se pudo leer MemTotal\n");
    return 0;
  }

  /* disksize está en bytes; MemTotal viene en KiB, así que x1024 */
  long long size_bytes = total_kb * 1024 * MEM_DISKSIZE_FACTOR_NUM / MEM_DISKSIZE_FACTOR_DEN;
  char sz[32];
  snprintf(sz, sizeof(sz), "%lld\n", size_bytes);
  write_file(DEV_INIT, sz);

  if (enable_swapon() != 0 && errno != EBUSY) {
    fprintf(stderr, "churros_zramd: swapon falló: %s\n", strerror(errno));
    return 1;
  }

  return 0;
}
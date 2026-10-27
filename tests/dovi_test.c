/* Copyright (c) 2026 kewe87. Licensed under LGPL-2.1-or-later. */
/* Test der libdovi-Umwandlung Profil 7 -> 8.1 auf dem TV.
 * Aufruf: dovi_test <p7-rpu.bin> [erwartetes-81-rpu.bin]
 * Die .bin-Dateien sind dovi_tool-Testdaten: 4 Byte Startcode + RPU. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stddef.h>

typedef struct DoviRpuOpaque DoviRpuOpaque;
typedef struct { const uint8_t *data; size_t len; } DoviData;

DoviRpuOpaque *dovi_parse_rpu (const uint8_t * buf, size_t len);
DoviRpuOpaque *dovi_parse_unspec62_nalu (const uint8_t * buf, size_t len);
const char *dovi_rpu_get_error (const DoviRpuOpaque * ptr);
int dovi_convert_rpu_with_mode (DoviRpuOpaque * ptr, uint8_t mode);
const DoviData *dovi_write_rpu (DoviRpuOpaque * ptr);
const DoviData *dovi_write_unspec62_nalu (DoviRpuOpaque * ptr);
void dovi_data_free (const DoviData * data);
void dovi_rpu_free (DoviRpuOpaque * ptr);

static uint8_t *
read_file (const char *path, size_t * len)
{
  FILE *f = fopen (path, "rb");
  uint8_t *buf;
  long n;

  if (!f)
    return NULL;
  fseek (f, 0, SEEK_END);
  n = ftell (f);
  fseek (f, 0, SEEK_SET);
  buf = malloc (n);
  if (fread (buf, 1, n, f) != (size_t) n) {
    fclose (f);
    free (buf);
    return NULL;
  }
  fclose (f);
  *len = n;
  return buf;
}

int
main (int argc, char **argv)
{
  size_t len, exp_len = 0;
  uint8_t *in, *exp = NULL;
  DoviRpuOpaque *rpu, *rpu2;
  const DoviData *out, *nal;
  int ret = 0;

  if (argc < 2)
    return 2;
  in = read_file (argv[1], &len);
  if (!in || len < 5)
    return 2;
  if (argc > 2)
    exp = read_file (argv[2], &exp_len);

  /* Datei: Startcode + RPU nach dem 7C 01-NAL-Kopf (escaped). Kopf wieder
   * voranstellen und wie im MKV-Baustein als UNSPEC62-NAL einlesen. */
  {
    uint8_t *nalbuf = malloc (len - 4 + 2);
    nalbuf[0] = 0x7C;
    nalbuf[1] = 0x01;
    memcpy (nalbuf + 2, in + 4, len - 4);
    rpu = dovi_parse_unspec62_nalu (nalbuf, len - 4 + 2);
    free (nalbuf);
  }
  if (dovi_rpu_get_error (rpu)) {
    printf ("parse error: %s\n", dovi_rpu_get_error (rpu));
    return 1;
  }
  if (dovi_convert_rpu_with_mode (rpu, 2) != 0) {
    printf ("convert error: %s\n", dovi_rpu_get_error (rpu));
    return 1;
  }

  out = dovi_write_rpu (rpu);
  printf ("RPU unescaped nach Umwandlung: %zu Bytes\n", out->len);

  /* Ausgabe als UNSPEC62-NAL (escaped), Vergleich mit dovi_tool */
  nal = dovi_write_unspec62_nalu (rpu);
  if (exp) {
    if (nal->len == exp_len - 4 + 2 && memcmp (nal->data + 2, exp + 4,
            exp_len - 4) == 0)
      printf ("IDENTISCH mit dovi_tool mode 2\n");
    else {
      printf ("ABWEICHUNG zu dovi_tool (%zu vs %zu Bytes)\n", nal->len - 2,
          exp_len - 4);
      ret = 1;
    }
  }
  printf ("UNSPEC62-NAL: %zu Bytes, Header %02x %02x\n", nal->len,
      nal->data[0], nal->data[1]);
  rpu2 = dovi_parse_unspec62_nalu (nal->data, nal->len);
  if (dovi_rpu_get_error (rpu2)) {
    printf ("NAL-Rundlauf FEHLER: %s\n", dovi_rpu_get_error (rpu2));
    ret = 1;
  } else {
    printf ("NAL-Rundlauf OK\n");
  }

  dovi_rpu_free (rpu2);
  dovi_data_free (nal);
  dovi_data_free (out);
  dovi_rpu_free (rpu);
  free (in);
  free (exp);
  return ret;
}

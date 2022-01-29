#include "nist-its90.h"
#include <math.h>

/*
 * returns corrected temperature as 14-bit thermocouple temperature data
 *
 * D15:	sign
 * D14:	should be same as D15 (otherwise error)
 * D13:	should be same as D15
 * D12:	MSB 2^{10} (1024 degreeC)
 *  :
 *  :
 * D2:	2^0 (1 degreeC)
 * D1:	2^{-1} (0.5 degreeC)
 * D0:	LSB 2^{-2} (0.25 degreeC)
 *
 * or 0x8000 (D15 = 1, D14 = 0) if error (out of range).
 */

int
correctedTemperature(int rawTCTemp, int rawIntTemp) {
  FLOAT tctemp, inttemp;
  int result;

  if (rawTCTemp & 0x2000) {
    rawTCTemp |= 0xc000;
  }
  tctemp = (float)rawTCTemp / 4.0;

  if (rawIntTemp & 0x0800) {
    rawIntTemp |= 0xf000;
  }
  inttemp = (float)rawIntTemp / 16.0;

  result = (int)(emf2temp_K((tctemp - inttemp) * 0.041276 + temp2emf_K(inttemp)) * 4);

  if (result == NAN) {
    return 0x8000;	/* error */
  }
  return result;
}

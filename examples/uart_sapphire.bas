' RiscBasic UART example for the Efinix Sapphire SoC
' Prints a banner, then echoes every key and shows its code on the GPIO outputs

.include "include/CPU/SAPPHIRE.bas"
.include "include/boards/TEG1015.bas"
.include "lib/uart.bas"

DIM C AS BYTE

PRINT "RiscBasic on Sapphire ready", CR, LF

DO
  INPUT CHR C
  GPIO0.OUT = C
  PRINT "key ", CHR C, " = ", HEX C, CR, LF
LOOP

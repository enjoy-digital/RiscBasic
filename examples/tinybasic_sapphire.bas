' Tiny BASIC interpreter on the Efinix Sapphire SoC, console on UART0 (115200 8N1)
'
' The interpreter is lib/tinybasic.bas; this file only sets up the memory and the console.
' The 16K SoC RAM is split into 12K code and 4K data, about 2.8K of it for BASIC programs.
' With a larger SoC RAM, raise SOC_RAM_SIZE, RAM_SIZE and PSIZE together.

CONST SOC_RAM_SIZE = 16384
CONST RAM_SIZE     = 4096
CONST PSIZE        = 2816          ' program text; the rest of RAM is variables and stack

.include "include/CPU/SAPPHIRE.bas"
.include "lib/uart.bas"

FUNCTION KeyHit AS WORD            ' a character is waiting
  RETURN UART0.RXCOUNT
END FUNCTION

.include "lib/tinybasic.bas"

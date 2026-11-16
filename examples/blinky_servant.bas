' RiscBasic example for SERV core as SERVANT (one GPO bit only avaiable)

.include "include/CPU/SERVANT.bas"
.include "lib/uart.bas"


PRINT UART0, "RiscBasic ready", CR, LF

DO
  LED = NOT LED
  DELAY_MS 1000
LOOP

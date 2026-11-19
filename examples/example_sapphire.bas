' RiscBasic example for Efinix

.include "include/CPU/SAPPHIRE.bas"
.include "include/boards/TEG1015.bas"

DIM I AS WORD          ' RAM

DO
  GPIO0.OUT = I        ' count on all GPIO outputs (LED = I would only test I <> 0)
  I = I + 1
  DELAY_MS 1000  

LOOP

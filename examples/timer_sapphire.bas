' RiscBasic example: Efinix Sapphire SoC, CLINT machine timer interrupt
'
' The timer interrupts TICK_HZ times per second. The interrupt handler counts the
' ticks and toggles the LED once per second; the main program prints the uptime.

.include "include/CPU/SAPPHIRE.bas"
.include "include/CPU/SAPPHIRE_CLINT.bas"
.include "include/boards/TEG1015.bas"
.include "lib/uart.bas"

CONST TICK_HZ = 1000                        ' interrupts per second
#IF CLINT_HZ MOD TICK_HZ <> 0
#ERROR "TICK_HZ must divide CLINT_HZ evenly"
#ENDIF

DIM ticks   AS WORD                         ' timer interrupts since start
DIM ms      AS WORD                         ' ticks within the current second
DIM seconds AS WORD                         ' set by the interrupt handler
DIM shown   AS WORD                         ' last second printed by the main loop

ON IRQ MTIMER
  TimerNext                                 ' first: clears the interrupt
  ticks = ticks + 1
  ms = ms + 1
  IF ms = TICK_HZ THEN
    ms = 0
    seconds = seconds + 1
    LED = NOT LED                           ' 1 s on, 1 s off
  END IF
END IRQ

PRINT "RiscBasic Sapphire timer interrupt demo, ", DEC TICK_HZ, " interrupts per second", CR, LF
TimerStart CLINT_HZ / TICK_HZ

DO
  IF seconds <> shown THEN
    shown = seconds
    PRINT "uptime ", DEC shown, " s, ticks ", DEC ticks, CR, LF
  END IF
LOOP

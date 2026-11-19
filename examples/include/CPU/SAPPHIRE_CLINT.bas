'
' Efinix Sapphire SoC: CLINT machine timer (mtime / mtimecmp) for ON IRQ MTIMER
'
' Register offsets from the Sapphire BSP (driver/clint.h), base SYSTEM_CLINT_CTRL.
' mtime counts at SYSTEM_CLINT_HZ (= the 25 MHz system clock on this SoC).
' Include after include/CPU/SAPPHIRE.bas.
'

CONST CLINT_HZ = 25_000_000

DEVICE CLINT AT &HF8B0_0000
  REG CMPLO  AT +&H4000         ' mtimecmp of hart 0, low word
  REG CMPHI  AT +&H4004         ' mtimecmp of hart 0, high word
  REG TIMELO AT +&HBFF8 READONLY
  REG TIMEHI AT +&HBFFC READONLY
END DEVICE

DIM ClintPeriod AS WORD         ' timer ticks between interrupts
DIM ClintNextLo AS WORD         ' next compare value, 64 bits
DIM ClintNextHi AS WORD

'
' Move mtimecmp one period further. The timer interrupt stays active while
' mtime >= mtimecmp, so the ON IRQ MTIMER handler must call this first.
' The high word goes to all ones first, so no false match can happen while
' the two halves are written.
'
SUB TimerNext
  ClintNextLo = ClintNextLo + ClintPeriod
  IF ClintNextLo < ClintPeriod THEN ClintNextHi = ClintNextHi + 1
  CLINT.CMPHI = &HFFFF_FFFF
  CLINT.CMPLO = ClintNextLo
  CLINT.CMPHI = ClintNextHi
END SUB

'
' Start a periodic timer interrupt every 'period' CLINT ticks:
' read mtime, set the first compare value, then mie.MTIE (bit 7) and mstatus.MIE.
'
SUB TimerStart(period AS WORD)
  ClintPeriod = period
  DO                            ' read the 64-bit mtime without a carry in between
    ClintNextHi = CLINT.TIMEHI
    ClintNextLo = CLINT.TIMELO
  LOOP UNTIL ClintNextHi = CLINT.TIMEHI
  TimerNext
  ASM
    li     t0, 0x80
    csrrs  zero, mie, t0
    csrrsi zero, mstatus, 8
  END ASM
END SUB

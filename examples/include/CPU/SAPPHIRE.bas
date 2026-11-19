'
' Efinix Sapphire SoC (VexRiscv) with 16K RAM, no compressed instructions
'

TARGET RV32I
CLOCK  25_000_000
CPI    3               ' measured on T20 board: delay loop takes 6 cycles per pass
CODE   AT &HF900_0000 SIZE 14336
RAM    AT &HF900_3800 SIZE 2048 

'
' AMD IO Module
'
DEVICE GPIO0 AT &HF801_5000
  REG OUT  AT +4  WRITEONLY
  REG IN   AT +0  READONLY
END DEVICE


'
' Sapphire UART (SpinalHDL Apb3UartCtrl), SYSTEM_UART_0_IO_CTRL
' Comes out of reset as 115200 8N1 (set when the SoC is generated).
'
DEVICE UART0 AT &HF801_0000
  REG DATA   AT +0              ' write: push TX byte, read: pop RX byte (bit 16 = valid)
  REG STAT   AT +4  READONLY
  REG CLKDIV AT +8              ' baud = CLOCK / ((CLKDIV + 1) * 8)
  REG FRAME  AT +12             ' [2:0] data bits - 1, [9:8] parity, [16] stop bits
  FIELD TXFREE  = STAT[23:16]   ' free places in the TX FIFO
  FIELD RXCOUNT = STAT[31:24]   ' bytes waiting in the RX FIFO
  Put
  Get
END DEVICE

' No single ready bit in STAT, so PRINT / INPUT go through these handlers
SUB UART0Put(C AS BYTE)
  WAIT UNTIL UART0.TXFREE <> 0
  UART0.DATA = C
END SUB

FUNCTION UART0Get AS BYTE
  WAIT UNTIL UART0.RXCOUNT <> 0
  RETURN UART0.DATA
END FUNCTION


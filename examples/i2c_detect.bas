'
' RiscBasic example: i2cdetect
'
' Scans the I2C bus and prints the address map like Linux "i2cdetect -y":
'
'      0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
' 00:          -- -- -- -- -- -- -- -- -- -- -- -- --
' 10: -- -- -- -- -- -- -- -- -- -- 1A -- -- -- -- --
' ...
' 50: 50 -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
'
' Addresses 0x03 to 0x77 are probed, as i2cdetect does by default. Like i2cdetect, addresses
' 0x30-0x37 and 0x50-0x5F are probed with a one-byte read, so EEPROMs never see a write; all
' others with a quick write (START, address, STOP). "--" means no device answered.
'

.include "include/CPU/MCS-V.bas"
.include "include/boards/CR00107.bas"
.include "lib/uart.bas"

DIM addr AS BYTE        ' RAM
DIM row AS BYTE         ' RAM
DIM col AS BYTE         ' RAM
DIM found AS BYTE       ' RAM: devices that answered
DIM dummy AS BYTE       ' RAM: the byte of a read probe
DIM ackerr AS BYTE      ' RAM: 1 if a device did not acknowledge (I2CGetAck)

'
' I2C bitbang defs: SDA must be open-drain (see lib/i2c_bitbang.bas)
'
ALIAS SDA_OUT = GPIO1.OUT.0
ALIAS SCL_OUT = GPIO1.OUT.1
ALIAS SDA_IN = GPIO1.IN.0

.include "lib/i2c_bitbang.bas"

'
' Free the bus: up to 9 clocks with SDA released end any transfer a device is still in
' (for example after a reset in the middle of a read), then a STOP.
'
SUB I2CBusClear
  DIM k AS BYTE
  SDA_OUT = 1: I2CDelay
  FOR k = 1 TO 9
    SCL_OUT = 1: I2CDelay
    SCL_OUT = 0: I2CDelay
  NEXT
  I2CStop
END SUB

'
' 1 if a device answers at the 7-bit address a, else 0
'
FUNCTION I2CProbe(a AS BYTE) AS BYTE
  ackerr = 0
  SELECT CASE a
    CASE &H30 TO &H37, &H50 TO &H5F      ' read probe: EEPROMs and the like see no write
      WRITE I2C, Start, (a SHL 1) OR 1, GetAck
      IF ackerr = 0 THEN READ I2C, dummy, NACK
    CASE ELSE                            ' quick write: address only
      WRITE I2C, Start, a SHL 1, GetAck
  END SELECT
  I2CStop
  RETURN 1 - ackerr
END FUNCTION

PRINT "RiscBasic i2cdetect", 13, 10
I2CBusClear

PRINT "     0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F", 13, 10
found = 0
FOR row = 0 TO 7
  addr = row SHL 4
  PRINT HEX addr, ":"
  FOR col = 0 TO 15
    addr = (row SHL 4) + col
    IF addr < 3 OR addr > &H77 THEN
      PRINT "   "
    ELSEIF I2CProbe(addr) THEN
      PRINT " ", HEX addr
      found = found + 1
    ELSE
      PRINT " --"
    END IF
  NEXT
  PRINT 13, 10
NEXT
PRINT DEC found, " device(s) found", 13, 10

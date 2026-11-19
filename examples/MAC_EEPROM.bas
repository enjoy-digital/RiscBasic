' RiscBasic example

.include "include/CPU/MCS-V.bas"
.include "include/boards/CR00107.bas"
.include "lib/uart.bas"


DIM I AS BYTE          ' RAM
DIM J AS BYTE          ' RAM
DIM I2CAddr AS BYTE    ' RAM
DIM ackerr AS BYTE      ' RAM: 1 if a device did not acknowledge (GetAck)

'
' I2C bitbang defs
'
' SDA must be open-drain in the FPGA design: SDA_OUT = 0 pulls the line low, SDA_OUT = 1
' releases it (the pull-up makes it high), so a device can pull SDA low for its ACK and its
' data bits. A push-pull output would fight the device on every ACK and read.
'
ALIAS SDA_OUT = GPIO1.OUT.0
ALIAS SCL_OUT = GPIO1.OUT.1
ALIAS SDA_IN = GPIO1.IN.0

.include "lib/i2c_bitbang.bas"


PRINT "RiscBasic ready", 13, 10
PRINT "Read Write Demo for I2C devices", 13, 10
'
' I2C Read Demo
'
I2CAddr = &HFA
ackerr = 0

WRITE I2C, Start, &B1010_0100, GetAck, I2CAddr, GetAck, RepeatedStart, &B1010_0101, GetAck
IF ackerr THEN PRINT "No ACK from the device", 13, 10

PRINT "Value read: "

FOR J = 0 to 4
  READ I2C, I, ACK              ' more bytes follow
  PRINT HEX I
NEXT
READ I2C, I, NACK, Stop         ' last byte: NACK, so the EEPROM releases SDA for the STOP
PRINT HEX I, 13, 10













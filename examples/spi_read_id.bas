' RiscBasic example

.include "include/CPU/MCS-V.bas"
.include "include/boards/CR00107.bas"
.include "lib/uart.bas"


DIM I AS BYTE          ' RAM
DIM J AS BYTE          ' RAM
DIM I2CAddr AS BYTE    ' RAM
DIM ackerr AS BYTE      ' RAM: 1 if a device did not acknowledge (GetAck)


PRINT "RiscBasic ready", CR, LF

'
' SPI bitbang defs
'
'
ALIAS SPI_MOSI = GPIO2.OUT.0
ALIAS SPI_SCK  = GPIO2.OUT.1
ALIAS SPI_SS   = GPIO2.OUT.2
ALIAS SPI_MISO = GPIO2.IN.0

SPI_SS = 1 'make sure is de-selected initially
SPI_SCK = 0

.include "lib/spi_bitbang.bas"


PRINT "Read ID Demo for SPI devices", CR, LF
'
' SPI Read Demo
'
WRITE SPI, Start, &B1001_1111

PRINT "ID Value read: "

FOR J = 0 to 3
  READ SPI, I              ' more bytes follow
  PRINT HEX I
NEXT

PRINT CR, LF

PRINT "90...:"
WRITE SPI, Stop

WRITE SPI, Start, &H90, 0, 0, 0    ' Read Manufacturer / Device ID, address 0
FOR J = 0 TO 1
  READ SPI, I                      ' manufacturer, then device ID
  PRINT HEX I
NEXT
WRITE SPI, Stop
PRINT CR, LF









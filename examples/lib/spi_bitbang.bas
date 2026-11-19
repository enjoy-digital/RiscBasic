'
' SPI bitbang defs
'
'
' Stream support functions. Every routine starts and ends with SCL low,
' except Start (starts from the idle bus) and Stop (leaves the bus idle).
'
SUB SPIWrite(wrval AS BYTE)
  DIM temp AS BYTE       ' RAM
  
  FOR temp = 0 to 7
    SPI_MOSI = wrval.7 
    SHL wrval         
    SPI_SCK = 1
    SPI_SCK = 0
  NEXT
END SUB

FUNCTION SPIRead AS BYTE
  DIM temp AS BYTE       ' RAM
  DIM rdval AS BYTE       ' RAM

  FOR temp = 0 to 7
    SHL rdval
    SPI_SCK = 1
    rdval.0 = SPI_MISO      ' 
    SPI_SCK = 0
  NEXT
  RETURN rdval
END FUNCTION

SUB SPIStart
  SPI_SS = 0
END SUB

SUB SPIStop
  SPI_SS = 1
END SUB












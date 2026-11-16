'
' I2C bitbang defs
'
SUB I2CDelay
'
' Half-bit time: SCL low for one delay, high for one delay (about 50 kHz)
'
  DELAY_US 5
END SUB
'
' Stream support functions. Every routine starts and ends with SCL low,
' except Start (starts from the idle bus) and Stop (leaves the bus idle).
'
SUB I2CWrite(wrval AS BYTE)
  DIM temp AS BYTE       ' RAM
  
  FOR temp = 0 to 7
    SDA_OUT = wrval.7 ' output high bit, while SCL is low
    SHL wrval         ' shift left
    I2CDelay
    SCL_OUT = 1: I2CDelay   ' device samples SDA while SCL is high
    SCL_OUT = 0
  NEXT
END SUB

FUNCTION I2CRead AS BYTE
  DIM temp AS BYTE       ' RAM
  DIM rdval AS BYTE       ' RAM

  SDA_OUT = 1             ' release SDA: the device drives it
  FOR temp = 0 to 7
    SHL rdval
    I2CDelay
    SCL_OUT = 1: I2CDelay
    rdval.0 = SDA_IN      ' read I2C SDA bus value while SCL is high
    SCL_OUT = 0
  NEXT
  RETURN rdval
END FUNCTION

SUB I2CGetAck             ' after a written byte: the device acknowledges by pulling SDA low
  SDA_OUT = 1: I2CDelay
  SCL_OUT = 1: I2CDelay
  IF SDA_IN THEN ackerr = 1
  SCL_OUT = 0
END SUB

SUB I2CACK                ' after a read byte: more bytes follow
  SDA_OUT = 0: I2CDelay
  SCL_OUT = 1: I2CDelay
  SCL_OUT = 0
END SUB

SUB I2CNACK               ' after the last read byte
  SDA_OUT = 1: I2CDelay
  SCL_OUT = 1: I2CDelay
  SCL_OUT = 0
END SUB

SUB I2CStart              ' SDA falls while SCL is high
  SDA_OUT = 1: SCL_OUT = 1: I2CDelay
  SDA_OUT = 0:              I2CDelay
  SCL_OUT = 0
END SUB

SUB I2CRepeatedStart      ' from SCL low: release SDA, then SCL, then a START
  SDA_OUT = 1: I2CDelay
  SCL_OUT = 1: I2CDelay
  SDA_OUT = 0: I2CDelay
  SCL_OUT = 0
END SUB

SUB I2CStop               ' SDA rises while SCL is high
  SDA_OUT = 0: I2CDelay
  SCL_OUT = 1: I2CDelay
  SDA_OUT = 1: I2CDelay
END SUB












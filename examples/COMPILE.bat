del *.lst
del *.mem
del *.bin
del *.hex
del *.elf

python ../source/riscbasic.py fit_interrupt.bas
python ../source/riscbasic.py MAC_EEPROM.bas

python ../source/riscbasic.py i2c_detect.bas
python ../source/riscbasic.py blinky_servant.bas

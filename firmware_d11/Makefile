# Build using arduino-cli, because the Arduino.mk doesn't support the Mattairtech boards.

PROJECT = firmware_d11
TARGET = $(PROJECT).MattairTech_Arduino.samd.d11c14a

default: all

all: $(TARGET).bin

upload: $(TARGET).bin
	echo "connect" > upload.jlink
	echo "erase" >> upload.jlink
	echo "loadbin $(TARGET).bin, 0" >> upload.jlink
	echo "r" >> upload.jlink
	echo "go" >> upload.jlink
	echo "q" >> upload.jlink
	JLinkExe -device atsamd11c14 -if swd -speed 4000 -CommanderScript upload.jlink

clean:
	rm -vf $(TARGET).bin $(TARGET).elf

$(TARGET).bin: firmware_d11.ino
	(cd ..; arduino-cli compile --verbose --fqbn MattairTech_Arduino:samd:d11c14a:float=both,config=enabled,clock=internal,timer=timer_732Hz,bootloader=0kb,serial=no_uart,usb=cdc firmware_d11)

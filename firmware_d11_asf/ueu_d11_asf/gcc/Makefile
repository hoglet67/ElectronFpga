################################################################################
# Automatically-generated file. Do not edit!
################################################################################

ifdef SystemRoot
	SHELL = cmd.exe
	MK_DIR = mkdir
else
	ifeq ($(shell uname), Linux)
		MK_DIR = mkdir -p
	endif

	ifeq ($(shell uname | cut -d _ -f 1), CYGWIN)
		MK_DIR = mkdir -p
	endif

	ifeq ($(shell uname | cut -d _ -f 1), MINGW32)
		MK_DIR = mkdir -p
	endif

	ifeq ($(shell uname | cut -d _ -f 1), MINGW64)
		MK_DIR = mkdir -p
	endif

	ifeq ($(shell uname | cut -d _ -f 1), DARWIN)
		MK_DIR = mkdir -p
	endif
endif

# List the subdirectories for creating object files
SUB_DIRS +=  \
 \
hpl/usb \
gcc \
usb/class/cdc/device \
usb/device \
hpl/dmac \
hal/src \
hpl/pm \
hpl/sysctrl \
hal/utils/src \
hpl/sercom \
hpl/gclk \
Device_Startup \
hpl/core \
usb

# List the object files
OBJS +=  \
hal/src/hal_io.o \
usb/class/cdc/device/cdcdf_acm.o \
hal/utils/src/utils_syscalls.o \
hal/src/hal_spi_m_sync.o \
hpl/usb/hpl_usb.o \
hal/src/hal_delay.o \
hpl/pm/hpl_pm.o \
hpl/core/hpl_init.o \
hal/utils/src/utils_list.o \
hpl/core/hpl_core_m0plus_base.o \
hal/utils/src/utils_assert.o \
usb_start.o \
hpl/sysctrl/hpl_sysctrl.o \
hpl/gclk/hpl_gclk.o \
usb/usb_protocol.o \
hal/src/hal_init.o \
hal/src/hal_usb_device.o \
main.o \
driver_init.o \
hpl/sercom/hpl_sercom.o \
hal/src/hal_gpio.o \
hal/utils/src/utils_event.o \
hal/src/hal_sleep.o \
Device_Startup/system_samd11.o \
hpl/dmac/hpl_dmac.o \
atmel_start.o \
usb/device/usbdc.o \
Device_Startup/startup_samd11.o \
hal/src/hal_atomic.o

OBJS_AS_ARGS +=  \
"hal/src/hal_io.o" \
"usb/class/cdc/device/cdcdf_acm.o" \
"hal/utils/src/utils_syscalls.o" \
"hal/src/hal_spi_m_sync.o" \
"hpl/usb/hpl_usb.o" \
"hal/src/hal_delay.o" \
"hpl/pm/hpl_pm.o" \
"hpl/core/hpl_init.o" \
"hal/utils/src/utils_list.o" \
"hpl/core/hpl_core_m0plus_base.o" \
"hal/utils/src/utils_assert.o" \
"usb_start.o" \
"hpl/sysctrl/hpl_sysctrl.o" \
"hpl/gclk/hpl_gclk.o" \
"usb/usb_protocol.o" \
"hal/src/hal_init.o" \
"hal/src/hal_usb_device.o" \
"main.o" \
"driver_init.o" \
"hpl/sercom/hpl_sercom.o" \
"hal/src/hal_gpio.o" \
"hal/utils/src/utils_event.o" \
"hal/src/hal_sleep.o" \
"Device_Startup/system_samd11.o" \
"hpl/dmac/hpl_dmac.o" \
"atmel_start.o" \
"usb/device/usbdc.o" \
"Device_Startup/startup_samd11.o" \
"hal/src/hal_atomic.o"

# List the directories containing header files
DIR_INCLUDES +=  \
-I"./" \
-I"./config" \
-I"./hal/include" \
-I"./hal/utils/include" \
-I"./hpl/core" \
-I"./hpl/dmac" \
-I"./hpl/gclk" \
-I"./hpl/pm" \
-I"./hpl/port" \
-I"./hpl/sercom" \
-I"./hpl/sysctrl" \
-I"./hpl/usb" \
-I"./hri" \
-I"./" \
-I"./config" \
-I"./usb" \
-I"./usb/class/cdc" \
-I"./usb/class/cdc/device" \
-I"./usb/device" \
-I"./" \
-I"./CMSIS/Core/Include" \
-I"./include"

# List the dependency files
DEPS := $(OBJS:%.o=%.d)

DEPS_AS_ARGS +=  \
"hal/src/hal_gpio.d" \
"hal/src/hal_io.d" \
"hal/utils/src/utils_syscalls.d" \
"usb/class/cdc/device/cdcdf_acm.d" \
"hpl/usb/hpl_usb.d" \
"hal/src/hal_spi_m_sync.d" \
"hpl/core/hpl_core_m0plus_base.d" \
"hal/utils/src/utils_list.d" \
"usb_start.d" \
"hal/utils/src/utils_assert.d" \
"hal/src/hal_delay.d" \
"hpl/core/hpl_init.d" \
"hpl/sysctrl/hpl_sysctrl.d" \
"usb/usb_protocol.d" \
"hpl/gclk/hpl_gclk.d" \
"hal/src/hal_usb_device.d" \
"hpl/dmac/hpl_dmac.d" \
"hal/src/hal_init.d" \
"driver_init.d" \
"main.d" \
"hal/src/hal_sleep.d" \
"hpl/sercom/hpl_sercom.d" \
"hal/utils/src/utils_event.d" \
"hal/src/hal_atomic.d" \
"Device_Startup/startup_samd11.d" \
"usb/device/usbdc.d" \
"hpl/pm/hpl_pm.d" \
"atmel_start.d"

OUTPUT_FILE_NAME :=ueu
QUOTE := "
OUTPUT_FILE_PATH +=$(OUTPUT_FILE_NAME).elf
OUTPUT_FILE_PATH_AS_ARGS +=$(OUTPUT_FILE_NAME).elf

vpath %.c ./
vpath %.s ./
vpath %.S ./

# All Target
all: $(SUB_DIRS) $(OUTPUT_FILE_PATH)

# Linker target

$(OUTPUT_FILE_PATH): $(OBJS)
	@echo Building target: $@
	@echo Invoking: ARM/GNU Linker
	$(QUOTE)arm-none-eabi-gcc$(QUOTE) -o $(OUTPUT_FILE_NAME).elf $(OBJS_AS_ARGS) -Wl,--start-group -lm -Wl,--end-group -mthumb \
-Wl,-Map="$(OUTPUT_FILE_NAME).map" --specs=nano.specs -Wl,--gc-sections -mcpu=cortex-m0plus \
 \
-T"./Device_Startup/samd11c14a_flash.ld" \
-L"./Device_Startup"
	@echo Finished building target: $@

	"arm-none-eabi-objcopy" -O binary "$(OUTPUT_FILE_NAME).elf" "$(OUTPUT_FILE_NAME).bin"
	"arm-none-eabi-objcopy" -O ihex -R .eeprom -R .fuse -R .lock -R .signature  \
        "$(OUTPUT_FILE_NAME).elf" "$(OUTPUT_FILE_NAME).hex"
	"arm-none-eabi-objcopy" -j .eeprom --set-section-flags=.eeprom=alloc,load --change-section-lma \
        .eeprom=0 --no-change-warnings -O binary "$(OUTPUT_FILE_NAME).elf" \
        "$(OUTPUT_FILE_NAME).eep" || exit 0
	"arm-none-eabi-objdump" -h -S "$(OUTPUT_FILE_NAME).elf" > "$(OUTPUT_FILE_NAME).lss"
	"arm-none-eabi-size" "$(OUTPUT_FILE_NAME).elf"

	

# Compiler targets

# Makefile default is -Os, Atmel Studio default is -O1
C_OPT=-Os

# Shared flags
C_CPP_FLAGS=-mthumb -DDEBUG $(C_OPT) -fno-exceptions -ffunction-sections -mlong-calls -g3 -Wall -D__SAMD11C14A__ -mcpu=cortex-m0plus -c $(DIR_INCLUDES) -MD -MP -MF "$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -MT"$(@:%.o=%.o)"

# Language-specific flags
C_FLAGS=-x c -std=gnu99 $(C_CPP_FLAGS)
CPP_FLAGS=-x c++ -std=c++11 $(C_CPP_FLAGS)

%.o: %.c
	@echo Building file: $<
	@echo ARM/GNU C Compiler
	$(QUOTE)arm-none-eabi-gcc$(QUOTE) $(C_FLAGS) -o "$@" "$<"
	@echo Finished building: $<

%.o: %.cpp
	@echo Building file: $<
	@echo ARM/GNU C++ Compiler
	$(QUOTE)arm-none-eabi-g++$(QUOTE) $(CPP_FLAGS) -o "$@" "$<"
	@echo Finished building: $<

%.o: %.s
	@echo Building file: $<
	@echo ARM/GNU Assembler
	$(QUOTE)arm-none-eabi-as$(QUOTE) $(C_FLAGS) -o "$@" "$<"
	@echo Finished building: $<

%.o: %.S
	@echo Building file: $<
	@echo ARM/GNU Preprocessing Assembler
	$(QUOTE)arm-none-eabi-gcc$(QUOTE) $(C_FLAGS) -o "$@" "$<"
	@echo Finished building: $<

# Detect changes in the dependent files and recompile the respective object files.
ifneq ($(MAKECMDGOALS),clean)
ifneq ($(strip $(DEPS)),)
-include $(DEPS)
endif
endif

$(SUB_DIRS):
	$(MK_DIR) "$@"

clean:
	rm -f $(OBJS_AS_ARGS)
	rm -f $(OUTPUT_FILE_PATH)
	rm -f $(DEPS_AS_ARGS)
	rm -f $(OUTPUT_FILE_NAME).a $(OUTPUT_FILE_NAME).hex $(OUTPUT_FILE_NAME).bin \
        $(OUTPUT_FILE_NAME).lss $(OUTPUT_FILE_NAME).eep $(OUTPUT_FILE_NAME).map \
        $(OUTPUT_FILE_NAME).srec
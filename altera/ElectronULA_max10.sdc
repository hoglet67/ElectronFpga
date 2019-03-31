#**************************************************************
# Intel Max 10 SDC settings
# Users are recommended to modify this file to match users logic.
#**************************************************************

#**************************************************************
# Create Clock
#**************************************************************

# External clock inputs
create_clock -period "16 MHz" -name clk_in [get_ports clk_in]

#ElectronFpga_core:electron_core|ElectronULA:ula|clk_video

# Generated clocks (via PLL from 16MHz clk_in)
create_generated_clock -source {max10_pll1_inst|altpll_component|pll1|inclk[0]} -duty_cycle 50.00 -name clock_16 {max10_pll1_inst|altpll_component|pll1|clk[0]}
create_generated_clock -source {max10_pll1_inst|altpll_component|pll1|inclk[0]} -divide_by 2 -multiply_by 3 -duty_cycle 50.00 -name clock_24 {max10_pll1_inst|altpll_component|pll1|clk[1]}
create_generated_clock -source {max10_pll1_inst|altpll_component|pll1|inclk[0]} -multiply_by 2 -duty_cycle 50.00 -name clock_32 {max10_pll1_inst|altpll_component|pll1|clk[2]}
create_generated_clock -source {max10_pll1_inst|altpll_component|pll1|inclk[0]} -divide_by 2 -multiply_by 5 -duty_cycle 50.00 -name clock_40 {max10_pll1_inst|altpll_component|pll1|clk[3]}
create_generated_clock -source {max10_pll1_inst|altpll_component|pll1|inclk[0]} -divide_by 29 -multiply_by 60 -duty_cycle 50.00 -name clock_33 {max10_pll1_inst|altpll_component|pll1|clk[4]}

# Include this if building with IncludeICEDebugger
# create_clock -period "16 MHz"  -name clock_avr {electron_core:bbc_micro|clock_avr}

	
#**************************************************************
# Create Generated Clock
#**************************************************************

# Doing this manually above so we can name the clock
#derive_pll_clocks


#**************************************************************
# Set Clock Latency
#**************************************************************

#**************************************************************
# Set Clock Uncertainty
#**************************************************************
derive_clock_uncertainty

#**************************************************************
# Set Input Delay (other inputs)
#**************************************************************
# Board Delay (Data) + Propagation Delay - Board Delay (Clock)

# Design with CPU running at 2MHz allows for ~14 32MHz cycles
# so probably safe to leave unconstrained:

#set_input_delay -min -clock clock_32    0.0 [get_ports FL_DQ]
#set_input_delay -max -clock clock_32    0.0 [get_ports FL_DQ]

# Asynchronous, so don't bother constraining:

#set_input_delay -min -clock clock_32    0.0 [get_ports SW]
#set_input_delay -max -clock clock_32    0.0 [get_ports SW]
#set_input_delay -min -clock clock_32    0.0 [get_ports KEY]
#set_input_delay -max -clock clock_32    0.0 [get_ports KEY]
#set_input_delay -min -clock clock_32    0.0 [get_ports UART_RXD]
#set_input_delay -max -clock clock_32    0.0 [get_ports UART_RXD]

# More complex, so don't bother constraining:

#set_input_delay -min -clock clock_32    0.0 [get_ports PS2_CLK]
#set_input_delay -max -clock clock_32    0.0 [get_ports PS2_CLK]
#set_input_delay -min -clock clock_32    0.0 [get_ports PS2_DAT]
#set_input_delay -max -clock clock_32    0.0 [get_ports PS2_DAT]
#set_input_delay -min -clock clock_32    0.0 [get_ports I2C_SCLK]
#set_input_delay -max -clock clock_32    0.0 [get_ports I2C_SCLK]
#set_input_delay -min -clock clock_32    0.0 [get_ports I2C_SDAT]
#set_input_delay -max -clock clock_32    0.0 [get_ports I2C_SDAT]
#set_input_delay -min -clock clock_32    0.0 [get_ports SD_MISO]
#set_input_delay -max -clock clock_32    0.0 [get_ports SD_MISO]

# Unused:
#    AUD_ADCDAT
#    DRAM_DQ
#    DRAM_BA_0
#    DRAM_BA_1
#    DRAM_CAS_N
#    DRAM_CKE
#    DRAM_CLK
#    DRAM_CS_N
#    DRAM_LDQM
#    DRAM_RAS_N
#    DRAM_UDQM
#    DRAM_WE_N
#    GPIO_0
#    GPIO_1

#**************************************************************
# Set Output Delay (other outputs)
#**************************************************************
# max : Board Delay (Data) - Board Delay (Clock) + tsu (External Device)
# min : Board Delay (Data) - Board Delay (Clock) - th (External Device)

# Design with CPU running at 2MHz allows for ~14 32MHz cycles
# for FLASH data reads, so this is not important

set_output_delay -clock clock_16 -min 0    [get_ports SRAM_ADDR*]
set_output_delay -clock clock_16 -max 20   [get_ports SRAM_ADDR*]
set_output_delay -clock clock_16 -min 0    [get_ports SRAM_OE_N]
set_output_delay -clock clock_16 -max 20   [get_ports SRAM_OE_N]
set_output_delay -clock clock_16 -min 0    [get_ports SRAM_WE_N]
set_output_delay -clock clock_16 -max 20   [get_ports SRAM_WE_N]
set_output_delay -clock clock_16 -min 0    [get_ports SRAM_DQ*]
set_output_delay -clock clock_16 -max 20   [get_ports SRAM_DQ*]
set_output_delay -clock clock_16 -min 0    [get_ports FL_ADDR*]
set_output_delay -clock clock_16 -max 20   [get_ports FL_ADDR*]
set_output_delay -clock clock_16 -min 0    [get_ports FL_RST_N]
set_output_delay -clock clock_16 -max 20   [get_ports FL_RST_N]

# Setting a max of 0 allows the data delay to be a whole clock cycle, less any notional clock skew
# Add -source_latency_included to prevent clock skew being included

set_output_delay -clock clock_16 -min 0   [get_ports UART_TXD]
set_output_delay -clock clock_16 -max 0   [get_ports UART_TXD]
set_output_delay -clock clock_32 -min 0   [get_ports I2C_SCLK]
set_output_delay -clock clock_32 -max 0   [get_ports I2C_SCLK]
set_output_delay -clock clock_32 -min 0   [get_ports I2C_SDAT]
set_output_delay -clock clock_32 -max 0   [get_ports I2C_SDAT]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_XCK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_XCK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_BCLK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_BCLK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_ADCLRCK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_ADCLRCK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_DACLRCK]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_DACLRCK]
set_output_delay -clock clock_32 -min 0   [get_ports AUD_DACDAT]
set_output_delay -clock clock_32 -max 0   [get_ports AUD_DACDAT]
set_output_delay -clock clock_16 -min 0   [get_ports SD_MOSI]
set_output_delay -clock clock_16 -max 0   [get_ports SD_MOSI]
set_output_delay -clock clock_16 -min 0   [get_ports SD_SCLK]
set_output_delay -clock clock_16 -max 0   [get_ports SD_SCLK]

# Not critical
set_false_path -from * -to [get_ports HEX*]
set_false_path -from * -to [get_ports LED*]
set_false_path -from * -to [get_ports VGA*]

#set_output_delay -clock clock_32 -min 0   [get_ports HEX*]
#set_output_delay -clock clock_32 -max 0   [get_ports HEX*]
#set_output_delay -clock clock_32 -min 0   [get_ports LED*]
#set_output_delay -clock clock_32 -max 0   [get_ports LED*]
#set_output_delay -clock clock_32 -min 0   [get_ports VGA*]
#set_output_delay -clock clock_32 -max 0   [get_ports VGA*]
#set_output_delay -clock clock_24 -min 0   [get_ports VGA*] -add_delay
#set_output_delay -clock clock_24 -max 0   [get_ports VGA*] -add_delay
#set_output_delay -clock clock_27 -min 0   [get_ports VGA*] -add_delay
#set_output_delay -clock clock_27 -max 0   [get_ports VGA*] -add_delay

# Ununsed or fixed
set_false_path -from * -to [get_ports SRAM_CE_N]
set_false_path -from * -to [get_ports SRAM_UB_N]
set_false_path -from * -to [get_ports SRAM_LB_N]
set_false_path -from * -to [get_ports DRAM_ADDR*]
set_false_path -from * -to [get_ports DRAM_DQ*]
set_false_path -from * -to [get_ports FL_OE_N]
set_false_path -from * -to [get_ports FL_WE_N]
set_false_path -from * -to [get_ports FL_CE_N]
set_false_path -from * -to [get_ports SD_nCS]
set_false_path -from * -to [get_ports GPIO_0*]
set_false_path -from * -to [get_ports GPIO_1*]
    
#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -asynchronous -group {clock_16}  -group {clock_32}
set_clock_groups -asynchronous -group {clock_32}  -group {clock_16}
set_clock_groups -asynchronous -group {clock_16}  -group {clock_24}
set_clock_groups -asynchronous -group {clock_24}  -group {clock_16}
set_clock_groups -asynchronous -group {clock_16}  -group {clock_33}
set_clock_groups -asynchronous -group {clock_33}  -group {clock_16}
set_clock_groups -asynchronous -group {clock_16}  -group {clock_40}
set_clock_groups -asynchronous -group {clock_40}  -group {clock_16}

#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************



#**************************************************************
# Set Load
#**************************************************************


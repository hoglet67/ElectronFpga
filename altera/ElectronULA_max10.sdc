#**************************************************************
# Intel Max 10 SDC settings
# Users are recommended to modify this file to match users logic.
#**************************************************************

# https://fpgawiki.intel.com/wiki/Timing_Constraints is helpful to understand
# the directives in this file.

#**************************************************************
# Create Clock
#**************************************************************

# External clock inputs
create_clock -period "16 MHz" -name clk_in [get_ports clk_in]
create_clock -period "16 MHz" -name clk_osc [get_ports clk_osc]

# Generated clocks (via PLL from 16MHz input clock)
# Comment these out to use derive_pll_clocks instead
#create_generated_clock -source max10_pll1_inst|altpll_component|auto_generated|pll1|inclk[0] -duty_cycle 50.00 -name clock_16 [get_pins max10_pll1_inst|altpll_component|auto_generated|pll1|clk[0]]
#create_generated_clock -source max10_pll1_inst|inclk[0] -divide_by 2 -multiply_by 3 -duty_cycle 50.00 -name clock_24 [get_pins max10_pll1_inst|clk[1]]
#create_generated_clock -source max10_pll1_inst|inclk[0] -multiply_by 2 -duty_cycle 50.00 -name clock_32 [get_pins max10_pll1_inst|clk[2]]
#create_generated_clock -source max10_pll1_inst|inclk[0] -divide_by 2 -multiply_by 5 -duty_cycle 50.00 -name clock_40 [get_pins max10_pll1_inst|clk[3]]
#create_generated_clock -source max10_pll1_inst|inclk[0] -divide_by 29 -multiply_by 60 -duty_cycle 50.00 -name clock_33 [get_pins max10_pll1_inst|clk[4]]

# Clock muxes
create_clock -period "16 MHz" -name clk_16M00_a [get_ports clk_16M00_a]
create_clock -period "16 MHz" -name clk_16M00_b [get_ports clk_16M00_b]
create_clock -period "16 MHz" -name clk_16M00_c [get_ports clk_16M00_c]

# Include this if building with IncludeICEDebugger
# create_clock -period "16 MHz"  -name clock_avr {electron_core:bbc_micro|clock_avr}


#**************************************************************
# Create Generated Clock
#**************************************************************

# Alternatively use a create_generated_clock line for each clock
derive_pll_clocks


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

#**************************************************************
# Set Output Delay (other outputs)
#**************************************************************
# max : Board Delay (Data) - Board Delay (Clock) + tsu (External Device)
# min : Board Delay (Data) - Board Delay (Clock) - th (External Device)

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


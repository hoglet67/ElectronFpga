set_operating_conditions -grade c -model slow -speed 8 -setup -hold

create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}] -add
create_clock -name audio_clk -period 40.690 -waveform {0 20.345} [get_ports {audio_clk}] -add

// Create clock definitions for each of the derived clocks
create_generated_clock -name clock_27 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 27 [get_nets {clock_27}]
create_generated_clock -name clock_48 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 48 [get_nets {clock_48}]
create_generated_clock -name clock_96 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 96 [get_nets {clock_96}]
//create_generated_clock -name clock_81 -source [get_ports {sys_clk}] -master_clock sys_clk -divide_by 27 -multiply_by 81 [get_nets {clock_81}]
create_generated_clock -name spdif_clk -source [get_ports {audio_clk}] -master_clock audio_clk -divide_by 4 -multiply_by 1 [get_nets {spdif_clk}]

// Ignore any timing paths between the main and HDMI clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {clock_27}]
set_clock_groups -asynchronous -group [get_clocks {clock_27}] -group [get_clocks {clock_48}]
//set_clock_groups -asynchronous -group [get_clocks {clock_27}] -group [get_clocks {clock_81}]

// Ignore any timing paths from main to spdif clocks
set_clock_groups -asynchronous -group [get_clocks {clock_48}] -group [get_clocks {spdif_clk}]

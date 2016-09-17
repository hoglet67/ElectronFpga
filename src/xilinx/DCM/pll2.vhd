library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity pll2 is
port
 (-- Clock in ports
  CLKIN_IN          : in     std_logic;
  -- Clock out ports
  CLK0_OUT          : out    std_logic;
  CLK1_OUT          : out    std_logic;
  CLK2_OUT          : out    std_logic;
  CLK3_OUT          : out    std_logic
 );
end pll2;

architecture xilinx of pll2 is
    signal GND_BIT     : std_logic;
    signal CLKFBOUT    : std_logic;
    signal CLKFB       : std_logic;
    signal CLKFBIN     : std_logic;
    signal CLKIN       : std_logic;
    signal CLK0        : std_logic;
    signal CLK0_BUF    : std_logic;
    signal CLK1        : std_logic;
    signal CLK1_BUF    : std_logic;
    signal CLK2        : std_logic;
    signal CLK2_BUF    : std_logic;
    signal CLK3        : std_logic;
    signal CLK3_BUF    : std_logic;

begin

    GND_BIT <= '0';
    
    -- This PLL completely de-skews the clock network wrt the input pin
    -- Note: the BUFIO2 instance needed manually placing in the .ucf file
    
    -- Clock input io2 buffer
    CLKIN_BUFIO2_INST : BUFIO2
        port map (I => CLKIN_IN, DIVCLK => CLKIN);

    -- Clock feedback output buffer
    CLKFB_BUFG_INST : BUFG
        port map (I => CLKFBOUT, O => CLKFB);
        
    -- Clock feedback io2 buffer
    CLKFB_BUFIO2FB_INST : BUFIO2FB
        port map (I => CLKFB, O => CLKFBIN);
    
    -- CLK0 output buffer
    CLK0_BUFG_INST : BUFG
        port map (I => CLK0, O => CLK0_BUF);
    CLK0_OUT <= CLK0_BUF;

    -- CLK1 output buffer
    CLK1_BUFG_INST : BUFG
        port map (I => CLK1, O => CLK1_BUF);
    CLK1_OUT <= CLK1_BUF;

    -- CLK2 output buffer
    CLK2_BUFG_INST : BUFG
        port map (I => CLK2, O => CLK2_BUF);
    CLK2_OUT <= CLK2_BUF;

    -- CLK3 output buffer
    CLK3_BUFG_INST : BUFG
        port map (I => CLK3, O => CLK3_BUF);
    CLK3_OUT <= CLK3_BUF;

    
    INST_PLL : PLL_BASE
    generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLK_FEEDBACK         => "CLKFBOUT",
        COMPENSATION         => "SYSTEM_SYNCHRONOUS", -- not sure this is correct
        DIVCLK_DIVIDE        => 1,
        CLKFBOUT_MULT        => 30,         -- 16 x 30 = 480MHz
        CLKFBOUT_PHASE       => 0.000,
        CLKOUT0_DIVIDE       => 30,         -- 480 / 30 = 16MHz
        CLKOUT0_PHASE        => 0.000,
        CLKOUT0_DUTY_CYCLE   => 0.500,
        CLKOUT1_DIVIDE       => 20,         -- 480 / 20 = 24 MHz
        CLKOUT1_PHASE        => 0.000,
        CLKOUT1_DUTY_CYCLE   => 0.500,
        CLKOUT2_DIVIDE       => 15,         -- 480 / 15 = 32 MHz
        CLKOUT2_PHASE        => 0.000,
        CLKOUT2_DUTY_CYCLE   => 0.500,
        CLKOUT3_DIVIDE       => 12,         -- 480 / 12 = 40 MHZ
        CLKOUT3_PHASE        => 0.000,
        CLKOUT3_DUTY_CYCLE   => 0.500,
        CLKIN_PERIOD         => 50.000,     -- WARNING, this is 20MHz, should be 16MHz, but this is < min of 19MHz
        REF_JITTER           => 0.010)
    port map (
        -- Input clock control
        CLKIN               => CLKIN,
        CLKFBIN             => CLKFBIN,
        -- Output clocks
        CLKFBOUT            => CLKFBOUT,
        CLKOUT0             => CLK0,
        CLKOUT1             => CLK1,
        CLKOUT2             => CLK2,
        CLKOUT3             => CLK3,
        CLKOUT4             => open,
        CLKOUT5             => open,
        LOCKED              => open,
        RST                 => GND_BIT
     );

end xilinx;

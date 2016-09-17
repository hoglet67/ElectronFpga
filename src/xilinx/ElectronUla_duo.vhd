--------------------------------------------------------------------------------
-- Copyright (c) 2016 David Banks
--------------------------------------------------------------------------------
--   ____  ____ 
--  /   /\/   / 
-- /___/  \  /    
-- \   \   \/    
--  \   \         
--  /   /         Filename  : ElectronUla_duo.vhd
-- /___/   /\     Timestamp : 17/09/2016
-- \   \  /  \ 
--  \___\/\___\ 
--
--Design Name: ElectronFpga_core


-- TODO:
-- Implement Cassette Out

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- TODO:
-- IRQ_n should be open collector
-- NMI_n needs adding
-- HS_n  needs adding
-- CasIn needs adding
-- CasOut needs adding
-- CasMotor needs adding
-- Contention needs implementing (refector from core?)
-- clock pll currently running out of spec (16MHz, min should be 19MHz)

entity ElectronULA_duo is
    port (
        clk_in    : in  std_logic;
        
        -- CPU Interface
        clk_out   : out   std_logic;
        addr      : in    std_logic_vector(15 downto 0);
        data      : inout std_logic_vector(7 downto 0);
        R_W_n     : in  std_logic;
        RST_n     : inout  std_logic;
        IRQ_n     : out std_logic;

        -- Data Bus Enble
        DBE_n     : out std_logic;

        -- Rom Enable
        ROM_n     : out std_logic;
        
        -- Video
        red       : out std_logic;
        green     : out std_logic;
        blue      : out std_logic;
        csync     : out std_logic;

        -- Audio
        sound     : out std_logic;

        -- Keyboard
        kbd       : in  std_logic_vector(3 downto 0);
        caps      : out std_logic;
        
        -- Misc
        ARDUINO_RESET : out std_logic;
        SW1           : in std_logic
        );
end;

architecture behavioral of ElectronULA_duo is


signal clock_16        : std_logic;
signal clock_24        : std_logic;
signal clock_32        : std_logic;
signal clock_33        : std_logic;
signal clock_40        : std_logic;

signal clken_counter   : std_logic_vector(3 downto 0);
signal ula_clken       : std_logic;

signal data_in         : std_logic_vector(7 downto 0);
signal data_out        : std_logic_vector(7 downto 0);
signal video_red       : std_logic_vector(3 downto 0);
signal video_green     : std_logic_vector(3 downto 0);
signal video_blue      : std_logic_vector(3 downto 0);
signal video_hsync     : std_logic;
signal video_vsync     : std_logic;
signal DBE             : std_logic;
signal rom_latch       : std_logic_vector(3 downto 0);

signal powerup_reset_n : std_logic;
signal reset_counter   : std_logic_vector (15 downto 0);

begin

    inst_pll: entity work.pll2 port map(
        -- 16 MHz input clock
        CLKIN_IN => clk_in,
        -- the main system clock, and also the video clock in sRGB mode
        CLK0_OUT => clock_16,
        -- used as a 24.00MHz for the SAA5050 in Mode 7
        CLK1_OUT  => clock_24,
        -- used as a output clock MIST scan doubler for the SAA5050 in Mode 7
        CLK2_OUT  => clock_32,
        -- used as a video clock when the ULA is in 60Hz VGA Mode
        CLK3_OUT  => clock_40
    );

    inst_dcm : entity work.dcm2 port map(
        CLKIN_IN          => clk_in,
        -- used as a video clock when the ULA is in 50Hz VGA Mode
        CLKFX_OUT         => clock_33
    );

    clk_gen : process(clock_16)
    begin
        if rising_edge(clock_16) then
            clken_counter <= clken_counter + 1;
            clk_out <= clken_counter(3);
            if clken_counter = "1111" then
                ula_clken <= '1';
            else
                ula_clken <= '0';
            end if;
        end if;
    end process;
       
    ula : entity work.ElectronULA
    generic map (
        Include32KRAM    => true,
        IncludeJafaMode7 => false
    )
    port map (
        clk_16M00 => clock_16,
        clk_24M00 => clock_24,
        clk_32M00 => clock_32,
        clk_33M33 => clock_33,
        clk_40M00 => clock_40,
        
        -- CPU Interface
        cpu_clken => ula_clken,
        addr      => addr,
        data_in   => data_in,
        data_out  => data_out,
        R_W_n     => R_W_n,
        RST_n     => RST_n,
        IRQ_n     => IRQ_n,
        NMI_n     => '1',

        -- Rom Enable
        ROM_n     => ROM_n,

        -- Video
        red       => video_red,
        green     => video_green,
        blue      => video_blue,
        vsync     => video_vsync,
        hsync     => video_hsync,

        -- Audio
        sound     => sound,

        -- Casette
        casIn     => '1',
        casOut    => open,

        -- Keyboard
        kbd       => kbd,

        -- MISC
        caps      => caps,
        motor     => open,

        rom_latch => rom_latch,

        mode_init => "00",

        contention => open
    );

    red   <= video_red(3);
    green <= video_green(3);
    blue  <= video_blue(3);
    csync <= video_hsync;

    -- Enable data bus transceiver when ULA or RAM selected
    -- TODO: Push down into ULA
    DBE <= '1' when addr(15) = '0' or addr(15 downto 8) = x"FE" or (addr(15 downto 14) = "10" and rom_latch(3 downto 1) = "100") 
               else '0';
    DBE_n <= not DBE;

    data_in <= data;
    data <= data_out when R_W_n = '1' and DBE = '1' else "ZZZZZZZZ";
    
--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    reset_gen : process(clock_16)
    begin
        if rising_edge(clock_16) then
            if (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= reset_counter(reset_counter'high);
        end if;
    end process;

    -- Reset is open collector to avoid contention when BREAK pressed
    RST_n <= '0' when powerup_reset_n = '0' else 'Z';
            
    -- Hold the Duo's Arduino core in reset
    ARDUINO_RESET <= SW1;

end behavioral;

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
        
        -- SD Card
        SDMISO         : in  std_logic;
        SDSS           : out std_logic;
        SDCLK          : out std_logic;
        SDMOSI         : out std_logic;

        -- Misc
        ARDUINO_RESET : out std_logic;
        SW1           : in std_logic
        );
end;

architecture behavioral of ElectronULA_duo is

signal clock_16          : std_logic;
signal clock_24          : std_logic;
signal clock_32          : std_logic;
signal clock_33          : std_logic;
signal clock_40          : std_logic;

signal clken_counter     : std_logic_vector(3 downto 0);
signal ula_clken         : std_logic;
signal via1_clken        : std_logic;
signal via4_clken        : std_logic;

signal data_in           : std_logic_vector(7 downto 0);
signal ula_data          : std_logic_vector(7 downto 0);
signal ula_irq_n         : std_logic;
signal video_red         : std_logic_vector(3 downto 0);
signal video_green       : std_logic_vector(3 downto 0);
signal video_blue        : std_logic_vector(3 downto 0);
signal video_hsync       : std_logic;
signal video_vsync       : std_logic;
signal DBE               : std_logic;
signal rom_latch         : std_logic_vector(3 downto 0);

signal powerup_reset_n   : std_logic;
signal reset_counter     : std_logic_vector (15 downto 0);

signal ula_enable        : std_logic;

signal rom_enable        : std_logic;
signal rom_data          : std_logic_vector(7 downto 0);
signal rom_we            : std_logic;

signal mc6522_enable     : std_logic;
signal mc6522_data       : std_logic_vector(7 downto 0);
signal mc6522_data_r     : std_logic_vector(7 downto 0);
signal mc6522_irq_n      : std_logic;
-- Port A is not really used, so signals directly loop back out to in
signal mc6522_ca2        : std_logic;
signal mc6522_porta      : std_logic_vector(7 downto 0);
-- Port B is used for the MMBEEB style SDCard Interface
signal mc6522_cb1_in     : std_logic;
signal mc6522_cb1_out    : std_logic;
signal mc6522_cb1_oe_l   : std_logic;
signal mc6522_cb2_in     : std_logic;
signal mc6522_portb_in   : std_logic_vector(7 downto 0);
signal mc6522_portb_out  : std_logic_vector(7 downto 0);
signal mc6522_portb_oe_l : std_logic_vector(7 downto 0);
signal sdclk_int         : std_logic;

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
            if clken_counter = "1111" then
                via1_clken <= '1';
            else
                via1_clken <= '0';
            end if;
            if clken_counter(1 downto 0) = "11" then
                via4_clken <= '1';
            else
                via4_clken <= '0';
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
        data_out  => ula_data,
        R_W_n     => R_W_n,
        RST_n     => RST_n,
        IRQ_n     => ula_irq_n,
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
    DBE_n <= '0' when ula_enable = '1' or rom_enable = '1' or mc6522_enable = '1' else '1';
       
    ula_enable <= '1' when addr(15) = '0' or addr(15 downto 8) = x"FE" or (addr(15 downto 14) = "10" and rom_latch(3 downto 1) = "100") else '0';

    data_in <= data;
    
    data <= mc6522_data_r when R_W_n = '1' and mc6522_enable = '1' else
            rom_data      when R_W_n = '1' and rom_enable = '1' else 
            ula_data      when R_W_n = '1' and ula_enable = '1' else
            "ZZZZZZZZ";

    IRQ_n <= mc6522_irq_n AND ula_irq_n;

--------------------------------------------------------
-- Paged ROM
--------------------------------------------------------

    rom_enable  <= '1' when addr(15 downto 14) = "10" and rom_latch = "0100" else '0';

    rom_we <= '1' when rom_enable = '1' and ula_clken = '1' else '0';
              
    rom : entity work.expansion_rom port map(
        clk      => clock_16,
        we       => rom_we,
        addr     => addr(13 downto 0),
        data_in  => data_in,
        data_out => rom_data
    );
    
--------------------------------------------------------
-- MMC Filing System
--------------------------------------------------------

    mc6522_enable  <= '1' when addr(15 downto 4) = x"fcb" else '0';
    
    via : entity work.M6522 port map(
        I_RS       => addr(3 downto 0),
        I_DATA     => data_in(7 downto 0),
        O_DATA     => mc6522_data(7 downto 0),
        I_RW_L     => R_W_n,
        I_CS1      => mc6522_enable,
        I_CS2_L    => '0',
        O_IRQ_L    => mc6522_irq_n,
        I_CA1      => '0',
        I_CA2      => mc6522_ca2,
        O_CA2      => mc6522_ca2,
        O_CA2_OE_L => open,
        I_PA       => mc6522_porta,
        O_PA       => mc6522_porta,
        O_PA_OE_L  => open,
        I_CB1      => mc6522_cb1_in,
        O_CB1      => mc6522_cb1_out,
        O_CB1_OE_L => mc6522_cb1_oe_l,
        I_CB2      => mc6522_cb2_in,
        O_CB2      => open,
        O_CB2_OE_L => open,
        I_PB       => mc6522_portb_in,
        O_PB       => mc6522_portb_out,
        O_PB_OE_L  => mc6522_portb_oe_l,
        RESET_L    => RST_n,
        I_P2_H     => via1_clken,
        ENA_4      => via4_clken,
        CLK        => clock_16);

    -- This is needed as in v003 of the 6522 data out is only valid while I_P2_H is asserted
    -- I_P2_H is driven from via1_clken
    data_latch: process(clock_16)
    begin
        if rising_edge(clock_16) then
            if (via1_clken = '1') then
                mc6522_data_r <= mc6522_data;
            end if;
        end if;
    end process;
    
    -- loop back data port
    mc6522_portb_in <= mc6522_portb_out;

    -- SDCLK is driven from either PB1 or CB1 depending on the SR Mode
    sdclk_int     <= mc6522_portb_out(1) when mc6522_portb_oe_l(1) = '0' else
                     mc6522_cb1_out      when mc6522_cb1_oe_l = '0' else
                     '1';
    SDCLK         <= sdclk_int;
    mc6522_cb1_in <= sdclk_int;

    -- SDMOSI is always driven from PB0
    SDMOSI        <= mc6522_portb_out(0) when mc6522_portb_oe_l(0) = '0' else
                     '1';
    -- SDMISO is always read from CB2
    mc6522_cb2_in <= SDMISO;

    -- SDSS is hardwired to 0 (always selected) as there is only one slave attached
    SDSS          <= '0';

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

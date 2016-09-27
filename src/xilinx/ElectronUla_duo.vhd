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
--Design Name: ElectronUla_duo

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- TODO:
-- NMI_n needs adding
-- HS_n  needs adding
-- CasIn needs adding
-- CasOut needs adding
-- CasMotor needs adding
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
        SW1           : in std_logic;
        LED           : out std_logic
        );
end;

architecture behavioral of ElectronULA_duo is

signal clock_16          : std_logic;
signal clock_24          : std_logic;
signal clock_32          : std_logic;
signal clock_33          : std_logic;
signal clock_40          : std_logic;

signal led_counter       : std_logic_vector(23 downto 0);
signal clk_counter       : std_logic_vector(2 downto 0);
signal cpu_clken         : std_logic;

signal data_in           : std_logic_vector(7 downto 0);

signal ula_enable        : std_logic;
signal ula_data          : std_logic_vector(7 downto 0);
signal ula_irq_n         : std_logic;
signal video_red         : std_logic_vector(3 downto 0);
signal video_green       : std_logic_vector(3 downto 0);
signal video_blue        : std_logic_vector(3 downto 0);
signal video_hsync       : std_logic;
signal video_vsync       : std_logic;
signal rom_latch         : std_logic_vector(3 downto 0);

signal powerup_reset_n   : std_logic;
signal reset_counter     : std_logic_vector (15 downto 0);

signal rom_enable        : std_logic;
signal rom_data          : std_logic_vector(7 downto 0);
signal rom_we            : std_logic;

signal turbo             : std_logic_vector(1 downto 0);

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

    -- TODO
    -- clk_out is not correct as the low time is always 250ns
    clk_gen : process(clock_16)
    begin
        if rising_edge(clock_16) then
            if cpu_clken = '1' then
                clk_counter <= (others => '0');
                clk_out <= '0';
            elsif clk_counter(2) = '0' then
                clk_counter <= clk_counter + 1;
            else
                clk_out <= '1';
            end if;
        end if;
    end process;

    ula : entity work.ElectronULA
    generic map (
        IncludeMMC       => true,
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
        addr      => addr,
        data_in   => data_in,
        data_out  => ula_data,
        data_en   => ula_enable,
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

        -- SD Card
        SDMISO    => SDMISO,
        SDSS      => SDSS,
        SDCLK     => SDCLK,
        SDMOSI    => SDMOSI,

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

        -- Clock Generation
        cpu_clken_out  => cpu_clken,
        turbo          => turbo,
        turbo_out      => turbo
    );

    red   <= video_red(3);
    green <= video_green(3);
    blue  <= video_blue(3);
    csync <= video_hsync;

    -- IRQ is open collector to avoid contention with the expansion bus
    IRQ_n <= '0' when ula_irq_n = '0' else 'Z';

    -- Enable data bus transceiver when ULA or ROM selected
    DBE_n <= '0' when ula_enable = '1' or rom_enable = '1' else '1';

    data_in <= data;

    data <= rom_data      when R_W_n = '1' and rom_enable = '1' else
            ula_data      when R_W_n = '1' and ula_enable = '1' else
            "ZZZZZZZZ";

--------------------------------------------------------
-- Paged ROM
--------------------------------------------------------

    rom_enable  <= '1' when addr(15 downto 14) = "10" and rom_latch = "0100" else '0';

    rom_we <= '1' when rom_enable = '1' and cpu_clken = '1' else '0';

    rom : entity work.expansion_rom port map(
        clk      => clock_16,
        we       => rom_we,
        addr     => addr(13 downto 0),
        data_in  => data_in,
        data_out => rom_data
    );

--------------------------------------------------------
-- Speed LED
--------------------------------------------------------

    led_gen : process(clock_16)
    begin
        if rising_edge(clock_16) then
            led_counter <= led_counter + 1;
        end if;
    end process;

    LED <= led_counter(led_counter'high - to_integer(unsigned(turbo)));

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

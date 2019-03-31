--------------------------------------------------------------------------------
-- Copyright (c) 2016 David Banks
-- Copyright (c) 2019 Google LLC
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- TODO:
-- NMI_n needs adding
-- HS_n  needs adding
-- RAM lines need adding (RA7..0, RD3..0, RAS, CAS, WE)

entity ElectronULA_max10 is
    port (
        clk_in        : in  std_logic;

        -- CPU Interface
        clk_out       : out   std_logic;
        addr          : in    std_logic_vector(15 downto 0);
        data          : inout std_logic_vector(7 downto 0);
        R_W_n         : in  std_logic;
        RST_n         : inout  std_logic;
        IRQ_n         : out std_logic;

        -- Data Bus Enble
        DBE_n         : out std_logic;

        -- Rom Enable
        ROM_n         : out std_logic;

        -- Video
        red           : out std_logic;
        green         : out std_logic;
        blue          : out std_logic;
        csync         : out std_logic;

        -- Audio
        sound         : out std_logic;

        -- Keyboard
        kbd           : in  std_logic_vector(3 downto 0);
        caps          : out std_logic;
        
        -- Cassette
        casIn         : in  std_logic;
        casOut        : out std_logic;
        casMO         : out std_logic;

        -- SD Card
        SDMISO        : in  std_logic;
        SDSS          : out std_logic;
        SDCLK         : out std_logic;
        SDMOSI        : out std_logic;

        -- Misc
        ARDUINO_RESET : out std_logic;
        SW1           : in std_logic;
        LED           : out std_logic
        );
end;

architecture behavioral of ElectronULA_max10 is

signal clock_16          : std_logic;
signal clock_24          : std_logic;
signal clock_32          : std_logic;
signal clock_33          : std_logic;
signal clock_40          : std_logic;

signal pll_reset         : std_logic;
signal pll_reset_counter : std_logic_vector (1 downto 0) := "00";
signal pll1_locked       : std_logic;
signal pll_locked_sync   : std_logic_vector(2 downto 0) := "000";

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

signal caps_led          : std_logic;

begin

    -- According to the Max 10 datasheet (Table 27), 5MHz < fIN < 472.5 MHz, and
    -- the VCO runs between 600-1300 MHz.  We might want a lower-jitter clock than
    -- the 16MHz one from the Electron though.

    -- TODO(myelin) test PLLs with both electron clock and discrete oscillator

    max10_pll1_inst : entity work.max10_pll1 PORT MAP (
        areset   => pll_reset,
        -- PLL input clock
        inclk0   => clk_in,
        -- the main system clock, and also the video clock in sRGB mode
        c0       => clock_16,
        -- used as a 24.00MHz for the SAA5050 in Mode 7
        c1       => clock_24,
        -- used as a output clock MIST scan doubler for the SAA5050 in Mode 7
        c2       => clock_32,
        -- used as a video clock when the ULA is in 60Hz VGA Mode
        c3       => clock_40,
		  -- used as a video clock when the ULA is in 50Hz VGA Mode
        c4       => clock_33,
        locked   => pll1_locked
    );

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
        IncludeVGA       => true,
        IncludeJafaMode7 => true
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
        casIn     => casIn,
        casOut    => casOut,

        -- Keyboard
        kbd       => kbd,

        -- MISC
        caps      => caps_led,
        motor     => casMO,

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
    caps  <= not caps_led;
    
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

    rom_enable  <= '1' when addr(15 downto 14) = "10" and rom_latch(3 downto 1) = "111" else '0';

    rom_we <= '1' when rom_enable = '1' and cpu_clken = '1' else '0';

    -- TODO(myelin) figure out why Quartus can't find expansion_rom.  Is it
    -- having trouble compiling expansion_rom.v?

    -- rom : entity work.expansion_rom port map(
    --     clk      => clock_16,
    --     we       => rom_we,
    --     addr     => rom_latch(0) & addr(13 downto 0),
    --     data_in  => data_in,
    --     data_out => rom_data
    -- );

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

            -- pll_reset_counter is a 2 bit counter, which holds the PLL in
            -- reset for two clocks.

            if (pll_reset_counter(pll_reset_counter'high) = '0') then
                pll_reset_counter <= pll_reset_counter + 1;
            end if;
            pll_reset <= not pll_reset_counter(pll_reset_counter'high);

            -- pll1_locked is asynchronous.

            pll_locked_sync <= pll_locked_sync(1 downto 0) & pll1_locked;

            -- reset_counter is a 16 bit counter, resulting in POR active for
            -- 32768 clocks or 2.048 ms.  It starts counting when the two PLLs
            -- are locked.

            if (pll_locked_sync(2) = '1' and reset_counter(reset_counter'high) = '0') then
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

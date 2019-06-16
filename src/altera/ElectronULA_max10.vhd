--------------------------------------------------------------------------------
-- Copyright (c) 2016 David Banks
-- Copyright (c) 2019 Google LLC
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ElectronULA_max10 is
    port (
        -- 16 MHz clock from Electron
        clk_in        : in  std_logic;
        -- 16 MHz clock from oscillator
        clk_osc       : in std_logic;

        -- QSPI flash chip
        flash_nCE     : out std_logic := '1';  -- pulled high on board
        flash_SCK     : out std_logic := '1';
        flash_IO0     : inout std_logic := 'Z';
        flash_IO1     : inout std_logic := 'Z';
        flash_IO2     : inout std_logic := 'Z';
        flash_IO3     : inout std_logic := 'Z';

        -- SDRAM
        sdram_DQ      : inout std_logic_vector(15 downto 0) := (others => 'Z');
        sdram_A       : out std_logic_vector(12 downto 0) := (others => '1');
        sdram_BA      : out std_logic_vector(1 downto 0) := (others => '1');
        sdram_nCS     : out std_logic := '1';  -- pulled high on board
        sdram_nWE     : out std_logic := '1';
        sdram_nCAS    : out std_logic := '1';
        sdram_nRAS    : out std_logic := '1';
        sdram_CLK     : out std_logic := '1';
        sdram_CKE     : out std_logic := '0';
        sdram_UDQM    : out std_logic := '1';
        sdram_LDQM    : out std_logic := '1';

        -- USB
        USB_M         : inout std_logic := 'Z';
        USB_P         : inout std_logic := 'Z';
        USB_PU        : out std_logic := 'Z';

        -- Enable input buffer for kbd[3:0], NMI_n_in, IRQ_n_in, RnW_in, clk_in
        input_buf_nOE : out std_logic := '0';  -- pulled high on board

        -- Enable output buffer for clk_out, nHS, red, green, blue, csync, casMO, casOut
        misc_buf_nOE  : inout std_logic := '0';  -- pulled high on board

        -- CPU Interface
        clk_out       : out std_logic;
        A_buf_nOE     : out std_logic := '0';  -- default on; pulled high on board
        A_buf_DIR     : out std_logic := '1';  -- default to buffer from Elk to FPGA
        addr          : inout std_logic_vector(15 downto 0);
        D_buf_nOE     : out std_logic := '1';  -- default off; pulled high on board
        D_buf_DIR     : out std_logic := '1';  -- default to buffer from Elk to FPGA
        data          : inout std_logic_vector(7 downto 0);
        RnW_in        : in std_logic;
        RnW_out       : out std_logic := '1';
        RnW_nOE       : out std_logic := '1';  -- pulled high on board
        RST_n_out     : inout std_logic := '1';  -- pulled high on board
        RST_n_in      : inout std_logic;
        IRQ_n_out     : inout std_logic := '1';  -- pulled high on board
        IRQ_n_in      : inout std_logic;
        NMI_n_in      : inout std_logic;

        -- Rom Enable
        ROM_n         : out std_logic;

        -- Video
        red           : out std_logic;
        green         : out std_logic;
        blue          : out std_logic;
        csync         : out std_logic;
        HS_n          : out std_logic := '1';  -- TODO is this unused?

        -- Audio DAC
        dac_dacdat    : inout std_logic;
        dac_lrclk     : inout std_logic;
        dac_bclk      : inout std_logic;
        dac_mclk      : inout std_logic;
        dac_nmute     : inout std_logic;

        -- Keyboard
        kbd           : in  std_logic_vector(3 downto 0);
        caps          : out std_logic;
        
        -- Cassette
        casIn         : in  std_logic;
        casOut        : out std_logic;
        casMO         : out std_logic := '1';

        -- SD card
        sd_CLK_SCK    : out std_logic;
        sd_CMD_MOSI   : out std_logic;
        sd_DAT0_MISO  : inout std_logic;
        sd_DAT1       : inout std_logic := 'Z';
        sd_DAT2       : inout std_logic := 'Z';
        sd_DAT3_nCS   : inout std_logic;  -- pulled high on board

        -- serial port
        serial_RXD    : in std_logic;
        serial_TXD    : out std_logic := '1';

        -- Debug MCU interface
        mcu_debug_RXD : out std_logic := '1';
        mcu_debug_TXD : in std_logic;  -- currently used to switch SPI port between flash (0) and boundary scan (1)
        mcu_MOSI      : in std_logic;
        mcu_MISO      : out std_logic := '1';
        mcu_SCK       : in std_logic;
        mcu_SS        : in std_logic
    );
end;

architecture behavioral of ElectronULA_max10 is

signal clock_16          : std_logic;
signal clock_24          : std_logic;
signal clock_32          : std_logic;
signal clock_33          : std_logic;
signal clock_40          : std_logic;
signal clock_96          : std_logic := '1';
signal clock_div_96_32   : std_logic_vector(1 downto 0) := (others => '0');

-- Divide 96MHz / 833 = 115246 baud serial
signal serial_tx_count   : std_logic_vector(9 downto 0) := (others => '0');
signal serial_rx_count   : std_logic_vector(9 downto 0) := (others => '0');

signal pll_reset         : std_logic;
signal pll_reset_counter : std_logic_vector(1 downto 0) := (others => '0');
signal pll1_locked       : std_logic;
signal pll_locked_sync   : std_logic_vector(2 downto 0) := (others => '0');

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

signal mcu_MOSI_sync     : std_logic_vector(2 downto 0) := "000";
signal mcu_SS_sync       : std_logic_vector(2 downto 0) := "111";
signal mcu_SCK_sync      : std_logic_vector(2 downto 0) := "000";

-- debug boundary scan over SPI
signal debug_boundary_vector : std_logic_vector(31 downto 0);

begin

    -- According to the Max 10 datasheet (Table 27), 5MHz < fIN < 472.5 MHz, and
    -- the VCO runs between 600-1300 MHz.  We might want a lower-jitter clock than
    -- the 16MHz one from the Electron though.

    -- TODO(myelin) test PLLs with both electron clock and discrete oscillator

    max10_pll1_inst : entity work.max10_pll1 PORT MAP (
        areset   => pll_reset,
        -- inclk0   => clk_in,   -- PLL input: 16MHz from Elk - TODO test this
        inclk0   => clk_osc,    -- PLL input: 16MHz from oscillator
        c0       => clock_16,   -- main system clock / sRGB video clock
        c1       => clock_24,   -- for the SAA5050 in Mode 7
        c2       => clock_96,   -- SDRAM/flash, divided to 32 for scan doubler for the SAA5050 in Mode 7
        c3       => clock_40,   -- video clock when in 60Hz VGA Mode
        c4       => clock_33,   -- video clock when in 50Hz VGA Mode
        locked   => pll1_locked
    );

    -- debug SPI interface with mcu; currently just a boundary scan that reads most of the inputs.
    -- to read: bring SS high then low, then clock out 32 bits.
    spi : process(clock_96)
    begin
        if rising_edge(clock_96) then
            mcu_MOSI_sync <= mcu_MOSI_sync(1 downto 0) & mcu_MOSI;
            mcu_SCK_sync <= mcu_SCK_sync(1 downto 0) & mcu_SCK;
            mcu_SS_sync <= mcu_SS_sync(1 downto 0) & mcu_SCK;
            if mcu_SS_sync(2) = '0' then
                if mcu_SS_sync(1) = '1' then
                    -- start of transaction
                    debug_boundary_vector <= addr & data & RnW_in & RST_n_in & IRQ_n_in & NMI_n_in & kbd;
                end if;
                if mcu_SCK_sync(2) = '0' and mcu_SCK_sync(1) = '1' then
                    -- falling SCK edge; shift debug_boundary_vector out mcu_MISO
                    debug_boundary_vector <= '0' & debug_boundary_vector(31 downto 1);
                end if;
            end if;
        end if;
    end process;

    -- when mcu_debug_TXD is low, pass MCU SPI port through to flash
    mcu_MISO <= flash_IO1 when mcu_debug_TXD = '0' else debug_boundary_vector(0);
    flash_nCE <= mcu_SS when mcu_debug_TXD = '0' else '1';
    flash_IO0 <= mcu_MOSI when mcu_debug_TXD = '0' else '1';
    flash_SCK <= mcu_SCK when mcu_debug_TXD = '0' else '1';
    mcu_debug_RXD <= mcu_debug_TXD;  -- loopback serial for MCU debugging

    -- divide clock_96 to get clock_32 and clock_serial
    divide_96mhz : process(clock_96)
    begin
        if rising_edge(clock_96) then
            -- Divide 96/3 to get 32MHz
            if clock_div_96_32 = "10" then
                -- if clock_32 = '0' then
                --     clock_16 <= not clock_16;
                -- end if;
                clock_32 <= not clock_32;
                clock_div_96_32 <= "00";
            else
                clock_div_96_32 <= clock_div_96_32 + 1;
            end if;

            -- Divide 96/833 to get serial clock
            if serial_tx_count = 833 then
                serial_tx_count <= (others => '0');
            else
                serial_tx_count <= serial_tx_count + 1;
            end if;
            -- TODO also reset serial_rx_count when we get a start bit
            if serial_rx_count = 833 then
                serial_rx_count <= (others => '0');
            else
                serial_rx_count <= serial_rx_count + 1;
            end if;
        end if;
    end process;

    -- DEBUG output serial clock on serial_TXD
    serial_TXD <= '1' when serial_tx_count < 417 else '0';

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
        IncludeJafaMode7 => false  -- TODO get character ROM working
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
        R_W_n     => RnW_in,
        RST_n     => RST_n_out,
        IRQ_n     => ula_irq_n,
        NMI_n     => NMI_n_in,

        -- Rom Enable
        ROM_n     => ROM_n,

        -- Video
        red       => video_red,
        green     => video_green,
        blue      => video_blue,
        vsync     => video_vsync,
        hsync     => video_hsync,

        -- Audio
        sound     => dac_dacdat,  -- TODO support DAC interface / add jumper on PCB

        -- SD Card
        SDMISO    => sd_DAT0_MISO,
        SDSS      => sd_DAT3_nCS,
        SDCLK     => sd_CLK_SCK,
        SDMOSI    => sd_CMD_MOSI,

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
    IRQ_n_out <= '0' when ula_irq_n = '0' else 'Z';

    -- Enable data bus transceiver when ULA or ROM selected
    D_buf_nOE <= '0' when ula_enable = '1' or rom_enable = '1' else '1';
    -- DIR=1 buffers from Elk to FPGA, DIR=0 buffers from FPGA to Elk
    D_buf_DIR <= '1' when RnW_in = '0' else '0';

    data_in <= data;

    data <= rom_data      when RnW_in = '1' and rom_enable = '1' else
            ula_data      when RnW_in = '1' and ula_enable = '1' else
            "ZZZZZZZZ";

--------------------------------------------------------
-- Paged ROM
--------------------------------------------------------

    -- Provide ROMs 14 and 15
    rom_enable  <= '1' when addr(15 downto 14) = "10" and rom_latch(3 downto 1) = "111" else '0';

    rom_we <= '1' when rom_enable = '1' and cpu_clken = '1' else '0';

    -- There isn't enough room in the 10M08SC to fit the expansion ROMs, so they live in a
    -- separate QPI flash chip instead.

    -- Timing: The ULA produces PHI0, which the 6502 delays to produce PHI2;
    -- reads are referenced to PHI2. I believe we have about 190 ns from the
    -- rising edge of PHI0 to set up the data bus.  There's no single signal
    -- that lets us know when the CPU hold time is over, but holding until
    -- addr changes should work okay.

    -- As such our ROM emulator should sample addr on the rising clk_out edge
    -- and hold until rom_enable drops.

    -- We clock the flash at 96MHz and use the QPI fast read function.



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
    RST_n_out <= '0' when powerup_reset_n = '0' else 'Z';

end behavioral;

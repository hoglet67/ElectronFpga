--------------------------------------------------------------------------------
-- Copyright (c) 2016 David Banks
-- Copyright (c) 2019 Google LLC
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- TODO figure out how to emulate BBC/Master keyboard reads using an internal CPU

entity ElectronULA_max10 is
    generic (
        -- Set this to true to include an internal 6502 core.
        -- You MUST remove the CPU from the main board when doing this,
        -- as the ULA will drive the address bus and RnW.
        InternalCPU   : boolean := true
    );
    port (
        -- 16 MHz clock from Electron
        clk_in        : in std_logic;
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
        sdram_CKE     : out std_logic := '0';  -- active high
        sdram_UDQM    : out std_logic := '1';  -- active low
        sdram_LDQM    : out std_logic := '1';

        -- USB
        USB_M         : inout std_logic := 'Z';
        USB_P         : inout std_logic := 'Z';
        USB_PU        : out std_logic := 'Z';

        -- Enable input buffer for kbd[3:0], NMI_n_in, IRQ_n_in, RnW_in, clk_in
        input_buf_nOE : out std_logic := '0';  -- pulled high on board

        -- Enable output buffer for clk_out, nHS, red, green, blue, csync, casMO, casOut
        misc_buf_nOE  : out std_logic := '0';  -- pulled high on board

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
        RST_n_out     : out std_logic := '1';  -- pulled high on board
        RST_n_in      : in std_logic;
        IRQ_n_out     : out std_logic := '1';  -- pulled high on board
        IRQ_n_in      : in std_logic;
        NMI_n_in      : in std_logic;

        -- Rom Enable
        ROM_n         : out std_logic;

        -- Video
        red           : out std_logic;
        green         : out std_logic;
        blue          : out std_logic;
        csync         : out std_logic;
        HS_n          : out std_logic := '1';  -- TODO is this unused?

        -- Audio DAC
        dac_dacdat    : out std_logic := '0';  -- DAC data
        dac_lrclk     : out std_logic := '0';  -- Left/right clock
        dac_bclk      : out std_logic := '0';  -- Bit clock
        dac_mclk      : out std_logic := '0';  -- Master clock
        dac_nmute     : out std_logic := '0';

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
        sd_DAT0_MISO  : in std_logic;
        sd_DAT1       : inout std_logic := 'Z';
        sd_DAT2       : inout std_logic := 'Z';
        sd_DAT3_nCS   : out std_logic;  -- pulled high on board

        -- serial port
        serial_RXD    : out std_logic := '1';  --DEBUG in std_logic;
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

-- Maps to either clk_in or clk_osc depending which one we are using
signal clock_input       : std_logic;
-- Generated clocks:
signal clock_16          : std_logic;
signal clock_24          : std_logic;
signal clock_32          : std_logic;
signal clock_33          : std_logic;
signal clock_40          : std_logic;
signal clock_96          : std_logic := '1';
signal clock_div_96_24   : std_logic_vector(1 downto 0) := (others => '0');

-- Divide clock_16 down to ~1 Hz to blink the caps LED
signal blinky_div        : std_logic_vector(24 downto 0) := (others => '0');

-- Divide 96MHz / 833 = 115246 baud serial
signal serial_tx_count   : std_logic_vector(9 downto 0) := (others => '0');
signal serial_rx_count   : std_logic_vector(9 downto 0) := (others => '0');

signal pll_reset         : std_logic := '1';
signal pll_reset_counter : std_logic_vector(1 downto 0) := (others => '0');
signal pll1_locked       : std_logic;
signal pll_locked_sync   : std_logic_vector(2 downto 0) := (others => '0');
signal pll_locked_sync_96 : std_logic_vector(2 downto 0) := (others => '0');

signal led_counter       : std_logic_vector(23 downto 0);
signal clk_counter       : std_logic_vector(2 downto 0);
signal cpu_clken         : std_logic;
signal clk_out_int       : std_logic;
signal cpu_clken_16_sync : std_logic;
signal cpu_clken_96_sync : std_logic_vector(2 downto 0);
-- will go high for one clock_96 cycle when A/D are valid for a write
signal start_write_96    : std_logic;
-- will go high for one clock_96 cycle when A is valid for a read
signal start_read_96     : std_logic;
-- one shot timer to generate start_read_96
signal wait_for_ads_counter : std_logic_vector(4 downto 0) := (others => '1');

signal kbd_access        : std_logic;
signal bus_write_from_internal_device : std_logic;

signal ula_enable        : std_logic;
signal ula_addr          : std_logic_vector(15 downto 0);
signal ula_data_out      : std_logic_vector(7 downto 0);
signal ula_irq_n         : std_logic;
signal video_red         : std_logic_vector(3 downto 0);
signal video_green       : std_logic_vector(3 downto 0);
signal video_blue        : std_logic_vector(3 downto 0);
signal video_hsync       : std_logic;
signal video_vsync       : std_logic;
signal rom_latch         : std_logic_vector(3 downto 0);

signal powerup_reset_n   : std_logic := '0';
signal reset_counter     : std_logic_vector (15 downto 0);
signal RST_n_sync_16     : std_logic_vector(1 downto 0);
signal NMI_n_sync_16     : std_logic_vector(1 downto 0);

-- Active high reset for flash and SDRAM; will be high until ~1us after the PLL locks
signal memory_reset_96   : std_logic := '1';
signal reset_counter_96  : std_logic_vector(8 downto 0);

-- Outbound CPU signals when soft CPU is being used
signal cpu_addr          : std_logic_vector(23 downto 0);
signal cpu_data_out      : std_logic_vector(7 downto 0);
signal cpu_RnW_out       : std_logic;

-- Internal variable for data bus
signal data_in           : std_logic_vector(7 downto 0);
signal RnW               : std_logic;

signal turbo             : std_logic_vector(1 downto 0);

signal caps_led          : std_logic;

signal mcu_MOSI_sync     : std_logic_vector(2 downto 0) := "000";
signal mcu_SS_sync       : std_logic_vector(2 downto 0) := "111";
signal mcu_SCK_sync      : std_logic_vector(2 downto 0) := "000";

-- debug boundary scan over SPI
signal boundary_scan     : std_logic := '0';
signal debug_boundary_vector : std_logic_vector(47 downto 0);

signal flash_enable      : std_logic;
signal flash_data_out    : std_logic_vector(7 downto 0) := x"FF";
signal flash_reset       : std_logic;
signal flash_read        : std_logic;

signal sdram_enable      : std_logic;
signal sdram_data_out    : std_logic_vector(7 downto 0) := x"42";
signal sdram_init        : std_logic := '1';  -- Power on reset for sdram
signal sdram_reading     : std_logic;
signal sdram_writing     : std_logic;
signal sdram_refreshing  : std_logic;
signal sdram_check_refresh : std_logic;

begin

--------------------------------------------------------
-- Debugging
--------------------------------------------------------

    -- debug SPI interface with mcu; currently just a boundary scan that reads most of the inputs.
    -- to read: bring SS high then low, then clock out 48 bits.
    spi : process(clock_96)
    begin
        if rising_edge(clock_96) then
            mcu_MOSI_sync <= mcu_MOSI_sync(1 downto 0) & mcu_MOSI;
            mcu_SCK_sync <= mcu_SCK_sync(1 downto 0) & mcu_SCK;
            mcu_SS_sync <= mcu_SS_sync(1 downto 0) & mcu_SS;

            if mcu_SS_sync(2) = '0' then
                if mcu_SS_sync(1) = '1' then
                    -- start of transaction
                    debug_boundary_vector <=
                        "10101010" &  -- AA
                        addr &        -- FF FF
                        data &        -- FF
                        RnW & '0' & powerup_reset_n & RST_n_in & powerup_reset_n & IRQ_n_in & ula_irq_n & NMI_n_in &  -- BF
                        kbd & '1' & '1' & '1' & '1'; -- FF
                end if;
                if mcu_SCK_sync(2) = '1' and mcu_SCK_sync(1) = '0' then
                    -- rising SCK edge; mcu_MOSI_sync(2) contains the input bit
                end if;
                if mcu_SCK_sync(2) = '0' and mcu_SCK_sync(1) = '1' then
                    -- falling SCK edge; shift debug_boundary_vector out mcu_MISO, MSB first
                    debug_boundary_vector <= debug_boundary_vector(debug_boundary_vector'high-1 downto 0) & '0';
                end if;
            end if;
        end if;
    end process;

    -- when mcu_debug_TXD is low, pass MCU SPI port through to flash
    boundary_scan <= '0';  -- Boundary scan off (needed to operate as ULA)
    --boundary_scan <= mcu_debug_TXD;  -- Turn on boundary scan when SPI is connected to debug SPI
    mcu_MISO <= flash_IO1 when mcu_debug_TXD = '0' else debug_boundary_vector(debug_boundary_vector'high);
    flash_nCE <= mcu_SS when mcu_debug_TXD = '0' else '1';
    flash_IO0 <= mcu_MOSI when mcu_debug_TXD = '0' else '1';
    flash_SCK <= mcu_SCK when mcu_debug_TXD = '0' else '1';
    mcu_debug_RXD <= mcu_debug_TXD;  -- loopback serial for MCU debugging

    --serial_TXD <= '1' when serial_tx_count < 417 else '0'; -- verified on scope
    --serial_TXD <= clock_16; -- verified on scope
    --serial_TXD <= cpu_clken; -- verified on scope
    serial_TXD <= clk_out_int; -- verified on scope
    --serial_RXD <= kbd(3);
    serial_RXD <= kbd_access;


--------------------------------------------------------
-- ULA
--------------------------------------------------------

    ula : entity work.ElectronULA
    generic map (
        IncludeMMC       => false,
        Include32KRAM    => true,
        IncludeVGA       => false, -- TODO disabled to simplify clocks
        IncludeJafaMode7 => false  -- TODO get character ROM working
    )
    port map (
        clk_16M00 => clock_16,
        clk_24M00 => clock_24,
        clk_32M00 => clock_32,
        clk_33M33 => clock_33,
        clk_40M00 => clock_40,

        -- CPU Interface
        addr      => ula_addr,  -- Updated on rising clk_out edge
        data_in   => data_in,
        data_out  => ula_data_out,
        data_en   => ula_enable,
        R_W_n     => RnW,
        RST_n     => RST_n_sync_16(1),
        IRQ_n     => ula_irq_n,  -- IRQ output from ULA
        NMI_n     => NMI_n_sync_16(1),

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

    -- Blink CAPS at 1 Hz
    --blink_caps : process(clock_16)
    --begin
    --    if rising_edge(clock_16) then
    --        blinky_div <= blinky_div + 1;
    --    end if;
    --end process;
    --caps <= blinky_div(blinky_div'high);

    -- Light up CAPS on reset
    --caps <= RST_n_sync_16(1);
    
    -- IRQ_n_out drives the enable on an open collector buffer which pulls the external IRQ line down
    IRQ_n_out <= ula_irq_n;

    -- CPU data bus and RnW signal
    data_in <= data;
    RnW <= cpu_RnW_out when InternalCPU else RnW_in;

    -- '1' when the CPU is reading from a device on the ULA PCB
    bus_write_from_internal_device <= '1' when RnW = '1' and (
        flash_enable = '1'    -- Output from flash
        or sdram_enable = '1' -- Output from SDRAM
        or ula_enable = '1'   -- Output from ULA
    ) else '0';

    -- '0' to enable data bus buffer
    D_buf_nOE <= '0' when (
        InternalCPU                              -- Input to/output from internal CPU
        or boundary_scan = '1'                   -- Input to boundary scan
        or bus_write_from_internal_device = '1'  -- Something local wants to write to the bus
    ) else '1';

    -- DIR=1 buffers from Elk to FPGA, DIR=0 buffers from FPGA to Elk
    D_buf_DIR <=
        -- outwards when something local is writing to the bus
        '0' when bus_write_from_internal_device = '1' else
        -- inwards when the internal CPU is reading, outwards when it is writing
        RnW when InternalCPU else
        -- inwards when external CPU is writing
        '1' when RnW = '0' else
        -- inwards during boundary scan
        '1' when boundary_scan = '1' else
        -- default outwards (buffer should be disabled)
        '0';

    -- Order here should match D_buf_DIR expression above.
    data <= ula_data_out   when RnW = '1' and ula_enable = '1' else
            flash_data_out when RnW = '1' and flash_enable = '1' else
            sdram_data_out when RnW = '1' and sdram_enable = '1' else
            cpu_data_out   when RnW = '0' and InternalCPU else
            "ZZZZZZZZ";  -- ext CPU, RnW = '0' or boundary_scan = '1'


--------------------------------------------------------
-- Internal CPU (optional)
--------------------------------------------------------

    GenCPU: if InternalCPU generate
        T65core : entity work.T65
        port map (
            Mode            => "00",
            Abort_n         => '1',
            SO_n            => '1',  -- Signal not routed to the ULA
            Res_n           => RST_n_in,
            Enable          => cpu_clken,
            Clk             => clock_16,
            Rdy             => '1',  -- Signal not routed to the ULA
            IRQ_n           => IRQ_n_in,
            NMI_n           => NMI_n_in,
            R_W_n           => cpu_RnW_out,
            Sync            => open,  -- Signal not routed to the ULA
            A               => cpu_addr,
            DI              => data_in,
            DO              => cpu_data_out
        );
        -- Buffer address outwards
		  addr <= cpu_addr(15 downto 0);
        A_buf_DIR <= '0';
        -- Buffer RnW outwards
        RnW_out <= cpu_RnW_out;
        RnW_nOE <= '0';
    end generate;


--------------------------------------------------------
-- Audio DAC
--------------------------------------------------------

    -- Standby mode
    dac_bclk <= clock_16;
    dac_mclk <= clock_16;
    dac_nmute <= '0';

    -- Master clock runs at 16 MHz
    -- Divide by 128 to get fs = 125 kHz sample rate
    -- We need 17 BCLK times per sample because I2S requires a dummy BCLK cycle after a LRCLK transition
    -- So BCLK >= fs * 17 * 2 = 6.375 MHz; probably just use 8MHz.

--------------------------------------------------------
-- SDRAM
--------------------------------------------------------

    -- Sideways RAM
    sdram_enable <= '0';  -- '1' when addr(15 downto 14) = "10" and (rom_latch = 6 or rom_latch = 7) else '0';

    -- Disable SDRAM for now
    sdram_CLK <= clock_96;
    sdram_nCS <= '1';
    sdram_nWE <= '1';
    sdram_nCAS <= '1';
    sdram_nRAS <= '1';
    sdram_UDQM <= '1';
    sdram_LDQM <= '1';

    -- TODO move all of this into ula_sdram.v
    -- TODO start sdram read when start_read_96 = '1' and ram is selected
    -- TODO start sdram write when start_write_96 = '1' and ram is selected

    -- We clock the SDRAM at 96MHz, i.e. there are 24 cycles in 250 ns and 48 in 500 ns.

    -- Two possibilities in a clock cycle:
    -- start_write_96 asserted at start of PHI1 period; write takes the next 62.5 ns
    -- start_read_96 asserted at PHI1+tADS; read takes the next 62.5 ns

    -- In all cases, if it's time for a refresh (about every 7 us), we have
    -- time for that after a read or write.

    -- In 4MHz operation (250 ns clock), start_read_96 = PHI1+70ns, so we're done after 132.5 ns.
    -- In 2MHz operation (500 ns clock), start_read_96 = PHI1+177ns, so we're done after 240 ns.

    -- 0: ACTIVE -- nCS=0 RAS=0 CAS=1 WE=1 addr=row BA=bank
    -- 1: NOP    -- nCS=0 RAS=1 CAS=1 WE=1
    -- 2: READ   -- nCS=0 RAS=1 CAS=0 WE=1 addr=col BA1:0=bank A10=1 (enable auto precharge)
    -- 3: NOP    -- nCS=0 RAS=1 CAS=1 WE=1
    -- 4: NOP    -- register output data here
    -- 5: NOP
    -- 6: NOP
    -- 7: NOP    -- Now switch to refresh mode
    -- 8: AUTO REFRESH -- 
    -- 9: nCS=1

    sdram_loop : process(clock_96)
    begin
        if rising_edge(clock_96) then
            sdram_check_refresh <= '0';

            if sdram_init = '1' then
                if memory_reset_96 = '0' then
                    -- We're out of reset; start the SDRAM init process
                    sdram_CKE <= '1';
                end if;
            elsif sdram_reading = '1' then
            elsif sdram_writing = '1' then
            elsif sdram_refreshing = '1' then
            end if;

            if start_write_96 = '1' then
                if sdram_enable = '1' then
                    sdram_writing <= '1';
                else
                    sdram_check_refresh <= '1';
                end if;
            elsif start_read_96 = '1' then
                if sdram_enable = '1' then
                    sdram_reading <= '1';
                else
                    sdram_check_refresh <= '1';
                end if;
            end if;

            if sdram_check_refresh = '1' then
                -- TODO check sdram refresh timer and kick off a refresh if so
            end if;

            -- reset everything if we're just powering up
            if memory_reset_96 = '1' then
                sdram_CKE <= '0';
                sdram_init <= '1';
                sdram_reading <= '0';
                sdram_writing <= '0';
                sdram_refreshing <= '0';
                sdram_check_refresh <= '0';
            end if;
        end if;
    end process;

--------------------------------------------------------
-- Paged ROM
--------------------------------------------------------

    -- Provide ROMs 14 and 15 using the QPI flash chip
    flash_enable <= '1' when addr(15 downto 14) = "10" and (rom_latch = 12 or rom_latch = 13 or rom_latch = 14 or rom_latch = 15) else '0';

    -- We clock the flash at 96MHz and use the QPI fast read function.
    -- 1: drop /CE
    -- 2-3: cmd
    -- 4-9: addr
    -- 10-15: dummy
    -- 16-17: read byte
    -- 18: raise /CE
    -- so flash_data_out will be valid 18 clocks (187.5ns) after start_read_96.

    --flash : entity work.qpi_flash
    --port map (
    --    clk => clock_96,
    --    en => flash_enable,  -- Asynchronous but safe to sample when read = '1'
    --    reset => memory_reset_96,
    --    read => start_read_96,  -- Read cycle trigger
    --    addr => flash_bank & addr,
    --    data_out => flash_data_out,
    --    -- External pins
    --    flash_nCE => flash_nCE,
    --    flash_SCK => flash_SCK,
    --    flash_IO0 => flash_IO0,
    --    flash_IO1 => flash_IO1,
    --    flash_IO2 => flash_IO2,
    --    flash_IO3 => flash_IO3
    --);


--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    reset_gen : process(clock_input)
    begin
        if rising_edge(clock_input) then

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

    -- Reset drives the enable on an open collector buffer which pulls the 5V RESET line down
    RST_n_out <= powerup_reset_n;

    reset_gen_96 : process(clock_96)
    begin
        if rising_edge(clock_96) then
            -- synchronize pll1_locked with clock_96, then release reset 128 clocks later
            pll_locked_sync_96 <= pll_locked_sync_96(1 downto 0) & pll1_locked;
            if pll_locked_sync_96(2) = '1' and reset_counter_96(reset_counter_96'high) = '0' then
                reset_counter_96 <= reset_counter_96 + 1;
            end if;
            memory_reset_96 <= not reset_counter_96(reset_counter_96'high);
        end if;
    end process;

--------------------------------------------------------
-- Clock generation
--------------------------------------------------------

    --clock_input <= clk_osc;  -- Use 16MHz oscillator (works nicely)
    clock_input <= clk_in;  -- Use 16MHz clock from ULA pin

    -- TODO(myelin) test PLLs with both electron clock and discrete oscillator

    max10_pll1_inst : entity work.max10_pll1 PORT MAP (
        areset   => pll_reset,
        inclk0   => clock_input, -- PLL input: 16MHz from oscillator or ULA pin
        c0       => clock_16,    -- main system clock / sRGB video clock
        c1       => clock_32,    -- for scan doubler for the SAA5050 in Mode 7
        c2       => clock_96,    -- SDRAM/flash, divided to 24 for the SAA5050 in Mode 7
        c3       => clock_40,    -- video clock when in 60Hz VGA Mode
        c4       => clock_33,    -- video clock when in 50Hz VGA Mode
        locked   => pll1_locked
    );

    -- Generate a 250 ns low pulse on PHI OUT for four 16 MHz cycles after
    -- cpu_clken == 1 (i.e. cpu_clken = '1' for the last 62.5ns of a PHI0
    -- cycle) in 1MHz/2MHz mode, or a 125 ns low pulse in 4MHz mode.
    clk_gen : process(clock_16)
    begin
        if rising_edge(clock_16) then
            -- Synchronize reset and NMI for ULA
            RST_n_sync_16 <= RST_n_sync_16(0) & RST_n_in;
            NMI_n_sync_16 <= NMI_n_sync_16(0) & NMI_n_in;
            -- Generate a signal that's synced to the rising edge, for cpu_clken_96_sync later
            cpu_clken_16_sync <= cpu_clken;
            -- Generate clk_out (but hold clock when in reset)
            if cpu_clken = '1' then -- and RST_n_sync_16(1) = '1' then
                if turbo = "11" then
                    -- 4MHz clock; produce a 125 ns low pulse
                    clk_counter <= "011";
                    -- TODO 4MHz will not work with QPI flash at 96MHz
                else
                    -- 1MHz or 2MHz clock; produce a 250 ns low pulse
                    clk_counter <= "001";
                end if;
                clk_out_int <= '0';
            elsif clk_counter(2) = '0' then
                clk_counter <= clk_counter + 1;
            else
                -- Update addr from 6502 on rising clk_out edge
                if clk_out_int = '0' then
                    ula_addr <= addr;
                end if;
                clk_out_int <= '1';
            end if;
        end if;
    end process;
    clk_out <= clk_out_int;
    kbd_access <= '1' when addr(15 downto 14) = "10" and rom_latch = 8 else '0';

    generate_start_read_write_signals : process(clock_96)
    begin
        if rising_edge(clock_96) then
            -- Probably don't need a synchronizer here, but just in case...
            -- cpu_clken_16_sync will go high shortly after clock_16.
            -- cpu_clken_96_sync(2): 3/96 (0.5/16) us after clock_16, i.e 0.5/16 us before clk_out low
            cpu_clken_96_sync <= cpu_clken_96_sync(1 downto 0) & cpu_clken_16_sync;

            -- start_write_96: high for 1/96 us, .33/16 us before clk_out low when RnW = '0'
            -- start_read_96: high for 1/96 us when it's safe to sample addr for a read from sdram or flash
            start_write_96 <= '0';
            start_read_96 <= '0';
            if cpu_clken_96_sync(2) = '1' and cpu_clken_96_sync(1) = '0' then
                if RnW = '0' then
                    start_write_96 <= '1';
                end if;
                wait_for_ads_counter <= "00000";
            elsif wait_for_ads_counter /= 18 then
                -- A/RnW/D are valid for write at the start of the PHI0 low cycle (from the previous cpu cycle)
                -- A/RnW are valid for read at the end of the PHI0 low cycle (for the current cycle).
                -- For 2MHz parts -- R6502A: tRWS = tADS = 140 ns; UM6502B/BE: tRWS = tADS = 100ns
                -- For 4MHz parts -- UM6502CE: tRWS = 60ns, tADS = 70 ns
                -- For 14MHz parts -- W65C02S6TPG-14: tADS = 30 ns
                -- These are referenced to PHI2, which can be delayed up to 30ns from PHI0.
                -- So we really want a delay of about 170 ns (~17 * clock_96) from clk_out low to start_read_96 high.
                if wait_for_ads_counter = 17 and RnW = '1' then
                    start_read_96 <= '1';
                end if;
                wait_for_ads_counter <= wait_for_ads_counter + 1;
            end if;
        end if;
    end process;

    -- divide clock_96 to get clock_32 and clock_serial
    divide_96mhz : process(clock_96)
    begin
        if rising_edge(clock_96) then
            -- Divide 96/4 to get 24MHz
            if clock_div_96_24 = "11" then
                clock_24 <= not clock_24;
                clock_div_96_24 <= "00";
            else
                clock_div_96_24 <= clock_div_96_24 + 1;
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

end behavioral;

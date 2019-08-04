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
        InternalCPU   : boolean := true;
        -- Set this as true to include the experimental DAC code
        IncludeAudio  : boolean := true;
        -- Set this as true to include JAFA Mode 7 support
        IncludeMode7  : boolean := true;
        -- Set this as true to include Mega Games Cartridge emulation
        IncludeMGC    : boolean := true
    );
    port (
        -- 16 MHz clock from Electron
        clk_in        : in std_logic;
        -- 16 MHz clock from oscillator
        clk_osc       : in std_logic;

        -- QSPI flash chip
        flash_nCE     : out std_logic := '1';  -- pulled high on board
        flash_SCK     : out std_logic := '0';
        flash_IO0     : inout std_logic := 'Z';  -- MOSI
        flash_IO1     : inout std_logic := 'Z';  -- MISO
        flash_IO2     : inout std_logic := 'Z';  -- /WP
        flash_IO3     : inout std_logic := 'Z';  -- /HOLD or /RESET

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
        dac_nmute     : out std_logic := '0';  -- '0' for standby mode

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
        mcu_debug_RXD : in std_logic;  -- prepping to switch ports around; out std_logic := '1';
        mcu_debug_TXD : in std_logic;  -- currently used to switch SPI port between flash (0) and boundary scan (1)
        mcu_MOSI      : in std_logic;
        mcu_MISO      : out std_logic := '1';
        mcu_SCK       : in std_logic;
        mcu_SS        : in std_logic
    );
end;

architecture behavioral of ElectronULA_max10 is

-- Need to declare this as a component because Quartus can't do entity
-- instantiation with Verilog modules.
component qpi_flash is
    port (
        clk : in std_logic;
        ready : out std_logic;
        reset : in std_logic;
        read : in std_logic;
        addr : in std_logic_vector(23 downto 0);
        data_out : out std_logic_vector(7 downto 0);
        passthrough : in std_logic;
        passthrough_nCE : in std_logic;
        passthrough_SCK : in std_logic;
        passthrough_MOSI : in std_logic;
        flash_nCE : out std_logic;
        flash_SCK : out std_logic;
        flash_IO0 : inout std_logic;
        flash_IO1 : inout std_logic;
        flash_IO2 : inout std_logic;
        flash_IO3 : inout std_logic
    );
end component qpi_flash;

-- Maps to either clk_in or clk_osc depending which one we are using
signal clock_input       : std_logic;
-- Generated clocks:
signal clock_16          : std_logic;
signal clock_24          : std_logic;  -- TODO remove, if clken_ttxt works
signal clock_32          : std_logic;
signal clock_33          : std_logic;
signal clock_40          : std_logic;
signal clock_96          : std_logic := '1';
signal clock_div_96_24   : std_logic_vector(1 downto 0) := (others => '0');

signal clken_ttxt_counter : std_logic_vector(3 downto 0) := (others => '0');
signal clken_ttxt        : std_logic := '0';

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

signal rom_enable_n      : std_logic;
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

-- Active high reset for flash and SDRAM; will be high until ~42us after the PLL locks
signal memory_reset_96   : std_logic := '1';
signal reset_counter_96  : std_logic_vector(12 downto 0);

-- Outbound CPU signals when soft CPU is being used
signal cpu_addr          : std_logic_vector(23 downto 0);
signal cpu_data_out      : std_logic_vector(7 downto 0);
signal cpu_RnW_out       : std_logic;

-- Internal variable for data bus
signal data_in           : std_logic_vector(7 downto 0);
signal RnW               : std_logic;

signal turbo             : std_logic_vector(1 downto 0);

signal caps_led          : std_logic;

signal sound_bit         : std_logic;
signal audio_bit_clock   : std_logic := '0';
signal audio_lr_clock    : std_logic := '0';
signal audio_data_out    : std_logic := '0';
signal audio_counter     : std_logic_vector(5 downto 0) := (others => '0');
signal audio_shifter     : std_logic_vector(15 downto 0) := (others => '0');

-- SPI comms with microcontroller
signal mcu_MOSI_sync     : std_logic_vector(2 downto 0) := "000";
signal mcu_SS_sync       : std_logic_vector(2 downto 0) := "111";
signal mcu_SCK_sync      : std_logic_vector(2 downto 0) := "000";
signal mcu_shifter       : std_logic_vector(7 downto 0) := (others => '0');
signal mcu_shift_count   : std_logic_vector(2 downto 0) := (others => '0');
signal mcu_shifter_byte  : std_logic_vector(7 downto 0);
signal mcu_MISO_int      : std_logic;
signal mcu_state         : std_logic_vector(7 downto 0);  -- state machine state
signal mcu_flash_passthrough : std_logic := '0';  -- sticky passthrough bit
signal mcu_flash_spi     : std_logic := '0';  -- connect MCU to flash
signal mcu_flash_spi_clocking : std_logic := '0';  -- '0' during first clock cycle after connecting MCU to flash
--signal mcu_flash_qpi     : std_logic := '0';  -- connect MCU to flash
--signal mcu_flash_qpi_cmd : std_logic := '0';  -- '1' when reading QPI rnw/command over SPI
--signal mcu_flash_qpi_rnw : std_logic := '1';  -- QPI RnW
--signal mcu_flash_qpi_txn : std_logic := '0';  -- QPI strobe
--signal mcu_flash_qpi_counter : std_logic_vector(1 downto 0);

-- debug boundary scan over SPI
signal boundary_scan     : std_logic := '0';
signal debug_boundary_vector : std_logic_vector(47 downto 0);

-- USB serial port on FCA1 (status), FCA0 (data)
signal usb_serial_enable : std_logic := '0';
signal usb_serial_data   : std_logic_vector(7 downto 0);
signal usb_elk_rx_reading : std_logic := '0';
signal usb_elk_rx_empty  : std_logic := '0';
signal usb_elk_rx_byte   : std_logic_vector(7 downto 0);
signal usb_elk_tx_full   : std_logic := '0';
signal usb_elk_tx_byte   : std_logic_vector(7 downto 0);
signal usb_elk_remote_has_byte : std_logic := '0';
signal usb_elk_tx_full_sent : std_logic := '0';
signal usb_elk_rx_empty_sent : std_logic := '0';

signal empty_bank_enable : std_logic;

signal flash_enable      : std_logic := '0';
signal flash_bank        : std_logic_vector(7 downto 0) := x"00";  -- bits 23-16 of flash address
signal flash_addr        : std_logic_vector(23 downto 0);
signal flash_data_out    : std_logic_vector(7 downto 0) := x"FF";
signal flash_ready       : std_logic;
signal flash_reset       : std_logic := '0';
signal flash_read        : std_logic;

signal sdram_enable        : std_logic;         -- SDRAM selected by CPU
signal sdram_clken         : std_logic := '0';  -- 48MHz clock enable
signal sdram_address       : std_logic_vector(23 downto 0);
signal sdram_ready         : std_logic;
signal sdram_done          : std_logic;
signal sdram_data_out      : std_logic_vector(15 downto 0) := x"8442";
--signal sdram_init          : std_logic := '1';  -- Power on reset for sdram
signal sdram_access        : std_logic := '0';
signal sdram_writing       : std_logic;
signal sdram_refreshing    : std_logic;
signal sdram_check_refresh : std_logic;
signal sdram_low_bank_en   : std_logic;
signal sdram_high_bank_en  : std_logic;
signal sdram_refresh_counter : std_logic_vector(4 downto 0) := (others => '0');  -- kicked off after cpu_clken

-- SAA5050 character ROM loader (copies from QPI flash to SAA5050 block RAM)
signal char_rom_loaded   : std_logic := '0';  -- Holds system in reset until it transitions to '1'
signal char_rom_state    : std_logic_vector(1 downto 0) := "00";
signal char_rom_read     : std_logic := '0';  -- Read strobe to QPI controller
signal char_rom_we       : std_logic := '0';  -- Write strobe to SAA5050 block RAM
signal char_rom_start    : std_logic_vector(23 downto 0) := x"FFC000";  -- Char ROM lives in flash-16k (first 8k is MODE 7 ROM)
signal char_rom_addr     : std_logic_vector(12 downto 0) := (others => '0');  -- "done" bit + 4k address counter

-- MGC registers
signal mgc_bank           : std_logic_vector(6 downto 0) := (others => '0');  -- Low seven bits of the bank ID
signal mgc_high_bank      : std_logic := '0';  -- High bit of the bank ID if mgc_use_both_banks==1
signal mgc_use_both_banks : std_logic := '0';  -- 0 to use two banks, 1 to use one
signal mgc_flash_addr     : std_logic_vector(23 downto 0);

-- Plus 1 registers
signal plus1_status_selected : std_logic;

begin

--------------------------------------------------------
-- Debug SPI port + USB serial port
--------------------------------------------------------

    -- SPI interface with mcu
    spi : process(clock_96)
    begin
        if rising_edge(clock_96) then
            -- Synchronous SPI; 48MHz ATSAMD MCU can do 12 MHz max, so we have plenty of time

            -- Assume 12 MHz master, so we have 8 clocks per master clock.

            -- clk  0 - sck=0 sync(0)=0 sync(1)=0 sync(2)=0
            -- clk  1 - sck=1 sync(0)=0 sync(1)=0 sync(2)=0  -- master clocks in bit from us now
            -- clk  2 - sck=1 sync(0)=1 sync(1)=0 sync(2)=0
            -- clk  3 - sck=1 sync(0)=1 sync(1)=1 sync(2)=0
            --          edge detected; our activity affects clk 4
            -- clk  4 - sck=1 sync(0)=1 sync(1)=1 sync(2)=1
            -- clk  5 - sck=1 sync(0)=1 sync(1)=1 sync(2)=1
            -- clk  6 - sck=1 sync(0)=1 sync(1)=1 sync(2)=1
            -- clk  7 - sck=1 sync(0)=1 sync(1)=1 sync(2)=1
            -- clk  8 - sck=1 sync(0)=1 sync(1)=1 sync(2)=1
            -- clk  9 - sck=0 sync(0)=1 sync(1)=1 sync(2)=1
            -- clk 10 - sck=0 sync(0)=0 sync(1)=1 sync(2)=1
            -- clk 11 - sck=0 sync(0)=0 sync(1)=0 sync(2)=1
            --          edge detected; our activity affects clk 12
            -- clk 12 - sck=0 sync(0)=0 sync(1)=0 sync(2)=0
            -- clk 13 - sck=0 sync(0)=0 sync(1)=0 sync(2)=0
            -- clk 14 - sck=0 sync(0)=0 sync(1)=0 sync(2)=0
            -- clk 15 - sck=0 sync(0)=0 sync(1)=0 sync(2)=0
            -- clk 16 - sck=0 sync(0)=0 sync(1)=0 sync(2)=0
            -- clk 17 - sck=1 sync(0)=0 sync(1)=0 sync(2)=0 -- master clocks in bit from us now
            -- clk 18 - sck=1 sync(0)=1 sync(1)=0 sync(2)=0

            -- MOSI is stable except around clocks 10-13, so it should be
            -- pretty safe for us to do everything in clock 3, and copy
            -- mcu_shifter(7) into mcu_MISO_int on every clock.  That way
            -- we'll update MISO around clock 5.

            -- SCK rise: detected

            mcu_MOSI_sync <= mcu_MOSI_sync(1 downto 0) & mcu_MOSI;
            mcu_SCK_sync <= mcu_SCK_sync(1 downto 0) & mcu_SCK;
            mcu_SS_sync <= mcu_SS_sync(1 downto 0) & mcu_SS;

            flash_reset <= '0';

            if mcu_SS_sync(1) = '1' then
                -- SS high; reset everything
                mcu_shifter <= x"AA";
                mcu_shift_count <= "000";
                mcu_state <= x"00";
                mcu_flash_spi <= '0';
                mcu_flash_spi_clocking <= '0';
                --mcu_flash_qpi <= '0';
                --mcu_flash_qpi_cmd <= '0';
                --mcu_flash_qpi_txn <= '0';
                --mcu_flash_qpi_counter <= "00";
            else
                -- SS low
                mcu_MISO_int <= mcu_shifter(7);
                if mcu_SCK_sync(2) = '0' and mcu_SCK_sync(1) = '1' then
                    -- rising SCK edge happened 2-3 cycles ago
                    --mcu_MISO_int <= mcu_shifter(6);
                    mcu_shifter <= mcu_shifter_byte;  -- {mcu_shifter[6:0], mcu_MOSI_sync[2]}
                    mcu_shift_count <= mcu_shift_count + 1;

                    if mcu_shift_count = "111" then
                        -- just received a byte: mcu_shifter_byte
                        case mcu_state is
                            when x"00" =>  -- command byte
                                mcu_state <= mcu_shifter_byte;
                                mcu_shifter <= x"55";  -- debug
                                case mcu_shifter_byte is
                                    when x"02" =>
                                        -- pass remainder of transaction through to flash
                                        mcu_flash_spi <= '1';
                                    --when x"03" =>
                                    --    -- Starting a QPI flash transaction
                                    --    flash_nCE <= '0';
                                    --    mcu_flash_qpi <= '1';
                                    --    mcu_flash_qpi_cmd <= '1';
                                    when x"05" =>
                                        -- Boundary scan
                                        debug_boundary_vector <=
                                            "10101010" &  -- AA
                                            x"FFFF" & flash_data_out &
                                            -- addr &        -- FF FF
                                            -- data &        -- FF
                                            RnW & '0' & powerup_reset_n & RST_n_in & powerup_reset_n & IRQ_n_in & ula_irq_n & NMI_n_in &  -- BF
                                            kbd & '1' & '1' & '1' & '1'; -- FF
                                    when x"07" =>
                                        -- USB serial port transaction
                                        -- Bit 0 set if we have buffer space to receive a byte
                                        -- Bit 1 set if we have a byte to send to the MCU
                                        mcu_shifter <= "000000" & usb_elk_tx_full & (usb_elk_rx_empty and not usb_elk_rx_reading);
                                        usb_elk_tx_full_sent <= usb_elk_tx_full;
                                        usb_elk_rx_empty_sent <= usb_elk_rx_empty and not usb_elk_rx_reading;
                                    when others =>
                                end case;
                            when x"01" =>  -- configure passthrough
                                -- Bit 0 = flash passthrough (send 01 01 to set passthrough, 01 00 to unset)
                                mcu_flash_passthrough <= mcu_shifter_byte(0);
                            when x"02" =>  -- SPI to flash; no-op
                            --when x"03" =>  -- QPI to flash
                            --    -- Begin QPI tx/rx byte
                            --    -- Alternate command / data bytes
                            --    if mcu_flash_qpi_cmd = '1' then
                            --        -- Just read a command byte: 0 for tx, 1 for rx
                            --        if mcu_shifter_byte(0) = '0' then
                            --            -- TX
                            --            mcu_flash_qpi_rnw <= '0';  -- TX
                            --            mcu_flash_qpi_cmd <= '0';  -- Next byte is data
                            --        else
                            --            -- RX
                            --            mcu_flash_qpi_rnw <= '1';  -- RX
                            --            mcu_flash_qpi_txn <= '1';  -- Read now
                            --        end if;
                            --    else
                            --        -- Just read a data byte for a TX transaction
                            --        mcu_flash_qpi_cmd <= '1';  -- Next byte is command
                            --        mcu_flash_qpi_txn <= '1';  -- Write now
                            --    end if;
                            --    -- Result reads out during the next command byte.
                            when x"04" =>  -- NOP state; we end up here after a serial port transaction
                            when x"05" =>  -- Boundary scan
                                -- Copy in the next byte
                                mcu_shifter <= debug_boundary_vector(47 downto 40);
                                --mcu_MISO_int <= debug_boundary_vector(47);  -- work around off by one error
                                debug_boundary_vector <= debug_boundary_vector(39 downto 0) & x"00";
                            when x"06" =>  -- Reset flash (06 00)
                                flash_reset <= '1';
                            when x"07" =>  -- USB serial port byte 1 of 2 (status)
                                -- mcu_shifter_byte contains remote status
                                -- Remote has buffer space if mcu_shifter_byte(0) is set
                                if usb_elk_tx_full_sent = '1' and mcu_shifter_byte(0) = '1' then
                                    mcu_shifter <= usb_elk_tx_byte;
                                    usb_elk_tx_full <= '0';
                                end if;
                                -- Remote has a byte for us if mcu_shifter_byte(1) is set
                                usb_elk_remote_has_byte <= mcu_shifter_byte(1);
                                mcu_state <= x"08";
                            when x"08" =>  -- USB serial port byte 2 of 2 (data)
                                if usb_elk_rx_empty_sent = '1' and usb_elk_remote_has_byte = '1' then
                                    usb_elk_rx_byte <= mcu_shifter_byte;
                                    usb_elk_rx_empty <= '0';
                                end if;
                                mcu_state <= x"04";
                            when others =>
                        end case;
                    end if;
                elsif mcu_SCK_sync(2) = '1' and mcu_SCK_sync(1) = '0' then
                    -- falling SCK edge
                    if mcu_flash_spi = '1' then
                        -- We've just started SPI passthrough and have been waiting
                        -- for mcu_SCK to go low before starting to buffer it.
                        mcu_flash_spi_clocking <= '1';
                    end if;
                end if;
            end if;

            -- QPI transaction (quick enough to perform between mcu_SCK clock edges!)
            --if mcu_flash_qpi_txn = '1' then
            --    mcu_flash_qpi_counter <= mcu_flash_qpi_counter + 1;
            --    if mcu_flash_qpi_counter(0) = '1' then
            --        if mcu_flash_qpi_rnw = '1' then
            --            -- RX; clock data from flash_IO* into mcu_shifter
            --            mcu_shifter <= mcu_shifter(3 downto 0) & flash_IO3 & flash_IO2 & flash_IO1 & flash_IO0;
            --        else
            --            -- TX; shift mcu_shifter to update flash_IO*
            --            mcu_shifter <= mcu_shifter(3 downto 0) & "0000";
            --        end if;
            --        if mcu_flash_qpi_counter(1) = '1' then
            --            mcu_flash_qpi_txn <= '0';  -- Done!
            --        end if;
            --    end if;
            --end if;

            -- Override all that if we're passing SPI through to the flash
            if mcu_flash_spi_clocking = '1' then
                mcu_MISO_int <= flash_IO1;
            end if;

            -- USB serial port: CPU interface
            if usb_serial_enable = '1' and addr(0) = '0' then
                if start_read_96 = '1' then
                    if usb_elk_rx_empty = '0' then
                        -- Flag that we're reading from the serial port to keep data
                        -- stable for the next clock
                        usb_elk_rx_reading <= '1';
                        usb_elk_rx_empty <= '1';
                    end if;
                end if;
                if start_write_96 = '1' then
                    -- Writing serial data
                    if usb_elk_tx_full = '0' then
                        usb_elk_tx_byte <= data_in;
                        usb_elk_tx_full <= '1';
                    end if;
                end if;
            end if;
            -- Clear the "CPU reading; don't overwrite data" flag
            if start_read_96 = '1' and usb_elk_rx_reading = '1' then
                usb_elk_rx_reading <= '0';
            end if;

        end if;
    end process;

    mcu_shifter_byte <= mcu_shifter(6 downto 0) & mcu_MOSI_sync(2);
    mcu_MISO <= mcu_MISO_int;

    -- USB serial port: CPU interface
    usb_serial_enable <= '1' when addr = x"FCA0" or addr = x"FCA1" else '0';
    -- Bit 1 set if we can send a byte (!tx_full); bit 0 set if we have received a byte (!rx_empty)
    usb_serial_data <= "000000" & (not usb_elk_tx_full) & (not usb_elk_rx_empty) when addr(0) = '1' else usb_elk_rx_byte;

    -- DEBUG I/O
    -- mcu_debug_RXD <= mcu_debug_TXD;  -- loopback serial for MCU debugging
    --serial_TXD <= '1' when serial_tx_count < 417 else '0'; -- verified on scope
    --serial_TXD <= clock_16; -- verified on scope
    --serial_TXD <= cpu_clken; -- verified on scope
    --serial_TXD <= clk_out_int; -- verified on scope
    --serial_TXD <= audio_bit_clock; -- verified 8MHz
    --serial_TXD <= audio_data_out;

    --serial_RXD <= kbd(3);
    --serial_RXD <= kbd_access;
    --serial_RXD <= audio_lr_clock;  -- verified 125 kHz
    --serial_RXD <= flash_ready;  -- goes low for 0.26 us (250 ns in simulation, so that's about right)

    --serial_TXD <= sdram_ready;
    --serial_RXD <= sdram_done;

    -- char_rom_read and char_rom_we both go high for 0.7141 s, i.e. 174 us * 4096
    -- then there's a 1.109 ms period where they behave as expected
    -- with a pulse on read every 0.27 us.  so that's probably the full char rom read happening.
    serial_TXD <= char_rom_read;
    --serial_RXD <= char_rom_we;
    serial_RXD <= flash_ready;


--------------------------------------------------------
-- ULA
--------------------------------------------------------

    ula : entity work.ElectronULA
    generic map (
        IncludeMMC       => true,
        Include32KRAM    => true,
        IncludeVGA       => false,
        IncludeJafaMode7 => IncludeMode7,
        UseClockMux      => true,
        UseTTxtClock     => true
    )
    port map (
        clk_16M00 => clock_16,
        --clk_24M00 => clock_24,
        clk_32M00 => clock_32,
        clk_33M33 => clock_33,
        clk_40M00 => clock_40,
        clk_ttxt  => clock_96,
        clken_ttxt_12M => clken_ttxt,

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
        ROM_n     => rom_enable_n,

        -- Video
        red       => video_red,
        green     => video_green,
        blue      => video_blue,
        vsync     => video_vsync,
        hsync     => video_hsync,

        -- Audio
        sound     => sound_bit,

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
        turbo_out      => turbo,

        -- SAA5050 character ROM loading
        char_rom_we   => char_rom_we,
        char_rom_addr => char_rom_addr(11 downto 0),
        char_rom_data => flash_data_out
    );

    ROM_n <= rom_enable_n;
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
        empty_bank_enable = '1'
        or flash_enable = '1'    -- Output from flash
        or sdram_enable = '1' -- Output from SDRAM
        or ula_enable = '1'   -- Output from ULA
        or usb_serial_enable = '1'  -- Output from USB serial port
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
            x"FF"          when RnW = '1' and empty_bank_enable = '1' else
            x"FF"          when RnW = '1' and plus1_status_selected = '1' else
            flash_data_out when RnW = '1' and flash_enable = '1' else
            sdram_data_out(15 downto 8) when RnW = '1' and sdram_enable = '1' and addr(0) = '1' else
            sdram_data_out(7 downto 0) when RnW = '1' and sdram_enable = '1' and addr(0) = '0' else
            usb_serial_data when RnW = '1' and usb_serial_enable = '1' else
            cpu_data_out   when RnW = '0' and InternalCPU else
            "ZZZZZZZZ";  -- ext CPU, RnW = '0' or boundary_scan = '1'


--------------------------------------------------------
-- Internal CPU (optional)
--------------------------------------------------------

    -- Plus 1 status register:
    -- D4 = joystick fire button 0
    -- D5 = joystick fire button 1
    -- D6 = analog chip select
    -- D7 = parallel port status
    plus1_status_selected <= '1' when addr = x"FC72" else '0';

    -- Plus 1 analog data register
    -- plus1_analog_selected <= '1' when addr = x"FC70" else '0';


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

    GenDAC: if IncludeAudio generate

        -- Simple I2S implementation for 1-bit mono output to the WM8524 DAC

        -- Master clock runs at 16 MHz
        -- Divide by 128 to get fs = 125 kHz sample rate
        -- We need 17 BCLK times per sample because I2S requires a dummy BCLK cycle after a LRCLK transition
        -- So BCLK >= fs * 17 * 2 = 6.375 MHz.  8 MHz is convenient so we'll use that.
        -- So we have 64 BCLK periods per sample, or 32 per channel.

        -- DACDAT and LRCLK inputs are sampled on the rising edge of BCLK, and need 7ns setup / 5ns hold.
        -- BCLK has a period of 125ns so it's easy to meet these by just changing them on its falling edge.

        dac_nmute <= '1';
        dac_mclk <= clock_16;
        dac_bclk <= audio_bit_clock;
        dac_lrclk <= audio_lr_clock;
        dac_dacdat <= audio_data_out;
        i2s_process : process(clock_16)
        begin
          if rising_edge(clock_16) then
            audio_bit_clock <= not audio_bit_clock;
            if audio_bit_clock = '1' then
                -- Update LRCLK and DACDAT on falling edge of BCLK
                audio_counter <= audio_counter + 1;
                audio_lr_clock <= audio_counter(5);
                audio_data_out <= audio_shifter(15);
                audio_shifter <= audio_shifter(14 downto 0) & '0';
                -- Reload audio_shifter one clock after changing dac_lrclk
                if audio_counter(4 downto 0) = "00000" then
                    --audio_shifter <= sound_bit & "000000000000000";  -- Full volume
                    audio_shifter <= "0" & sound_bit & "00000000000000";  -- Half volume
                end if;
            end if;
          end if;
        end process;

    end generate;

    NoGenDAC: if not IncludeAudio generate

        -- Standby mode
        dac_bclk <= clock_16;
        dac_mclk <= clock_16;
        dac_nmute <= '0';

    end generate;

--------------------------------------------------------
-- SDRAM
--------------------------------------------------------

    -- Sideways RAM
    sdram_enable <= '1' when addr(15 downto 14) = "10" and (rom_latch >= 4 and rom_latch < 8) else '0';

    -- Clock it at 48 MHz, so I don't have to care too much about timing analysis
    gen_sdram_clk : process (clock_96)
    begin
        if rising_edge(clock_96) then
            -- Signals from the controller update on cycles where sdram_clken = '1',
            -- i.e. we should output a rising clock edge then.
            sdram_clken <= not sdram_clken;
            sdram_CLK <= sdram_clken;
            if (start_write_96 = '1' or start_read_96 = '1') and sdram_enable = '1' then
                -- Set flags that need to stick around until a cycle where the SDRAM clock is enabled
                sdram_access <= '1';
                sdram_writing <= RnW;
                sdram_address <= "0000000" & rom_latch(3 downto 0) & addr(13 downto 1);
                sdram_high_bank_en <= not addr(0);
                sdram_low_bank_en <= addr(0);
            end if;
            if sdram_clken = '1' then
                -- Reset SDRAM trigger because it will have been seen on this cycle
                sdram_access <= '0';
                sdram_refreshing <= '0';
            end if;

            -- Generate refresh signal
            if sdram_refresh_counter = 24 then
                sdram_refreshing <= '1';
            end if;
        end if;
    end process;

    sdram_controller : entity work.sdram_simple PORT MAP (
        -- Host side
        clk_100m0_i => clock_96,
        clk_en      => sdram_clken,
        reset_i     => memory_reset_96,
        refresh_i   => sdram_refreshing,
        rw_i        => sdram_access,
        we_i        => sdram_writing,
        addr_i      => sdram_address,
        data_i      => data & data,
        ub_i        => sdram_high_bank_en,
        lb_i        => sdram_low_bank_en,
        ready_o     => sdram_ready,
        done_o      => sdram_done,
        data_o      => sdram_data_out,

        -- SDRAM side
        sdCke_o     => sdram_CKE,
        sdCe_bo     => sdram_nCS,
        sdRas_bo    => sdram_nRAS,
        sdCas_bo    => sdram_nCAS,
        sdWe_bo     => sdram_nWE,
        sdBs_o      => sdram_BA,
        sdAddr_o    => sdram_A,
        sdData_io   => sdram_DQ,
        sdDqmh_o    => sdram_UDQM,
        sdDqml_o    => sdram_LDQM
    );

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

--    sdram_loop : process(clock_96)
--    begin
--        if rising_edge(clock_96) then
--            sdram_check_refresh <= '0';
--
--            if sdram_init = '1' then
--                if memory_reset_96 = '0' then
--                    -- We're out of reset; start the SDRAM init process
--                    sdram_CKE <= '1';
--                end if;
--            elsif sdram_reading = '1' then
--            elsif sdram_writing = '1' then
--            elsif sdram_refreshing = '1' then
--            end if;
--
--            if start_write_96 = '1' then
--                if sdram_enable = '1' then
--                    sdram_writing <= '1';
--                else
--                    sdram_check_refresh <= '1';
--                end if;
--            elsif start_read_96 = '1' then
--                if sdram_enable = '1' then
--                    sdram_reading <= '1';
--                else
--                    sdram_check_refresh <= '1';
--                end if;
--            end if;
--
--            if sdram_check_refresh = '1' then
--                -- TODO check sdram refresh timer and kick off a refresh if so
--            end if;
--
--            -- reset everything if we're just powering up
--            if memory_reset_96 = '1' then
--                sdram_CKE <= '0';
--                sdram_init <= '1';
--                sdram_reading <= '0';
--                sdram_writing <= '0';
--                sdram_refreshing <= '0';
--                sdram_check_refresh <= '0';
--            end if;
--        end if;
--    end process;

--------------------------------------------------------
-- Paged ROM
--------------------------------------------------------

    -- Drive data bus with FF when nothing else is (required with bus hold buffers in v1)
    empty_bank_enable <= '1' when (
        addr(15 downto 14) = "10"
        and rom_enable_n = '1' and flash_enable = '0' and sdram_enable = '0' and ula_enable = '0'
    ) else '0';

    -- Provide ROMs using the QPI flash chip
    flash_enable <= '1' when addr(15 downto 14) = "10" and (rom_latch < 4 or rom_latch >= 12) else '0';
    -- Right now this maps to the first 16 x 16kB = 256kB of flash.

    flash_addr <= char_rom_start + char_rom_addr(11 downto 0) when char_rom_read = '1'
        else mgc_flash_addr when IncludeMGC and (rom_latch = 2 or rom_latch = 3)
        else "000000" & rom_latch & addr(13 downto 0);

    mgc_flash_addr <= "01" & (not mgc_high_bank) & mgc_bank & addr(13 downto 0) when mgc_use_both_banks = '1'
        else "01" & rom_latch(0) & mgc_bank & addr(13 downto 0);

    flash_controller : qpi_flash
    port map (
        clk => clock_96,
        ready => flash_ready,
        reset => memory_reset_96 or flash_reset,
        read => char_rom_read or (start_read_96 and flash_enable),  -- Read cycle trigger
        addr => flash_addr,
        data_out => flash_data_out,
        -- Passthrough: when active (passthrough = '1'), IO1/2/3 are inputs with
        -- a weak pullup, and nCE/SCK/IO0 are passed through (registered on clock_96).
        passthrough => mcu_flash_spi_clocking or mcu_flash_passthrough,
        passthrough_nCE => not mcu_flash_spi_clocking,
        passthrough_SCK => mcu_SCK_sync(0),
        passthrough_MOSI => mcu_MOSI_sync(0),
        -- External pins
        flash_nCE => flash_nCE,
        flash_SCK => flash_SCK,
        flash_IO0 => flash_IO0,
        flash_IO1 => flash_IO1,
        flash_IO2 => flash_IO2,
        flash_IO3 => flash_IO3
    );

    gen_mgc : if IncludeMGC generate
        process (clock_96)
        begin
            if rising_edge(clock_96) then
                if start_write_96 = '1' then
                    if addr = x"FC00" then
                        mgc_bank <= data_in(6 downto 0);
                    end if;
                    if addr = x"FC08" then
                        mgc_high_bank <= data_in(1);
                        mgc_use_both_banks <= data_in(2);
                    end if;
                end if;
                if RST_n_sync_16(1) = '0' then
                    -- TODO sync with clock_96 instead
                    mgc_bank <= (others => '0');
                    mgc_use_both_banks <= '0';
                    mgc_high_bank <= '0';
                end if;
            end if;
        end process;
    end generate;

    load_mode7_char_rom : if IncludeMode7 generate
        -- On startup, load SAA5050 character ROM from QPI flash.
        char_rom_loaded <= char_rom_addr(char_rom_addr'high);
        process (clock_96)
        begin
            if rising_edge(clock_96) then
                if char_rom_loaded = '0' then
                    char_rom_read <= '0';
                    char_rom_we <= '0';
                    case char_rom_state is
                        when "00" =>
                            -- Start a new read when flash ready
                            if flash_ready = '1' then
                                -- Start a new read
                                char_rom_read <= '1';
                                char_rom_state <= "01";
                            end if;
                        when "01" =>
                            -- Wait for data available then send it to the char rom
                            if flash_ready = '1' then
                                char_rom_we <= '1';
                                char_rom_state <= "10";
                            end if;
                        when "10" =>
                            -- Increment address for next read
                            char_rom_addr <= char_rom_addr + 1;
                            char_rom_state <= "00";
                        when "11" =>
                            -- Unused
                    end case;
                end if;
            end if;
        end process;
    end generate;


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
    RST_n_out <= '1' when
        powerup_reset_n = '1' and
        (IncludeMode7 = false or char_rom_loaded = '1')  -- stay in reset until char rom loaded
        else '0';

    reset_gen_96 : process(clock_96)
    begin
        if rising_edge(clock_96) then
            -- Serial flash needs at least 20 us to start up, and 30us after a software reset,
            -- so delay at least 30 us (2880 clocks).  Easy option: 4096 clocks (42.7 us).

            -- Synchronize pll1_locked with clock_96, then release reset 4096 clocks later:
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

            -- cpu_clken_16_sync is synchronized with clock_16.

            -- With InternalCPU, it will be high for the clock *after* a T65
            -- cycle, so as soon as it goes low, it's safe for clock_96
            -- processes to sample addr/data.  Assuming aligned clock_16 and
            -- clock_96 edges, cpu_clken_96_sync(1) will go low 20.83 ns
            -- later.

            -- With an external CPU, it will be low during the first 62.5 ns
            -- of the low clk_out period.  Assuming aligned clock_16 and
            -- clock_96 edges, cpu_clken_96_sync(1) will go low 20.83 ns into
            -- the low clk_out period.  TODO figure out memory timing.

            cpu_clken_96_sync <= cpu_clken_96_sync(1 downto 0) & cpu_clken_16_sync;

            -- start_write_96: high for 1/96 us when it's safe to sample addr/data for a memory (sdram/flash) write.
            -- start_read_96: high for 1/96 us when it's safe to sample addr for a memory (sdram/flash) read.
            start_write_96 <= '0';
            start_read_96 <= '0';
            if sdram_refresh_counter /= 31 then
                sdram_refresh_counter <= sdram_refresh_counter + 1;
            end if;
            If InternalCPU then
                if cpu_clken_96_sync(2) = '1' and cpu_clken_96_sync(1) = '0' then
                    -- falling edge of cpu_clken_16_sync; T65 clock should be all done by now
                    if RnW = '0' then
                        start_write_96 <= '1';
                    else
                        start_read_96 <= '1';
                    end if;
                    sdram_refresh_counter <= (others => '0');
                end if;
            elsif cpu_clken_96_sync(2) = '1' and cpu_clken_96_sync(1) = '0' then
                -- falling edge of cpu_clken
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

            -- Generate a pulse on the 12MHz teletext clock enable
            -- every 8 clock_96 cycles.
            clken_ttxt <= '0';
            if clken_ttxt_counter(clken_ttxt_counter'high) = '1' then
                clken_ttxt <= '1';
                clken_ttxt_counter <= "0001";
            else
                clken_ttxt_counter <= clken_ttxt_counter + 1;
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

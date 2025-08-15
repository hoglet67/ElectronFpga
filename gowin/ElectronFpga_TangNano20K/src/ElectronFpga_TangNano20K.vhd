-- Electron FPGA for the Tang Nano 20K
--
-- Copright (c) 2025 David Banks
--
-- All rights reserved
--
-- Redistribution and use in source and synthezised forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in synthesized form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name of the author nor the names of other contributors may
--   be used to endorse or promote products derived from this software without
--   specific prior written agreement from the author.
--
-- * License is granted for non-commercial use only.  A fee may not be charged
--   for redistributions as source code or in synthesized/hardware form without
--   specific prior written agreement from the author.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.board_config_pack.all;

-- This is generated dynamically using tclPre
library work;
use work.version_config_pack.all;

entity ElectronFpga_TangNano20K is
    generic (
        UseRomSlot9            : boolean := true; -- allow use of ROMs in slot 9 (the keyboard alias)
        IncludeHDMI            : boolean := true;
        IncludeICEDebugger     : boolean := G_CONFIG_DEBUGGER;
        IncludeABRRegs         : boolean := true;
        IncludeSerial          : boolean := true;
        IncludeUserPort        : boolean := true;
        IncludeAmxMouse        : boolean := true;
        IncludeJafaMode7       : boolean := true;

        IncludeFullRS423       : boolean := false; -- Overrides PiTube
        IncludeTrace           : boolean := false; -- Overrides PiTube/VGA

        IncludeBootStrap       : boolean := true;
        IncludeMonitor         : boolean := true;
        IncludeCoProExt        : boolean := not G_CONFIG_VGA;
        IncludeI2SAudio        : boolean := true;
        IncludeSPDIFAudio      : boolean := true;
        IncludeVGADAC          : boolean := G_CONFIG_VGA;

        PRJ_ROOT               : string  := "../../..";
        MOS_NAME               : string  := "/roms/tmp/os10_basic.bit";
        SIM                    : boolean := false
        );
    port (
        sys_clk         : in    std_logic;     -- 27MHz clock from the oscillator (pin 4)
                                               -- or from the SI5351 CLK0 (pin 10)

        audio_clk       : in    std_logic;     -- 24.576MHz audio clock from the SI5351 CLK1 (pin 11)

        btn1            : in    std_logic;     -- Powerup reset
        btn2            : in    std_logic;     -- Toggle HDMI / DVI modes
        reconfig_n      : out   std_logic;
        led             : inout std_logic_vector (5 downto 0);
        ws2812_din      : out   std_logic;
        key_conf        : in    std_logic;

        -- Keyboard / Mouse
        ps2_clk         : inout std_logic;
        ps2_data        : inout std_logic;
        ps2_mouse_clk   : inout std_logic;
        ps2_mouse_data  : inout std_logic;

        -- Joystick
        js_clk          : out   std_logic;     -- this is actually just phi2 to save a pin
        js_load_n       : out   std_logic;
        js_data         : in    std_logic;

        -- SD Card
        tf_miso         : in    std_logic;
        tf_cs           : out   std_logic;
        tf_sclk         : out   std_logic;
        tf_mosi         : out   std_logic;

        -- USB UART
        uart_rx         : in    std_logic;
        uart_tx         : out   std_logic;

        -- HDMI
        tmds_clk_p      : out   std_logic;
        tmds_clk_n      : out   std_logic;
        tmds_d_p        : out   std_logic_vector(2 downto 0);
        tmds_d_n        : out   std_logic_vector(2 downto 0);

        -- VGA
        vga_r           : inout std_logic;
        vga_r_n         : inout std_logic;
        vga_g           : inout std_logic;
        vga_g_n         : inout std_logic;
        vga_b           : inout std_logic;
        vga_b_n         : inout std_logic;
        vga_hs          : inout std_logic;
        vga_vs          : inout std_logic;

        -- I2S Audio
        i2s_mclk        : out   std_logic;
        i2s_bclk        : out   std_logic;
        i2s_lrclk       : out   std_logic;
        i2s_din         : out   std_logic;
        pa_en           : inout std_logic;

        -- 1-bit DAC Audio
        audiol          : inout std_logic; -- inout at this can also be configures as I2C_SCL (IncludeAnalogJS)
        audior          : inout std_logic; -- inout at this can also be configures as I2C_SDA (IncludeAnalogJS)

        -- SPDIF Audio
        audio_spdif     : out   std_logic;

        -- Magic ports for SDRAM to be inferred
        O_sdram_clk     : out   std_logic;
        O_sdram_cke     : out   std_logic;
        O_sdram_cs_n    : out   std_logic;
        O_sdram_cas_n   : out   std_logic;
        O_sdram_ras_n   : out   std_logic;
        O_sdram_wen_n   : out   std_logic;
        IO_sdram_dq     : inout std_logic_vector(31 downto 0);
        O_sdram_addr    : out   std_logic_vector(10 downto 0);
        O_sdram_ba      : out   std_logic_vector(1 downto 0);
        O_sdram_dqm     : out   std_logic_vector(3 downto 0);

        -- SPI Flash (for ROM data)
        flash_cs        : out   std_logic;     -- Active low FLASH chip select
        flash_si        : out   std_logic;     -- Serial output to FLASH chip SI pin
        flash_ck        : out   std_logic;     -- FLASH clock
        flash_so        : in    std_logic      -- Serial input from FLASH chip SO pin
        );
end entity;

architecture rtl of ElectronFpga_TangNano20K is

    --------------------------------------------------------
    -- FPGA Primitive Components
    --------------------------------------------------------

    component rPLL
        generic (
            FCLKIN: in string := "100.0";
            DEVICE: in string := "GW1N-4";
            DYN_IDIV_SEL: in string := "false";
            IDIV_SEL: in integer := 0;
            DYN_FBDIV_SEL: in string := "false";
            FBDIV_SEL: in integer := 0;
            DYN_ODIV_SEL: in string := "false";
            ODIV_SEL: in integer := 8;
            PSDA_SEL: in string := "0000";
            DYN_DA_EN: in string := "false";
            DUTYDA_SEL: in string := "1000";
            CLKOUT_FT_DIR: in bit := '1';
            CLKOUTP_FT_DIR: in bit := '1';
            CLKOUT_DLY_STEP: in integer := 0;
            CLKOUTP_DLY_STEP: in integer := 0;
            CLKOUTD3_SRC: in string := "CLKOUT";
            CLKFB_SEL: in string := "internal";
            CLKOUT_BYPASS: in string := "false";
            CLKOUTP_BYPASS: in string := "false";
            CLKOUTD_BYPASS: in string := "false";
            CLKOUTD_SRC: in string := "CLKOUT";
            DYN_SDIV_SEL: in integer := 2
        );
        port (
            CLKOUT: out std_logic;
            LOCK: out std_logic;
            CLKOUTP: out std_logic;
            CLKOUTD: out std_logic;
            CLKOUTD3: out std_logic;
            RESET: in std_logic;
            RESET_P: in std_logic;
            CLKIN: in std_logic;
            CLKFB: in std_logic;
            FBDSEL: in std_logic_vector(5 downto 0);
            IDSEL: in std_logic_vector(5 downto 0);
            ODSEL: in std_logic_vector(5 downto 0);
            PSDA: in std_logic_vector(3 downto 0);
            DUTYDA: in std_logic_vector(3 downto 0);
            FDLY: in std_logic_vector(3 downto 0)
        );
    end component;

    component CLKDIV
        generic (
            DIV_MODE : string := "2";
            GSREN: in string := "false"
        );
        port (
            CLKOUT: out std_logic;
            HCLKIN: in std_logic;
            RESETN: in std_logic;
            CALIB: in std_logic
        );
    end component;

    component OSER10
        generic (
            GSREN : string := "false";
            LSREN : string := "true"
        );
        port (
            Q : out std_logic;
            D0 : in std_logic;
            D1 : in std_logic;
            D2 : in std_logic;
            D3 : in std_logic;
            D4 : in std_logic;
            D5 : in std_logic;
            D6 : in std_logic;
            D7 : in std_logic;
            D8 : in std_logic;
            D9 : in std_logic;
            FCLK : in std_logic;
            PCLK : in std_logic;
            RESET : in std_logic
        );
    end component;

    component ELVDS_OBUF
        port (
            I : in std_logic;
            O : out std_logic;
            OB : out std_logic
        );
    end component;

    function RESETBITS return natural is
    begin
        if SIM then
            return 10;
        else
            return 20; --DB: > 10ms for SPI to start up?
        end if;
    end function;

    --------------------------------------------------------
    -- Version ROM
    --------------------------------------------------------

    type version_rom_type is array(0 to 31) of unsigned(7 downto 0);

    function init_version_rom return version_rom_type is
        variable tmp : version_rom_type;
        variable nibble : unsigned(3 downto 0);
        variable i : integer;
    begin
        -- Git version
        for i in 0 to 7 loop
            nibble := unsigned(G_CONFIG_VERSION(i * 4 + 3 downto i * 4));
            if nibble < 10 then
                tmp(7 - i) := to_unsigned(character'pos('0'), 8) + nibble;
            else
                tmp(7 - i) := to_unsigned(character'pos('A'), 8) + nibble - 10;
            end if;
        end loop;
        -- Git dirty flag
        i := 8;
        if G_CONFIG_DIRTY then
            tmp(i) := to_unsigned(character'pos('?'), 8);
            i := i + 1;
        end if;
        tmp(i) := to_unsigned(character'pos(' '), 8);
        -- VGA vs PiTube
        if G_CONFIG_VGA then
            tmp(i+1) := to_unsigned(character'pos('V'), 8);
            tmp(i+2) := to_unsigned(character'pos('G'), 8);
            tmp(i+3) := to_unsigned(character'pos('A'), 8);
            i := i + 4;
        else
            tmp(i+1) := to_unsigned(character'pos('P'), 8);
            tmp(i+2) := to_unsigned(character'pos('i'), 8);
            tmp(i+3) := to_unsigned(character'pos('T'), 8);
            tmp(i+4) := to_unsigned(character'pos('u'), 8);
            tmp(i+5) := to_unsigned(character'pos('b'), 8);
            tmp(i+6) := to_unsigned(character'pos('e'), 8);
            i := i + 7;
        end if;
        tmp(i) := to_unsigned(character'pos(' '), 8);
        -- NoDebugger vs Debugger
        if not G_CONFIG_DEBUGGER then
            tmp(i+1) := to_unsigned(character'pos('N'), 8);
            tmp(i+2) := to_unsigned(character'pos('o'), 8);
            i := i + 2;
        end if;
        tmp(i+1) := to_unsigned(character'pos('D'), 8);
        tmp(i+2) := to_unsigned(character'pos('e'), 8);
        tmp(i+3) := to_unsigned(character'pos('b'), 8);
        tmp(i+4) := to_unsigned(character'pos('u'), 8);
        tmp(i+5) := to_unsigned(character'pos('g'), 8);
        tmp(i+6) := to_unsigned(character'pos('g'), 8);
        tmp(i+7) := to_unsigned(character'pos('e'), 8);
        tmp(i+8) := to_unsigned(character'pos('r'), 8);
        tmp(i+9) := x"0D";
        i := i + 10;
        while (i < 32) loop
            tmp(i) := x"00";
            i := i + 1;
        end loop;
        return tmp;
    end function;

    signal version_rom : version_rom_type := init_version_rom;
    signal version_rom_byte : std_logic_vector(7 downto 0);

    --------------------------------------------------------
    -- Signals
    --------------------------------------------------------

    signal clock_16        : std_logic; -- system clock
    signal clock_24        : std_logic; -- Jafa Mode 7 and debugger clock
    signal clock_27        : std_logic; -- HDMI slow clock
    signal clock_32        : std_logic; -- Jafa Mode 7
    signal clock_40        : std_logic; -- VGA 60Hz clock
    signal clock_96        : std_logic;
    signal clock_96_p      : std_logic;
    signal clock_135       : std_logic;
    signal clock_81        : std_logic;
    signal clock_405       : std_logic;
    signal spdif_clk       : std_logic; -- 6.144MHz SPDIF clock

    -- Signals for the memory controller
    signal mem_ready       : std_logic;
    signal mem_strobe      : std_logic;
    signal mem_refresh     : std_logic;

    -- Audio
    signal dac_l_in        : std_logic_vector(9 downto 0);
    signal dac_r_in        : std_logic_vector(9 downto 0);
    signal audio_l_tmp     : std_logic;
    signal audio_r_tmp     : std_logic;
    signal audio_l         : std_logic_vector(19 downto 0);
    signal audio_r         : std_logic_vector(19 downto 0);

    -- output used to load sample into SPDIF (spdif clock domain)
    signal spdif_load      : std_logic;

    signal joystick1       : std_logic_vector(4 downto 0) := (others => '1');
    signal joystick2       : std_logic_vector(4 downto 0) := (others => '1');
    signal jumper          : std_logic_vector(5 downto 0) := (others => '0');
    signal last_phi2       : std_logic := '0';
    signal sr_counter      : unsigned(3 downto 0) := (others => '0');
    signal sr_mirror       : std_logic_vector(15 downto 0) := (others => '0');

    signal powerup_reset_n : std_logic := '0';
    signal hard_reset_n    : std_logic;
    signal reset_counter   : std_logic_vector(RESETBITS downto 0);
    signal config_counter  : std_logic_vector(20 downto 0) := (others => '0'); -- 16ms debounce
    signal config_last     : std_logic := '0';

    signal ext_A_stb       : std_logic;
    signal ext_A           : std_logic_vector (18 downto 0);
    signal ext_Din         : std_logic_vector (7 downto 0);
    signal ext_Dout        : std_logic_vector (7 downto 0);
    signal ext_nCS         : std_logic;
    signal ext_nWE         : std_logic;
    signal ext_nWE_long    : std_logic;
    signal ext_nOE         : std_logic;

    signal vid_mode        : std_logic_vector(1 downto 0);

    signal caps_led        : std_logic;
    signal motor_led       : std_logic;

    signal i_VGA_R         : std_logic_vector(3 downto 0);
    signal i_VGA_G         : std_logic_vector(3 downto 0);
    signal i_VGA_B         : std_logic_vector(3 downto 0);
    signal vga_r_int       : std_logic;
    signal vga_g_int       : std_logic;
    signal vga_b_int       : std_logic;
    signal vga_hs_int      : std_logic;
    signal vga_vs_int      : std_logic;

    -- HDMI
    signal hdmi_aspect     : std_logic_vector(1 downto 0) := "11";
    signal hdmi_audio_en   : std_logic := '1';
    signal vid_debug       : std_logic;
    signal tmds_r          : std_logic_vector(9 downto 0);
    signal tmds_g          : std_logic_vector(9 downto 0);
    signal tmds_b          : std_logic_vector(9 downto 0);

    -- External tube
    signal phi2            : std_logic;
    signal ext_tube_do     : std_logic_vector(7 downto 0);
    signal ext_tube_ntube  : std_logic;
    signal ext_tube_ctrl   : std_logic_vector(5 downto 0); -- signals that use the LED output

    -- CPU tracing
    signal trace_data      :   std_logic_vector(7 downto 0);
    signal trace_r_nw      :   std_logic;
    signal trace_sync      :   std_logic;

    -- Mem Controller Monior LEDs
    signal monitor_leds    :   std_logic_vector(5 downto 0);

    -- HDMI PLL synchronization
    signal pll1_lock       : std_logic;
    signal pll2_lock       : std_logic;

    -- 1MHz Bus
    signal ext_1mhz_clk    : std_logic; -- the system clock
    signal ext_1mhz_clken  : std_logic; -- a 1MHz strobe, valid for one system clock cycle
    signal ext_1mhz_nrst   : std_logic;
    signal ext_1mhz_pgfc_n : std_logic;
    signal ext_1mhz_pgfd_n : std_logic;
    signal ext_1mhz_r_nw   : std_logic;
    signal ext_1mhz_addr   : std_logic_vector(7 downto 0);
    signal ext_1mhz_di     : std_logic_vector(7 downto 0);
    signal ext_1mhz_do     : std_logic_vector(7 downto 0);

    -- Multiboot
    signal reconfig        : std_logic;
    signal pa_en_dout      : std_logic;

    -- LEDs
    signal multiboot_leds  : std_logic_vector(5 downto 0);
    signal normal_leds     : std_logic_vector(5 downto 0);

    -- UART
    signal avr_rx          : std_logic;
    signal avr_tx          : std_logic;
    signal serial_rx       : std_logic;
    signal serial_tx       : std_logic;
    signal serial_rts      : std_logic;
    signal serial_cts      : std_logic;

    -- Test
    signal test            : std_logic_vector(7 downto 0);

begin

    --------------------------------------------------------
    -- Electron Core
    --------------------------------------------------------

    electron_core : entity work.ElectronFpga_core
    generic map (
        UseRomSlot9        => UseRomSlot9,
        IncludeHDMI        => IncludeHDMI,
        IncludeICEDebugger => IncludeICEDebugger,
        IncludeABRRegs     => IncludeABRRegs,
        IncludeSerial      => IncludeSerial,
        IncludeUserPort    => IncludeUserPort,
        IncludeAmxMouse    => IncludeAmxMouse,
        IncludeJafaMode7   => IncludeJafaMode7
    )
    port map (
        -- Clocks
        clk_16M00         => clock_16,
        clk_24M00         => clock_24,
        clk_27M00         => clock_27,
        clk_32M00         => clock_32,
        clk_33M33         => clock_27,
        clk_40M00         => clock_40,
        -- Hard reset (active low)
        hard_reset_n      => hard_reset_n,
        -- Keyboard
        ps2_clk           => ps2_clk,
        ps2_data          => ps2_data,
        -- Mouse
        ps2_mouse_clk     => ps2_mouse_clk,
        ps2_mouse_data    => ps2_mouse_data,
        -- Digital Joystick
        joystick1         => joystick1,
        joystick2         => joystick2,
        -- VGA Video
        video_red         => i_VGA_R,
        video_green       => i_VGA_G,
        video_blue        => i_VGA_B,
        video_hsync       => vga_hs_int,
        video_vsync       => vga_vs_int,
        -- HDMI Video
        hdmi_audio_en     => hdmi_audio_en,
        tmds_r            => tmds_r,
        tmds_g            => tmds_g,
        tmds_b            => tmds_b,
        -- Audio
        audio_l           => audio_l_tmp,
        audio_r           => audio_r_tmp,
        -- External memory (e.g. SRAM and/or FLASH)
        -- 512KB logical address space
        ext_nOE           => ext_nOE,
        ext_nWE           => ext_nWE,
        ext_nWE_long      => ext_nWE_long,
        ext_nCS           => ext_nCS,
        ext_A             => ext_A,
        ext_Dout          => ext_Dout,
        ext_Din           => ext_Din,
        -- SD Card
        SDMISO            => tf_miso,
        SDSS              => tf_cs,
        SDCLK             => tf_sclk,
        SDMOSI            => tf_mosi,
        -- KeyBoard LEDs (active high)
        caps_led          => caps_led,
        motor_led         => motor_led,
        -- Casette Port
        cassette_in       => '0',
        cassette_out      => open,
        -- Format of Video
        -- 00 - sRGB - interlaced
        -- 01 - sRGB - non interlaced
        -- 10 - 576p - 50Hz (27MHz pixel clock for 720x576 50Hz HDMI timings)
        -- 11 - 600p - 60Hz (40MHz pixel clock for 800x600 60Hz SVGA timings)
        vid_mode          => vid_mode,
        fake_timing       => not jumper(3),
        -- Test outputs
        test              => test,
        -- External 1MHz bus
        ext_1mhz_clken    => ext_1mhz_clken, -- a 1MHz strobe, valid for one system clock cycle
        ext_1mhz_nrst     => ext_1mhz_nrst,
        ext_1mhz_pgfc_n   => ext_1mhz_pgfc_n,
        ext_1mhz_pgfd_n   => ext_1mhz_pgfd_n,
        ext_1mhz_r_nw     => ext_1mhz_r_nw,
        ext_1mhz_addr     => ext_1mhz_addr,
        ext_1mhz_di       => ext_1mhz_di,
        ext_1mhz_do       => ext_1mhz_do,
        ext_1mhz_irq_n    => open,
        ext_1mhz_nmi_n    => open,
        -- ICE T65 Deubgger 115200 baud serial
        avr_RxD           => avr_rx,
        avr_TxD           => avr_tx,
        -- SCN2681 RS423 Interface
        serial_RxD        => serial_rx,
        serial_TxD        => serial_tx,
        serial_CTS        => serial_cts,
        serial_RTS        => serial_rts,
        -- 6502 Tracing
        trace_data        => trace_data,
        trace_r_nw        => trace_r_nw,
        trace_sync        => trace_sync,
        -- Raw CPU interface
        phi2              => phi2
    );

    audio_l <= x"10000" when audio_l_tmp = '1' else x"F0000";
    audio_r <= x"10000" when audio_r_tmp = '1' else x"F0000";

    vid_mode <= "10"; -- Force 50Hz VGA mode for now

    --------------------------------------------------------
    -- Clock Generation
    --------------------------------------------------------

    -- 48 MHz master clock from 27MHz input clock
    -- plus intermediate 96MHz clock for scan doubler

    pll1 : rPLL
        generic map (
            FCLKIN => "27",
            DEVICE => "GW2AR-18C",
            IDIV_SEL => 8,
            FBDIV_SEL => 31,
            ODIV_SEL => 8,
            DYN_SDIV_SEL => 6,
            PSDA_SEL => "1000"          -- 180 degree phase shift
        )
        port map (
            CLKIN    => sys_clk,
            CLKOUT   => clock_96,       -- 96MHz clock for SDRAM
            CLKOUTP  => clock_96_p,     -- 96MHz clock for SDRAM, phase shifted 180 degrees
            CLKOUTD  => clock_16,       -- 16MHz main clock
            CLKOUTD3 => clock_32,
            LOCK     => pll1_lock,
            RESET    => '0',
            RESET_P  => '0',
            CLKFB    => '0',
            FBDSEL   => (others => '0'),
            IDSEL    => (others => '0'),
            ODSEL    => (others => '0'),
            PSDA     => (others => '0'),
            DUTYDA   => (others => '0'),
            FDLY     => (others => '0')
        );

    pll2 : rPLL
        generic map (
            FCLKIN => "27",
            DEVICE => "GW2AR-18C",
            IDIV_SEL => 0,
            FBDIV_SEL => 14,
            ODIV_SEL => 2
        )
        port map (
            CLKIN    => sys_clk,
            CLKOUT   => clock_405,      -- 405MHz VGA 1-bit DAC clock
            CLKOUTP  => open,
            CLKOUTD  => open,
            CLKOUTD3 => clock_135,      -- 135MHz HDMI Serial Clock (5x the HDMI Pixel Clock)
            LOCK     => pll2_lock,
            RESET    => '0',
            RESET_P  => '0',
            CLKFB    => '0',
            FBDSEL   => (others => '0'),
            IDSEL    => (others => '0'),
            ODSEL    => (others => '0'),
            PSDA     => (others => '0'),
            DUTYDA   => (others => '0'),
            FDLY     => (others => '0')
            );

    clkdiv_dac : CLKDIV
        generic map (
            DIV_MODE => "5",            -- Divide by 5
            GSREN => "false"
        )
        port map (
            RESETN => '1',
            HCLKIN => clock_405,
            CLKOUT => clock_81,
            CALIB  => '1'
        );


    clkdiv5 : CLKDIV
        generic map (
            DIV_MODE => "5",            -- Divide by 5
            GSREN => "false"
        )
        port map (
            RESETN => '1',
            HCLKIN => clock_135,
            CLKOUT => clock_27,         -- 27MHz HDMI Pixel Clock
            CALIB  => '1'
        );

    clkdiv4 : CLKDIV
        generic map (
            DIV_MODE => "4",            -- Divide by 4
            GSREN => "false"
        )
        port map (
            RESETN => powerup_reset_n,
            HCLKIN => clock_96,
            CLKOUT => clock_24,         -- 24MHz AVR Clock
            CALIB  => '1'
        );

    clkdiv_spdif : CLKDIV
        generic map (
            DIV_MODE => "4",            -- Divide by 4
            GSREN => "false"
        )
        port map (
            RESETN => '1',
            HCLKIN => audio_clk,        -- 24.576MHz audio clock
            CLKOUT => spdif_clk,        --  6.144MHz spdif clock
            CALIB  => '1'
        );

    --------------------------------------------------------
    -- Power Up Reset Generation
    --------------------------------------------------------

    process(clock_16)
    begin
        if rising_edge(clock_16) then
            if btn1 = '1' then
                reset_counter <= (others => '0');
            elsif (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= reset_counter(reset_counter'high);
            hard_reset_n <= not (not powerup_reset_n or not mem_ready);
        end if;
    end process;

    process(clock_16)
    begin
        if rising_edge(clock_16) then
            if powerup_reset_n = '0' then
                hdmi_audio_en <= jumper(4);
            elsif btn2 = '1' then
                config_counter <= (others => '1');
            elsif config_counter(config_counter'high) = '1' then
                config_counter <= config_counter - 1;
            elsif config_last = '1' then
                hdmi_audio_en <= not hdmi_audio_en;
            end if;
            config_last <= config_counter(config_counter'high);
        end if;
    end process;

    --------------------------------------------------------
    -- Multiboot Reconfig
    --------------------------------------------------------

    inst_multiboot : entity work.multiboot
        generic map (
            CORE_ID => G_CORE_ID
            )
        port map (
            clock           => clock_16,
            powerup_reset_n => powerup_reset_n,
            btn1            => btn1,
            btn2            => btn2,
            btn3            => key_conf,
            jumper          => jumper,
            led             => multiboot_leds,
            pa_en_dout      => pa_en_dout,
            reconfig        => reconfig
            );

    pa_en      <= '0' when pa_en_dout = '0' else 'Z';
    reconfig_n <= '0' when reconfig = '1' else 'Z';

    --------------------------------------------------------
    -- SPDIF
    --------------------------------------------------------

    -- Note: this block assumes a fixed 48KHz sample rate derived
    -- from an external spdif_clk of 6.144MHz, which must be
    -- locked to the main system clock. This constraint is
    -- satisfied by virtue of the way we configure the MS5351A
    -- clock generator.
    --
    -- When legacy audio is selected this is not ideal!
    -- PSG = 125KHz, SID = 1MHz, M5K = 48.487KHz.
    --
    -- It might in this case to switch the SPDIF output to the M5K.

    gen_spdif_audio : if IncludeSPDIFAudio generate
        signal spdif_in        : std_logic_vector(19 downto 0);
        signal channelA        : std_logic;
        signal div64           : unsigned(5 downto 0) := (others => '0');
    begin

        spdif_in <= audio_l when channelA = '1' else audio_r;

        process(spdif_clk)
        begin
            if rising_edge(spdif_clk) then
                div64 <= div64 + 1;
                if div64 = 0 then
                    spdif_load <= '1';
                else
                    spdif_load <= '0';
                end if;
            end if;
        end process;

        spdif_serialize: entity work.spdif_serializer
            port map (
                clk          => spdif_clk,
                clken        => '1',
                auxAudioBits => (others => '0'),
                sample       => spdif_in,
                load         => spdif_load,
                channelA     => channelA,
                spdifOut     => audio_spdif
                );
    end generate;

    gen_no_spdif_audio : if not IncludeSPDIFAudio generate
        audio_spdif <= '1';
    end generate;

    --------------------------------------------------------
    -- Audio DACs
    --------------------------------------------------------

        -- Convert from signed to unsigned
        dac_l_in <= (not audio_l(19)) & audio_l(18 downto 10);
        dac_r_in <= (not audio_r(19)) & audio_r(18 downto 10);

        dac_l : entity work.pwm_sddac
            generic map (
                msbi_g => 9
                )
            port map (
                clk_i => clock_16,
                reset => '0',
                dac_i => dac_l_in,
                dac_o => audiol
                );

        dac_r : entity work.pwm_sddac
            generic map (
                msbi_g => 9
                )
            port map (
                clk_i => clock_16,
                reset => '0',
                dac_i => dac_r_in,
                dac_o => audior
                );

    --------------------------------------------------------
    -- HDMI Output
    --------------------------------------------------------

    --  Serialize the three 10-bit TMDS channels to three serialized 1-bit TMDS streams

    hdmi : if (IncludeHDMI) generate
        signal serialized_c : std_logic;
        signal serialized_r : std_logic;
        signal serialized_g : std_logic;
        signal serialized_b : std_logic;
    begin

        ser_b : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map(
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_b,
                D0    => tmds_b(0),
                D1    => tmds_b(1),
                D2    => tmds_b(2),
                D3    => tmds_b(3),
                D4    => tmds_b(4),
                D5    => tmds_b(5),
                D6    => tmds_b(6),
                D7    => tmds_b(7),
                D8    => tmds_b(8),
                D9    => tmds_b(9)
            );

        ser_g : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_g,
                D0    => tmds_g(0),
                D1    => tmds_g(1),
                D2    => tmds_g(2),
                D3    => tmds_g(3),
                D4    => tmds_g(4),
                D5    => tmds_g(5),
                D6    => tmds_g(6),
                D7    => tmds_g(7),
                D8    => tmds_g(8),
                D9    => tmds_g(9)
            );

        ser_r : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_r,
                D0    => tmds_r(0),
                D1    => tmds_r(1),
                D2    => tmds_r(2),
                D3    => tmds_r(3),
                D4    => tmds_r(4),
                D5    => tmds_r(5),
                D6    => tmds_r(6),
                D7    => tmds_r(7),
                D8    => tmds_r(8),
                D9    => tmds_r(9)
                );

        ser_c : OSER10
            generic map (
                GSREN => "false",
                LSREN => "true"
            )
            port map (
                PCLK  => clock_27,
                FCLK  => clock_135,
                RESET => '0',
                Q     => serialized_c,
                D0    => '1',
                D1    => '1',
                D2    => '1',
                D3    => '1',
                D4    => '1',
                D5    => '0',
                D6    => '0',
                D7    => '0',
                D8    => '0',
                D9    => '0'
            );

        -- Encode the 1-bit serialized TMDS streams to Low-voltage differential signaling (LVDS) HDMI output pins

        OBUFDS_c : ELVDS_OBUF
            port map (
                I  => serialized_c,
                O  => tmds_clk_p,
                OB => tmds_clk_n
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => serialized_b,
                O  => tmds_d_p(0),
                OB => tmds_d_n(0)
            );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => serialized_g,
                O  => tmds_d_p(1),
                OB => tmds_d_n(1)
            );

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => serialized_r,
                O  => tmds_d_p(2),
                OB => tmds_d_n(2)
            );

    end generate;

    --------------------------------------------------------
    -- I2S Audio
    --------------------------------------------------------

    -- For the MAX98357A (on the Tang Nano 20K)
    -- and the CS4354 (on the Dock board)

    -- The CS4354 has LRCLK polarity Left=0 Right=1 but the datasheet
    -- is ambiguous as to which of AOUTA/B is Left/Right. On the Tang
    -- Nano 20K PCB I guessed that AOUTA was Left, but this appear to
    -- be wrong. So we swap then here.

    -- This also swaps the polarity for the MAX98357A, but as we'd
    -- like to use this in mono mode (output = L/2 + R/2) then that
    -- shouldn't matter.

    gen_i2s : if IncludeI2SAudio generate
        signal tmp_l : std_logic_vector(19 downto 0);
        signal tmp_r : std_logic_vector(19 downto 0);
    begin

        -- Attenuate the speaker output
        process(audio_l, audio_r, pa_en)
        begin
            if pa_en = '1' then
                -- Speaker
                tmp_l <= (3 downto 0 => audio_l(19)) & audio_l(19 downto 4);
                tmp_r <= (3 downto 0 => audio_r(19)) & audio_r(19 downto 4);
            else
                -- Line out
                tmp_l <= audio_l;
                tmp_r <= audio_r;
            end if;
        end process;

        i2s : entity work.i2s_simple
            generic map (
                ATTENUATE  => 0,         -- No attenuation, allows use of full dynamic range
                CLOCKSPEED => 6144000,   -- SPDIF Clock
                SAMPLERATE => 48000      -- Output sample rate of new audio resampler
                )
            port map (
                clock      => spdif_clk,
                reset_n    => '1',       -- Avoid a nasty click on powerup_reset_n
                audio_l    => tmp_l,
                audio_r    => tmp_r,
                i2s_lrclk  => i2s_lrclk,
                i2s_bclk   => i2s_bclk,
                i2s_din    => i2s_din
                );
        i2s_mclk <= audio_clk;
    end generate;

    not_gen_i2s : if not IncludeI2SAudio generate
        i2s_mclk   <= 'Z';
        i2s_lrclk  <= 'Z';
        i2s_bclk   <= 'Z';
        i2s_din    <= 'Z';
    end generate;

    --------------------------------------------------------
    -- SDRAM Memory Controller
    --------------------------------------------------------

    e_mem: entity work.mem_tang_20k
        generic map (
            IncludeMonitor => IncludeMonitor,
            IncludeBootStrap => IncludeBootstrap,
            SIM => SIM,
            PRJ_ROOT => PRJ_ROOT,
            MOS_NAME => MOS_NAME
        )
        port map (
            CLK_96         => clock_96,
            CLK_96_p       => clock_96_p,
            CLK_48         => clock_16,

            rst_n          => powerup_reset_n,

            READY          => mem_ready,

            core_rfsh_stb  => mem_refresh,
            core_A_stb     => mem_strobe,
            core_A         => ext_A,
            core_Din       => ext_Din,
            core_Dout      => ext_Dout,
            core_nCS       => ext_nCS,
            core_nWE       => '1', -- not currently used by the memory controller
            core_nWE_long  => ext_nWE_long,
            core_nOE       => ext_nOE,

            O_sdram_clk    => O_sdram_clk     ,
            O_sdram_cke    => O_sdram_cke     ,
            O_sdram_cs_n   => O_sdram_cs_n    ,
            O_sdram_cas_n  => O_sdram_cas_n   ,
            O_sdram_ras_n  => O_sdram_ras_n   ,
            O_sdram_wen_n  => O_sdram_wen_n   ,
            IO_sdram_dq    => IO_sdram_dq     ,
            O_sdram_addr   => O_sdram_addr    ,
            O_sdram_ba     => O_sdram_ba      ,
            O_sdram_dqm    => O_sdram_dqm     ,

            led            => monitor_leds,

            FLASH_CS       => flash_cs,
            FLASH_SI       => flash_si,
            FLASH_CK       => flash_ck,
            FLASH_SO       => flash_so
        );

--------------------------------------------------------
-- VGA outputs
--------------------------------------------------------

    -- Note: It's a build error if both IncludeVGADAC and IncludeCoProExt are both set

    vga_1bit_dac : if IncludeVGADAC generate
    begin

        e_vidr:entity work.dac1_oser
            port map (
                rst_i               => not hard_reset_n,
                clk_sample_i        => clock_27,
                clk_dac_px_i        => clock_81,
                clk_dac_i           => clock_405,
                sample_i            => unsigned(i_VGA_r),
                bitstream_o         => vga_r_int
                );
        e_vidg:entity work.dac1_oser
            port map (
                rst_i               => not hard_reset_n,
                clk_sample_i        => clock_27,
                clk_dac_px_i        => clock_81,
                clk_dac_i           => clock_405,
                sample_i            => unsigned(i_VGA_g),
                bitstream_o         => vga_g_int
                );
        e_vidb:entity work.dac1_oser
            port map (
                rst_i               => not hard_reset_n,
                clk_sample_i        => clock_27,
                clk_dac_px_i        => clock_81,
                clk_dac_i           => clock_405,
                sample_i            => unsigned(i_VGA_b),
                bitstream_o         => vga_b_int
                );

        -- Manually instantiate differential output buffers to avoid
        -- warning about vga_x_n being unused.

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => vga_r_int,
                O  => vga_r,
                OB => vga_r_n
             );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => vga_g_int,
                O  => vga_g,
                OB => vga_g_n
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => vga_b_int,
                O  => vga_b,
                OB => vga_b_n
             );

        vga_hs <= vga_hs_int;
        vga_vs <= vga_vs_int;

    end generate;

    not_vga_1bit_dac : if not IncludeVGADAC and not includeCoProExt generate

        -- Manually instantiate differential output buffers to avoid
        -- warning about vga_x_n being unused.

        OBUFDS_r : ELVDS_OBUF
            port map (
                I  => i_VGA_R(i_VGA_R'high),
                O  => vga_r,
                OB => vga_r_n
             );

        OBUFDS_g : ELVDS_OBUF
            port map (
                I  => i_VGA_G(i_VGA_G'high),
                O  => vga_g,
                OB => vga_g_n
             );

        OBUFDS_b : ELVDS_OBUF
            port map (
                I  => i_VGA_B(i_VGA_B'high),
                O  => vga_b,
                OB => vga_b_n
                );

        vga_hs <= vga_hs_int;
        vga_vs <= vga_vs_int;

    end generate;


--------------------------------------------------------
-- External tube connections
--------------------------------------------------------

    -- Note: It's a build error if both IncludeVGADAC and IncludeCoProExt are both set

    ext_tube_ntube <= '0' when ext_1mhz_pgfc_n = '0' and ext_1mhz_addr(7 downto 3) = "11100" else '1';

    GenCoProExt: if IncludeCoProExt and not IncludeTrace and not IncludeFullRS423 generate
    begin
        ext_tube_do  <= vga_g & vga_b_n & vga_vs & vga_hs & vga_r_n & vga_b & vga_g_n & vga_r when jumper(2) = '0' else x"FE";

        vga_g   <= ext_1mhz_di(7) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_b_n <= ext_1mhz_di(6) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_vs  <= ext_1mhz_di(5) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_hs  <= ext_1mhz_di(4) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_r_n <= ext_1mhz_di(3) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_b   <= ext_1mhz_di(2) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_g_n <= ext_1mhz_di(1) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';
        vga_r   <= ext_1mhz_di(0) when ext_1mhz_r_nw = '0' and phi2 = '1' else 'Z';

        ext_tube_ctrl(5) <= ext_1mhz_nrst;
        ext_tube_ctrl(4) <= ext_1mhz_addr(2);
        ext_tube_ctrl(3) <= ext_1mhz_addr(1);
        ext_tube_ctrl(2) <= ext_tube_ntube;
        ext_tube_ctrl(1) <= ext_1mhz_r_nw;
        ext_tube_ctrl(0) <= ext_1mhz_addr(0);

    end generate;

    GenCoProNotExt: if not IncludeCoProExt or IncludeTrace or IncludeFullRS423 generate
    begin
        ext_tube_do  <= x"FE";
        ext_tube_ctrl <= (others => '1');
    end generate;

--------------------------------------------------------
-- External shift register for joysticks / config links
--------------------------------------------------------

    process(clock_16)
    begin
        if rising_edge(clock_16) then
            -- external 74LV165A clocked on rising edge, so work here on falling edge
            if phi2 = '0' and last_phi2 = '1' then
                if sr_counter = "1111" then
                    js_load_n <= '0';
                else
                    js_load_n <= '1';
                end if;
                if sr_counter = "0000" then
                    joystick1 <= sr_mirror(12 downto 8);
                    joystick2 <= sr_mirror(4 downto 0);
                    jumper    <= sr_mirror(7 downto 5) & sr_mirror(15 downto 13);
                end if;
                sr_mirror  <= sr_mirror(14 downto 0) & js_data;
                sr_counter <= sr_counter + 1;
            end if;
            mem_strobe  <= phi2 and not last_phi2; -- on the rising edge (middle of the cyle)
            mem_refresh <= last_phi2 and not phi2; -- on the falling edge
            last_phi2 <= phi2;
        end if;
    end process;

    --------------------------------------------------------
    -- 6502 Instruction Tracing via the debug connector
    --------------------------------------------------------

    trace: if IncludeTrace generate
    begin
        -- Debug connector:
        --  1 = GND
        --  2 = PHI2
        --  3 = PWM_L
        --  4 = PWM_R
        --  5 = VGA_HS     data(7)
        --  6 = LED0       sync
        --  7 = LED1       rnw
        --  8 = VGA_R      data(6)
        --  9 = VGA_R_n    data(5)
        -- 10 = VGA_G      data(4)
        -- 11 = VGA_G_n    data(3)
        -- 12 = VGA_B      data(2)
        -- 13 = VGA_B_n    data(1)
        -- 14 = VGA_VS     data(0)
        -- 15 = LED2       '1' (nTube in case Pi present)
        -- 16 = LED5       reset_n
        -- 17 = LED4       '0'
        -- 18 = LED3       '0;
        -- 19 = KEY_CONF
        -- 20 = GND
        --
        -- Note: data ordering is for simplicity of wiring, and
        -- doesn't match the PiTube data ordering.
        vga_hs  <= trace_data(7);
        vga_r   <= trace_data(6);
        vga_r_n <= trace_data(5);
        vga_g   <= trace_data(4);
        vga_g_n <= trace_data(3);
        vga_b   <= trace_data(2);
        vga_b_n <= trace_data(1);
        vga_vs  <= trace_data(0);
        led(0)  <= trace_sync;
        led(1)  <= trace_r_nw;

    end generate;

--------------------------------------------------------
-- Outputs/signals whose function depends on the Includes
--------------------------------------------------------

    js_clk <= phi2;

    gen_fullrs423: if IncludeFullRS423 generate
        led(2) <= 'Z';        -- DTR
        led(3) <= serial_rts; -- CTS
        led(4) <= 'Z';        -- TX
        led(5) <= serial_tx;  -- RX
        serial_rx  <= led(4);
        serial_cts <= led(2);
        uart_tx    <= avr_tx;
        avr_rx     <= uart_rx;
    end generate;

    gen_not_fullrs423: if not IncludeFullRS423 generate
        normal_leds <= (caps_led & motor_led & powerup_reset_n & hard_reset_n & mem_ready & hdmi_audio_en) xor "111111";
        led <= ext_tube_ctrl  when IncludeCoProExt                          else
               multiboot_leds when G_CORE_ID >= 0 and powerup_reset_n = '0' else
               monitor_leds   when IncludeMonitor                           else
               normal_leds;
        uart_tx    <= avr_tx  when IncludeICEDebugger and jumper(5) = '1' else serial_tx;
        serial_rx  <= '1'     when IncludeICEDebugger and jumper(5) = '1' else uart_rx;
        serial_cts <= '1';
        avr_rx     <= uart_rx when IncludeICEDebugger and jumper(5) = '1' else '1';
    end generate;

    process(clock_16)
    begin
        if rising_edge(clock_16) then
            if ext_1mhz_addr < 32 then
                version_rom_byte <= std_logic_vector(version_rom(conv_integer(ext_1mhz_addr(4 downto 0))));
            else
                version_rom_byte <= x"00";
            end if;
        end if;
    end process;

    ext_1mhz_do <= ext_tube_do      when ext_tube_ntube  = '0' else
                   version_rom_byte when ext_1mhz_pgfd_n = '0' else
                   x"FF";

    ws2812_din <= '0';

end architecture;

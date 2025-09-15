--------------------------------------------------------------------------------
-- Copyright (c) 2015 David Banks
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : ElectronFpga_duo.vhf
-- /___/   /\     Timestamp : 28/07/2015
-- \   \  /  \
--  \___\/\___\
--
--Design Name: ElectronFpga_duo
--Device: Spartan6 LX9

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.Vcomponents.all;

entity ElectronFpga_duo is
    port (
        clk_32M00      : in    std_logic;
        ps2_clk        : in    std_logic;
        ps2_data       : in    std_logic;
        ps2_mouse_clk  : inout std_logic;
        ps2_mouse_data : inout std_logic;
        JOYSTICK1      : in    std_logic_vector (9 downto 1);
        JOYSTICK2      : in    std_logic_vector (9 downto 1);
        ERST           : in    std_logic;
        red            : out   std_logic_vector (3 downto 0);
        green          : out   std_logic_vector (3 downto 0);
        blue           : out   std_logic_vector (3 downto 0);
        vsync          : out   std_logic;
        hsync          : out   std_logic;
        audioL         : out   std_logic;
        audioR         : out   std_logic;
        casIn          : in    std_logic;
        casOut         : out   std_logic;
        LED            : out   std_logic_vector (4 downto 1);
        SRAM_nOE       : out   std_logic;
        SRAM_nWE       : out   std_logic;
        SRAM_nCS       : out   std_logic;
        SRAM_A         : out   std_logic_vector (20 downto 0);
        SRAM_D         : inout std_logic_vector (7 downto 0);
        ARDUINO_RESET  : out   std_logic;
        SW1            : in    std_logic;
        FLASH_CS       : out   std_logic; -- Active low FLASH chip select
        FLASH_SI       : out   std_logic; -- Serial output to FLASH chip SI pin
        FLASH_CK       : out   std_logic; -- FLASH clock
        FLASH_SO       : in    std_logic; -- Serial input from FLASH chip SO pin
        SDMISO         : in    std_logic;
        SDSS           : out   std_logic;
        SDCLK          : out   std_logic;
        SDMOSI         : out   std_logic;
        DIP            : in    std_logic_vector(1 downto 0);
        avr_RxD        : in    std_logic;
        avr_TxD        : out   std_logic;
        serial_RxD     : in    std_logic;
        serial_CTS     : in    std_logic;
        serial_TxD     : out   std_logic;
        serial_RTS     : out   std_logic
     );
end;

architecture behavioral of ElectronFpga_duo is

    signal clock_48        : std_logic;
    signal clock_24        : std_logic;
    signal clock_27        : std_logic;
    signal hard_reset_n    : std_logic;
    signal powerup_reset_n : std_logic;
    signal reset_counter   : std_logic_vector (9 downto 0);
    signal RAM_A           : std_logic_vector (18 downto 0);
    signal RAM_Din         : std_logic_vector (7 downto 0);
    signal RAM_Dout        : std_logic_vector (7 downto 0);
    signal RAM_nWE         : std_logic;
    signal RAM_nOE         : std_logic;
    signal RAM_nCS         : std_logic;
    signal rgb_red         : std_logic_vector (3 downto 0);
    signal rgb_green       : std_logic_vector (3 downto 0);
    signal rgb_blue        : std_logic_vector (3 downto 0);
    signal rgb_csync       : std_logic;
    signal vga_red         : std_logic_vector (3 downto 0);
    signal vga_green       : std_logic_vector (3 downto 0);
    signal vga_blue        : std_logic_vector (3 downto 0);
    signal vga_hsync       : std_logic;
    signal vga_vsync       : std_logic;
    signal joystick1_int   : std_logic_vector (4 downto 0);
    signal joystick2_int   : std_logic_vector (4 downto 0);

-----------------------------------------------
-- Bootstrap ROM Image from SPI FLASH into SRAM
-----------------------------------------------

    -- start address of user data in FLASH as obtained from bitmerge.py
    -- this is safely beyond the end of the bitstream
    constant user_address  : std_logic_vector(23 downto 0) := x"060000";

    -- lenth of user data in FLASH = 256KB (16x 16K ROM) images
    constant user_length   : std_logic_vector(23 downto 0) := x"040000";

    -- high when FLASH is being copied to SRAM, can be used by user as active high reset
    signal bootstrap_busy  : std_logic;

begin

    inst_pll1: entity work.pll1 port map(
        -- 32 MHz input clock
        CLKIN_IN => clk_32M00,
        -- the main system clock, and also the video clock in sRGB mode
        CLK0_OUT => clock_48,
        -- used as a 24.00MHz for the SAA5050 in Mode 7
        CLK1_OUT => clock_24,
        -- used as a output clock MIST scan doubler for the SAA5050 in Mode 7
        CLK2_OUT => open,
        -- used as a video clock when the ULA is in 60Hz VGA Mode
        CLK3_OUT => open
    );


    inst_dcm1 : entity work.dcm1 port map(
        CLKIN_IN          => clk_32M00,
        -- used as a video clock when the ULA is in 50Hz VGA Mode
        CLKFX_OUT         => clock_27
    );

    electron_core : entity work.ElectronFpga_core
    generic map (
        UseRomSlot9        => false,
        IncludeSRGB        => true,
        IncludeVGA         => true,
        IncludeHDMI        => false,
        IncludeICEDebugger => true,
        IncludeABRRegs     => true,
        IncludeSerial      => true,
        IncludeAMXMouse    => true,
        IncludeUserPort    => true,
        IncludeMRB         => true,
        IncludeSP64        => true,   -- depends on MRB
        IncludeJafaMode7   => true
    )
    port map (
        sys_clk           => clock_48, -- system clock
        clk_24M00         => clock_24, -- used for debugger
        clk_27M00         => clock_27, -- used for HDMI and VGA
        interlace         => DIP(0),

        hard_reset_n      => hard_reset_n,
        ps2_clk           => ps2_clk,
        ps2_data          => ps2_data,
        ps2_mouse_clk     => ps2_mouse_clk,
        ps2_mouse_data    => ps2_mouse_data,
        joystick1         => joystick1_int,
        joystick2         => joystick2_int,
        rgb_red           => rgb_red,
        rgb_green         => rgb_green,
        rgb_blue          => rgb_blue,
        rgb_csync         => rgb_csync,
        vga_red           => vga_red,
        vga_green         => vga_green,
        vga_blue          => vga_blue,
        vga_vsync         => vga_vsync,
        vga_hsync         => vga_hsync,
        audio_l           => audioL,
        audio_r           => audioR,
        ext_nOE           => RAM_nOE,
        ext_nWE           => RAM_nWE,
        ext_nCS           => RAM_nCS,
        ext_A             => RAM_A,
        ext_Dout          => RAM_Dout,
        ext_Din           => RAM_Din,
        SDMISO            => SDMISO,
        SDSS              => SDSS,
        SDCLK             => SDCLK,
        SDMOSI            => SDMOSI,
        caps_led          => LED(1),
        motor_led         => LED(2),
        cassette_in       => casIn,
        cassette_out      => casOut,
        avr_RxD           => avr_RxD,
        avr_TxD           => avr_TxD,
        serial_RxD        => serial_RxD,
        serial_CTS        => serial_CTS,
        serial_TxD        => serial_TxD,
        serial_RTS        => serial_RTS
        );

    joystick1_int <= JOYSTICK1(6) & JOYSTICK1(4) & JOYSTICK1(3) & JOYSTICK1(2) & JOYSTICK1(1);
    joystick2_int <= JOYSTICK2(6) & JOYSTICK2(4) & JOYSTICK2(3) & JOYSTICK2(2) & JOYSTICK2(1);

    red   <= rgb_red   when DIP(1) = '0' else vga_red;
    green <= rgb_green when DIP(1) = '0' else vga_green;
    blue  <= rgb_blue  when DIP(1) = '0' else vga_blue;
    hsync <= rgb_csync when DIP(1) = '0' else vga_hsync;
    vsync <= '1'       when DIP(1) = '0' else vga_vsync;

    LED(3) <= '0';
    LED(4) <= '0';

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    -- Generate a reliable power up reset, as ERST on the Papilio doesn't do this
    reset_gen : process(clock_48)
    begin
        if rising_edge(clock_48) then
            if (reset_counter(reset_counter'high) = '0') then
                reset_counter <= reset_counter + 1;
            end if;
            powerup_reset_n <= not ERST and reset_counter(reset_counter'high);
        end if;
    end process;

   -- extend the version seen by the core to hold the 6502 reset during bootstrap
   hard_reset_n <= powerup_reset_n and not bootstrap_busy;

--------------------------------------------------------
-- Papilio Duo Misc
--------------------------------------------------------

    -- Follow convention for keeping Arduino reset
    ARDUINO_RESET <= SW1;

--------------------------------------------------------
-- BOOTSTRAP SPI FLASH to SRAM
--------------------------------------------------------

    inst_bootstrap: entity work.bootstrap
    generic map (
        user_address   => user_address,
        user_length    => user_length
    )
    port map(
        clock           => clock_48,
        powerup_reset_n => powerup_reset_n,
        bootstrap_busy  => bootstrap_busy,
        RAM_nOE         => RAM_nOE,
        RAM_nWE         => RAM_nWE,
        RAM_nCS         => RAM_nCS,
        RAM_A           => RAM_A,
        RAM_Din         => RAM_Din,
        RAM_Dout        => RAM_Dout,
        SRAM_nOE        => SRAM_nOE,
        SRAM_nWE        => SRAM_nWE,
        SRAM_nCS        => SRAM_nCS,
        SRAM_A          => SRAM_A,
        SRAM_D          => SRAM_D,
        FLASH_CS        => FLASH_CS,
        FLASH_SI        => FLASH_SI,
        FLASH_CK        => FLASH_CK,
        FLASH_SO        => FLASH_SO
    );

end behavioral;

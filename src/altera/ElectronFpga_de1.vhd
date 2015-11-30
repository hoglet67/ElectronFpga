-- Acorn Electron for the Altera/Terasic DE1
--
-- Copright (c) 2015 David Banks
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
--
-- Altera/Terasic DE1 top-level
--
-- (c) 2015 David Banks

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

-- Generic top-level entity for Altera DE1 board
entity ElectronFpga_de1 is
port (
    -- Clocks
    CLOCK_24_0  :   in  std_logic;
    CLOCK_24_1  :   in  std_logic;
    CLOCK_27_0  :   in  std_logic;
    CLOCK_27_1  :   in  std_logic;
    CLOCK_50    :   in  std_logic;
    EXT_CLOCK   :   in  std_logic;

    -- Switches
    SW          :   in  std_logic_vector(9 downto 0);
    -- Buttons
    KEY         :   in  std_logic_vector(3 downto 0);

    -- 7 segment displays
    HEX0        :   out std_logic_vector(6 downto 0);
    HEX1        :   out std_logic_vector(6 downto 0);
    HEX2        :   out std_logic_vector(6 downto 0);
    HEX3        :   out std_logic_vector(6 downto 0);
    -- Red LEDs
    LEDR        :   out std_logic_vector(9 downto 0);
    -- Green LEDs
    LEDG        :   out std_logic_vector(7 downto 0);

    -- VGA
    VGA_R       :   out std_logic_vector(3 downto 0);
    VGA_G       :   out std_logic_vector(3 downto 0);
    VGA_B       :   out std_logic_vector(3 downto 0);
    VGA_HS      :   out std_logic;
    VGA_VS      :   out std_logic;

    -- Serial
    UART_RXD    :   in  std_logic;
    UART_TXD    :   out std_logic;

    -- PS/2 Keyboard
    PS2_CLK     :   in  std_logic;
    PS2_DAT     :   in  std_logic;

    -- I2C
    I2C_SCLK    :   inout   std_logic;
    I2C_SDAT    :   inout   std_logic;

    -- Audio
    AUD_XCK     :   out     std_logic;
    AUD_BCLK    :   out     std_logic;
    AUD_ADCLRCK :   out     std_logic;
    AUD_ADCDAT  :   in      std_logic;
    AUD_DACLRCK :   out     std_logic;
    AUD_DACDAT  :   out     std_logic;

    -- SRAM
    SRAM_ADDR   :   out     std_logic_vector(17 downto 0);
    SRAM_DQ     :   inout   std_logic_vector(15 downto 0);
    SRAM_CE_N   :   out     std_logic;
    SRAM_OE_N   :   out     std_logic;
    SRAM_WE_N   :   out     std_logic;
    SRAM_UB_N   :   out     std_logic;
    SRAM_LB_N   :   out     std_logic;

    -- SDRAM
    DRAM_ADDR   :   out     std_logic_vector(11 downto 0);
    DRAM_DQ     :   inout   std_logic_vector(15 downto 0);
    DRAM_BA_0   :   in      std_logic;
    DRAM_BA_1   :   in      std_logic;
    DRAM_CAS_N  :   in      std_logic;
    DRAM_CKE    :   in      std_logic;
    DRAM_CLK    :   in      std_logic;
    DRAM_CS_N   :   in      std_logic;
    DRAM_LDQM   :   in      std_logic;
    DRAM_RAS_N  :   in      std_logic;
    DRAM_UDQM   :   in      std_logic;
    DRAM_WE_N   :   in      std_logic;

    -- Flash
    FL_ADDR     :   out     std_logic_vector(21 downto 0);
    FL_DQ       :   in      std_logic_vector(7 downto 0);
    FL_RST_N    :   out     std_logic;
    FL_OE_N     :   out     std_logic;
    FL_WE_N     :   out     std_logic;
    FL_CE_N     :   out     std_logic;

    -- SD card (SPI mode)
    SD_nCS      :   out     std_logic;
    SD_MOSI     :   out     std_logic;
    SD_SCLK     :   out     std_logic;
    SD_MISO     :   in      std_logic;

    -- GPIO
    GPIO_0      :   inout   std_logic_vector(35 downto 0);
    GPIO_1      :   inout   std_logic_vector(35 downto 0)
    );
end entity;

architecture rtl of ElectronFpga_de1 is


-------------
-- Signals
-------------

signal clock_16         : std_logic;
signal clock_24         : std_logic;
signal clock_32         : std_logic;
signal clock_33         : std_logic;
signal clock_40         : std_logic;

signal i2s_lrclk        : std_logic;
signal audio_l          : std_logic;
signal audio_r          : std_logic;
signal hard_reset_n     : std_logic;

signal pll_reset        : std_logic;
signal pll1_locked      : std_logic;
signal pll2_locked      : std_logic;

signal motor_led        : std_logic;
signal caps_led         : std_logic;

signal pcm_inl          : std_logic_vector(15 downto 0);
signal pcm_inr          : std_logic_vector(15 downto 0);
signal pcm_outl         : std_logic_vector(15 downto 0);
signal pcm_outr         : std_logic_vector(15 downto 0);
signal pcm_mono         : std_logic_vector(8 downto 0);
signal pcm_sign         : std_logic;
signal pcm_mag          : std_logic_vector(7 downto 0);

signal ext_A            : std_logic_vector (18 downto 0);
signal ext_Din          : std_logic_vector (7 downto 0);
signal ext_Dout         : std_logic_vector (7 downto 0);
signal ext_nCS          : std_logic;
signal ext_nWE          : std_logic;
signal ext_nOE          : std_logic;

signal is_done          : std_logic;
signal is_error         : std_logic;

signal cpu_addr         : std_logic_vector (15 downto 0);

signal cas_monitor      : std_logic;
signal cas_in           : std_logic;
signal cas_out           : std_logic; -- currently not used

function hex_to_seven_seg(hex: std_logic_vector(3 downto 0))
        return std_logic_vector
    is begin
        case hex is
            --                   abcdefg
            when x"0" => return "0111111";
            when x"1" => return "0000110";
            when x"2" => return "1011011";
            when x"3" => return "1001111";
            when x"4" => return "1100110";
            when x"5" => return "1101101";
            when x"6" => return "1111101";
            when x"7" => return "0000111";
            when x"8" => return "1111111";
            when x"9" => return "1101111";
            when x"a" => return "1110111";
            when x"b" => return "1111100";
            when x"c" => return "0111001";
            when x"d" => return "1011110";
            when x"e" => return "1111001";
            when x"f" => return "1110001";
            when others => return "0000000";
        end case;
    end;

begin

--------------------------------------------------------
-- Clock Generation
--------------------------------------------------------

    pll1: entity work.pll1
    port map (
        areset         => pll_reset,
        inclk0         => CLOCK_24_0,
        c0             => clock_16,
        c1             => clock_32,
        c2             => clock_40,
        locked         => pll1_locked
    );

    pll2: entity work.pll2
    port map (
        areset         => pll_reset,
        inclk0         => CLOCK_50,
        c0             => clock_33,
        locked         => pll2_locked
    );

    clock_24 <= CLOCK_24_0;

--------------------------------------------------------
-- Electron Core
--------------------------------------------------------


    electron_core : entity work.ElectronFpga_core
    generic map (
        IncludeICEDebugger => false,
        IncludeABRRegs     => true,
        IncludeJafaMode7   => true
    )
    port map (
        clk_16M00         => clock_16,
        clk_24M00         => clock_24,
        clk_32M00         => clock_32,
        clk_33M33         => clock_33,
        clk_40M00         => clock_40,
        hard_reset_n      => hard_reset_n,
        ps2_clk           => PS2_CLK,
        ps2_data          => PS2_DAT,
        video_red         => VGA_R,
        video_green       => VGA_G,
        video_blue        => VGA_B,
        video_vsync       => VGA_VS,
        video_hsync       => VGA_HS,
        audio_l           => audio_l,
        audio_r           => audio_r,
        ext_nOE           => ext_nOE,
        ext_nWE           => ext_nWE,
        ext_nCS           => ext_nCS,
        ext_A             => ext_A,
        ext_Dout          => ext_Dout,
        ext_Din           => ext_Din,
        SDMISO            => SD_MISO,
        SDSS              => SD_nCS,
        SDCLK             => SD_SCLK,
        SDMOSI            => SD_MOSI,
        caps_led          => caps_led,
        motor_led         => motor_led,
        cassette_in       => cas_in,
        cassette_out      => cas_out,
        vid_mode          => SW(8 downto 7),
        test              => open,
        avr_RxD           => UART_RXD,
        avr_TxD           => UART_TXD,
        cpu_addr          => cpu_addr
    );

--------------------------------------------------------
-- Power Up Reset Generation
--------------------------------------------------------

    -- Asynchronous reset
    -- PLL is reset by external reset switch
    pll_reset <= not KEY(0);

    hard_reset_n <= not (pll_reset or not pll1_locked or not pll2_locked);

--------------------------------------------------------
-- Audio DACs
--------------------------------------------------------

    -- implement tape monitoring controlled by the motor and SW1
	 cas_monitor <= motor_led and SW(0);
	 
    pcm_outl <= "0" & audio_l & "00000000000000" when cas_monitor <= '0' else pcm_inl;
    pcm_outr <= "0" & audio_r & "00000000000000" when cas_monitor <= '0' else pcm_inr;
                
    i2s : entity work.i2s_intf
    port map (
        CLK         => clock_32,
        nRESET      => hard_reset_n,
        PCM_INL     => pcm_inl,
        PCM_INR     => pcm_inr,
        PCM_OUTL    => pcm_outl,
        PCM_OUTR    => pcm_outr,
        I2S_MCLK    => AUD_XCK,
        I2S_LRCLK   => i2s_lrclk,
        I2S_BCLK    => AUD_BCLK,
        I2S_DOUT    => AUD_DACDAT,
        I2S_DIN     => AUD_ADCDAT
    );
    AUD_DACLRCK <= i2s_lrclk;
    AUD_ADCLRCK <= i2s_lrclk;

    i2c : entity work.i2c_loader
    generic map (
        log2_divider => 7
    )
    port map (
        CLK         => clock_32,
        nRESET      => hard_reset_n,
        I2C_SCL     => I2C_SCLK,
        I2C_SDA     => I2C_SDAT,
        IS_DONE     => is_done,
        IS_ERROR    => is_error
    );
    
--------------------------------------------------------
-- Casette Input (from Line In)
--------------------------------------------------------

    -- generate an 9 bit mono audio signal
    pcm_mono <= (pcm_INL(15) & pcm_INL(15 downto 8)) + (pcm_INR(15) & pcm_INR(15 downto 8));

    -- convert to sign and 8-bit magnitude
    pcm_sign <= pcm_mono(8);
    pcm_mag  <= pcm_mono(7 downto 0) when pcm_mono(8) = '0' else (x"00" - pcm_mono(7 downto 0));

    -- the casette input is driven from the sign of the mono signal
    cas_in   <= pcm_sign;

--------------------------------------------------------
-- LEDs
--------------------------------------------------------

    -- Red LEDs
    LEDR(0)          <= caps_led;
    LEDR(1)          <= motor_led;
    LEDR(3 downto 2) <= (others => '0');
    LEDR(4)          <= is_error;
    LEDR(5)          <= not is_done;
    LEDR(9 downto 6) <= (others => '0');

    -- Green LEDs used as a simple VU meter for the tape input level
    -- driven from the magnitude of the mono line-in signal. Reversing
    -- the bits gives a more natural left-to-right appearance.
    LEDG(0) <= pcm_mag(7) when motor_led = '1' else '0';
    LEDG(1) <= pcm_mag(6) when motor_led = '1' else '0';
    LEDG(2) <= pcm_mag(5) when motor_led = '1' else '0';
    LEDG(3) <= pcm_mag(4) when motor_led = '1' else '0';
    LEDG(4) <= pcm_mag(3) when motor_led = '1' else '0';
    LEDG(5) <= pcm_mag(2) when motor_led = '1' else '0';
    LEDG(6) <= pcm_mag(1) when motor_led = '1' else '0';
    LEDG(7) <= pcm_mag(0) when motor_led = '1' else '0';

    -- HEX Displays (active low) show current processor address
    HEX3 <= hex_to_seven_seg(cpu_addr(15 downto 12)) xor "1111111";
    HEX2 <= hex_to_seven_seg(cpu_addr(11 downto  8)) xor "1111111";
    HEX1 <= hex_to_seven_seg(cpu_addr( 7 downto  4)) xor "1111111";
    HEX0 <= hex_to_seven_seg(cpu_addr( 3 downto  0)) xor "1111111";

--------------------------------------------------------
-- Map external memory bus to SRAM/FLASH
--------------------------------------------------------

    -- 4MB FLASH Layout
    -- 0x000000-0x05FFFF = BBC ROMs
    -- 0x060000-0x07FFFF = Unused
    -- 0x080000-0x0BFFFF = Electron ROMs
    -- 0x0C0000-0x3FFFFF - Unused

    -- ext_a(18) selects between FLASH and SRAM
    -- 0x00000-0x3FFFF -> FLASH 0x080000-0x0BFFFF
    -- 0x40000-0x7FFFF -> SRAM
    ext_Dout  <= SRAM_DQ(7 downto 0) when ext_a(18) = '1' else FL_DQ;

    -- FLASH control signals
    FL_RST_N  <= hard_reset_n;
    FL_CE_N   <= ext_nCS;
    FL_OE_N   <= ext_nOE;
    FL_WE_N   <= '1';

    -- Flash address change every at most every 16 cycles (2MHz)
    -- 001 maps to FLASH address 0x080000
    FL_ADDR   <= "001" & ext_a;

    -- SRAM control signals
    SRAM_UB_N <= '1';
    SRAM_LB_N <= '0';
    SRAM_CE_N <= ext_nCS;
    SRAM_OE_N <= ext_nOE;

    -- Gate the WE with clock to provide more address/data hold time
    SRAM_WE_N <= ext_nWE or not clock_16;

    SRAM_ADDR <= ext_a(17 downto 0);
    SRAM_DQ(15 downto 8) <= (others => 'Z');
    SRAM_DQ(7 downto 0) <= ext_Din when ext_nWE = '0' else (others => 'Z');

    -- Unused outputs
    DRAM_ADDR <= (others => 'Z');
    DRAM_DQ   <= (others => 'Z');

end architecture;

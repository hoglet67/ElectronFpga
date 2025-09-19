--------------------------------------------------------------------------------
-- Copyright (c) 2025 David Banks
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : ElectronULAEnhanced.vhd
-- /___/   /\     Timestamp : 21/08/2025
-- \   \  /  \
--  \___\/\___\
--
--
-- This module extends the basic Electron ULA with the following features
--    VGA output (including scan doubling)
--    HDMI  output (including scan doubling)
--    Jafa Mode 7
--    Memory Mapped SPI port for MMFS
--
--Design Name: ElectronULAEnhanced

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ElectronULAEnhanced is
    generic (
        IncludeMMC       : boolean := true;
        Include32KRAM    : boolean := true;
        IncludeSRGB      : boolean := true;
        IncludeVGA       : boolean := true;
        IncludeHDMI      : boolean := true;
        IncludeJafaMode7 : boolean := false;
        LimitROMSpeed    : boolean := true;   -- true to limit ROM speed to 2MHz
        LimitIOSpeed     : boolean := true;   -- true to limit IO speed to 1MHz
        TTxtClockSpeed   : integer := 24;     -- frequency of the ttxt_clk clock
        IncludeTTxtROM   : boolean := true    -- false if the SAA5050 character ROM needs loading
        );
    port (
        -- System clock: should be 16MHz
        sys_clk        : in  std_logic;
        sys_clken      : in  std_logic;

        -- Power on reset
        hard_reset_n   : in std_logic := '1';

        -- Teletext clock
        ttxt_clk       : in  std_logic := '0';

        -- CPU Interface
        addr           : in  std_logic_vector(15 downto 0);
        data_in        : in  std_logic_vector(7 downto 0);  -- Async, but stable on rising edge of cpu_clken
        data_out       : out std_logic_vector(7 downto 0);
        data_en        : out std_logic;
        R_W_n          : in  std_logic;
        RST_n          : in  std_logic;
        IRQ_n          : out std_logic;
        NMI_n          : in  std_logic;

        -- Rom Enable
        ROM_n          : out std_logic;

        -- Optional SCART/RGB Video (from the basic ULA)
        interlace      : in  std_logic := '1';
        rgb_red        : out std_logic_vector(3 downto 0);
        rgb_green      : out std_logic_vector(3 downto 0);
        rgb_blue       : out std_logic_vector(3 downto 0);
        rgb_csync      : out std_logic;

        -- Optional VGA Video (uses HDMI pixel clock)
        vga_red        : out std_logic_vector(3 downto 0);
        vga_green      : out std_logic_vector(3 downto 0);
        vga_blue       : out std_logic_vector(3 downto 0);
        vga_vsync      : out std_logic;
        vga_hsync      : out std_logic;

        -- Optional HDMI Video
        hdmi_clk       : in    std_logic;
        hdmi_audio_en  : in    std_logic := '0';
        tmds_r         : out   std_logic_vector(9 downto 0);
        tmds_g         : out   std_logic_vector(9 downto 0);
        tmds_b         : out   std_logic_vector(9 downto 0);

        -- Audio
        sound          : out std_logic;

        -- Keyboard
        kbd            : in  std_logic_vector(3 downto 0);

        -- SD Card
        SDMISO         : in  std_logic;
        SDSS           : out std_logic;
        SDCLK          : out std_logic;
        SDMOSI         : out std_logic;

        -- Casette
        casIn          : in  std_logic;
        casOut         : out std_logic;

        -- MISC
        caps           : out std_logic;
        motor          : out std_logic;

        -- 4-bit ROM latch
        rom_latch      : out std_logic_vector(3 downto 0);

        -- Clock Generation
        cpu_clken_out  : out std_logic;
        mhz1_clken_out : out std_logic;
        mhz4_clken_out : out std_logic;
        cpu_clk_out    : out std_logic;
        turbo          : in std_logic_vector(1 downto 0);
        turbo_out      : out std_logic_vector(1 downto 0) := "01";

        -- SAA5050 character ROM loading
        char_rom_we   : in std_logic := '0';
        char_rom_addr : in std_logic_vector(10 downto 0) := (others => '0');
        char_rom_data : in std_logic_vector(7 downto 0) := (others => '0')
        );
end;

architecture behavioral of ElectronULAEnhanced is

    -- Electon ULA SD Video
    signal ula_red         : std_logic;
    signal ula_green       : std_logic;
    signal ula_blue        : std_logic;
    signal ula_vsync_n     : std_logic;
    signal ula_hsync_n     : std_logic;
    signal ula_csync_n     : std_logic;
    signal ula_field       : std_logic;
    signal sound_int       : std_logic;
    signal ula_den         : std_logic;
    signal ula_do          : std_logic_vector(7 downto 0);
    signal cpu_clken       : std_logic;
    signal mhz1_clken      : std_logic;
    signal mhz4_clken      : std_logic;
    signal cpu_clk         : std_logic;

    -- Jafa Mode 7 SD Video
    signal ttxt_clken      : std_logic;
    signal jafa_do         : std_logic_vector(7 downto 0);
    signal jafa_den        : std_logic;
    signal jafa_red        : std_logic;
    signal jafa_red_even   : std_logic;
    signal jafa_red_odd    : std_logic;
    signal jafa_green      : std_logic;
    signal jafa_green_even : std_logic;
    signal jafa_green_odd  : std_logic;
    signal jafa_blue       : std_logic;
    signal jafa_blue_even  : std_logic;
    signal jafa_blue_odd   : std_logic;
    signal jafa_csync      : std_logic;
    signal jafa_hsync      : std_logic;
    signal jafa_vsync      : std_logic;
    signal jafa_field      : std_logic;
    signal mode7_enable    : std_logic;

    -- HD Video (after scan doubler)
    signal hd_red          : std_logic;
    signal hd_green        : std_logic;
    signal hd_blue         : std_logic;
    signal hd_vsync        : std_logic;
    signal hd_hsync        : std_logic;

    -- SPI SD Card
    signal spisd_do        : std_logic_vector(7 downto 0);
    signal spisd_enable    : std_logic;

    -- Constants to make if/generate easier
    constant IncludeHD     : boolean := IncludeVGA or IncludeHDMI;


begin

--------------------------------------------------------
-- ElectronULA
--------------------------------------------------------

    inst_ula : entity work.ElectronULA
        generic map (
            Include32KRAM => Include32KRAM,
            LimitROMSpeed => LimitROMSpeed,
            LimitIOSpeed  => LimitIOSpeed
            )
        port map (
            -- System clock: should be 16MHz
            sys_clk   => sys_clk,
            sys_clken => sys_clken,
            -- Power on reset
            hard_reset_n => hard_reset_n,
            -- CPU Interface
            addr      => addr,
            data_in   => data_in,
            data_out  => ula_do,
            data_en   => ula_den,
            R_W_n     => R_W_n,
            RST_n     => RST_n,
            IRQ_n     => IRQ_n,
            NMI_n     => NMI_n,
            -- Rom Enable
            ROM_n     => ROM_n,
            -- RGB Video
            interlace => interlace,
            red       => ula_red,
            green     => ula_green,
            blue      => ula_blue,
            vsync     => ula_vsync_n,
            hsync     => ula_hsync_n,
            csync     => ula_csync_n,
            blank     => open,
            field     => ula_field,
            -- Audio
            sound     => sound_int,
            -- Keyboard
            kbd       => kbd,
            -- Casette
            casIn     => casIn,
            casOut    => casOut,
            -- MISC
            caps      => caps,
            motor     => motor,
            -- 4-bit ROM latch
            rom_latch => rom_latch,
            -- Clock Generation
            cpu_clken_out  => cpu_clken,
            mhz1_clken_out => mhz1_clken,
            mhz4_clken_out => mhz4_clken,
            cpu_clk_out    => cpu_clk,
            turbo          => turbo,
            turbo_out      => turbo_out
            );


    -- ULA Reads + RAM Reads + KBD Reads
    data_out <= ula_do     when ula_den = '1'                       else
                jafa_do    when jafa_den = '1' and IncludeJafaMode7 else
                spisd_do   when spisd_enable = '1' and IncludeMMC   else
                x"F1";

    data_en  <= '1'        when ula_den = '1'                        else
                '1'        when jafa_den = '1' and IncludeJafaMode7  else
                '1'        when spisd_enable = '1' and IncludeMMC    else
                '0';

--------------------------------------------------------
-- Optional MMC Filing System (Memory Mapped SPI)
--------------------------------------------------------

    MMCIncluded: if IncludeMMC generate

        spisd_enable  <= '1' when cpu_clken = '1' and addr = x"fc8c" else '0';

        Inst_SPI_Port: entity work.SPI_Port
            port map (
                nRST    => RST_n,
                clk     => sys_clk,
                clken   => sys_clken,  -- needs to be 16MHz or less (SPI clock is half this rate)
                enable  => spisd_enable,
                nwe     => R_W_n,
                datain  => data_in,
                dataout => spisd_do,
                SDMISO  => SDMISO,
                SDMOSI  => SDMOSI,
                SDSS    => SDSS,
                SDCLK   => SDCLK
                );

    end generate;

    MMCNotIncluded: if not IncludeMMC generate

        SDCLK    <= '1';
        SDMOSI   <= '1';
        SDSS     <= '1';
        spisd_do <= x"FE";

    end generate;

--------------------------------------------------------
-- Optional Standard Definition Jafa Mode 7
--------------------------------------------------------

    JafaIncluded: if IncludeJafaMode7 generate
        -- This gracefully handles passing zero in
        function f_log2 (x : natural) return natural is
            variable i : natural;
        begin
            i := 1;
            while (2**i < x) and i < 31 loop
                i := i + 1;
            end loop;
            return i;
        end function;

        function f_max_divider return natural is
        begin
            return TTxtClockSpeed / 12 - 1;
        end function;

        signal ttxt_divider   : unsigned(f_log2(f_max_divider) - 1 downto 0) := (others => '0');

    begin

        process(ttxt_clk)
        begin
            if rising_edge(ttxt_clk) then
                if ttxt_divider = to_unsigned(f_max_divider, ttxt_divider'length) then
                    ttxt_clken <= '1';
                    ttxt_divider <= (others => '0');
                else
                    ttxt_clken <= '0';
                    ttxt_divider <= ttxt_divider + 1;
                end if;
            end if;
        end process;

        jafa : entity work.JafaMode7
            generic map (
                IncludeTTxtROM => IncludeTTxtROM
                )
            port map (
                -- CPU interface
                sys_clk       => sys_clk,
                mhz1_clken    => mhz1_clken,
                cpu_clken     => cpu_clken,
                RST_n         => RST_n,
                R_W_n         => R_W_n,
                addr          => addr,
                data_in       => data_in,
                data_out      => jafa_do,
                data_en       => jafa_den,
                -- Teletext clock
                ttxt_clk      => ttxt_clk,
                ttxt_clken    => ttxt_clken,
                -- Video out
                mode7_enable  => mode7_enable,
                red           => jafa_red,
                green         => jafa_green,
                blue          => jafa_blue,
                vsync         => jafa_vsync,
                hsync         => jafa_hsync,
                csync         => jafa_csync,
                field         => jafa_field,
                red_even      => jafa_red_even,
                red_odd       => jafa_red_odd,
                green_even    => jafa_green_even,
                green_odd     => jafa_green_odd,
                blue_even     => jafa_blue_even,
                blue_odd      => jafa_blue_odd,
                -- SAA5050 character ROM loading
                char_rom_we   => char_rom_we,
                char_rom_addr => char_rom_addr,
                char_rom_data => char_rom_data
                );
    end generate;

--------------------------------------------------------
-- Scan Doubler for both Electron ULA and Mode 7
--------------------------------------------------------

    HDIncluded: if IncludeHD generate
        -- scan doubler inputs
        signal vid_clk       : std_logic;
        signal vid_clken     : std_logic;
        signal tmp_even_in   : std_logic_vector(2 downto 0);
        signal tmp_odd_in    : std_logic_vector(2 downto 0);
        signal tmp_hsync_in  : std_logic;
        signal tmp_vsync_in  : std_logic;
        -- scan doubler outputs
        signal tmp_rgb       : std_logic_vector(2 downto 0);
        signal tmp_rgb_out   : std_logic_vector(2 downto 0);
        signal tmp_hsync     : std_logic;
        signal tmp_vsync     : std_logic;
        signal bypass        : std_logic;
    begin

        vid_clk   <= sys_clk;
        vid_clken <= ttxt_clken when IncludeJafaMode7 and mode7_enable = '1' else sys_clken;

        tmp_even_in  <= jafa_red_even & jafa_green_even & jafa_blue_even when IncludeJafaMode7 and mode7_enable = '1' else
                        ula_red & ula_green & ula_blue;

        tmp_odd_in   <= jafa_red_odd & jafa_green_odd & jafa_blue_odd when IncludeJafaMode7 and mode7_enable = '1' else
                        ula_red & ula_green & ula_blue;

        tmp_hsync_in <= jafa_hsync when IncludeJafaMode7 and mode7_enable = '1' else not ula_hsync_n;
        tmp_vsync_in <= jafa_vsync when IncludeJafaMode7 and mode7_enable = '1' else not ula_vsync_n;

        inst_rgb2vga_scandoubler: entity work.rgb2vga_scandoubler
            generic map (
                WIDTH        => 3,
                VGA_CLK_MHZ  => 27
                )
            port map (
                mode         => mode7_enable,
                pal_clk      => vid_clk,
                pal_clken    => vid_clken,
                pal_rgb_even => tmp_even_in,
                pal_rgb_odd  => tmp_odd_in,
                pal_hsync    => tmp_hsync_in,
                pal_vsync    => tmp_vsync_in,
                vga_clk      => hdmi_clk,
                vga_clken    => '1',
                vga_rgb      => tmp_rgb,
                vga_hsync    => tmp_hsync,
                vga_vsync    => tmp_vsync
                );

        bypass <= not jafa_field when IncludeJafaMode7 and mode7_enable = '1' else not ula_field;

        inst_linedelay : entity work.linedelay
            generic map (
                WIDTH => 3,
                DEPTH => 864
                )
            port map (
                clock  => hdmi_clk,
                clken  => '1',
                bypass => bypass,
                din    => tmp_rgb,
                dout   => tmp_rgb_out
                );

        hd_red   <= tmp_rgb_out(2);
        hd_green <= tmp_rgb_out(1);
        hd_blue  <= tmp_rgb_out(0);
        hd_hsync <= tmp_hsync;
        hd_vsync <= tmp_vsync;

    end generate;

--------------------------------------------------------
-- HDMI Video Output
--------------------------------------------------------

    HDMIncluded: if IncludeHDMI generate
        signal hsync1          : std_logic;
        signal vsync1          : std_logic;
        signal hcnt            : unsigned(9 downto 0);
        signal vcnt            : unsigned(9 downto 0);
        signal vsize           : unsigned(9 downto 0);
        signal voffset         : unsigned(9 downto 0);
        signal blank           : std_logic;

        signal hdmi_red        : std_logic_vector(7 downto 0);
        signal hdmi_green      : std_logic_vector(7 downto 0);
        signal hdmi_blue       : std_logic_vector(7 downto 0);
        signal hdmi_hsync      : std_logic;
        signal hdmi_vsync      : std_logic;
        signal hdmi_blank      : std_logic;
        signal hdmi_aspect_169 : std_logic;
        signal hdmi_audio      : std_logic_vector (15 downto 0);

    begin

        -- Mode 0..6 we need to create a blanking signal to have a 720px wide image
        -- Mode 7 has it's own blanking to give a 540 wide image; we don't currently use that

        voffset <= to_unsigned( 39, 10) when hdmi_audio_en = '1' else to_unsigned( 55, 10);
        vsize   <= to_unsigned(576, 10) when hdmi_audio_en = '1' else to_unsigned(540, 10);
        blank   <= '1' when hcnt < 68 or hcnt >= 68 + 720 or vcnt < voffset or vcnt >= voffset + vsize else '0';
        hdmi_aspect_169 <= '1' when IncludeJafaMode7 and mode7_enable = '1' else '0';

        process(hdmi_clk)
        begin
            if rising_edge(hdmi_clk) then
                if sound_int = '1' then
                    hdmi_audio <= x"1000";
                else
                    hdmi_audio <= x"F000";
                end if;
                hsync1 <= hd_hsync;
                if hsync1 = '1' and hd_hsync = '0' then
                    hcnt <= (others => '0');
                    vsync1 <= hd_vsync;
                    if vsync1 = '1' and hd_vsync = '0' then
                        vcnt <= (others => '0');
                    else
                        vcnt <= vcnt + 1;
                    end if;
                else
                    hcnt <= hcnt + 1;
                end if;
                if blank = '1' then
                    hdmi_blank <= '1';
                    hdmi_red   <= (others => '0');
                    hdmi_green <= (others => '0');
                    hdmi_blue  <= (others => '0');
                else
                    hdmi_blank <= '0';
                    hdmi_red   <= (others => hd_red);
                    hdmi_green <= (others => hd_green);
                    hdmi_blue  <= (others => hd_blue);
                end if;
                if hcnt >= 732 + 68 then -- 800
                    hdmi_hsync <= '0';
                    if vcnt >= 581 + 39 then -- 620
                        hdmi_vsync <= '0';
                    else
                        hdmi_vsync <= '1';
                    end if;
                else
                    hdmi_hsync <= '1';
                end if;
            end if;
        end process;

        inst_hdmi: entity work.hdmi
            generic map (
                FREQ => 27000000,  -- pixel clock frequency
                FS   => 48000,     -- audio sample rate - should be 32000, 44100 or 48000
                CTS  => 27000,     -- CTS = Freq(pixclk) * N / (128 * Fs)
                N    => 6144       -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
                --FS   => 32000,   -- audio sample rate - should be 32000, 44100 or 48000
                --CTS  => 27000,   -- CTS = Freq(pixclk) * N / (128 * Fs)
                --N    => 4096     -- N = 128 * Fs /1000,  128 * Fs /1500 <= N <= 128 * Fs /300
                )
            port map (
                -- clocks
                I_CLK_PIXEL      => hdmi_clk,
                -- components
                I_R              => hdmi_red,
                I_G              => hdmi_green,
                I_B              => hdmi_blue,
                I_BLANK          => hdmi_blank,
                I_HSYNC          => hdmi_hsync,
                I_VSYNC          => hdmi_vsync,
                I_ASPECT_169     => hdmi_aspect_169,
                -- PCM audio
                I_AUDIO_ENABLE   => hdmi_audio_en,
                I_AUDIO_PCM_L    => hdmi_audio,
                I_AUDIO_PCM_R    => hdmi_audio,
                -- TMDS parallel pixel synchronous outputs (serialize LSB first)
                O_RED            => tmds_r,
                O_GREEN          => tmds_g,
                O_BLUE           => tmds_b
                );

    end generate;

    HDMINotIncluded: if not IncludeHDMI generate
        tmds_r <= (others => '0');
        tmds_g <= (others => '0');
        tmds_b <= (others => '0');
    end generate;

--------------------------------------------------------
-- VGA Video output
--------------------------------------------------------

    VGAIncluded : if IncludeVGA generate
        vga_red   <= (others => hd_red);
        vga_green <= (others => hd_green);
        vga_blue  <= (others => hd_blue);
        vga_vsync <= hd_vsync;
        vga_hsync <= hd_hsync;
    end generate;

    VGANotIncluded : if not IncludeVGA generate
        vga_red   <= (others => '0');
        vga_green <= (others => '0');
        vga_blue  <= (others => '0');
        vga_hsync <= '0';
        vga_vsync <= '0';
    end generate;

--------------------------------------------------------
-- SCART/RGB Video output
--------------------------------------------------------

    SRGBIncluded : if IncludeSRGB generate
        rgb_red   <= (others => jafa_red)   when IncludeJafaMode7 and mode7_enable = '1' else
                     (others => ula_red);
        rgb_green <= (others => jafa_green) when IncludeJafaMode7 and mode7_enable = '1' else
                     (others => ula_green);
        rgb_blue  <= (others => jafa_blue)  when IncludeJafaMode7 and mode7_enable = '1' else
                     (others => ula_blue);
        rgb_csync <= not jafa_csync         when IncludeJafaMode7 and mode7_enable = '1' else
                     ula_csync_n;
    end generate;

    SRGBNotIncluded : if not IncludeSRGB generate
        rgb_red   <= (others => '0');
        rgb_green <= (others => '0');
        rgb_blue  <= (others => '0');
        rgb_csync <= '0';
    end generate;

--------------------------------------------------------
-- Clock / Clock Enable Outputs
--------------------------------------------------------

    sound          <= sound_int;
    cpu_clken_out  <= cpu_clken;
    mhz1_clken_out <= mhz1_clken;
    mhz4_clken_out <= mhz4_clken;
    cpu_clk_out    <= cpu_clk;


end behavioral;

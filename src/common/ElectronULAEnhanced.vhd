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
        clk_16M00      : in  std_logic;

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
        char_rom_addr : in std_logic_vector(11 downto 0) := (others => '0');
        char_rom_data : in std_logic_vector(7 downto 0) := (others => '0')
        );
end;

architecture behavioral of ElectronULAEnhanced is

    -- Electon ULA SD Video
    signal sd_red          : std_logic;
    signal sd_green        : std_logic;
    signal sd_blue         : std_logic;
    signal sd_vsync        : std_logic;
    signal sd_hsync        : std_logic;
    signal sd_csync        : std_logic;
    signal sd_blank        : std_logic;
    signal sd_field        : std_logic;
    signal sound_int       : std_logic;

    -- Electron ULA HS Video (after scan doubler)
    signal hd_red          : std_logic;
    signal hd_green        : std_logic;
    signal hd_blue         : std_logic;
    signal hd_vsync        : std_logic;
    signal hd_hsync        : std_logic;
    signal hd_blank        : std_logic;

    signal ula_den         : std_logic;
    signal ula_do          : std_logic_vector(7 downto 0);
    signal cpu_clken       : std_logic;
    signal mhz1_clken      : std_logic;
    signal mhz4_clken      : std_logic;
    signal cpu_clk         : std_logic;

    -- Jafa SD
    signal jafa_sd_do      : std_logic_vector(7 downto 0);
    signal jafa_sd_den     : std_logic;
    signal jafa_sd_red     : std_logic;
    signal jafa_sd_green   : std_logic;
    signal jafa_sd_blue    : std_logic;
    signal jafa_sd_csync   : std_logic;
    signal mode7_enable_sd : std_logic;

    -- Jafa HD
    signal jafa_hd_do      : std_logic_vector(7 downto 0);
    signal jafa_hd_den     : std_logic;
    signal jafa_hd_red     : std_logic;
    signal jafa_hd_green   : std_logic;
    signal jafa_hd_blue    : std_logic;
    signal jafa_hd_hsync   : std_logic;
    signal jafa_hd_vsync   : std_logic;
    signal jafa_hd_blank   : std_logic;
    signal mode7_enable_hd : std_logic;

    -- SPI SD Card
    signal spisd_do        : std_logic_vector(7 downto 0);
    signal spisd_enable    : std_logic;

    -- Constants to make if/generate easier
    constant IncludeHD     : boolean := IncludeVGA or IncludeHDMI;
    constant IncludeJafaSD : boolean := IncludeJafaMode7 and IncludeSRGB;
    constant IncludeJafaHD : boolean := IncludeJafaMode7 and (IncludeVGA or IncludeHDMI);

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
            clk_16M00 => clk_16M00,
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
            red       => sd_red,
            green     => sd_green,
            blue      => sd_blue,
            vsync     => sd_vsync,
            hsync     => sd_hsync,
            csync     => sd_csync,
            blank     => sd_blank,
            field     => sd_field,
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
                jafa_sd_do when jafa_sd_den = '1' and IncludeJafaSD else
                jafa_hd_do when jafa_hd_den = '1' and IncludeJafaHD else
                spisd_do   when spisd_enable = '1' and IncludeMMC   else
                x"F1";

    data_en  <= '1'        when ula_den = '1'                        else
                '1'        when jafa_sd_den = '1' and IncludeJafaSD  else
                '1'        when jafa_hd_den = '1' and IncludeJafaHD  else
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
                clk     => clk_16M00,
                clken   => '1',  -- needs to be 16MHz or less (SPI clock is half this rate)
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

    JafaSDIncluded: if IncludeJafaSD generate

        jafa_sd : entity work.JafaMode7
            generic map (
                ScanDoubled    => false,
                IncludeTTxtROM => IncludeTTxtROM
                )
            port map (
                -- CPU interface
                clk_16M00     => clk_16M00,
                cpu_clken     => cpu_clken,
                RST_n         => RST_n,
                R_W_n         => R_W_n,
                addr          => addr,
                data_in       => data_in,
                data_out      => jafa_sd_do,
                data_en       => jafa_sd_den,
                -- Teletext clock
                ttxt_clk      => ttxt_clk,
                -- Video out
                mode7_enable  => mode7_enable_sd,
                red           => jafa_sd_red,
                green         => jafa_sd_green,
                blue          => jafa_sd_blue,
                vsync         => open,
                hsync         => open,
                csync         => jafa_sd_csync,
                blank         => open,
                -- SAA5050 character ROM loading
                char_rom_we   => char_rom_we,
                char_rom_addr => char_rom_addr,
                char_rom_data => char_rom_data
                );
    end generate;

--------------------------------------------------------
-- Optional High Definition Jafa Mode 7
--------------------------------------------------------

    JafaHDIncluded: if IncludeJafaHD generate

        jafa_hd : entity work.JafaMode7
            generic map (
                ScanDoubled    => true,
                TTxtClockSpeed => TTxtClockSpeed,
                IncludeTTxtROM => IncludeTTxtROM
                )
            port map (
                -- CPU interface
                clk_16M00     => clk_16M00,
                cpu_clken     => cpu_clken,
                RST_n         => RST_n,
                R_W_n         => R_W_n,
                addr          => addr,
                data_in       => data_in,
                data_out      => jafa_hd_do,
                data_en       => jafa_hd_den,
                -- Teletext clock
                ttxt_clk      => ttxt_clk,
                -- Video out
                hd_clk        => hdmi_clk,
                mode7_enable  => mode7_enable_hd,
                red           => jafa_hd_red,
                green         => jafa_hd_green,
                blue          => jafa_hd_blue,
                vsync         => jafa_hd_vsync,
                hsync         => jafa_hd_hsync,
                csync         => open,
                blank         => jafa_hd_blank,
                -- SAA5050 character ROM loading
                char_rom_we   => char_rom_we,
                char_rom_addr => char_rom_addr,
                char_rom_data => char_rom_data
                );
    end generate;

--------------------------------------------------------
-- Scan Doubler for Electron ULA
--------------------------------------------------------

    HDIncluded: if IncludeHD generate
        signal rgb_in     : std_logic_vector(2 downto 0);
        signal rgb_tmp    : std_logic_vector(2 downto 0);
        signal rgb_out    : std_logic_vector(2 downto 0);
        signal hsync_tmp  : std_logic;
        signal vsync_tmp  : std_logic;
        signal blank_tmp  : std_logic;
        signal bypass     : std_logic;
    begin
        rgb_in <= sd_red & sd_green & sd_blue;

        inst_rgb2vga_scandoubler: entity work.rgb2vga_scandoubler
            generic map (
                WIDTH => 3
                )
            port map (
                clock => clk_16M00,
                clken => '1',
                clk25 => hdmi_clk,
                mode => '0',
                rgbi_in => rgb_in,
                hSync_in => sd_hsync,
                vSync_in => sd_vsync,
                rgbi_out => rgb_tmp,
                hSync_out => hsync_tmp,
                vSync_out => vsync_tmp
                );

        bypass <= not sd_field;

        inst_linedelay : entity work.linedelay
            generic map (
                WIDTH => 3,
                DEPTH => 864
                )
            port map (
                clock  => hdmi_clk,
                clken  => '1',
                bypass => bypass,
                din    => rgb_tmp,
                dout   => rgb_out
                );

        hd_red   <= jafa_hd_red   when IncludeJafaMode7 and mode7_enable_hd = '1' else rgb_out(2);
        hd_green <= jafa_hd_green when IncludeJafaMode7 and mode7_enable_hd = '1' else rgb_out(1);
        hd_blue  <= jafa_hd_blue  when IncludeJafaMode7 and mode7_enable_hd = '1' else rgb_out(0);
        hd_hsync <= jafa_hd_hsync when IncludeJafaMode7 and mode7_enable_hd = '1' else hsync_tmp;
        hd_vsync <= jafa_hd_vsync when IncludeJafaMode7 and mode7_enable_hd = '1' else vsync_tmp;
        hd_blank <= jafa_hd_blank when IncludeJafaMode7 and mode7_enable_hd = '1' else '0';  -- Unused when video comes from ULA

    end generate;

--------------------------------------------------------
-- HDMI Video Output
--------------------------------------------------------

    HDMIncluded: if IncludeHDMI generate
        signal hsync1     : std_logic;
        signal vsync1     : std_logic;
        signal hcnt       : unsigned(9 downto 0);
        signal vcnt       : unsigned(9 downto 0);
        signal vsize      : unsigned(9 downto 0);
        signal voffset    : unsigned(9 downto 0);

        signal blank      : std_logic;
        signal hdmi_red   : std_logic_vector(7 downto 0);
        signal hdmi_green : std_logic_vector(7 downto 0);
        signal hdmi_blue  : std_logic_vector(7 downto 0);
        signal hdmi_hsync : std_logic;
        signal hdmi_vsync : std_logic;
        signal hdmi_blank : std_logic;
        signal hdmi_audio : std_logic_vector (15 downto 0);

    begin

        -- Mode 0..6 we need to create a blanking signal to have a 720px wide image
        -- Mode 7 has it's own blanking to give a 540 wide image

        voffset <= to_unsigned( 39, 10) when hdmi_audio_en = '1' else to_unsigned( 55, 10);
        vsize   <= to_unsigned(576, 10) when hdmi_audio_en = '1' else to_unsigned(540, 10);
        blank   <= hd_blank when IncludeJafaMode7 and mode7_enable_hd = '1' else
                   '1'      when hcnt < 68 or hcnt >= 68 + 720 or vcnt < voffset or vcnt >= voffset + vsize else
                   '0';

        process(hdmi_clk)
        begin
            if rising_edge(hdmi_clk) then
                if sound_int = '1' then
                    hdmi_audio <= x"1000";
                else
                    hdmi_audio <= x"F000";
                end if;
                hsync1 <= hd_hsync;
                if hsync1 = '0' and hd_hsync = '1' then
                    hcnt <= (others => '0');
                    vsync1 <= hd_vsync;
                    if vsync1 = '0' and hd_vsync = '1' then
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
                I_ASPECT_169     => '0',
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
        rgb_red   <= (others => jafa_sd_red)   when IncludeJafaSD and mode7_enable_sd = '1' else
                     (others => sd_red);
        rgb_green <= (others => jafa_sd_green) when IncludeJafaSD and mode7_enable_sd = '1' else
                     (others => sd_green);
        rgb_blue  <= (others => jafa_sd_blue)  when IncludeJafaSD and mode7_enable_sd = '1' else
                     (others => sd_blue);
        rgb_csync <= jafa_sd_csync             when IncludeJafaSD and mode7_enable_sd = '1' else
                     sd_csync;
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

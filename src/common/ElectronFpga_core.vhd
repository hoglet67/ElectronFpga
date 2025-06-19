--------------------------------------------------------------------------------
-- Copyright (c) 2015 David Banks
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : ElectronFpga_core.vhd
-- /___/   /\     Timestamp : 28/07/2015
-- \   \  /  \
--  \___\/\___\
--
--Design Name: ElectronFpga_core

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ElectronFpga_core is
    generic (
        IncludeHDMI        : boolean := false;
        IncludeICEDebugger : boolean := false;
        IncludeABRRegs     : boolean := false;
        IncludeJafaMode7   : boolean := false
    );
    port (
        -- Clocks
        clk_16M00      : in  std_logic;
        clk_24M00      : in  std_logic; -- for Jafa Mode7
        clk_32M00      : in  std_logic; -- for Jafa Mode7
        clk_33M33      : in  std_logic;
        clk_40M00      : in  std_logic;
        clk_27M00      : in  std_logic := '0';

        -- Hard reset (active low)
        hard_reset_n   : in  std_logic;

        -- Keyboard
        ps2_clk        : in  std_logic;
        ps2_data       : in  std_logic;

        -- VGA Video
        video_red      : out std_logic_vector (3 downto 0);
        video_green    : out std_logic_vector (3 downto 0);
        video_blue     : out std_logic_vector (3 downto 0);
        video_vsync    : out std_logic;
        video_hsync    : out std_logic;

        -- HDMI Video
        hdmi_audio_en  : in    std_logic := '0';
        tmds_r         : out   std_logic_vector(9 downto 0);
        tmds_g         : out   std_logic_vector(9 downto 0);
        tmds_b         : out   std_logic_vector(9 downto 0);

        -- Audio
        audio_l        : out std_logic;
        audio_r        : out std_logic;

        -- External memory (e.g. SRAM and/or FLASH)
        -- 512KB logical address space
        ext_nOE        : out std_logic;
        ext_nWE        : out std_logic;
        ext_nCS        : out std_logic;
        ext_A          : out std_logic_vector (18 downto 0);
        ext_Dout       : in  std_logic_vector (7 downto 0);
        ext_Din        : out std_logic_vector (7 downto 0);

        -- SD Card
        SDMISO         : in  std_logic;
        SDSS           : out std_logic;
        SDCLK          : out std_logic;
        SDMOSI         : out std_logic;

        -- KeyBoard LEDs (active high)
        caps_led       : out std_logic;
        motor_led      : out std_logic;

        -- Casette Port
        cassette_in    : in  std_logic;
        cassette_out   : out std_logic;

        -- Format of Video
        -- 00 - sRGB - interlaced
        -- 01 - sRGB - non interlaced
        -- 10 - SVGA - 50Hz
        -- 11 - SVGA - 60Hz
        vid_mode       : in  std_logic_vector(1 downto 0);

        -- Test outputs
        test           : out std_logic_vector(7 downto 0);

        -- External 1MHz bus
        ext_1mhz_clken : out   std_logic; -- a 1MHz strobe, valid for one system clock cycle
        ext_1mhz_nrst  : out   std_logic;
        ext_1mhz_pgfc_n: out   std_logic;
        ext_1mhz_pgfd_n: out   std_logic;
        ext_1mhz_r_nw  : out   std_logic;
        ext_1mhz_addr  : out   std_logic_vector(7 downto 0);
        ext_1mhz_di    : out   std_logic_vector(7 downto 0);
        ext_1mhz_do    : in    std_logic_vector(7 downto 0) := (others => '1');
        ext_1mhz_irq_n : in    std_logic := '1';
        ext_1mhz_nmi_n : in    std_logic := '1';

        -- ICE T65 Deubgger 115200 baud serial
        avr_RxD        : in    std_logic;
        avr_TxD        : out   std_logic;

        phi2           : out   std_logic;
        cpu_rnw        : out   std_logic;
        cpu_addr       : out   std_logic_vector(15 downto 0)

    );
end;

architecture behavioral of ElectronFpga_core is

    signal RSTn              : std_logic;
    signal cpu_R_W_n         : std_logic;
    signal cpu_a             : std_logic_vector (23 downto 0);
    signal cpu_din           : std_logic_vector (7 downto 0);
    signal cpu_dout          : std_logic_vector (7 downto 0);
    signal ula_IRQ_n         : std_logic;
    signal cpu_IRQ_n         : std_logic;
    signal cpu_NMI_n         : std_logic;
    signal ROM_n             : std_logic;
    signal io_fred           : std_logic;
    signal io_jim            : std_logic;

    signal ula_data          : std_logic_vector (7 downto 0);
    signal ula_enable        : std_logic;

    signal key_break         : std_logic;
    signal key_turbo         : std_logic_vector(1 downto 0);
    signal sound             : std_logic;
    signal kbd_data          : std_logic_vector(3 downto 0);

    signal io_clken         : std_logic;
    signal cpu_clken         : std_logic;
    signal cpu_clken_r       : std_logic;

    signal rom_latch         : std_logic_vector(3 downto 0);

    signal ext_enable        : std_logic;

    signal abr_enable        : std_logic;
    signal abr_lo_bank_lock  : std_logic;
    signal abr_hi_bank_lock  : std_logic;

    signal video_vsync_int   : std_logic;
    signal video_hsync_int   : std_logic;
    signal video_red_int     : std_logic_vector(3 downto 0);
    signal video_green_int   : std_logic_vector(3 downto 0);
    signal video_blue_int    : std_logic_vector(3 downto 0);

begin

    video_vsync <= video_vsync_int;
    video_hsync <= video_hsync_int;
    video_red   <= video_red_int;
    video_green <= video_green_int;
    video_blue  <= video_blue_int;

    GenDebug: if IncludeICEDebugger generate
        signal cpu_clken1 : std_logic;
    begin
        core : entity work.MOS6502CpuMonCore
            generic map (
                UseT65Core   => true,
                UseAlanDCore => false
                )
            port map (
                clock_avr    => clk_24M00,
                busmon_clk   => clk_16M00,
                busmon_clken => cpu_clken1,
                cpu_clk      => clk_16M00,
                cpu_clken    => cpu_clken,
                IRQ_n        => cpu_IRQ_n,
                NMI_n        => cpu_NMI_n,
                Sync         => open,
                Addr         => cpu_a(15 downto 0),
                R_W_n        => cpu_R_W_n,
                Din          => cpu_din,
                Dout         => cpu_dout,
                SO_n         => '1',
                Res_n        => RSTn,
                Rdy          => '1',
                trig         => "00",
                avr_RxD      => avr_RxD,
                avr_TxD      => avr_TxD,
                sw_reset_cpu => '0',
                sw_reset_avr => not hard_reset_n,
                led_bkpt     => open,
                led_trig0    => open,
                led_trig1    => open,
                tmosi        => open,
                tdin         => open,
                tcclk        => open
                );

        process(clk_16M00)
        begin
            if rising_edge(clk_16M00) then
                cpu_clken1 <= cpu_clken;
            end if;
        end process;

    end generate;

    GenNoDebugCore: if not IncludeICEDebugger generate
        T65core : entity work.T65
        port map (
            Mode            => "00",
            Abort_n         => '1',
            SO_n            => '1',
            Res_n           => RSTn,
            Enable          => cpu_clken,
            Clk             => clk_16M00,
            Rdy             => '1',
            IRQ_n           => cpu_IRQ_n,
            NMI_n           => cpu_NMI_n,
            R_W_n           => cpu_R_W_n,
            Sync            => open,
            A               => cpu_a,
            DI              => cpu_din,
            DO              => cpu_dout
        );
        avr_TxD <= avr_RxD;
    end generate;


    ula : entity work.ElectronULA
    generic map (
        IncludeMMC       => true,
        Include32KRAM    => false,
        IncludeVGA       => true,
        IncludeJafaMode7 => IncludeJafaMode7,
        LimitROMSpeed    => false,
        LimitIOSpeed     => false
    )
    port map (
        clk_16M00 => clk_16M00,
        clk_24M00 => clk_24M00,
        clk_32M00 => clk_32M00,
        clk_33M33 => clk_33M33,
        clk_40M00 => clk_40M00,

        -- CPU Interface
        addr      => cpu_a(15 downto 0),
        data_in   => cpu_dout,
        data_out  => ula_data,
        data_en   => ula_enable,
        R_W_n     => cpu_R_W_n,
        RST_n     => RSTn,
        IRQ_n     => ula_IRQ_n,
        NMI_n     => cpu_NMI_n,

        -- Rom Enable
        ROM_n     => ROM_n,

        -- Video
        red       => video_red_int,
        green     => video_green_int,
        blue      => video_blue_int,
        vsync     => video_vsync_int,
        hsync     => video_hsync_int,

        -- Audio
        sound     => sound,

        -- SD Card
        SDMISO    => SDMISO,
        SDSS      => SDSS,
        SDCLK     => SDCLK,
        SDMOSI    => SDMOSI,

        -- Casette
        casIn     => cassette_in,
        casOut    => cassette_out,

        -- Keyboard
        kbd       => kbd_data,

        -- MISC
        caps      => caps_led,
        motor     => motor_led,

        rom_latch => rom_latch,

        mode_init => vid_mode,

        -- Clock Generation
        cpu_clken_out  => cpu_clken,
        io_clken_out   => io_clken,
        cpu_clk_out    => phi2,
        turbo          => key_turbo

    );

    input : entity work.keyboard port map(
        clk        => clk_16M00,
        rst_n      => hard_reset_n, -- to avoid a loop when break pressed!
        ps2_clk    => ps2_clk,
        ps2_data   => ps2_data,
        col        => kbd_data,
        row        => cpu_a(13 downto 0),
        break      => key_break,
        turbo      => key_turbo
    );

    cpu_NMI_n <= ext_1mhz_nmi_n;
    cpu_IRQ_n <= not((not ext_1mhz_irq_n) or (not ula_IRQ_n));

    RSTn    <= hard_reset_n and key_break;
    audio_l <= sound;
    audio_r <= sound;

    ext_enable <= '1' when
                  -- ROM accrss
                  ROM_n = '0' or
                  -- Non screen main memory access (0000-2FFF)
                  cpu_a(15 downto 13) = "000" or cpu_a(15 downto 12) = "0010" or
                  -- Sideways RAM Access
                  (cpu_a(15 downto 14) = "10" and rom_latch(3 downto 1) /= "100") else '0';

    cpu_din <= ext_Dout       when ext_enable = '1' else
               ula_data       when ula_enable = '1' else
               ext_1mhz_do    when io_fred = '1' or io_jim = '1' else
               x"F1";

    -- Pipeline external memory interface
     -- External addresses 00000-3FFFF are routed to FLASH 80000-DFFFFF
     -- External addresses 40000-7FFFF are routed to SRAM
     -- Note: the bottom 32K of CPU address space is mapped to SRAM, 20K of this is overlaid by the ULA
    process(clk_16M00,hard_reset_n)
    begin

        if hard_reset_n = '0' then
            ext_A   <= (others => '0');
            ext_Din <= (others => '0');
            ext_nWE <= '1';
            ext_nOE <= '1';
        elsif rising_edge(clk_16M00) then
            -- delayed cpu_clken for use as an external write signal
            cpu_clken_r <= cpu_clken;
            if cpu_a(15) = '0' then
                -- exteral main memory access
                ext_A <= "1" & "000" & cpu_a(14 downto 0);
            elsif cpu_a(15 downto 14) = "11" then
                 -- The OS rom image lives in slot 8 as on the Elk this is where the
                 -- keyboard appears, which keeps the external memory image down to 256KB.
                ext_A <= "0" & "1000" & cpu_a(13 downto 0);
            elsif cpu_a(15 downto 14) = "10" and rom_latch(3 downto 2) = "00" then
                -- Slots 0..3 are mapped to SRAM
                ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
            elsif cpu_a(15 downto 14) = "10" and rom_latch(3 downto 0) = "0100" and cpu_a(13 downto 8) >= "110111" then
                -- Slots 4 (MMFS) has B700 onwards as writeable for private workspace so mapped to SRAM
                ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
            else
                -- everyting else is ROM
                ext_A <= "0" & rom_latch & cpu_a(13 downto 0);
            end if;

            ext_Din <= cpu_dout;

            if cpu_R_W_n = '1' or ext_enable = '0' or cpu_clken_r = '0' then
                -- Default is disable WE, except in a few cases
                ext_nWE <= '1';
            elsif cpu_a(15) = '0' then
                -- exteral main memory access
                ext_nWE <= '0';
            elsif cpu_a(14) = '0' and rom_latch(3 downto 2) = "00" and rom_latch(0) = '0' and abr_lo_bank_lock = '0' then
                -- Slots 0,2 are write protected with FCDC/FCDD
                ext_nWE <= '0';
            elsif cpu_a(14) = '0' and rom_latch(3 downto 2) = "00" and rom_latch(0) = '1' and abr_hi_bank_lock = '0' then
                -- Slots 1,3 are write protected with FCDE/FCDF
                ext_nWE <= '0';
            elsif cpu_a(14) = '0' and rom_latch(3 downto 0) = "0100" and cpu_a(13 downto 8) >= "110110" then
                -- Slots 4 (MMFS) has B600 onwards as writeable for private workspace
                ext_nWE <= '0';
            else
                -- Other slots are read only
                ext_nWE <= '1';
            end if;

            -- Could make this more restrictive
            if cpu_R_W_n = '1' and ext_enable = '1' then
                ext_nOE <= '0';
            else
                ext_nOE <= '1';
            end if;

        end if;
    end process;

    -- Always enabled
    ext_nCS <= '0';

--------------------------------------------------------
-- HDMI
--------------------------------------------------------

    GenHDMI: if IncludeHDMI generate
        signal hsync1     : std_logic;
        signal vsync1     : std_logic;
        signal hcnt       : std_logic_vector(9 downto 0);
        signal vcnt       : std_logic_vector(9 downto 0);
        signal hdmi_red   : std_logic_vector(7 downto 0);
        signal hdmi_green : std_logic_vector(7 downto 0);
        signal hdmi_blue  : std_logic_vector(7 downto 0);
        signal hdmi_hsync : std_logic;
        signal hdmi_vsync : std_logic;
        signal hdmi_blank : std_logic;
        signal hdmi_audio : std_logic_vector (15 downto 0);
    begin

        -- Recreate the video sync/blank signals that match standard HDTV 720x576p
        --
        -- Modeline "720x576 @ 50hz"  27    720   732   796   864   576   581   586   625
        --
        -- Hcnt is set to 0 on the trailing edge of hsync from the Beeb core
        -- so the H constants below need to be offset by 864-796=68
        --
        -- Vcnt is set to 0 on the trailing edge of vsync from the Beeb core
        -- so the V constants below need to be offset by 625-586=39
        --
        -- This only works because the Beeb core is generating 32us lines
        --
        -- The hdmidataencode module inserts a two 32 pixel data packets after the
        -- first edge of hsync. The hsync pluse + back porch needs to be at least
        -- this width. There are also min requirements on the size of control
        -- islands of 12 pixels.

        process(clk_27M00)
            variable voffset  : integer;
            variable vsize    : integer;
        begin
            if rising_edge(clk_27M00) then
                hdmi_audio <= x"1000" when sound = '1' else x"F000";
                hsync1 <= video_hsync_int;
                if hsync1 = '0' and video_hsync_int = '1' then
                    hcnt <= (others => '0');
                    vsync1 <= video_vsync_int;
                    if vsync1 = '0' and video_vsync_int = '1' then
                        vcnt <= (others => '0');
                    else
                        vcnt <= vcnt + 1;
                    end if;
                else
                    hcnt <= hcnt + 1;
                end if;
                if hdmi_audio_en = '1' then
                    voffset := 39;
                    vsize   := 576;
                else
                    voffset := 55;
                    vsize   := 540;
                end if;
                if hcnt < 68 or hcnt >= 68 + 720 or vcnt < voffset or vcnt >= voffset + vsize then
                    hdmi_blank <= '1';
                    hdmi_red   <= (others => '0');
                    hdmi_green <= (others => '0');
                    hdmi_blue  <= (others => '0');
                else
                    hdmi_blank <= '0';
                    hdmi_red   <= video_red_int   & "0000";
                    hdmi_green <= video_green_int & "0000";
                    hdmi_blue  <= video_blue_int  & "0000";
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
                I_CLK_PIXEL      => clk_27M00,
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

    GenNotHDMI: if not IncludeHDMI generate
        tmds_r <= (others => '0');
        tmds_g <= (others => '0');
        tmds_b <= (others => '0');
    end generate;

--------------------------------------------------------
-- ABR Lock Registers
--------------------------------------------------------

    ABRIncluded: if IncludeABRRegs generate
        abr_enable <= '1' when cpu_a(15 downto 2) & "00" = x"fcdc" else '0';
        process(clk_16M00, RSTn)
        begin
            if RSTn = '0' then
                abr_lo_bank_lock <= '1';
                abr_hi_bank_lock <= '1';
            elsif rising_edge(clk_16M00) then
                if cpu_clken = '1' then
                    if abr_enable = '1' and cpu_R_W_n = '0' then
                        if cpu_a(1) = '0' then
                            abr_lo_bank_lock <= cpu_a(0);
                        else
                            abr_hi_bank_lock <= cpu_a(0);
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

   ABRExcluded: if not IncludeABRRegs generate
       abr_lo_bank_lock <= '1';
       abr_hi_bank_lock <= '1';
   end generate;


--------------------------------------------------------
-- External 1MHz Bus
--------------------------------------------------------

-- This is always included as it's cheap, and all inputs default to
-- sensible values
   io_fred <= '1' when cpu_a(15 downto 8) = x"FC" else '0';
   io_jim  <= '1' when cpu_a(15 downto 8) = x"FD" else '0';

   ext_1mhz_clken  <= io_clken;
   ext_1mhz_nrst   <= RSTn;

   ext_1mhz_pgfc_n <= not io_fred;
   ext_1mhz_pgfd_n <= not io_jim;
   ext_1mhz_r_nw   <= cpu_R_W_n;
   ext_1mhz_addr   <= cpu_a(7 downto 0);
   ext_1mhz_di     <= cpu_dout;

   cpu_addr <= cpu_a(15 downto 0);
   cpu_rnw <= CPU_R_W_n;

   test <= video_vsync_int & video_hsync_int & video_blue_int(3) & video_green_int(3) & video_red_int(3)  & "00" & cpu_IRQ_n;

end behavioral;

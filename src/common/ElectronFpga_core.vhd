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
        UseRomSlot9        : boolean := false;  -- alias of keyboard
        IncludeHDMI        : boolean := false;
        IncludeICEDebugger : boolean := false;
        IncludeABRRegs     : boolean := false;
        IncludeSerial      : boolean := false;
        IncludeAMXMouse    : boolean := false;
        IncludeUserPort    : boolean := false;
        IncludeMRB         : boolean := false;
        IncludeSP64        : boolean := false;
        IncludeJafaMode7   : boolean := false
    );
    port (
        -- Clocks
        clk_16M00      : in  std_logic;
        clk_24M00      : in  std_logic; -- for Jafa Mode7
        clk_32M00      : in  std_logic := '0'; -- no longer used
        clk_33M33      : in  std_logic;
        clk_40M00      : in  std_logic;
        clk_27M00      : in  std_logic := '0';

        -- Hard reset (active low)
        hard_reset_n   : in  std_logic;

        -- Keyboard
        ps2_clk        : in  std_logic;
        ps2_data       : in  std_logic;

        -- Mouse
        ps2_mouse_clk        : inout std_logic;
        ps2_mouse_data       : inout std_logic;

        -- Digital Joysticks
        -- Bit 0 - Up (active low)
        -- Bit 1 - Down (active low)
        -- Bit 2 - Left (active low)
        -- Bit 3 - Right (active low)
        -- Bit 4 - Fire (active low)
        joystick1      : in    std_logic_vector(4 downto 0) := (others => '1');
        joystick2      : in    std_logic_vector(4 downto 0) := (others => '1');

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
        ext_nWE_long   : out std_logic;
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
        -- 10 - 576p - 50Hz (27MHz pixel clock for 720x576 50Hz HDMI timings)
        -- 11 - 600p - 60Hz (40MHz pixel clock for 800x600 60Hz SVGA timings)
        vid_mode       : in  std_logic_vector(1 downto 0);

        -- Fake the RTC and Display interrupt timing (useful in 60Hz modes)
        fake_timing    : in  std_logic := '0';

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

        -- Serial Port
        serial_RxD     : in    std_logic := '1'; -- TTL Levels - idle line state = 1
        serial_CTS     : in    std_logic := '1'; -- TTL Levels - clear to send = 1
        serial_TxD     : out   std_logic;
        serial_RTS     : out   std_logic;

        -- User Port
        mc6522_ca1_in     : in  std_logic := '1';
        mc6522_ca2_in     : in  std_logic := '1';
        mc6522_ca2_out    : out std_logic;
        mc6522_ca2_oe_l   : out std_logic;
        mc6522_porta_in   : in  std_logic_vector(7 downto 0) := (others => '1');
        mc6522_porta_out  : out std_logic_vector(7 downto 0);
        mc6522_porta_oe_l : out std_logic_vector(7 downto 0);
        mc6522_cb1_in     : in  std_logic := '1';
        mc6522_cb1_out    : out std_logic;
        mc6522_cb1_oe_l   : out std_logic;
        mc6522_cb2_in     : in  std_logic := '1';
        mc6522_cb2_out    : out std_logic;
        mc6522_cb2_oe_l   : out std_logic;
        mc6522_portb_in   : in  std_logic_vector(7 downto 0) := (others => '1');
        mc6522_portb_out  : out std_logic_vector(7 downto 0);
        mc6522_portb_oe_l : out std_logic_vector(7 downto 0);

        -- 6502 tracing outputs
        trace_data     : out   std_logic_vector(7 downto 0);
        trace_r_nw     : out   std_logic;
        trace_sync     : out   std_logic;

        phi2           : out   std_logic;
        cpu_rnw        : out   std_logic;
        cpu_addr       : out   std_logic_vector(15 downto 0)

    );
end;

architecture behavioral of ElectronFpga_core is

    component D2681 is
        generic (
            CLK_FREQ_HZ : integer
            );
        port (
            clk     : in        std_logic;
            reset   : in        std_logic;
            clken   : in        std_logic;
            enable  : in        std_logic;
            we      : in        std_logic;
            addr    : in        std_logic_vector(3 downto 0);
            di      : in        std_logic_vector(7 downto 0);
            do      : out       std_logic_vector(7 downto 0);
            ip_n    : in        std_logic_vector(6 downto 0);
            op_n    : out       std_logic_vector(7 downto 0);
            txa     : out       std_logic;
            rxa     : in        std_logic;
            txb     : out       std_logic;
            rxb     : in        std_logic;
            intr_n  : out       std_logic
            );
    end component;

    signal reset_n           : std_logic;
    signal reset             : std_logic;
    signal cpu_R_W_n         : std_logic;
    signal cpu_sync          : std_logic;
    signal cpu_a             : std_logic_vector (23 downto 0);
    signal cpu_din           : std_logic_vector (7 downto 0);
    signal cpu_dout          : std_logic_vector (7 downto 0);
    signal ula_a             : std_logic_vector (15 downto 0);

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
    signal cpu_turbo         : std_logic_vector(1 downto 0);
    signal sound             : std_logic;
    signal kbd_data          : std_logic_vector(3 downto 0);

    signal mhz1_clken        : std_logic;
    signal mhz4_clken        : std_logic;
    signal cpu_clken         : std_logic;
    signal cpu_clken_r       : std_logic;

    signal shadow            : std_logic;
    signal mrb_mode          : std_logic_vector(1 downto 0); -- 00 = normal, 10 = turbo; 11 = shadow

    signal sp64_ram_enable   : std_logic := '0';
    signal sp64_rom_select   : std_logic := '0';

    signal rom_latch         : std_logic_vector(3 downto 0);

    signal ext_enable        : std_logic;

    signal abr_lo_bank_lock  : std_logic;
    signal abr_hi_bank_lock  : std_logic;

    signal serial_enable     : std_logic := '0';
    signal serial_IRQ_n      : std_logic := '1';
    signal serial_data       : std_logic_vector(7 downto 0) := (others => '0');

    signal mouse_read        :   std_logic;
    signal mouse_err         :   std_logic;
    signal mouse_rx_data     :   std_logic_vector(7 downto 0);
    signal mouse_write       :   std_logic;
    signal mouse_tx_data     :   std_logic_vector(7 downto 0);
    signal mouse_x_a         :   std_logic;
    signal mouse_x_b         :   std_logic;
    signal mouse_y_a         :   std_logic;
    signal mouse_y_b         :   std_logic;
    signal mouse_left        :   std_logic;
    signal mouse_middle      :   std_logic;
    signal mouse_right       :   std_logic;

    signal mc6522_enable     : std_logic := '0';
    signal mc6522_IRQ_n      : std_logic := '1';
    signal mc6522_data       : std_logic_vector(7 downto 0) := (others => '0');

    signal video_vsync_int   : std_logic;
    signal video_hsync_int   : std_logic;
    signal video_blank_int   : std_logic;
    signal video_red_int     : std_logic_vector(3 downto 0);
    signal video_green_int   : std_logic_vector(3 downto 0);
    signal video_blue_int    : std_logic_vector(3 downto 0);

begin

    reset       <= not reset_n;

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
                Sync         => cpu_sync,
                Addr         => cpu_a(15 downto 0),
                R_W_n        => cpu_R_W_n,
                Din          => cpu_din,
                Dout         => cpu_dout,
                SO_n         => '1',
                Res_n        => reset_n,
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
            Res_n           => reset_n,
            Enable          => cpu_clken,
            Clk             => clk_16M00,
            Rdy             => '1',
            IRQ_n           => cpu_IRQ_n,
            NMI_n           => cpu_NMI_n,
            R_W_n           => cpu_R_W_n,
            Sync            => cpu_sync,
            A               => cpu_a,
            DI              => cpu_din,
            DO              => cpu_dout
        );
        avr_TxD <= avr_RxD;
    end generate;


    ula : entity work.ElectronULA
    generic map (
        IncludeMMC       => true,
        Include32KRAM    => IncludeMRB,
        IncludeVGA       => true,
        IncludeJafaMode7 => IncludeJafaMode7,
        LimitROMSpeed    => false,
        LimitIOSpeed     => false
    )
    port map (
        clk_16M00 => clk_16M00,
        clk_24M00 => clk_24M00,
        clk_33M33 => clk_33M33,
        clk_40M00 => clk_40M00,

        hard_reset_n => hard_reset_n,

        -- CPU Interface
        addr      => ula_a,   -- top bits forced to 110 when MRB shaddow access
        data_in   => cpu_dout,
        data_out  => ula_data,
        data_en   => ula_enable,
        R_W_n     => cpu_R_W_n,
        RST_n     => reset_n,
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
        blank     => video_blank_int,

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
        fake_timing => fake_timing,

        -- Clock Generation
        cpu_clken_out  => cpu_clken,
        mhz1_clken_out => mhz1_clken,
        mhz4_clken_out => mhz4_clken,
        cpu_clk_out    => phi2,
        turbo          => cpu_turbo

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
    cpu_IRQ_n <= not((not ext_1mhz_irq_n) or (not ula_IRQ_n) or (not serial_IRQ_n) or (not mc6522_irq_n));

    reset_n    <= hard_reset_n and key_break;
    audio_l <= sound;
    audio_r <= sound;

    serial_enable <= '1' when io_fred = '1' and cpu_a(7 downto 4) = x"6" else '0';

    ext_enable <= '1' when
                  -- ROM accrss
                  ROM_n = '0' or
                  -- Shadow memory access (0000-7FFF)
                  shadow = '1' or
                  -- Sideways ROM Access
                  (cpu_a(15 downto 14) = "10" and rom_latch /= "1000" and (rom_latch /= "1001" or UseRomSlot9)) else '0';

    cpu_din <= ext_Dout          when ext_enable = '1' else
               ula_data          when ula_enable = '1' else
               serial_data       when serial_enable = '1' else
               mc6522_data       when mc6522_enable = '1' and IncludeUserPort else
               "000" & (joystick1 xor "11111") when io_fred = '1' and cpu_a(7 downto 4) = x"C" else
               "000" & (joystick2 xor "11111") when io_fred = '1' and cpu_a(7 downto 4) = x"D" else
               ext_1mhz_do       when io_fred = '1' or io_jim = '1' else
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
                ext_A <= "1" & "111" & cpu_a(14 downto 0);
            elsif cpu_a(15 downto 14) = "11" then
                 -- The OS rom images lives in slot 0/1 as these are overlaid by sideway RAM
                ext_A <= "0" & "000" & mrb_mode(1) & cpu_a(13 downto 0);
            elsif cpu_a(15 downto 14) = "10" and rom_latch(3 downto 2) = "00" then
                -- Slots 0..3 are mapped to SRAM
                ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
            elsif cpu_a(15 downto 14) = "10" and rom_latch(3 downto 0) = "0100" and cpu_a(13 downto 8) >= "110111" then
                -- Slots 4 (MMFS) has B700 onwards as writeable for private workspace so mapped to SRAM
                ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
            elsif IncludeSP64 and cpu_a(15 downto 14) = "10" and rom_latch = "1010" and mrb_mode(1) = '1' then
                -- Slot 10 (Stop Press 64) has special behavior if this is included
                if cpu_a(13) = '1' and sp64_ram_enable = '1' then
                    -- There is a switchable 8KB RAM overlay from A000-BFFF
                    ext_A <= "1" & rom_latch & cpu_a(13 downto 0);
                else
                    -- There are two ROMs images which we preload into ROMs 2 and 3
                    ext_A <= "0" & "001" & (not sp64_rom_select) & cpu_a(13 downto 0);
                end if;
            else
                -- everyting else is ROM
                ext_A <= "0" & rom_latch & cpu_a(13 downto 0);
            end if;

            ext_Din <= cpu_dout;

            if cpu_R_W_n = '1' or ext_enable = '0' then
                -- Default is disable WE, except in a few cases
                ext_nWE_long <= '1';
                ext_nWE <= '1';
            elsif cpu_a(15) = '0' then
                -- exteral main memory access
                ext_nWE_long <= '0';
                ext_nWE <= cpu_clken_r;
            elsif cpu_a(14) = '0' and rom_latch(3 downto 2) = "00" and rom_latch(0) = '0' and abr_lo_bank_lock = '0' then
                -- Slots 0,2 are write protected with FCDC/FCDD
                ext_nWE_long <= '0';
                ext_nWE <= cpu_clken_r;
            elsif cpu_a(14) = '0' and rom_latch(3 downto 2) = "00" and rom_latch(0) = '1' and abr_hi_bank_lock = '0' then
                -- Slots 1,3 are write protected with FCDE/FCDF
                ext_nWE_long <= '0';
                ext_nWE <= cpu_clken_r;
            elsif cpu_a(14) = '0' and rom_latch(3 downto 0) = "0100" and cpu_a(13 downto 8) >= "110110" then
                -- Slots 4 (MMFS) has B600 onwards as writeable for private workspace
                ext_nWE_long <= '0';
                ext_nWE <= cpu_clken_r;
            elsif cpu_a(14) = '0' and rom_latch(3 downto 0) = "1010" and cpu_a(13) = '1' and sp64_ram_enable = '1' and IncludeSP64 then
                -- Slot 10 (Stop Press 64) has a switchable 8KB RAM overlay from A000-BFFF
                ext_nWE_long <= '0';
                ext_nWE <= cpu_clken_r;
            else
                -- Other slots are read only
                ext_nWE_long <= '1';
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
-- Stop Press 64
--------------------------------------------------------

    SP64Included: if IncludeSP64 generate
        process(clk_16M00, reset_n)
        begin
            if reset_n = '0' then
                sp64_ram_enable <= '0';
                sp64_rom_select  <= '0';
            elsif rising_edge(clk_16M00) then
                if cpu_clken = '1' then
                    -- Bits 0 and 7 of FCFA control the Stop Press 64 RAM/ROM overlay in slot 10
                    if io_fred = '1' and cpu_a(7 downto 0) = x"fa" and cpu_R_W_n = '0' then
                        sp64_ram_enable <= cpu_dout(7); -- '1' overlays 8KB RAM at A000-BFFF
                        sp64_rom_select <= cpu_dout(0); -- '1' selects the lower ROM
                    end if;
                end if;
            end if;
        end process;
    end generate;

--------------------------------------------------------
-- MRB (Master RAM Board)
--------------------------------------------------------

    -- FC7F=&80 :
    -- 0000-2fff = normal RAM
    -- 3000-7fff = normal RAM
    --
    -- FC7F=&00, MRB in 'turbo' mode :
    -- 0000-2fff = shadow RAM
    -- 3000-7fff = normal RAM
    --
    -- FC7F=&00, MRB in 'shadow' mode :
    -- 0000-2fff = shadow RAM
    -- 3000-7fff = shadow RAM, EXCEPT when accessed by code at &C000-&DFFF (OS VDU drivers)

    -- JGH: The MOS code suggests that code executing at &C000-&DFFF
    -- always accesses video RAM, code elsewhere accesses the RAM
    -- specified by bit 7 of &FC7F.

    -- ThomasHarte: Yep, I found some old notes and that's exactly
    -- what I used to know. The MSB of FC7F selects entire-range RAM
    -- visibility; the exception is that operations with their first
    -- byte in C000–DFFF that address 3000–7FFF always see the
    -- ordinary built-in memory.

    -- &027F   fx239   &EF   Shadow RAM flag
    --   &00 indicates no shadow screen or shadow screen not selected
    --   &01 indicates Electron Master RAM Turbo mode
    --   &80 indicates Electron Master RAM 64K mode

    -- F0B5 : AD FF 7F : LDA $7FFF   ; Save top byte of main memory
    -- F0B8 : 48       : PHA
    -- F0B9 : A9 80    : LDA #$80    ; A = 80
    -- F0BB : 8D FF 7F : STA $7FFF   ; Write 80 to main memory from address not in C000-DFFF
    -- F0BE : 0A       : ASL A       ; A = 00
    -- F0BF : 20 2A D0 : JSR $D02A   ; Write 00 to screen memory from address in C000-DFFF
    -- F0C2 : AD FF 7F : LDA $7FFF   ; Returns 80 (64K mode) if shadow / screen are distict, otherwise 00
    -- F0C5 : 30 0C    : BMI $F0D3
    -- F0C7 : A2 D8    : LDX #$D8
    -- F0C9 : A0 01    : LDY #$01
    -- F0CB : 84 D8    : STY $D8     ; 00D8 = 01 (Turbo mode)
    -- F0CD : A8       : TAY         ; A = 0; Y = 0
    -- F0CE : 20 F7 FB : JSR $FBF7   ; Test if turbo mode is enabled
    -- F0D1 : A5 D8    : LDA $D8
    -- F0D3 : 8D 7F 02 : STA $027F   ; 80 = shadow mode
    -- F0D6 : 68       : PLA
    -- F0D7 : 8D FF 7F : STA $7FFF   ; Restore top byte of main memory
    -- F0DA : 60       : RTS
    --
    -- FBF7 : 2C D2 D8 : BIT $D8D2   ; In MRB OS 3.0 D8D2 = 11111111; In ELK OS 1.0 D8D2 = 10101001
    -- FBFA : 70 01    : BVS $FBFD
    -- FBFC : B8       : CLV         ; superfluous as V=0 anyway
    -- FBFD : 4C DB F0 : JMP $F0DB   ; V=1 indicates MRB OS; V=0 indicates ELK OS
    --
    -- F0DB : 08       : PHP         ; Save flags inc IRQ status
    -- F0DC : 78       : SEI         ; disable interrupts
    -- F0DD : 38       : SEC
    -- F0DE : 6A       : ROR A       ; A = 80
    -- F0DF : 8D 7F FC : STA $FC7F   ; disable MRB
    -- F0E2 : 2A       : ROL A       ; A = 00
    -- F0E3 : 86 D6    : STX $D6     ; D7/D6 = 00D8
    -- F0E5 : 84 D7    : STY $D7
    -- F0E7 : A0 00    : LDY #$00
    -- F0E9 : 70 02    : BVS $F0ED   ; V=1 if MRB OS; V=0 for ELK OS
    -- F0EB : B1 D6    : LDA ($D6),Y ; executed if Elk OS: don't change 00D8
    -- F0ED : 91 D6    : STA ($D6),Y ; 00D8 = 0 - this always writes normal memory as MRB disable
    -- F0EF : A4 D7    : LDY $D7     ; restore Y
    -- F0F1 : 18       : CLC
    -- F0F2 : 6A       : ROR A       ; A = 00
    -- F0F3 : 8D 7F FC : STA $FC7F   ; enable MRB
    -- F0F6 : 2A       : ROL A       ; C -> A; A=01 if turbo mode; A=00 if normal mode
    -- F0F7 : 28       : PLP
    -- F0F8 : 60       : RTS

    MRBIncluded: if IncludeMRB generate
        signal mrb_enabled : std_logic; -- register at FC7C bit 7
        signal vdu_op      : std_logic; -- flag to indicate instruction address in C000-DFFF (VDU driver)
    begin
        -- Note: mrb_mode has the following values: 00 = normal, 10 = turbo; 11 = shadow
        shadow <=
            -- Normal memory when address >= 0x8000
            '0' when cpu_a(15) = '1'   else
            -- Normal memory when mrb_mode is "NORMAL"
            '0' when mrb_mode(1) = '0' else
            -- Normal memory when mrb is disabled with the FC7F register
            '0' when mrb_enabled = '0' else
            -- Normal memory when an access to screen memory (3000-7FFF) from either a VDU op or in turbo mode
            '0' when (cpu_a(15 downto 12) = "0011" or cpu_a(15 downto 14) = "01") and (vdu_op = '1' or mrb_mode(0) = '0')  else
            -- Otherwise use shadow memory
            '1';

        ula_a  <= "110" & cpu_a(12 downto 0) when shadow = '1' else cpu_a(15 downto 0);

        -- F1: 2MHz Mode  (OS 1.00)
        -- F2: MRB Off    (OS 1.00) - Normal Electron
        -- F3: MRB Turbo  (OS 3.10)
        -- F4: MRB Shadow (OS 3.10)

        cpu_turbo <= "10" when key_turbo = "00" else
                     "01";

        mrb_mode  <= "10" when key_turbo = "10" else
                     "11" when key_turbo = "11" else
                     "00";

        process(clk_16M00, reset_n)
        begin
            if reset_n = '0' then
                mrb_enabled <= '1'; -- enabled on reset
                vdu_op <= '0';
            elsif rising_edge(clk_16M00) then
                if cpu_clken = '1' then
                    -- The setting the MSB of FC7F disabled all MRB functionality
                    if io_fred = '1' and cpu_a(7 downto 0) = x"7f" and cpu_R_W_n = '0' then
                        mrb_enabled <= not cpu_dout(7);
                    end if;
                    -- Flag to indicate the current instruction address is C000..DFFF
                    if cpu_sync = '1' then
                        if cpu_a(15 downto 13) = "110" then
                            vdu_op <= '1';
                        else
                            vdu_op <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end process;
    end generate;

    MRBNotIncluded: if not IncludeMRB generate
        -- This retains the existing behaviour where 0000-2FFF used external RAM, allowing
        -- the ULA to contain just 20KB of screen memory
        shadow <= '1' when cpu_a(15 downto 13) = "000" or cpu_a(15 downto 12) = "0010" else '0';

        ula_a  <= cpu_a(15 downto 0);

        -- F1: 1MHz No Contention        (OS 1.00)
        -- F2: 1MHz/2MHz Mode/Contention (OS 1.00) - Normal Electron
        -- F3: 2MHz No Contention        (OS 1.00)
        -- F4: 4MHz No Contention        (OS 1.00)

        cpu_turbo <= key_turbo;

        mrb_mode <= "00";

    end generate;

--------------------------------------------------------
-- HDMI
--------------------------------------------------------

    GenHDMI: if IncludeHDMI generate
        signal hdmi_red   : std_logic_vector(7 downto 0);
        signal hdmi_green : std_logic_vector(7 downto 0);
        signal hdmi_blue  : std_logic_vector(7 downto 0);
        signal hdmi_hsync : std_logic;
        signal hdmi_vsync : std_logic;
        signal hdmi_blank : std_logic;
        signal hdmi_audio : std_logic_vector (15 downto 0);
    begin
        process(clk_27M00)
        begin
            if rising_edge(clk_27M00) then
                if sound = '1' then
                    hdmi_audio <= x"1000";
                else
                    hdmi_audio <= x"F000";
                end if;
                hdmi_red   <= video_red_int   & "0000";
                hdmi_green <= video_green_int & "0000";
                hdmi_blue  <= video_blue_int  & "0000";
                hdmi_hsync <= video_hsync_int;
                hdmi_vsync <= video_vsync_int;
                hdmi_blank <= video_blank_int;
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
        signal abr_enable : std_logic;
    begin
        abr_enable <= '1' when io_fred = '1' and cpu_a(7 downto 2) & "00" = x"dc" else '0';
        process(clk_16M00, reset_n)
        begin
            if reset_n = '0' then
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
-- Serial
--------------------------------------------------------

    SerialIncluded: if IncludeSerial generate
        signal ip_n  : std_logic_vector(6 downto 0);
        signal op_n  : std_logic_vector(7 downto 0);
        signal we    : std_logic;
        signal txa   : std_logic;
        signal rxa   : std_logic;
    begin
        we <= not CPU_R_W_n;

        inst_d2681 : D2681
            generic map (
                CLK_FREQ_HZ => 16000000
                )
            port map (
                clk     => clk_16M00,
                reset   => reset,
                clken   => cpu_clken,
                enable  => serial_enable,
                we      => we,
                addr    => cpu_a(3 downto 0),
                di      => cpu_dout,
                do      => serial_data,
                ip_n    => ip_n,
                op_n    => op_n,
                txa     => txa,
                rxa     => rxa,
                txb     => open,
                rxb     => '1',
                intr_n  => serial_IRQ_n
                );
        Serial_TxD <= txa;
        Serial_RTS <= op_n(0);
        rxa <= Serial_RxD;
        ip_n <= "1111" & Serial_CTS & "11";

    end generate;

    SerialNotIncluded: if not IncludeSerial generate
        Serial_TxD   <= '1';
        Serial_RTS   <= '1';
        serial_IRQ_n <= '1';
        serial_data  <= x"FC";
    end generate;

--------------------------------------------------------
-- User Port
--------------------------------------------------------

    mc6522_enable  <= '1' when io_fred = '1' and cpu_a(7 downto 4) = x"b" else '0';

    UserPortIncluded: if IncludeUserPort generate

        signal portb_in        : std_logic_vector(7 downto 0);
        signal cb1_in          : std_logic;
        signal cb2_in          : std_logic;
        signal mc6522_data_tmp : std_logic_vector(7 downto 0) := (others => '0');

    begin
        cb1_in      <= mc6522_cb1_in      and mouse_x_a;
        cb2_in      <= mc6522_cb2_in      and mouse_y_a;
        portb_in(7) <= mc6522_portb_in(7) and mouse_right;
        portb_in(6) <= mc6522_portb_in(6) and mouse_middle;
        portb_in(5) <= mc6522_portb_in(5) and mouse_left;
        portb_in(4) <= mc6522_portb_in(4);
        portb_in(3) <= mc6522_portb_in(3);
        portb_in(2) <= mc6522_portb_in(2) and mouse_y_b;
        portb_in(1) <= mc6522_portb_in(1);
        portb_in(0) <= mc6522_portb_in(0) and mouse_x_b;

        via : entity work.M6522 port map(
            I_RS       => cpu_a(3 downto 0),
            I_DATA     => cpu_dout,
            O_DATA     => mc6522_data_tmp,
            I_RW_L     => CPU_R_W_n,
            I_CS1      => mc6522_enable,
            I_CS2_L    => '0',
            O_IRQ_L    => mc6522_irq_n,
            I_CA1      => mc6522_ca1_in,
            I_CA2      => mc6522_ca2_in,
            O_CA2      => mc6522_ca2_out,
            O_CA2_OE_L => mc6522_ca2_oe_l,
            I_PA       => mc6522_porta_in,
            O_PA       => mc6522_porta_out,
            O_PA_OE_L  => mc6522_porta_oe_l,
            I_CB1      => cb1_in,
            O_CB1      => mc6522_cb1_out,
            O_CB1_OE_L => mc6522_cb1_oe_l,
            I_CB2      => cb2_in,
            O_CB2      => mc6522_cb2_out,
            O_CB2_OE_L => mc6522_cb2_oe_l,
            I_PB       => portb_in,
            O_PB       => mc6522_portb_out,
            O_PB_OE_L  => mc6522_portb_oe_l,
            RESET_L    => reset_n,
            I_P2_H     => mhz1_clken,
            ENA_4      => mhz4_clken,
            CLK        => clk_16M00
            );

        -- This is needed as in v003 of the 6522 data out is only valid while I_P2_H is asserted
        -- I_P2_H is driven from via1_clken
        data_latch: process(clk_16M00)
        begin
            if rising_edge(clk_16M00) then
                if mhz1_clken = '1' then
                    mc6522_data <= mc6522_data_tmp;
                end if;
            end if;
        end process;
    end generate;

    UserPortNotIncluded: if not IncludeUserPort generate
        mc6522_ca2_out    <= '1';
        mc6522_ca2_oe_l   <= '1';
        mc6522_porta_out  <= (others => '1');
        mc6522_porta_oe_l <= (others => '1');
        mc6522_cb1_out    <= '1';
        mc6522_cb1_oe_l   <= '1';
        mc6522_cb2_out    <= '1';
        mc6522_cb2_oe_l   <= '1';
        mc6522_portb_out  <= (others => '1');
        mc6522_portb_oe_l <= (others => '1');
        mc6522_irq_n      <= '1';
        mc6522_data       <= x"FC";
    end generate;

--------------------------------------------------------
-- AMX Mouse
--------------------------------------------------------

    MouseIncluded: if IncludeAMXMouse generate
        signal mse_clk_in   : std_logic;
        signal mse_clk_out  : std_logic;
        signal mse_data_in  : std_logic;
        signal mse_data_out : std_logic;
    begin

        ps2_mouse_clk  <= '0' when mse_clk_out = '0' else 'Z';
        mse_clk_in     <= ps2_mouse_clk;
        ps2_mouse_data <= '0' when mse_data_out = '0' else 'Z';
        mse_data_in    <= ps2_mouse_data;

        mouse_ps2interface: entity work.ps2interface
        generic map(
            MainClockSpeed => 16000000
        )
        port map(
           ps2_clk      => mse_clk_in,
           ps2_clk_out  => mse_clk_out,
           ps2_data     => mse_data_in,
           ps2_data_out => mse_data_out,
           clk          => clk_16M00,
           rst          => reset,
           tx_data      => mouse_tx_data,
           write        => mouse_write,
           rx_data      => mouse_rx_data,
           read         => mouse_read,
           busy         => open,
           err          => mouse_err
        );
        -- BBC Micro User Port (Mouse use)
        --  2 - CB1 - X Axis
        --  6 - D0  - X Dir
        --  4 - CB2 - Y Axis
        -- 10 - D2  - Y Dir
        -- 16 - D5  - Left button
        -- 18 - D6  - Middle button
        -- 20 - D7  - Right button
        mouse_controller: entity work.quadrature_controller port map(
           clk      => clk_16M00,
           rst      => reset,
           read     => mouse_read,
           err      => mouse_err,
           rx_data  => mouse_rx_data,
           write    => mouse_write,
           tx_data  => mouse_tx_data,
           x_a      => mouse_x_a,
           x_b      => mouse_x_b,
           y_a      => mouse_y_a,
           y_b      => mouse_y_b,
           left     => mouse_left,
           middle   => mouse_middle,
           right    => mouse_right
        );
    end generate;

    MouseNotIncluded: if not IncludeAMXMouse generate
        mouse_x_a    <= '1';
        mouse_x_b    <= '1';
        mouse_y_a    <= '1';
        mouse_y_b    <= '1';
        mouse_left   <= '1';
        mouse_middle <= '1';
        mouse_right  <= '1';
    end generate;

--------------------------------------------------------
-- 6502 Tracing
--------------------------------------------------------

    process(clk_16M00)
    begin
        if rising_edge(clk_16M00) then
            if cpu_clken = '1' then
                if cpu_R_W_n = '1' then
                    trace_data <= cpu_Din;
                else
                    trace_data <= cpu_Dout;
                end if;
                trace_r_nw <= cpu_R_W_n;
                trace_sync <= cpu_sync;
            end if;
        end if;
    end process;

--------------------------------------------------------
-- External 1MHz Bus
--------------------------------------------------------

-- This is always included as it's cheap, and all inputs default to
-- sensible values
   io_fred <= '1' when cpu_a(15 downto 8) = x"FC" else '0';
   io_jim  <= '1' when cpu_a(15 downto 8) = x"FD" else '0';

   ext_1mhz_clken  <= mhz1_clken;
   ext_1mhz_nrst   <= reset_n;

   ext_1mhz_pgfc_n <= not io_fred;
   ext_1mhz_pgfd_n <= not io_jim;
   ext_1mhz_r_nw   <= cpu_R_W_n;
   ext_1mhz_addr   <= cpu_a(7 downto 0);
   ext_1mhz_di     <= cpu_dout;

   cpu_addr <= cpu_a(15 downto 0);
   cpu_rnw <= CPU_R_W_n;

   test <= video_vsync_int & video_hsync_int & video_blue_int(3) & video_green_int(3) & video_red_int(3)  & "00" & cpu_IRQ_n;

end behavioral;

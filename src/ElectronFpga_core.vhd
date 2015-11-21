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
    port (
        -- Clocks
        clk_16M00      : in  std_logic;
        clk_33M33      : in  std_logic;
        clk_40M00      : in  std_logic;

        -- Hard reset (active low)
        hard_reset_n   : in  std_logic;

        -- Keyboard
        ps2_clk        : in  std_logic;
        ps2_data       : in  std_logic;

        -- Video
        video_red      : out std_logic_vector (3 downto 0);
        video_green    : out std_logic_vector (3 downto 0);
        video_blue     : out std_logic_vector (3 downto 0);
        video_vsync    : out std_logic;
        video_hsync    : out std_logic;

        -- Audio
        audio_l        : out std_logic;
        audio_r        : out std_logic;

        -- External memory (e.g. SRAM and/or FLASH)
        -- 512KB logical address space
        ext_nOE        : out std_logic;
        ext_nWE        : out std_logic;
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
        test           : out std_logic_vector(7 downto 0)
    );
end;

architecture behavioral of ElectronFpga_core is

    signal RSTn              : std_logic;
    signal cpu_R_W_n         : std_logic;
    signal cpu_addr          : std_logic_vector (15 downto 0);
    signal cpu_din           : std_logic_vector (7 downto 0);
    signal cpu_dout          : std_logic_vector (7 downto 0);
    signal cpu_IRQ_n         : std_logic;
    signal cpu_NMI_n         : std_logic;
    signal ROM_n             : std_logic;

    signal ula_data          : std_logic_vector (7 downto 0);

    signal clken_counter     : std_logic_vector (3 downto 0);
    signal cpu_cycle         : std_logic;
    signal cpu_clken         : std_logic;
    signal cpu_clken_r       : std_logic;
    signal cpu_clken_1       : std_logic;
    signal cpu_clken_2       : std_logic;
    signal cpu_clken_4       : std_logic;

    signal key_break         : std_logic;
    signal key_turbo         : std_logic_vector(1 downto 0);
    signal sound             : std_logic;
    signal kbd_data          : std_logic_vector(3 downto 0);

    signal ula_irq_n         : std_logic;

    signal via1_clken        : std_logic;
    signal via1_clken_1      : std_logic;
    signal via1_clken_2      : std_logic;
    signal via1_clken_4      : std_logic;
    signal via4_clken        : std_logic;
    signal via4_clken_1      : std_logic;
    signal via4_clken_2      : std_logic;
    signal via4_clken_4      : std_logic;
    signal mc6522_enable     : std_logic;
    signal mc6522_data       : std_logic_vector(7 downto 0);
    signal mc6522_irq_n      : std_logic;
    -- Port A is not really used, so signals directly loop back out to in
    signal mc6522_ca2        : std_logic;
    signal mc6522_porta      : std_logic_vector(7 downto 0);
    -- Port B is used for the MMBEEB style SDCard Interface
    signal mc6522_cb1_in     : std_logic;
    signal mc6522_cb1_out    : std_logic;
    signal mc6522_cb1_oe_l   : std_logic;
    signal mc6522_cb2_in     : std_logic;
    signal mc6522_portb_in   : std_logic_vector(7 downto 0);
    signal mc6522_portb_out  : std_logic_vector(7 downto 0);
    signal mc6522_portb_oe_l : std_logic_vector(7 downto 0);
    signal sdclk_int         : std_logic;

    signal rom_latch         : std_logic_vector(3 downto 0);

    signal contention        : std_logic;
    signal contention1       : std_logic;
    signal contention2       : std_logic;
    signal rom_access        : std_logic; -- always at 2mhz, no contention
    signal ram_access        : std_logic; -- 1MHz/2Mhz/Stopped

    signal clk_state         : std_logic_vector(2 downto 0);

    signal ext_enable        : std_logic;
    
begin

    cpu : entity work.T65 port map (
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
        A(23 downto 16) => open,
        A(15 downto 0)  => cpu_addr(15 downto 0),
        DI              => cpu_din,
        DO              => cpu_dout
    );

    via : entity work.M6522 port map(
        I_RS       => cpu_addr(3 downto 0),
        I_DATA     => cpu_dout(7 downto 0),
        O_DATA     => mc6522_data(7 downto 0),
        I_RW_L     => cpu_R_W_n,
        I_CS1      => mc6522_enable,
        I_CS2_L    => '0',
        O_IRQ_L    => mc6522_irq_n,
        I_CA1      => '0',
        I_CA2      => mc6522_ca2,
        O_CA2      => mc6522_ca2,
        O_CA2_OE_L => open,
        I_PA       => mc6522_porta,
        O_PA       => mc6522_porta,
        O_PA_OE_L  => open,
        I_CB1      => mc6522_cb1_in,
        O_CB1      => mc6522_cb1_out,
        O_CB1_OE_L => mc6522_cb1_oe_l,
        I_CB2      => mc6522_cb2_in,
        O_CB2      => open,
        O_CB2_OE_L => open,
        I_PB       => mc6522_portb_in,
        O_PB       => mc6522_portb_out,
        O_PB_OE_L  => mc6522_portb_oe_l,
        RESET_L    => RSTn,
        I_P2_H     => via1_clken,
        ENA_4      => via4_clken,
        CLK        => clk_16M00);

    -- SDCLK is driven from either PB1 or CB1 depending on the SR Mode
    sdclk_int     <= mc6522_portb_out(1) when mc6522_portb_oe_l(1) = '0' else
                     mc6522_cb1_out      when mc6522_cb1_oe_l = '0' else
                     '1';
    SDCLK         <= sdclk_int;
    mc6522_cb1_in <= sdclk_int;

    -- SDMOSI is always driven from PB0
    SDMOSI        <= mc6522_portb_out(0) when mc6522_portb_oe_l(0) = '0' else
                     '1';

    -- SDMISO is always read from CB2
    mc6522_cb2_in <= SDMISO;

    -- SDSS is hardwired to 0 (always selected) as there is only one slave attached
    SDSS          <= '0';


    ula : entity work.ElectronULA port map (
        clk_16M00 => clk_16M00,
        clk_33M33 => clk_33M33,
        clk_40M00 => clk_40M00,

        -- CPU Interface
        cpu_clken => cpu_clken,
        addr      => cpu_addr,
        data_in   => cpu_dout,
        data_out  => ula_data,
        R_W_n     => cpu_R_W_n,
        RST_n     => RSTn,
        IRQ_n     => ula_irq_n,
        NMI_n     => cpu_NMI_n,

        -- Rom Enable
        ROM_n     => ROM_n,

        -- Video
        red       => video_red,
        green     => video_green,
        blue      => video_blue,
        vsync     => video_vsync,
        hsync     => video_hsync,

        -- Audio
        sound     => sound,

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

        contention => contention
    );

    input : entity work.keyboard port map(
        clk        => clk_16M00,
        rst_n      => hard_reset_n, -- to avoid a loop when break pressed!
        ps2_clk    => ps2_clk,
        ps2_data   => ps2_data,
        col        => kbd_data,
        row        => cpu_addr(13 downto 0),
        break      => key_break,
        turbo      => key_turbo
    );

    mc6522_enable  <= '1' when cpu_addr(15 downto 4) = x"fcb" else '0';
    cpu_IRQ_n      <= mc6522_irq_n AND ula_irq_n;
    cpu_NMI_n      <= '1';

    RSTn    <= hard_reset_n and key_break;
    audio_l <= sound;
    audio_r <= sound;

    ext_enable <= '1' when ROM_n = '0' or (cpu_addr(15 downto 14) = "10" and rom_latch(3 downto 1) /= "100") else '0';
    
    cpu_din <= ext_Dout       when ext_enable = '1' else
               mc6522_data    when mc6522_enable = '1' else
               ula_data;

    -- The OS rom image lives in slot 8 as on the Elk this is where the
    -- keyboard appears, which keeps the external memory image down to 256KB.

    ext_A <= "0" & "1000"    & cpu_addr(13 downto 0) when cpu_addr(15 downto 14) = "11" else
             "0" & rom_latch & cpu_addr(13 downto 0);

    ext_Din <= cpu_dout;

    -- Slots 4,5,6,7 are writeable
    -- WE lags the cpu by one cycle to give the RAM some setup and hold time
    ext_nWE <= '0' when cpu_R_W_n = '0' and ext_enable = '1' and cpu_addr(15 downto 14) = "10" and rom_latch(3 downto 2) = "01" and cpu_clken_r = '1' else '1';

    -- Could make this more restrictinb
    ext_nOE <= '0' when cpu_R_W_n = '1' and ext_enable = '1'; 
        
--------------------------------------------------------
-- clock enable generator
--------------------------------------------------------

    -- ROM accesses always happen at 2Mhz
    rom_access <= not ROM_n;
    -- RAM accesses always happen at 1Mhz and subber contention
    ram_access <= not cpu_addr(15);
    -- IO accesses always happen at 1MHz and don't suffer contention

    clk_gen1 : process(clk_16M00, RSTn)
    begin
        if RSTn = '0' then
            clken_counter <= (others => '0');
        elsif rising_edge(clk_16M00) then
            -- delayed cpu_clken for use as an external write signal
            cpu_clken_r <= cpu_clken;
            -- clock state machine
            if clken_counter(0) = '1' and clken_counter(1) = '1' then
                case clk_state is
                when "000" =>
                    if rom_access = '1' then
                        -- 2MHz no contention
                        clk_state <= "001";
                    else
                        -- 1MHz, possible contention
                        clk_state <= "101";
                    end if;
                when "001" =>
                    -- CPU is clocked in this state
                    clk_state <= "010";
                when "010" =>
                    if rom_access = '1' then
                        -- 2MHz no contention
                        clk_state <= "011";
                    else
                        -- 1MHz, possible contention
                        clk_state <= "111";
                    end if;
                when "011" =>
                    -- CPU is clocked in this state
                    clk_state <= "000";
                when "100" =>
                    clk_state <= "101";
                when "101" =>
                    clk_state <= "110";
                when "110" =>
                    if ram_access = '1' and contention2 = '1' then
                        clk_state <= "111";
                    else
                        clk_state <= "011";
                    end if;
                when "111" =>
                    clk_state <= "100";
                when others => null;
                end case;
            end if;
            -- clken counter
            clken_counter <= clken_counter + 1;
            -- Synchronize contention signal
            contention1 <= contention;
            contention2 <= contention1;
            -- 1MHz
            -- cpu_clken active on cycle 0
            -- address/data changes on cycle 1
            cpu_clken_1  <= clken_counter(0) and clken_counter(1) and clken_counter(2) and clken_counter(3);
            via1_clken_1 <= clken_counter(0) and clken_counter(1) and clken_counter(2) and clken_counter(3);
            via4_clken_1 <= clken_counter(0) and clken_counter(1);
            -- 2MHz
            -- cpu_clken active on cycle 0, 8
            -- address/data changes on cycle 1, 9
            cpu_clken_2  <= clken_counter(0) and clken_counter(1) and clken_counter(2);
            via1_clken_2 <= clken_counter(0) and clken_counter(1) and clken_counter(2);
            via4_clken_2 <= clken_counter(0);
            -- 4MHz - no contention
            -- cpu_clken active on cycle 0, 4, 8, 12
            -- address/data changes on cycle 1, 5, 9, 13
            cpu_clken_4  <= clken_counter(0) and clken_counter(1);
            via1_clken_4 <= clken_counter(0) and clken_counter(1);
            via4_clken_4 <= '1';
        end if;
    end process;

    clk_gen2 : process(key_turbo, clken_counter, clk_state,
                       cpu_clken_1, cpu_clken_2, cpu_clken_4,
                       via1_clken_1, via1_clken_2, via1_clken_4,
                       via4_clken_1, via4_clken_2, via4_clken_4)
    begin
        case (key_turbo) is
            when "01" =>
                -- 2Mhz Contention
                cpu_clken <= '0';
                via1_clken <= '0';
                via4_clken <= '0';
                if clken_counter(0) = '1' and clken_counter(1) = '1' then
                    -- 1MHz/2MHz/Stopped
                    if clk_state = "001" or clk_state = "011" then
                        cpu_clken <= '1';
                    end if;
                    -- 1MHz fixed
                    if clk_state = "011" or clk_state = "111" then
                        via1_clken <= '1';
                    end if;
                    -- 4MHz fixed
                    via4_clken <= '1';
                end if;
            when "10" =>
                -- 2Mhz No Contention
                cpu_clken  <= cpu_clken_2;
                via1_clken <= via1_clken_2;
                via4_clken <= via4_clken_2;
            when "11" =>
                -- 4MHz No contention
                cpu_clken  <= cpu_clken_4;
                via1_clken <= via1_clken_4;
                via4_clken <= via4_clken_4;
            when others =>
                -- 1MHz No Contention
                cpu_clken  <= cpu_clken_1;
                via1_clken <= via1_clken_1;
                via4_clken <= via4_clken_1;
        end case;
    end process;

    test <= cpu_clken & cpu_clken_1 & cpu_clken_2 & contention2 & cpu_addr(15) & CPU_IRQ_n & "00";
end behavioral;



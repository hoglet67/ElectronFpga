--------------------------------------------------------------------------------
-- Copyright (c) 2025 David Banks
--------------------------------------------------------------------------------
--   ____  ____
--  /   /\/   /
-- /___/  \  /
-- \   \   \/
--  \   \
--  /   /         Filename  : JafaMode7.vhd
-- /___/   /\     Timestamp : 21/08/2025
-- \   \  /  \
--  \___\/\___\
--
--Design Name: JafaMode7
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity JafaMode7 is
    generic (
        TTxtClockSpeed : integer := 24;
        IncludeTTxtROM : boolean := true
        );
    port (
        -- CPU interface
        sys_clk       : in  std_logic;
        mhz1_clken    : in  std_logic;
        cpu_clken     : in  std_logic;
        RST_n         : in  std_logic;
        R_W_n         : in  std_logic;
        addr          : in  std_logic_vector(15 downto 0);
        data_in       : in  std_logic_vector(7 downto 0);
        data_out      : out std_logic_vector(7 downto 0);
        data_en       : out std_logic;
        -- Teletext clock
        ttxt_clk      : in  std_logic;
        ttxt_clken    : in  std_logic;
        -- Video out
        mode7_enable  : out std_logic;
        red           : out std_logic;
        green         : out std_logic;
        blue          : out std_logic;
        vsync         : out std_logic;
        hsync         : out std_logic;
        csync         : out std_logic;
        field         : out std_logic;
        blank         : out std_logic;

        red_even      : out std_logic;
        red_odd       : out std_logic;
        green_even    : out std_logic;
        green_odd     : out std_logic;
        blue_even     : out std_logic;
        blue_odd      : out std_logic;

        -- SAA5050 character ROM loading
        char_rom_we   : in std_logic := '0';
        char_rom_addr : in std_logic_vector(10 downto 0) := (others => '0');
        char_rom_data : in std_logic_vector(7 downto 0) := (others => '0')
        );
end;

architecture behavioral of JafaMode7 is

    signal ttxt_ram_we    : std_logic;
    signal ttxt_ram_data  : std_logic_vector(7 downto 0);
    signal ttxt_glr       : std_logic;
    signal ttxt_dew       : std_logic;
    signal ttxt_crs       : std_logic;
    signal ttxt_lose      : std_logic;
    signal ttxt_r         : std_logic;
    signal ttxt_g         : std_logic;
    signal ttxt_b         : std_logic;
    signal ttxt_r_even    : std_logic;
    signal ttxt_g_even    : std_logic;
    signal ttxt_b_even    : std_logic;
    signal ttxt_r_odd     : std_logic;
    signal ttxt_g_odd     : std_logic;
    signal ttxt_b_odd     : std_logic;
    signal ttxt_de        : std_logic;

    signal status_enable  : std_logic;
    signal status_do      : std_logic_vector(7 downto 0);

    signal crtc_enable    : std_logic;
    signal crtc_do        : std_logic_vector(7 downto 0);
    signal crtc_vsync     : std_logic;
    signal crtc_hsync     : std_logic;
    signal crtc_de        : std_logic;
    signal crtc_cursor    : std_logic;
    signal crtc_cursor1   : std_logic;
    signal crtc_cursor2   : std_logic;
    signal crtc_ma        : std_logic_vector(13 downto 0);
    signal crtc_ra        : std_logic_vector(4 downto 0);

begin

    -- FC1C - Write address register
    -- FC1D - Write data register
    -- FC1E - Read status register - only bit 5 (vsync) is implemented
    -- FC1F - Read data register

    ttxt_ram_we <= '1' when addr(15 downto 10) = "011111" and R_W_n = '0' and cpu_clken = '1' else '0';

    ram_1k : entity work.RAM_DualPortSimple
        generic map (
            DEPTH => 1024,
            AWIDTH => 10,
            DWIDTH => 8 -- could be reduced to 7 bits wide
            )
        port map (
            -- Port A is the 6502 port
            clka  => sys_clk,
            wea   => ttxt_ram_we,
            addra => addr(9 downto 0),
            dina  => data_in,
            -- Port B is the video port
            clkb  => sys_clk,
            addrb => crtc_ma(9 downto 0),
            doutb => ttxt_ram_data
            );


    process (sys_clk)
    begin
        if rising_edge(sys_clk) then
            -- Generate a cursor signal that is delayed by 2 characters
            if mhz1_clken = '1' then
                crtc_cursor1 <= crtc_cursor;
                crtc_cursor2 <= crtc_cursor1;
            end if;
        end if;
    end process;

    crtc_enable <= '1' when addr(15 downto 0) = x"fc1c" or
                   addr(15 downto 0) = x"fc1d" or
                   addr(15 downto 0) = x"fc1f"
                   else '0';

    status_enable <= '1' when addr(15 downto 0) = x"fc1e" else '0';

    status_do <= "00" & crtc_vsync & "00000";

    data_out <= crtc_do   when crtc_enable = '1'   else
                status_do when status_enable = '1' else
                x"F1";

    data_en  <= '1' when crtc_enable = '1'   else
                '1' when status_enable = '1' else
                '0';

    crtc : entity work.mc6845 port map (
        -- inputs
        CLOCK     => sys_clk,
        CLKEN     => mhz1_clken,
        CLKEN_CPU => cpu_clken,
        nRESET    => RST_n,
        ENABLE    => crtc_enable,
        R_nW      => R_W_n,
        RS        => addr(0),
        DI        => data_in,
        LPSTB     => '0',
        -- outputs
        DO        => crtc_do,
        VSYNC     => crtc_vsync,
        HSYNC     => crtc_hsync,
        DE        => crtc_de,
        CURSOR    => crtc_cursor,
        MA        => crtc_ma,
        RA        => crtc_ra
        );

    ttxt_glr <= not crtc_hsync;
    ttxt_dew <= crtc_vsync;
    ttxt_crs <= not crtc_ra(0);
    ttxt_lose <= crtc_de;

    teletext : entity work.saa5050
        generic map (
            IncludeTTxtROM => IncludeTTxtROM
            )
        port map (
            -- inputs
            CLOCK    => ttxt_clk,
            CLKEN    => ttxt_clken,
            nRESET   => RST_n,
            DI_CLOCK => sys_clk,
            DI_CLKEN => '1',
            DI       => ttxt_ram_data(6 downto 0),
            GLR      => ttxt_glr,
            DEW      => ttxt_dew,
            CRS      => ttxt_crs,
            LOSE     => ttxt_lose,
            -- outputs
            R        => ttxt_r,
            G        => ttxt_g,
            B        => ttxt_b,
            PIXDE    => ttxt_de,
            R_even   => ttxt_r_even,
            G_even   => ttxt_g_even,
            B_even   => ttxt_b_even,
            R_odd    => ttxt_r_odd,
            G_odd    => ttxt_g_odd,
            B_odd    => ttxt_b_odd,

            -- SAA5050 character ROM loading
            char_rom_we   => char_rom_we,
            char_rom_addr => char_rom_addr,
            char_rom_data => char_rom_data
            );

    -- make the cursor visible
    red        <= ttxt_r      xor crtc_cursor2;
    red_even   <= ttxt_r_even xor crtc_cursor2;
    red_odd    <= ttxt_r_odd  xor crtc_cursor2;
    green      <= ttxt_g      xor crtc_cursor2;
    green_even <= ttxt_g_even xor crtc_cursor2;
    green_odd  <= ttxt_g_odd  xor crtc_cursor2;
    blue       <= ttxt_b      xor crtc_cursor2;
    blue_even  <= ttxt_b_even xor crtc_cursor2;
    blue_odd   <= ttxt_b_odd  xor crtc_cursor2;
    hsync      <= crtc_hsync;
    vsync      <= crtc_vsync;
    csync      <= crtc_hsync or crtc_vsync;
    blank      <= not ttxt_de;

    -- enable mode 7
    mode7_enable <= crtc_ma(13);

    -- field output
    field <= not crtc_ra(0);

end behavioral;

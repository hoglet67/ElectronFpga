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
        ScanDoubled    : boolean := false;
        TTxtClockSpeed : integer := 24;
        IncludeTTxtROM : boolean := true
        );
    port (
        -- CPU interface
        clk_16M00     : in  std_logic;
        cpu_clken     : in  std_logic;
        RST_n         : in  std_logic;
        R_W_n         : in  std_logic;
        addr          : in  std_logic_vector(15 downto 0);
        data_in       : in  std_logic_vector(7 downto 0);
        data_out      : out std_logic_vector(7 downto 0);
        data_en       : out std_logic;
        -- Teletext clock
        ttxt_clk      : in  std_logic;
        -- Scandoubler clock
        hd_clk        : in  std_logic := '0';
        -- Video out
        mode7_enable  : out std_logic;
        red           : out std_logic;
        green         : out std_logic;
        blue          : out std_logic;
        vsync         : out std_logic;
        hsync         : out std_logic;
        csync         : out std_logic;
        blank         : out std_logic;
        -- SAA5050 character ROM loading
        char_rom_we   : in std_logic := '0';
        char_rom_addr : in std_logic_vector(11 downto 0) := (others => '0');
        char_rom_data : in std_logic_vector(7 downto 0) := (others => '0')
        );
end;

architecture behavioral of JafaMode7 is

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
        if ScanDoubled then
            return TTxtClockSpeed / 24 - 1;
        else
            return TTxtClockSpeed / 12 - 1;
        end if;
    end function;

    signal ttxt_clken     : std_logic;
    signal ttxt_divider   : unsigned(f_log2(f_max_divider) - 1 downto 0) := (others => '0');
    signal ttxt_ram_we    : std_logic;
    signal ttxt_ram_data  : std_logic_vector(7 downto 0);
    signal ttxt_glr       : std_logic;
    signal ttxt_dew       : std_logic;
    signal ttxt_crs       : std_logic;
    signal ttxt_lose      : std_logic;
    signal ttxt_r_tmp     : std_logic;
    signal ttxt_g_tmp     : std_logic;
    signal ttxt_b_tmp     : std_logic;
    signal ttxt_de_tmp    : std_logic;
    signal ttxt_r         : std_logic;
    signal ttxt_g         : std_logic;
    signal ttxt_b         : std_logic;
    signal ttxt_de        : std_logic;

    signal status_enable  : std_logic;
    signal status_do      : std_logic_vector(7 downto 0);

    signal crtc_clken     : std_logic;
    signal crtc_enable    : std_logic;
    signal crtc_do        : std_logic_vector(7 downto 0);
    signal crtc_vsync     : std_logic;
    signal crtc_vsync_n   : std_logic;
    signal crtc_hsync     : std_logic;
    signal crtc_hsync_n   : std_logic;
    signal crtc_de        : std_logic;
    signal crtc_cursor    : std_logic;
    signal crtc_cursor1   : std_logic;
    signal crtc_cursor2   : std_logic;
    signal crtc_ma        : std_logic_vector(13 downto 0);
    signal crtc_ra        : std_logic_vector(4 downto 0);

    signal is_scandoubled : std_logic;

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

    is_scandoubled <= '1' when ScanDoubled else '0';

    -- FC1C - Write address register
    -- FC1D - Write data register
    -- FC1E - Read status register - only bit 5 (vsync) is implemented
    -- FC1F - Read data register

    ttxt_ram_we <= '1' when addr(15 downto 10) = "011111" and R_W_n = '0' and cpu_clken = '1' else '0';

    ram_1k : entity work.RAM_DualPort
        generic map (
            DEPTH => 1024,
            AWIDTH => 10,
            DWIDTH => 8 -- could be reduced to 7 bits wide
            )
        port map (
            -- Port A is the 6502 port
            clka  => clk_16M00,
            wea   => ttxt_ram_we,
            addra => addr(9 downto 0),
            dina  => data_in,
            douta => open,
            -- Port B is the video port
            clkb  => clk_16M00,
            web   => '0',
            addrb => crtc_ma(9 downto 0),
            dinb  => x"00",
            doutb => ttxt_ram_data
            );


    process (clk_16M00)
        variable counter : std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk_16M00) then
            if counter = "1111" or (is_scandoubled = '1' and counter = "0111") then
                crtc_clken <= '1';
            else
                crtc_clken <= '0';
            end if;
            counter := counter + 1;
            -- Generate a cursor signal that is delayed by 2 characters
            if crtc_clken = '1' then
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
        CLOCK     => clk_16M00,
        CLKEN     => crtc_clken,
        CLKEN_CPU => '1',
        VGA       => is_scandoubled,
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

    crtc_hsync_n <= not crtc_hsync;
    crtc_vsync_n <= not crtc_vsync;

    ttxt_glr <= crtc_hsync_n;
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
            VGA      => is_scandoubled,
            DI_CLOCK => clk_16M00,
            DI_CLKEN => '1',
            DI       => ttxt_ram_data(6 downto 0),
            GLR      => ttxt_glr,
            DEW      => ttxt_dew,
            CRS      => ttxt_crs,
            LOSE     => ttxt_lose,
            -- outputs
            R        => ttxt_r_tmp,
            G        => ttxt_g_tmp,
            B        => ttxt_b_tmp,
            PIXDE    => ttxt_de_tmp,

            -- SAA5050 character ROM loading
            char_rom_we   => char_rom_we,
            char_rom_addr => char_rom_addr,
            char_rom_data => char_rom_data
            );

    -- make the cursor visible
    ttxt_r  <= ttxt_r_tmp xor crtc_cursor2;
    ttxt_g  <= ttxt_g_tmp xor crtc_cursor2;
    ttxt_b  <= ttxt_b_tmp xor crtc_cursor2;
    ttxt_de <= ttxt_de_tmp;

    -- enable mode 7
    mode7_enable <= crtc_ma(13);

    ScanDoubledEnabled: if ScanDoubled generate
        signal tmp_r     : std_logic;
        signal tmp_g     : std_logic;
        signal tmp_b     : std_logic;
        signal tmp_hs    : std_logic;
        signal tmp_vs    : std_logic;
        signal tmp_de    : std_logic;
    begin

        inst_retimer: entity work.retimer
            generic map (
                WIDTH => 1
                )
            port map (
                clk_in    => ttxt_clk,
                clken_in  => ttxt_clken,
                clk_out   => hd_clk,
                clken_out => '1',
                hs_in     => crtc_hsync_n,
                vs_in     => crtc_vsync_n,
                r_in(0)   => ttxt_r,
                g_in(0)   => ttxt_g,
                b_in(0)   => ttxt_b,
                de_in     => ttxt_de,
                hs_out    => tmp_hs,
                vs_out    => tmp_vs,
                de_out    => tmp_de,
                r_out(0)  => tmp_r,
                g_out(0)  => tmp_g,
                b_out(0)  => tmp_b
                );
        red   <= tmp_r;
        green <= tmp_g;
        blue  <= tmp_b;
        hsync <= tmp_hs;
        vsync <= tmp_vs;
        csync <= tmp_hs and tmp_vs;
        blank <= not tmp_de;
    end generate;

    ScanDoubledDisabled : if not ScanDoubled generate
        red   <= ttxt_r;
        green <= ttxt_g;
        blue  <= ttxt_b;
        hsync <= crtc_hsync_n;
        vsync <= crtc_vsync_n;
        csync <= crtc_hsync_n and crtc_vsync_n;
        blank <= not ttxt_de;
    end generate;

end behavioral;

--
-- Copyright (C) 2013 Chris McClelland
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rgb2vga_scandoubler is
    generic (
        WIDTH        : integer;       -- RGB width
        CWIDTH       : integer := 10; -- internal counter width
        CLK_OUT_FREQ : integer := 27
        );
    port (
        -- Selects between two different choices of sampling parms
        -- Use mode=0 at pal_clken = 16MHz and mode=1 at pal_clken = 12MHz
        mode         : in std_logic;

        -- Input 15.625kHz PAL signals
        pal_clk      : in  std_logic;
        pal_clken    : in  std_logic;
        pal_rgb_even : in  std_logic_vector(WIDTH - 1 downto 0); -- even (upper) row
        pal_rgb_odd  : in  std_logic_vector(WIDTH - 1 downto 0); -- odd (lower) row
        pal_hsync    : in  std_logic;
        pal_vsync    : in  std_logic;

        -- Output 31.250kHz VGA signals (scan doubled)
        vga_clk      : in  std_logic;
        vga_clken    : in  std_logic;
        vga_rgb      : out std_logic_vector(WIDTH - 1 downto 0);
        vga_hsync    : out std_logic;
        vga_vsync    : out std_logic
        );
end entity;

architecture rtl of rgb2vga_scandoubler is

    function f_log2 (x : natural) return natural is
        variable i : natural;
    begin
        i := 1;
        while (2**i < x) and i < 31 loop
            i := i + 1;
        end loop;
        return i;
    end function;

    -- Config parameters
    constant SAMPLE_OFFSET0 : integer := 176;
    constant SAMPLE_OFFSET1 : integer := 32;
    constant SAMPLE_WIDTH   : integer := 656;

    -- Values for 720x576p (total 864x625) with 27MHz clock
    -- worked quite well on Belina and on LG
    -- ModeLine "720x576" 27.00 720 732 796 864 576 581 586 625 -HSync -VSync


    constant HORIZ_RT       : integer := 64;
    constant HORIZ_BP       : integer := 68 + 32;
    constant HORIZ_DISP     : integer := 656;
    constant HORIZ_FP       : integer := 12 + 32;


--    -- Original values
--  constant CWIDTH        : integer := 10;
--  constant HORIZ_RT       : integer := 96;
--  constant HORIZ_BP       : integer := 30;
--  constant HORIZ_DISP     : integer := 656;
--  constant HORIZ_FP       : integer := 18;

--    -- Values for 1170x584 (total 1480x624) with 46.2MHz clock
--  constant CWIDTH        : integer := 11;
--  constant HORIZ_RT       : integer := 176;
--  constant HORIZ_BP       : integer := 404;
--  constant HORIZ_DISP     : integer := 656;
--  constant HORIZ_FP       : integer := 244;

--    -- Values for 800x600 (total 1056x625) with 33.032MHz clock
--  constant CWIDTH        : integer := 11;
--  constant HORIZ_RT       : integer := 96;
--  constant HORIZ_BP       : integer := 152;
--  constant HORIZ_DISP     : integer := 656;
--  constant HORIZ_FP       : integer := 152;

--    -- Values for 800x600 (total 1024x625) with 32.000MHz clock
--  constant CWIDTH        : integer := 11;
--  constant HORIZ_RT       : integer := 128;
--  constant HORIZ_BP       : integer := 160;
--  constant HORIZ_DISP     : integer := 656;
--  constant HORIZ_FP       : integer := 80;

--    -- Values for 800x600 (total 960x625) with 30.000MHz clock
--    -- Modeline "800x600@50" 30 800 814 884 960 600 601 606 625 +hsync +vsync
--  constant CWIDTH        : integer := 10;
--  constant HORIZ_RT       : integer := 70;
--  constant HORIZ_BP       : integer := 76 + 72;
--  constant HORIZ_DISP     : integer := 656;
--  constant HORIZ_FP       : integer := 14 + 72;

    -- Registers in the 16MHz clock domain:
    signal pal_hsync1       : std_logic;
    signal pal_counter      : unsigned(CWIDTH - 1 downto 0) := (others => '0');
    signal line             : std_logic := '1';

    -- Registers in the 25MHz clock domain:
    signal field            : std_logic := '1';
    signal vga_hsync1       : std_logic;
    signal vga_hsync2       : std_logic;
    signal vga_counter      : unsigned(CWIDTH - 1 downto 0) := to_unsigned(HORIZ_DISP + HORIZ_FP, CWIDTH);

    -- Synchronization
    signal sync_tmp1        : std_logic;
    signal sync_tmp2        : std_logic;
    signal sample_counter   : unsigned(f_log2(CLK_OUT_FREQ) - 1 downto 0);

    -- Signals on the write side of the RAM:
    signal writeEn          : std_logic;
    signal writeAddr        : std_logic_vector(CWIDTH downto 0); -- one extra bit for double buffering
    signal writeData        : std_logic_vector(2 * WIDTH - 1 downto 0);

    -- Signals on the read side of the RAM:
    signal readAddr         : std_logic_vector(CWIDTH downto 0); -- one extra bit for double buffering
    signal readData         : std_logic_vector(2 * WIDTH - 1 downto 0);

begin

    -- PAL clock domain ---------------------------------------------------------------------------

    -- there is nothing asynchronous here

    process(pal_clk)
    begin
        if rising_edge(pal_clk) then
            if pal_clken = '1' then
                pal_hsync1 <= pal_hsync;
                if pal_hsync1 = '0' and pal_hsync = '1' then
                    -- reload on trailing edge of hsync
                    if mode = '0' then
                        pal_counter <= to_unsigned(2**CWIDTH - SAMPLE_OFFSET0 + 1, CWIDTH);
                    else
                        pal_counter <= to_unsigned(2**CWIDTH - SAMPLE_OFFSET1 + 1, CWIDTH);
                    end if;
                    line <= not line;
                else
                    pal_counter <= pal_counter + 1;
                end if;
            end if;
        end if;
    end process;

    writeEn   <= '1' when pal_counter < SAMPLE_WIDTH else '0';
    writeData <= pal_rgb_even & pal_rgb_odd;
    writeAddr <= line & std_logic_vector(pal_counter);

    -- Double buffered block RAM straddling the input and output clock
    -- domains, for storing pixel lines; whilst we're reading from one
    -- line, we're writing to the other. Their roles swap every
    -- incoming 64us scanline.

    ram: entity work.rgb2vga_dpram
        generic map (
            DWIDTH    => WIDTH * 2,   -- * 2 to allow different data for odd and even lines
            AWIDTH    => CWIDTH + 1   -- + 1 for double buffering
            )
        port map(
            -- Write port
            wrclock   => pal_clk,
            wrclken   => pal_clken,
            wraddress => writeAddr,
            wren      => writeEn,
            data      => writeData,

            -- Read port
            rdclock   => vga_clk,
            rdclken   => vga_clken,
            rdaddress => readAddr,
            q         => readData
            );


    -- VGA clock domain ---------------------------------------------------------------------------

    -- Note: we don't bother to synchronize line as it never changes during the active part of the line

    readAddr  <= not line & std_logic_vector(vga_counter);

    process(vga_clk)
    begin
        if rising_edge(vga_clk) then

            if vga_clken = '1' then
                -- Note: the synchronization here is borrowed from the BeebFpga retimer
                --
                -- The input and output clocks are frequency locked
                -- because they are derived from the same clock input, but
                -- may have aribtrary phase.
                --
                -- It's important to only sample hsync when it's
                -- stable. That's what sample counter does. This counter
                -- wraps every microsecond, and a sample point it picked a
                -- couple of clocks after a transition is seen.
                --
                -- Note: this scheme only works because we know that the
                -- hsync period is an integer number of microseconds. So
                -- the trailing edge will be at a consistent point
                -- wrt. sample counter which has a period of one
                -- microsecond.

                sync_tmp1 <= pal_hsync;  -- synchronize async input
                sync_tmp2 <= sync_tmp1;

                -- synchronization counter that wraps every micro second
                if sample_counter = CLK_OUT_FREQ - 1 then
                    sample_counter <= (others => '0');
                else
                    sample_counter <= sample_counter + 1;
                end if;

                -- Synchronise the counter to the trailing edge of hsync, with some hysteresis to avoid continuously hunting
                -- (Note: this scheme relies on the nominal line being an integer number of microseconds long, which MODE 7 is)
                if sync_tmp2 = '0' and sync_tmp1 = '1' then
                    -- The next edge should be time at 26, 0 or 1; outside of this resync
                    if sample_counter > 1 and sample_counter < (CLK_OUT_FREQ - 1) then
                        sample_counter <= to_unsigned(1, sample_counter'length);
                    end if;
                end if;

                -- Sample once per microsecond, two clock cycles after the edge to be safe
                if sample_counter = 2 then
                    vga_vsync  <= pal_vsync;
                    vga_hsync1 <= pal_hsync;
                end if;

                vga_hsync2 <= vga_hsync1;
                if (vga_hsync1 = '1' and vga_hsync2 = '0') or (vga_counter = HORIZ_DISP + HORIZ_FP - 1) then
                    vga_counter <= to_unsigned(2**CWIDTH - HORIZ_RT - HORIZ_BP, CWIDTH);
                    field <= vga_hsync2;
                else
                    vga_counter <= vga_counter + 1;
                end if;

                -- regenerate a line doubled hsync
                if vga_counter >= to_unsigned(2**CWIDTH - HORIZ_RT - HORIZ_BP, CWIDTH) and vga_counter < to_unsigned(2**CWIDTH - HORIZ_BP, CWIDTH) then
                    vga_hsync <= '0';
                else
                    vga_hsync <= '1';
                end if;

                -- Select odd or even line data based on field, which is
                -- low for the first line and high for the second line
                vga_rgb <= readData(2*WIDTH - 1 downto WIDTH) when field = '0' else readData(WIDTH - 1 downto 0);

            end if;
        end if;
    end process;

end architecture;

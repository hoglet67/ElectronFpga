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
        WIDTH : integer
        );
    port (
        -- Selects between two different choices of sampling parms
        -- Use mode=0 at 16MHz and mode=1 at 12MHz
        mode         : in std_logic;

        -- Input 15.625kHz RGB signals
        clock        : in  std_logic;
        clken        : in  std_logic;
        rgbi_even_in : in  std_logic_vector(WIDTH - 1 downto 0); -- even (upper) row
        rgbi_odd_in  : in  std_logic_vector(WIDTH - 1 downto 0); -- odd (lower) row
        hSync_in     : in  std_logic;
        vSync_in     : in  std_logic;

        -- Output 31.250kHz VGA signals (scan doubled)
        clk25        : in  std_logic;
        rgbi_out     : out std_logic_vector(WIDTH - 1 downto 0);
        hSync_out    : out std_logic;
        vSync_out    : out std_logic
        );
end entity;

architecture rtl of rgb2vga_scandoubler is
    -- Config parameters
    constant SAMPLE_OFFSET0 : integer := 176;
    constant SAMPLE_OFFSET1 : integer := 32;
    constant SAMPLE_WIDTH   : integer := 656;

    -- Values for 720x576p (total 864x625) with 27MHz clock
    -- worked quite well on Belina and on LG
    -- ModeLine "720x576" 27.00 720 732 796 864 576 581 586 625 -HSync -VSync
    constant width25       : integer := 10;
    constant HORIZ_RT      : integer := 64;
    constant HORIZ_BP      : integer := 68 + 32;
    constant HORIZ_DISP    : integer := 656;
    constant HORIZ_FP      : integer := 12 + 32;


--    -- Original values
--  constant width25       : integer := 10;
--  constant HORIZ_RT      : integer := 96;
--  constant HORIZ_BP      : integer := 30;
--  constant HORIZ_DISP    : integer := 656;
--  constant HORIZ_FP      : integer := 18;

--    -- Values for 1170x584 (total 1480x624) with 46.2MHz clock
--  constant width25       : integer := 11;
--  constant HORIZ_RT      : integer := 176;
--  constant HORIZ_BP      : integer := 404;
--  constant HORIZ_DISP    : integer := 656;
--  constant HORIZ_FP      : integer := 244;

--    -- Values for 800x600 (total 1056x625) with 33.032MHz clock
--  constant width25       : integer := 11;
--  constant HORIZ_RT      : integer := 96;
--  constant HORIZ_BP      : integer := 152;
--  constant HORIZ_DISP    : integer := 656;
--  constant HORIZ_FP      : integer := 152;

--    -- Values for 800x600 (total 1024x625) with 32.000MHz clock
--  constant width25       : integer := 11;
--  constant HORIZ_RT      : integer := 128;
--  constant HORIZ_BP      : integer := 160;
--  constant HORIZ_DISP    : integer := 656;
--  constant HORIZ_FP      : integer := 80;

--    -- Values for 800x600 (total 960x625) with 30.000MHz clock
--    -- Modeline "800x600@50" 30 800 814 884 960 600 601 606 625 +hsync +vsync
--  constant width25       : integer := 10;
--  constant HORIZ_RT      : integer := 70;
--  constant HORIZ_BP      : integer := 76 + 72;
--  constant HORIZ_DISP    : integer := 656;
--  constant HORIZ_FP      : integer := 14 + 72;

    -- Registers in the 16MHz clock domain:
    signal hSync_s16       : std_logic;
    signal hCount16        : unsigned(9 downto 0) := (others => '0');
    signal lineToggle      : std_logic := '1';

    -- Registers in the 25MHz clock domain:
    signal field           : std_logic := '1';
    signal field_next      : std_logic;
    signal hSync_s25a      : std_logic;
    signal hSync_s25b      : std_logic;
    signal hCount25        : unsigned(width25 - 1 downto 0) := to_unsigned(HORIZ_DISP + HORIZ_FP, width25);

    -- Signals on the write side of the RAMs:
    signal writeEn         : std_logic;
    signal writeAddr       : std_logic_vector(10 downto 0);
    signal writeData       : std_logic_vector(2 * WIDTH - 1 downto 0);

    -- Signals on the read side of the RAMs:
    signal readAddr        : std_logic_vector(10 downto 0);
    signal readData        : std_logic_vector(2 * WIDTH - 1 downto 0);

begin

    -- 16MHz clock domain ---------------------------------------------------------------------------

    -- there is nothing asynchronous here

    process(clock)
    begin
        if rising_edge(clock) then
            if clken = '1' then
                hSync_s16 <= hSync_in;
                if hSync_s16 = '0' and hSync_in = '1' then
                    -- reload on trailing edge of hsync
                    if mode = '0' then
                        hCount16 <= to_unsigned(2**10 - SAMPLE_OFFSET0 + 1, 10);
                    else
                        hCount16 <= to_unsigned(2**10 - SAMPLE_OFFSET1 + 1, 10);
                    end if;
                    lineToggle <= not lineToggle;
                else
                    hCount16 <= hCount16 + 1;
                end if;
            end if;
        end if;
    end process;

    writeEn   <= '1' when hCount16 < SAMPLE_WIDTH and clken = '1' else '0';
    writeData <= rgbi_even_in & rgbi_odd_in;
    writeAddr <= lineToggle & std_logic_vector(hCount16);

    -- Double buffered block RAM straddling the input and output clock
    -- domains, for storing pixel lines; whilst we're reading from one
    -- line, we're writing to the other. Their roles swap every
    -- incoming 64us scanline.

    ram: entity work.rgb2vga_dpram
        generic map (
            WIDTH     => WIDTH * 2 -- double to allow different data for odd and even lines
            )
        port map(
            -- Write port
            wrclock   => clock,
            wraddress => writeAddr,
            wren      => writeEn,
            data      => writeData,

            -- Read port
            rdclock   => clk25,
            rdaddress => readAddr,
            q         => readData
            );


    -- 25MHz clock domain ---------------------------------------------------------------------------

    -- Note: we don't bother to synchronize lineToggle as it never changes during the active part of the line

    readAddr  <= not lineToggle & std_logic_vector(hCount25);

    -- Field is low for the first line and high for the second line
    rgbi_out <= readData(2*WIDTH - 1 downto WIDTH) when field = '0' else readData(WIDTH - 1 downto 0);

    -- Note: the synchronization here is potentially troublesome and will be improved in the next commit

    process(clk25)
    begin
        if rising_edge(clk25) then
            vSync_out  <= vSync_in; -- synchronize async input
            hSync_s25a <= hSync_in; -- synchronize async input
            hSync_s25b <= hSync_s25a;
            if (hSync_s25a = '1' and hSync_s25b = '0') or (hCount25 = HORIZ_DISP + HORIZ_FP - 1) then
                hCount25 <= to_unsigned(2**width25 - HORIZ_RT - HORIZ_BP, width25);
                field <= hSync_s25b;
            else
                hCount25 <= hCount25 + 1;
            end if;
            -- regenerate a line doubled hsync
            if hCount25 >= to_unsigned(2**width25 - HORIZ_RT - HORIZ_BP, width25) and hCount25 < to_unsigned(2**width25 - HORIZ_BP, width25) then
                hSync_out <= '0';
            else
                hSync_out <= '1';
            end if;
        end if;
    end process;

end architecture;

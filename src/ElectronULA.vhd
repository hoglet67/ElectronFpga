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


-- TODO:
-- Implement Cassette
-- Implement 50Hz VGA
-- Implement 15.875KHz RGB Video Output
-- Fix display interrupt to be once per field

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ElectronULA is
    port (
        clk_svga  : in  std_logic;
        clk_16M00 : in  std_logic;
        
        -- CPU Interface
        cpu_clken : in  std_logic;
        addr      : in  std_logic_vector(15 downto 0);
        data_in   : in  std_logic_vector(7 downto 0);
        data_out  : out std_logic_vector(7 downto 0);
        R_W_n     : in  std_logic;
        RST_n     : in  std_logic;
        IRQ_n     : out std_logic;
        NMI_n     : out std_logic;

        -- Rom Enable
        ROM_n     : out std_logic;
        
        -- SVGA
        red       : out std_logic_vector(3 downto 0);
        green     : out std_logic_vector(3 downto 0);
        blue      : out std_logic_vector(3 downto 0);
        vsync     : out std_logic;
        hsync     : out std_logic;

        -- Audio
        sound     : out std_logic;

        -- Keyboard
        kbd       : in  std_logic_vector(3 downto 0);

        -- MISC
        caps      : out std_logic;
        motor     : out std_logic;
        
        rom_latch : out std_logic_vector(3 downto 0)
        );
end;

architecture behavioral of ElectronULA is

  signal ram_we         : std_logic;
  signal ram_data       : std_logic_vector(7 downto 0);

  signal master_irq     : std_logic;
  signal master_nmi     : std_logic;

  signal power_on_reset : std_logic := '1';
  signal rtc_counter    : std_logic_vector(18 downto 0);
  signal sound_counter  : std_logic_vector(15 downto 0);
  signal sound_bit      : std_logic;
  signal isr_data       : std_logic_vector(7 downto 0);
  
  -- ULA Registers
  signal isr            : std_logic_vector(6 downto 2);
  signal ier            : std_logic_vector(6 downto 2);
  signal screen_base    : std_logic_vector(14 downto 6);
  signal data_shift     : std_logic_vector(7 downto 0);
  signal page_enable    : std_logic;
  signal page           : std_logic_vector(2 downto 0);
  signal counter        : std_logic_vector(7 downto 0);
  signal display_mode   : std_logic_vector(2 downto 0);
  signal comms_mode     : std_logic_vector(1 downto 0);
  
  type palette_type is array (0 to 7) of std_logic_vector (7 downto 0);  
  signal palette        : palette_type;

  signal svga_hcount    : std_logic_vector(10 downto 0);
  signal svga_hcount1   : std_logic_vector(10 downto 0);
  signal svga_vcount    : std_logic_vector(9 downto 0);
  signal char_row       : std_logic_vector(3 downto 0);
  signal row_offset     : std_logic_vector(14 downto 0);
  signal col_offset     : std_logic_vector(9 downto 0);
  signal screen_addr    : std_logic_vector(14 downto 0);
  signal screen_data    : std_logic_vector(7 downto 0);
  
  -- Screen Mode Registers

  -- the 256 byte page that the mode starts at
  signal mode_base      : std_logic_vector(7 downto 0);
  
  -- the number of bits per pixel (0 = 1BPP, 1 = 2BPP, 2=4BPP)
  signal mode_bpp       : std_logic_vector(1 downto 0);
  
   -- a '1' indicates a text mode (modes 3 and 6)
  signal mode_text      : std_logic;
  
  -- a '1' indicates a 40-col mode (modes 4, 5 and 6)
  signal mode_40        : std_logic;
  
  -- the number of bytes to increment row_offset when moving from one char row to the next
  signal mode_rowstep   : std_logic_vector(9 downto 0);
  
  signal display_field   : std_logic;
  signal display_end     : std_logic;
  signal display_end1    : std_logic;
  signal display_end2    : std_logic;

-- Helper function to cast an std_logic value to an integer
function sl2int (x: std_logic) return integer is
begin
    if x = '1' then
        return 1;
    else
        return 0;
    end if;
end;

-- Helper function to cast an std_logic_vector value to an integer
function slv2int (x: std_logic_vector) return integer is
begin
    return to_integer(unsigned(x));
end;
  
begin

    ram : entity work.RAM_32K_DualPort port map(

      -- Port A is the 6502 port
        clka  => clk_16M00,
        wea   => ram_we,
        addra => addr(14 downto 0),
        dina  => data_in,
        douta => ram_data,

        -- Port B is the VGA Port
        clkb  => clk_svga,
        web   => '0',
        addrb => screen_addr,
        dinb  => x"00",
        doutb => screen_data
    );

    sound <= sound_bit;
    
    -- FIXME: This should probably be gate with a clock enable
    ram_we <= '1' when addr(15) = '0' and R_W_n = '0' else '0';

    -- The external ROM is enabled:
    -- - When the address is C000-FBFF and FF00-FFFF (i.e. OS Rom)
    -- - When the address is 8000-BFFF and the ROM 10 or 11 is paged in (101x)
    ROM_n <= '0' when addr(15 downto 14) = "11" and addr(15 downto 8) /= x"FC" and addr(15 downto 8) /= x"FD" and addr(15 downto 8) /= x"FE" else
             '0' when addr(15 downto 14) = "10" and page_enable = '1' and page(2 downto 1) = "01" else
             '1';
      
    -- ULA Reads + RAM Reads + KBD Reads
    data_out <= ram_data              when addr(15) = '0' else
                "0000" & kbd          when addr(15 downto 14) = "10" and page_enable = '1' and page(2 downto 1) = "00" else
                isr_data              when addr(15 downto 8) = x"FE" and addr(3 downto 0) = x"0" else
                data_shift            when addr(15 downto 8) = x"FE" and addr(3 downto 0) = x"4" else
                x"F1"; -- todo FIXEME

    -- Register FEx0 is the Interrupt Status Register (Read Only)
    -- Bit 7 always reads as 1
    -- Bits 6..2 refect in interrups status regs
    -- Bit 1 is the power up reset bit, cleared by the first read after power up
    -- Bit 0 is the OR of bits 6..2
    master_irq <= isr(6) or isr(5) or isr(4) or isr(3) or isr(2);
    IRQ_n      <= not master_irq; 
    NMI_n      <= not master_nmi;
    isr_data   <= '0' & isr(6 downto 2) & power_on_reset & master_irq;
    
    rom_latch  <= page_enable & page;
   
    -- ULA Writes
    process (clk_16M00, RST_n)
    begin
        if (RST_n = '0') then
           master_nmi   <= '0';

           isr          <= (others => '0');
           ier          <= (others => '0');
           screen_base  <= (others => '0');
           data_shift   <= (others => '0');
           page_enable  <= '0';
           page         <= (others => '0');
           counter      <= (others => '0');
           comms_mode   <= (others => '0');

           rtc_counter   <= (others => '0');
           sound_counter <= (others => '0');
           sound_bit     <= '0';
                            
        elsif rising_edge(clk_16M00) then
            -- Synchronize the display end signal from the VGA clock domain
            display_end1 <= display_end;
            display_end2 <= display_end1;
            -- Generate the display end interrupt on the rising edge (bottom of the screen)
            if (display_end2 = '0' and display_end1 = '1') then
                isr(2) <= ier(2);
            end if;
            -- Generate the 50Hz real time clock interrupt
            if (rtc_counter = 319999) then
                rtc_counter <= (others => '0');
                isr(3) <= ier(3);
            else
                rtc_counter <= rtc_counter + 1;
            end if;
            -- Sound Frequency = 1MHz / [16 * (S + 1)]
            if (comms_mode = "01") then
                if (sound_counter = 0) then
                    sound_counter <= counter & "00000000";
                    sound_bit <= not sound_bit;
                else
                    sound_counter <= sound_counter - 1;
                end if;            
            end if;
            if (cpu_clken = '1') then
                if (addr(15 downto 8) = x"FE") then
                    if (R_W_n = '1') then
                        -- Clear the power on reset flag on the first read of the ISR (FEx0)
                        if (addr(3 downto 0) = x"0") then
                            power_on_reset <= '0';
                        end if;
                        -- Clear the RDFull interrupts on reading the data_shift register
                        if (addr(3 downto 0) = x"4") then
                            isr(4) <= '0';
                        end if;                    
                    else
                        case addr(3 downto 0) is
                        when x"0" =>
                            ier(6 downto 2) <= data_in(6 downto 2);
                        when x"1" =>
                        when x"2" =>
                            screen_base(8 downto 6) <= data_in(7 downto 5);
                        when x"3" =>
                            screen_base(14 downto 9) <= data_in(5 downto 0);
                        when x"4" =>
                            data_shift <= data_in;
                            -- Clear the TDEmpty interrupt on writing the
                            -- data_shift register
                            isr(5) <= '0';
                        when x"5" =>
                            if (data_in(7) = '1') then
                                -- Clear NMI
                                master_nmi <= '0';
                            end if;
                            if (data_in(6) = '1') then
                                -- Clear High Tone Detect IRQ
                                isr(6) <= '0';
                            end if;
                            if (data_in(5) = '1') then
                                -- Clear Real Time Clock IRQ
                                isr(3) <= '0';
                            end if;
                            if (data_in(4) = '1') then
                                -- Clear Display End IRQ
                                isr(2) <= '0';
                            end if;
                            if (page_enable = '1' and page(2) = '0') then
                                -- Roms 8-11 currently selected, so only selecting 8-15 will be honoured
                                if (data_in(3) = '1') then
                                    page_enable <= data_in(3);
                                    page <= data_in(2 downto 0);
                                end if;
                            else
                                -- Roms 0-7 or 12-15 currently selected, so anything goes
                                page_enable <= data_in(3);
                                page <= data_in(2 downto 0);                            
                            end if;
                        when x"6" =>
                            counter <= data_in;
                        when x"7" =>
                            caps         <= data_in(7);
                            motor        <= data_in(6);
                            case (data_in(5 downto 3)) is
                            when "000" =>
                                mode_base    <= x"30";
                                mode_bpp     <= "00";
                                mode_40      <= '0';
                                mode_text    <= '0';
                                mode_rowstep <= std_logic_vector(to_unsigned(633, 10)); -- 640 - 7
                            when "001" =>
                                mode_base    <= x"30";
                                mode_bpp     <= "01";
                                mode_40      <= '0';
                                mode_text    <= '0';
                                mode_rowstep <= std_logic_vector(to_unsigned(633, 10)); -- 640 - 7
                            when "010" =>
                                mode_base    <= x"30";
                                mode_bpp     <= "10";
                                mode_40      <= '0';
                                mode_text    <= '0';
                                mode_rowstep <= std_logic_vector(to_unsigned(633, 10)); -- 640 - 7
                            when "011" =>
                                mode_base    <= x"40";
                                mode_bpp     <= "00";
                                mode_40      <= '0';
                                mode_text    <= '1';
                                mode_rowstep <= std_logic_vector(to_unsigned(631, 10)); -- 640 - 9
                            when "100" =>
                                mode_base    <= x"58";
                                mode_bpp     <= "00";
                                mode_40      <= '1';
                                mode_text    <= '0';
                                mode_rowstep <= std_logic_vector(to_unsigned(313, 10)); -- 320 - 7
                            when "101" =>
                                mode_base    <= x"60";
                                mode_bpp     <= "01";
                                mode_40      <= '1';
                                mode_text    <= '0';
                                mode_rowstep <= std_logic_vector(to_unsigned(313, 10)); -- 320 - 7
                            when "110" =>
                                mode_base    <= x"60";
                                mode_bpp     <= "00";
                                mode_40      <= '1';
                                mode_text    <= '1';
                                mode_rowstep <= std_logic_vector(to_unsigned(311, 10)); -- 320 - 9
                            when "111" =>
                                -- mode 7 seems to default to mode 4
                                mode_base    <= x"58";
                                mode_bpp     <= "00";
                                mode_40      <= '1';
                                mode_text    <= '0';
                                mode_rowstep <= std_logic_vector(to_unsigned(313, 10)); -- 320 - 7
                            when others =>
                            end case;                            
                            comms_mode   <= data_in(2 downto 1);
                        when others =>
                            -- A '1' in the palatte data means disable the colour
                            -- Invert the stored palette, to make the palette logic simpler
                            palette(slv2int(addr(2 downto 0))) <= data_in xor "11111111";
                        end case;
                    end if;
                end if;          
            end if;
        end if;
    end process;

    -- Hard coded for mode 6 at the moment
    -- All modes output SGVA at 60Hz with a 40.000MHz Pixel Clock
    -- Horizontal 800 + 40 + 128 + 88 = total 1056
    -- Vertical   600 +  1 +   4 + 23 = total 628
    -- Within the the 640x512 is centred so starts at 80,44

    -- Horizontal 640 + (80 + 40) + 128 + (88 + 80) = total 1056
    -- Vertical   512 + (44 +  1) +   4 + (23 + 44) = total 628
    
    process (clk_svga)
    variable pixel : std_logic_vector(3 downto 0);
    begin
        if rising_edge(clk_svga) then
            -- pipeline svga_hcount by one cycle to compensate the register in the RAM
            svga_hcount1 <= svga_hcount;
            if (svga_hcount = 1055) then
                svga_hcount <= (others => '0');
                col_offset <= (others => '0');
                if (svga_vcount = 627) then
                    svga_vcount <= (others => '0');
                    char_row <= (others => '0');
                    row_offset <= (others => '0');
                    display_field <= not display_field;                    
                else
                    svga_vcount <= svga_vcount + 1;
                    if (svga_vcount(0) = '1') then
                        if ((mode_text = '0' and char_row = 7) or (mode_text = '1' and char_row = 9)) then
                            char_row <= (others => '0');
                            row_offset <= row_offset + mode_rowstep;
                        else
                            char_row <= char_row + 1;
                            row_offset <= row_offset + 1;
                        end if;
                    end if;
                end if;
            else
                svga_hcount <= svga_hcount + 1;
                if ((mode_40 = '0' and svga_hcount(2 downto 0) = "111") or
                    (mode_40 = '1' and svga_hcount(3 downto 0) = "1111")) then
                    col_offset <= col_offset + 8;
                end if;
            end if;
            -- RGB Data
            if (svga_vcount >= 512) then
                display_end <= display_field;
            else
                display_end <= '0';
            end if;
            if ((svga_hcount1 >= 720 and svga_hcount1 < 976) or (svga_vcount >= 556 and svga_vcount < 584)) then
                -- blanking is always black
                red   <= (others => '0');
                green <= (others => '0');
                blue  <= (others => '0');
            elsif (svga_hcount1 >= 640 or (mode_text = '0' and svga_vcount >= 512) or (mode_text = '1' and svga_vcount >= 500) or char_row >= 8) then
                -- border is always black (TODO, as some point fold this into the previous condition)
                red   <= (others => '0');
                green <= (others => '0');
                blue  <= (others => '0');
            else
                -- rendering an actual pixel
                if (mode_bpp = 0) then
                    -- 1 bit per pixel, map to colours 0 and 8 for the palette lookup
                    if (mode_40 = '1') then
                        pixel := screen_data(7 - slv2int(svga_hcount1(3 downto 1))) & "000";
                    else
                        pixel := screen_data(7 - slv2int(svga_hcount1(2 downto 0))) & "000";
                    end if;
                elsif (mode_bpp = 1) then
                    -- 2 bits per pixel, map to colours 0, 2, 8, 10 for the palette lookup
                    if (mode_40 = '1') then
                        pixel := screen_data(7 - slv2int(svga_hcount1(3 downto 2))) & "0" &
                                 screen_data(3 - slv2int(svga_hcount1(3 downto 2))) & "0";
                    else
                        pixel := screen_data(7 - slv2int(svga_hcount1(2 downto 1))) & "0" &
                                 screen_data(3 - slv2int(svga_hcount1(2 downto 1))) & "0";
                    end if;
                else
                    -- 4 bits per pixel, map directly for the palette lookup
                    if (mode_40 = '1') then
                        pixel := screen_data(7 - sl2int(svga_hcount1(3))) &
                                 screen_data(5 - sl2int(svga_hcount1(3))) &
                                 screen_data(3 - sl2int(svga_hcount1(3))) &
                                 screen_data(1 - sl2int(svga_hcount1(3)));
                    else
                        pixel := screen_data(7 - sl2int(svga_hcount1(2))) &
                                 screen_data(5 - sl2int(svga_hcount1(2))) &
                                 screen_data(3 - sl2int(svga_hcount1(2))) &
                                 screen_data(1 - sl2int(svga_hcount1(2)));
                    end if;
                end if;
                -- Implement Color Palette
                case (pixel) is
                when "0000" =>
                    red   <= (others => palette(1)(0));
                    green <= (others => palette(1)(4));
                    blue  <= (others => palette(0)(4));
                when "0001" =>
                    red   <= (others => palette(7)(0));
                    green <= (others => palette(7)(4));
                    blue  <= (others => palette(6)(4));
                when "0010" =>
                    red   <= (others => palette(1)(1));
                    green <= (others => palette(1)(5));
                    blue  <= (others => palette(0)(5));
                when "0011" =>
                    red   <= (others => palette(7)(1));
                    green <= (others => palette(7)(5));
                    blue  <= (others => palette(6)(5));
                when "0100" =>
                    red   <= (others => palette(3)(0));
                    green <= (others => palette(3)(4));
                    blue  <= (others => palette(2)(4));
                when "0101" =>
                    red   <= (others => palette(5)(0));
                    green <= (others => palette(5)(4));
                    blue  <= (others => palette(4)(4));
                when "0110" =>
                    red   <= (others => palette(3)(1));
                    green <= (others => palette(3)(5));
                    blue  <= (others => palette(2)(5));
                when "0111" =>
                    red   <= (others => palette(5)(1));
                    green <= (others => palette(5)(5));
                    blue  <= (others => palette(4)(5));
                when "1000" =>
                    red   <= (others => palette(1)(2));
                    green <= (others => palette(0)(2));
                    blue  <= (others => palette(0)(6));
                when "1001" =>
                    red   <= (others => palette(7)(2));
                    green <= (others => palette(6)(2));
                    blue  <= (others => palette(6)(6));
                when "1010" =>
                    red   <= (others => palette(1)(3));
                    green <= (others => palette(0)(3));
                    blue  <= (others => palette(0)(7));
                when "1011" =>
                    red   <= (others => palette(7)(3));
                    green <= (others => palette(6)(3));
                    blue  <= (others => palette(6)(7));
                when "1100" =>
                    red   <= (others => palette(3)(2));
                    green <= (others => palette(2)(2));
                    blue  <= (others => palette(2)(6));
                when "1101" =>
                    red   <= (others => palette(5)(2));
                    green <= (others => palette(4)(2));
                    blue  <= (others => palette(4)(6));
                when "1110" =>
                    red   <= (others => palette(3)(3));
                    green <= (others => palette(2)(3));
                    blue  <= (others => palette(2)(7));
                when "1111" =>
                    red   <= (others => palette(5)(3));
                    green <= (others => palette(4)(3));
                    blue  <= (others => palette(4)(7));
                when others =>
                end case;
            end if;              
            -- Vertical Sync
            if (svga_vcount = 556) then
                vsync <= '0';
            elsif (svga_vcount = 560) then
                vsync <= '1';
            end if;
            -- Horizontal Sync
            if (svga_hcount1 = 759) then
                hsync <= '0';
            elsif (svga_hcount1 = 887) then
                hsync <= '1';
            end if;
                    
        end if;        
    end process;
    
    process (screen_base, mode_base, row_offset, col_offset)
        variable tmp: std_logic_vector(15 downto 0);
    begin
        tmp := ("0" & screen_base & "000000") + row_offset + col_offset;
        if (tmp(15) = '1') then
            tmp := tmp + (mode_base & "00000000");
        end if;
        screen_addr <= tmp(14 downto 0);
    end process;
    
end behavioral;

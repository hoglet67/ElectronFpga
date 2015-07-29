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
        clk_svga  : in    std_logic;
        clk_16M00 : in    std_logic;
        ps2_clk   : in    std_logic;
        ps2_data  : in    std_logic;
        ERSTn     : in    std_logic;
        red       : out   std_logic_vector (3 downto 0);
        green     : out   std_logic_vector (3 downto 0);
        blue      : out   std_logic_vector (3 downto 0);
        vsync     : out   std_logic;
        hsync     : out   std_logic;
        audiol    : out   std_logic;
        audioR    : out   std_logic;
        LED1      : out   std_logic;        
        LED2      : out   std_logic
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

    signal rom_basic_data    : std_logic_vector (7 downto 0);
    signal rom_os_data       : std_logic_vector (7 downto 0);
    signal ula_data          : std_logic_vector (7 downto 0);

    signal clken_counter     : std_logic_vector (3 downto 0);
    signal cpu_cycle         : std_logic;
    signal cpu_clken         : std_logic;
      
    signal key_break   : std_logic;
    signal key_turbo   : std_logic_vector(1 downto 0);
    signal sound       : std_logic;
    signal kbd_data   : std_logic_vector(3 downto 0);

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

    rom_basic : entity work.RomBasic2 port map(
        clk     => clk_16M00,
        addr    => cpu_addr(13 downto 0),
        data    => rom_basic_data
    );

    rom_os : entity work.RomOS100 port map(
        clk     => clk_16M00,
        addr    => cpu_addr(13 downto 0),
        data    => rom_os_data
    );
     
    ula : entity work.ElectronULA port map (
        clk_svga  => clk_svga,
        clk_16M00 => clk_16M00,
        
        -- CPU Interface
        cpu_clken => cpu_clken,
        addr      => cpu_addr,
        data_in   => cpu_dout,
        data_out  => ula_data,
        R_W_n     => cpu_R_W_n,
        RST_n     => RSTn,
        IRQ_n     => cpu_IRQ_n,
        NMI_n     => cpu_NMI_n,

        -- Rom Enable
        ROM_n     => ROM_n,
        
        -- SVGA
        red       => red,
        green     => green,
        blue      => blue,
        vsync     => vsync,
        hsync     => hsync,

        -- Audio
        sound     => sound,

        -- Keyboard
        kbd       => kbd_data,

        -- MISC
        caps      => LED1,
        motor     => LED2
    );
        
    input : entity work.keyboard port map(
        clk        => clk_16M00,
        rst_n      => ERSTn, -- to avoid a loop when break pressed!
        ps2_clk    => ps2_clk,
        ps2_data   => ps2_data,
        col        => kbd_data,
        row        => cpu_addr(13 downto 0),
        break      => key_break,
        turbo      => key_turbo
    );

    RSTn    <= ERSTn and key_break;
    audiol  <= sound;
    audior  <= sound;
    cpu_din <= rom_basic_data when ROM_n = '0' and cpu_addr(14) = '0' else
               rom_os_data    when ROM_n = '0' and cpu_addr(14) = '1' else
               ula_data;
    
--------------------------------------------------------
-- clock enable generator
--------------------------------------------------------
    clk_gen : process(clk_16M00, RSTn)
    begin
        if RSTn = '0' then
            clken_counter <= (others => '0');
            cpu_clken <= '0';
        elsif rising_edge(clk_16M00) then
            clken_counter <= clken_counter + 1;
            case (key_turbo) is
                when "01" =>
                    -- 2MHz
                    -- cpu_clken active on cycle 0, 8
                    -- address/data changes on cycle 1, 9
                    cpu_clken <= clken_counter(0) and clken_counter(1) and clken_counter(2);  -- on cycles 0, 8
                when "10" =>
                    -- 4MHz
                    -- cpu_clken active on cycle 0, 4, 8, 12
                    -- address/data changes on cycle 1, 5, 9, 13
                    cpu_clken <= clken_counter(0) and clken_counter(1);
                when "11" =>
                    -- 8MHz
                    -- cpu_clken active on cycle 0, 2, 4, 6, 8, 10, 12, 14
                    -- address/data changes on cycle 1, 3, 5, 7, 9, 11, 13, 15
                    -- NOTE: this case is not ideal, because no matter how you time phi2, one or other
                    -- edge will change at the same time as address/data changes.
                    -- (1) Address Setup at start of write cycle
                    -- (2) Data hold and end of write cycle
                    -- For now we will optimise for (2)
                    cpu_clken <= clken_counter(0);
                when others =>
                    -- 1MHz
                    -- cpu_clken active on cycle 0
                    -- address/data changes on cycle 1
                    -- phi2 active on cycle 2..9
                    cpu_clken <= clken_counter(0) and clken_counter(1) and clken_counter(2) and clken_counter(3);
            end case;
        end if;
    end process;
    
end behavioral;



--------------------------------------------------------------------------------
-- Copyright (c) 2015 David Banks
--------------------------------------------------------------------------------
--   ____  ____ 
--  /   /\/   / 
-- /___/  \  /    
-- \   \   \/    
--  \   \         
--  /   /         Filename  : ElectronFpga_duo.vhf
-- /___/   /\     Timestamp : 28/07/2015
-- \   \  /  \ 
--  \___\/\___\ 
--
--Design Name: ElectronFpga_duo
--Device: Spartan6 LX9

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ElectronFpga_duo is
    port (
        clk_32M00      : in    std_logic;
        ps2_clk        : in    std_logic;
        ps2_data       : in    std_logic;
        ERST           : in    std_logic;
        red            : out   std_logic_vector (3 downto 0);
        green          : out   std_logic_vector (3 downto 0);
        blue           : out   std_logic_vector (3 downto 0);
        vsync          : out   std_logic;
        hsync          : out   std_logic;
        audioL         : out   std_logic;
        audioR         : out   std_logic;
        casIn          : in    std_logic;
        casOut         : out   std_logic;
        LED1           : out   std_logic;
        LED2           : out   std_logic;
        ARDUINO_RESET  : out   std_logic;
        SW1            : in    std_logic;
        SDMISO         : in    std_logic;
        SDSS           : out   std_logic;
        SDCLK          : out   std_logic;
        SDMOSI         : out   std_logic;
        DIP            : in    std_logic_vector(1 downto 0);
        test           : out   std_logic_vector(7 downto 0)
     );
end;

architecture behavioral of ElectronFpga_duo is

    signal clk_16M00      : std_logic;
    signal clk_33M33      : std_logic;
    signal clk_40M00      : std_logic;
    signal ERSTn          : std_logic;     
    signal pwrup_RSTn     : std_logic;
    signal reset_ctr      : std_logic_vector (7 downto 0) := (others => '0');

    signal rom_basic_data : std_logic_vector (7 downto 0);
    signal rom_os_data    : std_logic_vector (7 downto 0);
    signal rom_mmc_data   : std_logic_vector (7 downto 0);

    signal ext_A          : std_logic_vector (18 downto 0);
    signal ext_Din        : std_logic_vector (7 downto 0);
    signal ext_Dout       : std_logic_vector (7 downto 0);
    signal ext_nWE        : std_logic;
    signal ext_nOE        : std_logic;
    
begin

    inst_dcm4 : entity work.dcm4 port map(
        CLKIN_IN          => clk_32M00,
        CLK0_OUT          => clk_40M00,
        CLK0_OUT1         => open,
        CLK2X_OUT         => open
    );

    inst_dcm5 : entity work.dcm5 port map(
        CLKIN_IN          => clk_32M00,
        CLK0_OUT          => clk_16M00,
        CLK0_OUT1         => open,
        CLK2X_OUT         => open
    );

    inst_dcm6 : entity work.dcm6 port map(
        CLKIN_IN          => clk_32M00,
        CLK0_OUT          => clk_33M33,
        CLK0_OUT1         => open,
        CLK2X_OUT         => open
    );

    rom_basic : entity work.RomBasic2 port map(
        clk     => clk_16M00,
        addr    => ext_A(13 downto 0),
        data    => rom_basic_data
    );

    rom_os : entity work.RomOS100 port map(
        clk     => clk_16M00,
        addr    => ext_A(13 downto 0),
        data    => rom_os_data
    );

    rom_mmc : entity work.RomSmelk3006 port map(
        clk     => clk_16M00,
        addr    => ext_A(13 downto 0),
        data    => rom_mmc_data
    );

    ext_Dout <= rom_os_data    when ext_A(18 downto 15) = "0100" else
                rom_basic_data when ext_A(18 downto 15) = "0101" else
                rom_mmc_data   when ext_A(18 downto 14) = "00111" else
                x"AA";
    
    inst_ElectronFpga_core : entity work.ElectronFpga_core
     port map (
        clk_16M00         => clk_16M00,
        clk_33M33         => clk_33M33,
        clk_40M00         => clk_40M00,
        hard_reset_n      => ERSTn,
        ps2_clk           => ps2_clk,
        ps2_data          => ps2_data,
        video_red         => red,
        video_green       => green,
        video_blue        => blue,
        video_vsync       => vsync,
        video_hsync       => hsync,
        audio_l           => audioL,
        audio_r           => audioR,
        ext_nOE           => ext_nOE,
        ext_nWE           => ext_nWE,
        ext_A             => ext_A,
        ext_Dout          => ext_Dout,
        ext_Din           => ext_Din,
        SDMISO            => SDMISO,
        SDSS              => SDSS,
        SDCLK             => SDCLK,
        SDMOSI            => SDMOSI,
        caps_led          => LED1,
        motor_led         => LED2,
        cassette_in       => casIn,
        cassette_out      => casOut,
        vid_mode          => DIP,
        test              => test
    );  
    
    ERSTn      <= pwrup_RSTn and not ERST;
    ARDUINO_RESET <= SW1;

    -- On the Duo the external reset signal is not asserted on power up
    -- This internal counter forces power up reset to happen
    -- This is needed by the GODIL to initialize some of the registers
    ResetProcess : process (clk_16M00)
    begin
        if rising_edge(clk_16M00) then
            if (pwrup_RSTn = '0') then
                reset_ctr <= reset_ctr + 1;
            end if;
        end if;
    end process;
    pwrup_RSTn <= reset_ctr(7);
    
end behavioral;



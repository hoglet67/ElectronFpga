library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity RAM_DualPort is
    generic (
        DEPTH : integer;
        AWIDTH : integer;
        DWIDTH : integer
        );
    port (
        clk   : in  std_logic;
        cea   : in  std_logic := '1';
        wea   : in  std_logic;
        addra : in  std_logic_vector(AWIDTH - 1 downto 0);
        dina  : in  std_logic_vector(DWIDTH - 1 downto 0);
        douta : out std_logic_vector(DWIDTH - 1 downto 0);
        ceb   : in  std_logic := '1';
        addrb : in  std_logic_vector(AWIDTH - 1 downto 0);
        doutb : out std_logic_vector(DWIDTH - 1 downto 0)
        );
end;

architecture behavioral of RAM_DualPort is

    type ram_type is array (0 to DEPTH - 1) of std_logic_vector (DWIDTH - 1 downto 0);
    signal RAM : ram_type;

begin

    process (clk)
    begin
        if rising_edge(clk) then
            if cea = '1' then
                if wea = '1' then
                    RAM(conv_integer(addra)) <= dina;
                else
                    douta <= RAM(conv_integer(addra));
                end if;
            end if;
            if ceb = '1' then
                doutb <= RAM(conv_integer(addrb));
            end if;
        end if;
    end process;

end behavioral;

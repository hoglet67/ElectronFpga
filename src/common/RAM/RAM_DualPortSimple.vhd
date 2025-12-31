library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity RAM_DualPortSimple is
    generic (
        DEPTH : integer;
        AWIDTH : integer;
        DWIDTH : integer
        );
    port (
        clka  : in  std_logic;
        wea   : in  std_logic := '0';
        addra : in  std_logic_vector(AWIDTH - 1 downto 0);
        dina  : in  std_logic_vector(DWIDTH - 1 downto 0) := (others => '0');
        clkb  : in  std_logic;
        addrb : in  std_logic_vector(AWIDTH - 1 downto 0);
        doutb : out std_logic_vector(DWIDTH - 1 downto 0)
        );
end;

architecture behavioral of RAM_DualPortSimple is

    type ram_type is array (0 to DEPTH - 1) of std_logic_vector (DWIDTH - 1 downto 0);
    shared variable RAM : ram_type;

    signal addrb_reg : std_logic_vector(AWIDTH - 1 downto 0);
begin

    -- Port A
    process(clka)
    begin
        if rising_edge(clka) then
            if wea = '1' then
                RAM(conv_integer(addra)) := dina;
            end if;
        end if;
    end process;

    -- Port B
    process(clkb)
    begin
        if rising_edge(clkb) then
            doutb <= RAM(conv_integer(addrb_reg));
            addrb_reg <= addrb;
        end if;
    end process;

end behavioral;

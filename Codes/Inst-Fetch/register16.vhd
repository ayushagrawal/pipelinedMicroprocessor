library ieee;
use ieee.std_logic_1164.all;

entity register16 is
		port(dataIn: in std_logic_vector(15 downto 0);
			  enable: in std_logic;
			  dataOut: out std_logic_vector(15 downto 0);
			  clock: in std_logic;
			  reset: in std_logic);
	end entity;

architecture reg of register16 is
begin
	process(clock,enable)
		variable data: std_logic_vector(15 downto 0);
	begin
		if(clock'event and clock = '1') then
			if(reset = '1') then
				data := x"0000";
			elsif(enable = '1') then
				data := dataIn;
			end if;
			dataOut <= data;
		end if;
	end process;
end;

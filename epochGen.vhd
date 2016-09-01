----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Jason Murphy
-- 
-- Create Date:    16:35:45 03/20/2016 
-- Design Name: 
-- Module Name:    EpochGen - Behavioral 
-- Project Name: 		
-- Target Devices: 
-- Tool versions: 	ISE 14.7
-- Description: 	64 bit UNIX Epoch Time Gen
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
-- 3PPM 50mHZ clk tolerance < 1 sec / 4 days
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity epochGen is port (
	clk50 : in std_logic;
	epochTime : out std_logic_vector(31 downto 0);
	cmdReg : in std_logic_vector(7 downto 0));
end entity;

architecture Behavioral of epochGen is

signal div50 : integer range 0 to 50;
signal epochSig : std_logic_vector(31 downto 0);

begin
process(clk50) is
begin
	if rising_edge(clk50) then
		div50 <= div50 + 1;
		if div50 = 49 then
			epochSig <= epochSig + 1;
			if epochSig = X"D693A400" then
				epochSig <= X"00000000";
			end if;
			div50 <= 0;
			if cmdReg = "00000010" then
				epochSig <= X"00000000";
			end if;
		end if;
	end if;
end process;
epochTime <= epochSig(7 downto 0) & epochSig(15 downto 8) & epochSig(23 downto 16) & epochSig(31 downto 24);
end Behavioral;

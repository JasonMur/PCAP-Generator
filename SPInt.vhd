----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Jason Murphy
-- 
-- Create Date:    15:34:20 02/13/2016 
-- Design Name: 
-- Module Name:    SPInt - Behavioral 
-- Project Name: 
-- Target Devices: Spartan 6 on LogiPi
-- Tool versions: ISE 14.7
-- Description: SPI to 32 bit data bus read write interface
-- 
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity SPInt is Port (
		SCK  : in  std_logic;    -- SPI input clock
		MOSI : in  std_logic;    -- SPI serial data input
		MISO : out std_logic;
		CEON   : in  std_logic;   -- is the SPI bus ready for new data?
		dataIn : in std_logic_vector(31 downto 0); -- word read from SDRAM Fifo
		dataRdy : out std_logic);	--are we ready for new parallel data?
end SPInt;

architecture Behavioral of SPInt is

signal bitCount : std_logic_vector(4 downto 0) := "00000";
signal MISOReg : std_logic_vector(31 downto 0);

begin
	
process(SCK, CEON)
begin
	
	if CEON = '0' and falling_edge(SCK) then
		bitCount<=bitCount+1;
		
		if bitCount = "11111" then
			dataRdy<='1';
			MISOReg<=dataIn(30 downto 0) & '0';
			MISO<=dataIn(31);
		else
			MISO<=MISOReg(31);
			MISOReg<=MISOReg(30 downto 0) & '0';
		end if;
		
		if bitCount = "11110" then
			dataRdy <= '0';
		end if;
	end if;
	if CEON = '1' then
		bitCount(2 downto 0) <= "000";
	end if;
end process;	

end Behavioral;

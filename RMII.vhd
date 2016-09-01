----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Jason Murphy
-- 
-- Create Date:    15:45:07 02/27/2016 
-- Design Name: 
-- Module Name:    RMII - Behavioral 
-- Project Name: 		
-- Target Devices: 
-- Tool versions: 	ISE 14.7
-- Description: 	Phy RMII interface generating 32 bit data packets with Unix Epoch 64 bit time marker
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

entity RMII is port (
	clk50 : in std_logic;
	RxD : in std_logic_vector(1 downto 0);
	CRS_DV : in std_logic;
	MACData : out std_logic_vector(31 downto 0);
	DAV : out std_logic;
	epoch : in std_logic_vector(31 downto 0);
	startOfPckt : out std_logic);
end entity;

architecture Behavioral of RMII is
constant SFD : std_logic_vector(31 downto 0) := x"D5555555";
signal dataDWord : std_logic_vector(63 downto 0);
signal diBitCount : integer range 0 to 15;
type cmdSequence is (idle, detectPreamble, writeEpoch, frameStart, frameEnd, clearBuffer, error);
signal currentState: cmdSequence := idle;
signal RxDSig : std_logic_vector(1 downto 0);

begin
process(clk50) is
begin
	if rising_edge(clk50) then
		
		if CRS_DV = '1' then
			RxDSig <= RxD;
		else
			RxDSig <= "00";
		end if;
		dataDWord <= RxDSig & dataDWord(63 downto 2);
		diBitCount <= diBitCount + 1;
		if diBitCount = 15 then
			DAV <= '0';
			startOfPckt <= '0';
		end if;
		case currentState is
		when idle =>
			if CRS_DV = '0' then
				currentState <= detectPreamble;
			end if;
		when detectPreamble =>
			if dataDWord(63 downto 32) = SFD then
				DAV <= '1';
				MACData <= X"50636B74";
				currentState <= writeEpoch;
				diBitCount <= 1;
			end if;
		when writeEpoch =>
			if diBitCount = 0 then
				DAV <= '1';
				MACData <= epoch;
				startOfPckt <= '1';
				currentState <= frameStart;
			end if;
		when frameStart =>
			if CRS_DV = '1' then
				if diBitCount = 0 then
					MACData <= dataDWord(7 downto 0) & dataDword(15 downto 8) & dataDWord(23 downto 16) & dataDWord(31 downto 24);
					DAV <= '1';
				end if;
			else
				currentState <= frameEnd;
			end if;
		when frameEnd =>
			if diBitCount = 0 then
				MACData <= dataDWord(7 downto 0) & dataDword(15 downto 8) & dataDWord(23 downto 16) & dataDWord(31 downto 24);
				DAV <= '1';
				currentState <= clearBuffer;
			end if;
		when clearBuffer =>
			if diBitCount = 0 then
				MACData <= dataDWord(7 downto 0) & dataDword(15 downto 8) & dataDWord(23 downto 16) & dataDWord(31 downto 24);
				DAV <= '1';
				currentState <= detectPreamble;
			end if;
		when others =>
			currentState <= idle;
		end case;
	end if;
end process;
end Behavioral;


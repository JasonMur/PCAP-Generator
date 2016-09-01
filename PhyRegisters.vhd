----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 			Jason Murphy
-- 
-- Create Date:   	09:00 01/27/2016 
-- Design Name: 
-- Module Name:    	PhyRegisters - Behavioral 
-- Project Name: 	 	PhyProject
-- Target Devices: 
-- Tool versions:  	ISE 14.7
-- Description: 	 	C&C Interface for Net Phy serial and parallel
--                   reg's inc. standard Phy, Time and Addr and Fifo ctrl
--
-- Dependencies:   	Designed to interface with I2CInt on LogiPi
--
-- Revision: 			V1.0 Tested
-- Revision 			0.01 - File Created
-- Additional Comments: 
--
--Notes
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity PhyRegisters is port (
	regAddr, regDataIn : in std_logic_vector(7 downto 0);
	regDataOut : out std_logic_vector(7 downto 0);
	writeData, clk100, readData : in std_logic;
	MDIO : inout std_logic;
	MDC, Bsy : out std_logic;
	fifoWritePtr, fifoReadPtr : in std_logic_vector(31 downto 0);
	cmdReg : out std_logic_vector(7 downto 0));
end PhyRegisters;

architecture Behavioral of PhyRegisters is
signal writeDataSig : std_logic_vector(1 downto 0);
signal readDataSig : std_logic_vector(1 downto 0);
signal MDIOReg : std_logic_vector(31 downto 0);
signal oneShot : integer range 0 to 32;
signal bitCount : std_logic_vector(8 downto 0):= (others => '0');
signal phyAddr : std_logic_vector(4 downto 0) := "01100";
signal regDataFromPhy : std_logic_vector(15 downto 0);
signal regDataFromI2C : std_logic_vector(7 downto 0);
signal fifoWritePtrSig, fifoReadPtrSig, epochSig : std_logic_vector(23 downto 0);

begin
	process(clk100, bitCount) is
	begin
		if rising_edge(clk100) then	
			writeDataSig <= writeDataSig(0) & writeData;	--Debounce 
			readDataSig <= readDataSig(0) & readData;		--Debounce
			bitCount <= bitCount + 1;
			if bitCount = x"1FF" then				 	--On falling edge of MDC
				if oneShot < 32 then								--One shot increment through 32 bits
					oneShot <= oneShot + 1;						
					regDataFromPhy <= regDataFromPhy(14 downto 0) & MDIO; --Get data from the Phy 
					regDataOut <= regDataFromPhy(6 downto 0) & MDIO; 				-- write the first byte to the output register
				else																		--One Shot complete
					Bsy <= '0';															--So not busy
				end if;
				if MDIOReg(31) = '0' then						--Output all '0's from the register
					MDIO <= '0';
				else													--Output all '1's from the register
					MDIO <= 'Z';
				end if;
				MDIOReg <= MDIOReg(30 downto 0) & 'Z';
			end if;
			if writeDataSig = "10" then						--Write command received
				if regAddr(7) = '0' then
					if regAddr = x"7F" then					--Interface set up commands
						phyAddr <= regDataIn(4 downto 0);		--Set the controller address
					elsif regAddr(0) = '0' then					--If this is the first Byte
						regDataFromI2C <= regDataIn;				--Load first byte into reg
					else													--If second byte
						MDIOReg <= "0101" & phyAddr & regAddr(5 downto 1) & "10" & regDataIn & regDataFromI2C; --Load the rest of the register
						Bsy <= '1';										--Indicate we are busy
						oneShot <= 0;
					end if;
				else
					case regAddr is
					when x"80" =>
						cmdReg <= regDataIn;
					--when x"90" =>
					--	epochSig(7 downto 0) <= regDataIn;
					--	newEpoch <= '0';
					--when x"91" =>
					--	epochSig(15 downto 8) <= regDataIn;
					--when x"92" =>
					--	epochSig(23 downto 16) <= regDataIn;
					--when x"93" =>
					--	epoch <= regDataIn&epochSig;
					--	newEpoch <= '1';
					when others => null;
					end case;
				end if;
			end if;
			if readDataSig = "10" then							--If read command received
				if regAddr(7) = '0' then
					if regAddr(0) = '0' then						--and it's the first byte
						MDIOReg(31 downto 0) <= "0110" & phyAddr & regAddr(5 downto 1) & "ZZZZZZZZZZZZZZZZZZ"; --Load the register
						Bsy <= '1';										--Tell the I2C Interface we are busy
						oneShot <= 0;
					else													--If it's the second byte
						regDataOut <= regDataFromPhy(15 downto 8); --send it to the output register
					end if;
				else
					case regAddr is
					when x"90" =>
						regDataOut <= fifoWritePtr(7 downto 0);
						fifoWritePtrSig <= fifoWritePtr(31 downto 8);
					when x"91" =>
						regDataOut <= fifoWritePtrSig(7 downto 0);
					when x"92" =>
						regDataOut <= fifoWritePtrSig(15 downto 8);
					when x"93" =>
						regDataOut <= fifoWritePtrSig(23 downto 16);
					when x"A0" =>
						regDataOut <= fifoReadPtr(7 downto 0);
						fifoReadPtrSig <= fifoReadPtr(31 downto 8);
					when x"A1" =>
						regDataOut <= fifoReadPtrSig(7 downto 0);
					when x"A2" =>
						regDataOut <= fifoReadPtrSig(15 downto 8);
					when x"A3" =>
						regDataOut <= fifoReadPtrSig(23 downto 16);
					when others => null;
					end case;
				end if;
			end if;
		end if;
		MDC <= bitCount(8);  --Generate output the clock to the Phy
	end process;
end Behavioral;
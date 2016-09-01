----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Jason Murphy
-- 
-- Create Date:    15:34:20 02/13/2016 
-- Design Name: 
-- Module Name:    FIFOSync - Behavioral 
-- Project Name: 
-- Target Devices: Spartan 6 on LogiPi
-- Tool versions: ISE 14.7
-- Description: 	SDRAM circular buffer writing and reading 32 bit wide data
--	
--  
-- Dependencies: Interfaces with Mike Field's SDRAM controller @ <hamster@snap.net.nz>
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

entity FIFOSync is generic (
      address_width : natural);
Port (
	clk100 : in std_logic;
	address : out  std_logic_vector(address_width-2 downto 0); -- SDRAM address to read/write
	wr : out  std_logic;  -- SDRAM write not(read) signal
	cmdEnable : out  std_logic;  -- Set to '1' to issue new SDRAM command (only acted on when cmd_read = '1')
	cmdRdy : in std_logic;  -- '1' when SDRAM is ready to receive a command
	byteEnable : out  std_logic_vector(3 downto 0);  -- SDRAM byte masks for the write command (4 bytes = 32 bit word)
	writeDataOut, readDataOut : out  std_logic_vector(31 downto 0); -- write data to RAM and read data to external interface
	readDataIn, writeDataIn : in std_logic_vector(31 downto 0); -- data read from SDRAM and write data from external interface
	readEnable, writeEnable : in std_logic; -- Signals indicating extenral interfaces are ready to write or read data
	fifoWritePtr,fifoReadPtr : out std_logic_vector(31 downto 0); -- external circular buffer pointers
	startOfPckt : in std_logic; --signal indicating end of sequence of data (write buffer is updated at end of a sequence -set permanently high for continuous increment)
	cmdReg : in std_logic_vector(7 downto 0)); -- register for special Fifo commands (only two currently in use 0x0F = reset write buffer pointer and 0xF0 = reset read buffer pointer)
end FIFOSync;

architecture Behavioral of FIFOSync is

type cmdSequence is (idle, startRead, readLSW, readMSW, startWrite, writeLSW, writeMSW, skip);
signal currentState : cmdSequence := idle;  --current state declaration.
signal readCol, writeCol : std_logic_vector(7 downto 0) := (others => '0');
signal readRow, writeRow : std_logic_vector(12 downto 0) := (others => '0');
signal readBank, writeBank : std_logic_vector(1 downto 0) := (others => '0');
signal writeEnableReg, readEnableReg, startOfPcktReg : std_logic_vector(1 downto 0);
signal readDataFlag, writeDataFlag, startOfPcktFlag : std_logic;
signal fifoFillSig : std_logic_vector(32-address_width downto 0) := (others => '0');

begin
	
	process(clk100)
	begin
		if rising_edge(clk100) then
			writeEnableReg <= writeEnableReg(0) & writeEnable;
			readEnableReg <= readEnableReg(0) & readEnable;
			startOfPcktReg <= startOfPcktReg(0) & startOfPckt;
			
			if writeEnableReg = "01" then
				writeDataFlag <= '1';
				if startOfPcktReg = "01" then
					startOfPcktFlag <= '1';
				end if;
			end if;
			
			if readEnableReg = "01" then
				readDataFlag <= '1';
			end if;
			
			cmdEnable <= '0';
			case currentState is
			when startWrite =>
				if cmdRdy = '1' then
					cmdEnable <= '1';
					writeDataOut <= writeDataIn;
					wr <= '1';
					address <= writeRow&writeBank&writeCol;
					writeCol <= writeCol + 1;
					if writeCol = x"FF" then
						writeRow <= writeRow + 1;
						if writeRow = x"1FFF" then
							writeBank <= writeBank + 1;
						end if;
					end if;
					currentState <= writeLSW;
				end if;	
			when writeLSW =>
				currentState <= writeMSW;
			when writeMSW =>
				currentState <= skip;
			when skip =>
				currentState <= idle;
			when startRead =>
				if cmdRdy = '1' then
					wr <= '0';
					cmdEnable <= '1';
					address <= readRow&readBank&readCol;
					readCol <= readCol + 1;
					if readCol = x"FF" then
						readRow <= readRow + 1;
						if readRow = x"1FFF" then
							readBank <= readBank + 1;
						end if;
					end if;
					currentState <= readLSW;
				end if;
			when readLSW =>
				if cmdRdy = '1' then
					readDataOut <= readDataIn;
					currentState <= readMSW;
				end if;
			when readMSW =>
				currentState <= idle;
			when others =>
				if readDataFlag = '1' then
					readDataFlag <= '0';
					--if writeRow = readRow and writeBank = readBank and writeCol = readCol then
					--	fifoReadPtr(31) <= '1'; --FIFO is Empty (underrun error)
					--else
						fifoReadPtr <= fifoFillSig&readBank&readRow&readCol;
						currentState <= startRead;
					--end if;
				elsif writeDataFlag = '1' then
					writeDataFlag <= '0';
				--	if writeRow = readRow and writeBank = readBank and (writeCol+'1') = readCol then
				--		fifoWritePtr(31) <= '1'; --FIFO is Full (overrun error)
				--	else
						currentState <= startWrite;
						if startOfPcktFlag = '1' then
							fifoWritePtr <= fifoFillSig&writeBank&writeRow&writeCol;
							startOfPcktFlag <= '0';
						end if;
				--	end if;
				end if;
				if cmdReg = "00000001" then --Reset Fifo
					writeCol <= "00000000";
					writeRow <= "0000000000000";
					writeBank <= "00";
					fifoWritePtr <= "00000000000000000000000000000000";
					readCol <= "00000000";
					readRow <= "0000000000000";
					readBank <= "00";
					fifoReadPtr <= "00000000000000000000000000000000";
					currentState <= idle;
				end if;
			end case;
		end if ;
	end process;	
	byteEnable <= "1111";
end Behavioral;
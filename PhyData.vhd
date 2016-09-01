----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 			Jason Murphy
-- 
-- Create Date:    	17:05:56 03/20/2016 
-- Design Name: 
-- Module Name:    	PhyData.vhd - Behavioral 
-- Project Name: 
-- Target Devices: 	Spartan 6 on LogiPi
-- Tool versions: 	ISE 14.7
-- Description: 		Reads 32 bit data from RMII Phy Interface and 
--							writes data to SPI interface via SDRAM Fifo
--							
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity PhyData is
     Generic (address_width : natural);
      Port ( 		
			clk50, clk100 : in std_logic;
			address : out  std_logic_vector(address_width-2 downto 0); -- address to read/write
			wr : out  std_logic;                     -- Is this a write?
			cmdEnable : out  std_logic;  -- Set to '1' to issue new command (only acted on when cmd_read = '1')
			cmdRdy : in std_logic;  -- '1' when a new command will be acted on
			byteEnable : out  std_logic_vector(3 downto 0);  -- byte masks for the write command
			dataOut : out  std_logic_vector(31 downto 0); -- data for the write command
			dataIn : in std_logic_vector(31 downto 0); -- word read from SDRAM
			dataInRdy : in std_logic;
			
			SCK  : in  std_logic;    -- SPI input clock
			MOSI : in  std_logic;    -- SPI serial data input
			MISO : out std_logic;
			CEON   : in  std_logic;    -- chip select input (active low)
			
			RxD : in std_logic_vector(1 downto 0);
			CRS_DV : in std_logic;
			fifoWritePtr, fifoReadPtr : out std_logic_vector(31 downto 0);
			cmdReg : in std_logic_vector(7 downto 0));     
end PhyData;

architecture Behavioral of PhyData is

component SPInt is Port (
		SCK  : in  std_logic;    -- SPI input clock
		MOSI : in  std_logic;    -- SPI serial data input
		MISO : out std_logic;
		CEON   : in  std_logic;   -- is new data ready?dataOut : out  STD_LOGIC_VECTOR(31 downto 0); -- data for the write command
		dataIn : in std_logic_vector(31 downto 0); -- word read from SDRAM
		dataRdy : out std_logic);	
end component;

component RMII is port (
	clk50 : in std_logic;
	RxD : in std_logic_vector(1 downto 0);
	CRS_DV : in std_logic;
	MACData : out std_logic_vector(31 downto 0);
	DAV : out std_logic;
	epoch : in std_logic_vector(31 downto 0);
	startOfPckt : std_logic);
end component;

component epochGen is port (
	clk50 : in std_logic;
	epochTime : out std_logic_vector(31 downto 0);
	cmdReg : in std_logic_vector(7 downto 0));
end component;

component FIFOSync is generic (
      address_width : natural);
Port (
	clk100 : in std_logic;
	address : out  std_logic_vector(address_width-2 downto 0); -- address to read/write
	wr : out  std_logic;                     -- Is this a write?
	cmdEnable : out  std_logic;  -- Set to '1' to issue new command (only acted on when cmd_read = '1')
	cmdRdy : in std_logic;  -- '1' when a new command will be acted on
	byteEnable : out  std_logic_vector(3 downto 0);  -- byte masks for the write command
	writeDataOut, readDataOut : out  std_logic_vector(31 downto 0); -- data for the write command
	readDataIn, writeDataIn : in std_logic_vector(31 downto 0); -- word read from SDRAM
	readEnable, writeEnable : in std_logic;
	fifoWritePtr, fifoReadPtr : out std_logic_vector(31 downto 0);
	startOfPckt : in std_logic;
	cmdReg : in std_logic_vector(7 downto 0));
end component;


signal sigSPIDataOut, sigSPIDataIn : std_logic_vector(31 downto 0);
signal sigSPIDataRdy : std_logic;
signal sigRMIIDataOut, sigRMIIDataIn : std_logic_vector(31 downto 0);
signal sigRMIIDataRdy : std_logic;
signal epochTimeSig : std_logic_vector(31 downto 0);
signal startOfPcktSig : std_logic;
begin    

Inst_SPInt: SPInt
  Port map (
	SCK => SCK,
	MOSI => MOSI,
	MISO => MISO,
	CEON => CEON,
	dataIn => sigSPIDataIn,
	dataRdy => sigSPIDataRdy);
		
Inst_RMII: RMII 
Port map (
	clk50 => clk50,
	RxD => RxD,
	CRS_DV => CRS_DV,
	MACData => sigRMIIDataOut,
	DAV => sigRMIIDataRdy,
	epoch => epochTimeSig,
	startOfPckt => startOfPcktSig);
	
Inst_epochGen: epochGen
port map (
	clk50 => clk50,
	epochTime => epochTimeSig,
	cmdReg => cmdReg);
		
Inst_FIFOSync: FIFOSync
generic map (address_width => address_width)
Port map(
	clk100 => clk100,
	address => address,
	wr => wr,
	cmdEnable => cmdEnable,
	cmdRdy => cmdRdy,
	byteEnable => byteEnable,
	writeDataOut => dataOut,
	readDataOut => sigSPIDataIn,
	readDataIn => dataIn,
	writeDataIn => sigRMIIDataOut,
	readEnable => sigSPIDataRdy,
	writeEnable => sigRMIIDataRdy,
	fifoWritePtr => fifoWritePtr,
	fifoReadPtr => fifoReadPtr,
	startOfPckt => startOfPcktSig,
	cmdReg => cmdReg);

end Behavioral;
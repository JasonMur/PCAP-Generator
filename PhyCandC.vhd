----------------------------------------------------------------------------------
-- Engineer: 				Jason Murphy
-- Create Date:    		13:06:42 01/27/2016
-- Design Name: 			
-- Module Name:    		PhyCandC - Behavioral 
-- Project Name: 			PHY
-- Target Devices: 		Spartan 6 (xc6slx9-3tqg144)
-- Tool versions: 		ISE 14.7
-- Description: 			Module implementing I2C interface to read and write all C&C registers
-- Dependencies: 			
-- Revision: 				V1.0 Tested
-- Revision 				0.01 - File Created
-- Additional Comments: 
--	MSByte order differs between I2C Word and Block Data Transmission
--	i.e.[i2cset 0x62 0x01 0xABCD w]
--	and [i2cset 0x62 0x01 0xCD 0xAB i]
--	will both send binary data 0xABCD 
--	i.e. "<ST><OP><Addr><Reg><TA>1010101111001101"
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity PhyCandC is port( 
	MDIO : inout std_logic;
	MDC : out std_logic;
	clk100 : in std_logic; 
	sda : inout std_logic;
	sck : inout std_logic;
	sdaTest, sckTest, BsyTest : out std_logic;
	fifoWritePtr, fifoReadPtr : in std_logic_vector(31 downto 0);
	cmdReg : out std_logic_vector(7 downto 0));
end PhyCandC;

architecture Behavioral of PhyCandC is

component I2CInt port( 
	sda, sck : inout std_logic;
	clk100 : in std_logic; 
	Bsy : in std_logic;
	regAddr : out std_logic_vector (7 downto 0);
	regDataIn : in std_logic_vector (7 downto 0);
	regDataOut : out std_logic_vector (7 downto 0);
	readData, writeData : out std_logic;
	sdaTest, sckTest : out std_logic); 
end component;

component PhyRegisters port(
	regAddr, regDataIn : in std_logic_vector(7 downto 0);
	regDataOut : out std_logic_vector(7 downto 0);
	writeData, clk100, readData : in std_logic;
	MDIO : inout std_logic;
	MDC : out std_logic;
	Bsy : out std_logic;
	fifoWritePtr, fifoReadPtr : in std_logic_vector(31 downto 0);
	cmdReg : out std_logic_vector(7 downto 0));
end component;

signal regDataInSig, regDataOutSig : std_logic_vector (7 downto 0);
signal regAddrSig : std_logic_vector (7 downto 0);
signal writeDataSig, readDataSig, sckSig, BsySig : std_logic;

begin

I2C1 : I2CInt port map
(
	sda => sda,
	sck => sck,
	Bsy => BsySig,
	clk100 => clk100, 
	regAddr => regAddrSig,
	regDataIn => regDataInSig,
	regDataOut => regDataOutSig,
	readData => readDataSig,
	writeData => writeDataSig,
	sdaTest => sdaTest,
	sckTest => sckTest
);
  
 PhyRegisters1 : PhyRegisters port map
 (
	regAddr => regAddrSig,
	regDataIn => regDataOutSig,
	regDataOut => regDataInSig,
	writeData => writeDataSig,
	clk100 => clk100,
	readData => readDataSig,
	MDIO => MDIO,
	MDC => MDC,
	Bsy => BsySig,
	fifoWritePtr => fifoWritePtr,
	fifoReadPtr => fifoReadPtr,
	cmdReg => cmdReg
 );
 
BsyTest <= BsySig;
end Behavioral;
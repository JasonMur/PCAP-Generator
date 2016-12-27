/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

/* 
 * File:   main.cpp
 * LogiPi Phy interface 
 * Created on 01 May 2016
 * Author Jason Murphy
 */

#include <stdio.h> 
#include <errno.h> 
#include <stdlib.h> 
#include <stdint.h> 
#include <fcntl.h> 
#include <unistd.h> 
#include <sys/ioctl.h> 
#include <string.h>
#include <linux/types.h> 
#include <linux/spi/spidev.h> 
#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <endian.h>
#include <time.h>
#include "phy.h"
/*
uint32_t htobe32(uint32_t host_32bits);           // host to big-endian encoding
uint32_t htole32(uint32_t host_32bits);           // host to lil-endian encoding
uint32_t be32toh(uint32_t big_endian_32bits);     // big-endian to host encoding
uint32_t le32toh(uint32_t little_endian_32bits);  // lil-endian to host encoding
*/

#define SPI_MAX_READ_SIZE 0x1000 // Number of bytes that can be read via the SPI interface per read request
#define PCKT_BUFF_SIZE 0x2000  // Size of the packet Buffer
#define FIFO_SIZE 0x800000   //Physical size of FIFO on LogiPi
#define FILE_SIZE 0x8000   // size of each PCAP file to be written to disk
#define SPI_SPEED 30e6   // Speed of SPI bus to read MAC data
#define SPI_DELAY 10   // Delay in uS for SPI reads
#define SPI_BPW 8    // Bits per word for SPI bus reads

static int spiHandle = -1; 
static int i2cHandle = -1;
static int status = -1;

static void 
errxit(const char *msg) { 
    perror(msg); 
    exit(1); 
} 

int main(int argc, char ** argv) { 
    char  spiTxBuff[SPI_MAX_READ_SIZE], spiRxBuff[SPI_MAX_READ_SIZE];  // SPI buffers for high speed FIFO reads
    char  i2cTxBuff[32], i2cRxBuff[32]; // I2C buffers for C&C reads/writes
    char *pcktBuff, *pcktBuffPtr, *lastPckt; // Packet buffers
    const char *pcktDelimeter = "Pckt";
    char i2cDeviceAddr = 0x62; // I2C address for C&C
    unsigned int fifoWritePtr, fifoReadPtr, fifoData; // FIFO address pointers
    unsigned int byte, bytesRead, bytesWritten, fileNum; // Data Processing pointers
    char fileName[20], str1; 
    FILE * dataFile;
    time_t epochSeconds; //UNIX Epoch seconds

    pcktBuff = (char *) malloc(PCKT_BUFF_SIZE+65536);  //set Packet Buffer allowing for 1 complete max size packet overrun
    lastPckt = (char *) malloc(PCKT_BUFF_SIZE+65536);  //pointer to the last packet start
    pcktBuffPtr = pcktBuff;
    
    struct spi_ioc_transfer ioc = {  
        ioc.tx_buf = (unsigned long) spiTxBuff,   
        ioc.rx_buf = (unsigned long) spiRxBuff, 
        ioc.len = SPI_MAX_READ_SIZE, 
        ioc.speed_hz = SPI_SPEED, 
	ioc.delay_usecs = SPI_DELAY, 
	ioc.bits_per_word = SPI_BPW, 
	ioc.cs_change = 1 
    };
    uint8_t mode = SPI_MODE_0; 
	
    struct pcapGlobalHdr pcapGlobalHdr1 = {
        pcapGlobalHdr1.magicNumber = (uint32_t) htobe32(0xA1B2C3D4),//0xD4C3B2A1,
	pcapGlobalHdr1.versionMajor = (uint16_t) htobe16(2),//0x0200,
	pcapGlobalHdr1.versionMinor = (uint16_t) htobe16(4),//0x0400,
	pcapGlobalHdr1.thisZone = (uint32_t) 0,
	pcapGlobalHdr1.sigFigs = (uint32_t) 0,
	pcapGlobalHdr1.snapLen = (uint32_t) htobe32(65535),//0XFFFF0000,
	pcapGlobalHdr1.dlinkType = (uint32_t) htobe32(1),//0x01000000,
    };

    struct pcapPcktHdr pcapPcktHdr1; 
    struct etherHdr etherHdr1;
	
    i2cHandle = open("/dev/i2c-1", O_RDWR);
    if (i2cHandle < 0)
	errxit("Opening I2C device.");

    if(ioctl(i2cHandle, I2C_SLAVE, i2cDeviceAddr)<0)
	errxit("Configuring I2C device.");
	
    i2cTxBuff[0] = 0x7F;   //Set Phy Address
    i2cTxBuff[1] = 0x01;
    if(write(i2cHandle, i2cTxBuff, 2)<0)
	errxit("Writing Phy Address.");
    i2cTxBuff[0] = 0x80;
    i2cTxBuff[1] = 0x01;  //Reset Fifo pointers
    if(write(i2cHandle, i2cTxBuff, 2)<0)
	errxit("Resetting Fifo.");
    sleep(1);
    i2cTxBuff[1] = 0x02;  //Reset timecode
    if(write(i2cHandle, i2cTxBuff, 2)<0)
	errxit("Resetting epoch timecode.");
    sleep(1);
    i2cTxBuff[1] = 0x00;  //Enable Fifo and timecode
    if(write(i2cHandle, i2cTxBuff, 2)<0)
	errxit("Enabling Fifo and Epoch.");
    epochSeconds = time(NULL);
    sleep(1);
    //mkdir("./data", 0700);
		
    spiHandle = open("/dev/spidev0.0",O_RDWR); 
    if ( spiHandle < 0 ) 
        errxit("Opening SPI device."); 

    if (ioctl(spiHandle,SPI_IOC_WR_MODE,&mode)<0) 
	errxit("ioctl (2) setting SPI mode."); 

    if(ioctl(spiHandle,SPI_IOC_WR_BITS_PER_WORD,&ioc.bits_per_word)<0)
	errxit("ioct1 (2) setting SPI bits perword."); 

    memset(spiTxBuff, 0, sizeof(spiTxBuff));
    
    for (fileNum=0; fileNum<1024;fileNum++)
    {	
	snprintf(fileName, 20, ".//data//%d.dat", fileNum);
	printf("%s\n", fileName);
	sleep(2);
	dataFile = fopen(fileName, "wb+");
	if (dataFile == NULL)
            errxit("Opening data file.");
	fwrite(&pcapGlobalHdr1, 1, sizeof(pcapGlobalHdr1), dataFile);	
	bytesWritten = 0;
	while(bytesWritten<FILE_SIZE)
	{		
            sleep(1);
            i2cTxBuff[0] = 0x90;
            if(write(i2cHandle, i2cTxBuff, 1)<0)
		errxit("Error accessing FIFO write register.");
            if(read(i2cHandle, i2cRxBuff, 4)<0)
		errxit("Error getting FIFO write pointer.");
            fifoWritePtr = i2cRxBuff[0]+i2cRxBuff[1]*0x100+i2cRxBuff[2]*0x10000;
            printf("\nFifo write address: %08X \n", fifoWritePtr); 
		
            i2cTxBuff[0] = 0xA0;
            if(write(i2cHandle, i2cTxBuff, 1)<0)
		errxit("Error accessing FIFO read register.");
            if(read(i2cHandle, i2cRxBuff, 4)<0)
		errxit("Error getting FIFO read pointer.");
            fifoReadPtr = i2cRxBuff[0]+i2cRxBuff[1]*0x100+i2cRxBuff[2]*0x10000;
            printf("Fifo read address: %08X\n", fifoReadPtr); 
		
            fifoData=(((fifoWritePtr+FIFO_SIZE-fifoReadPtr)*(fifoReadPtr>fifoWritePtr) + (fifoWritePtr-fifoReadPtr)*(fifoWritePtr>fifoReadPtr))*4);
					
            if(fifoData > PCKT_BUFF_SIZE)
            {			
                printf("Fifo BLOCK full, reading %d bytes of data...\n", fifoData);
                bytesRead=0;
		*lastPckt=0;
                ioc.len = SPI_MAX_READ_SIZE;				
		while(fifoData)
		{
                    if (fifoData<SPI_MAX_READ_SIZE)
			ioc.len = fifoData;					
                    if (ioctl(spiHandle,SPI_IOC_MESSAGE(1),&ioc)<0)
                        errxit("ioctl (2) for SPI I/O"); 
                    memcpy(&pcktBuff[bytesRead], spiRxBuff, ioc.len);
                    bytesRead+=ioc.len;
                    fifoData -= ioc.len;
                    printf("Fifo Buffer = %d\n",fifoData);
		}
		memcpy(&pcktBuff[bytesRead], pcktDelimeter, 4);	
		bytesRead+=4;			
		for (byte=0;byte<bytesRead;byte++)
                    printf("%c",pcktBuff[byte]);		
		printf("\nBytes read = %d with delimeter of %c%c%c%c\n",bytesRead,pcktBuff[bytesRead-4],pcktBuff[bytesRead-3],pcktBuff[bytesRead-2],pcktBuff[bytesRead-1]);
		//getchar();
                while (pcktBuff = (char *)memmem(pcktBuff,bytesRead-(pcktBuff-pcktBuffPtr),pcktDelimeter,4))
		{
                    printf("Found %c%c%c%c @ Position: %d \n",pcktBuff[0],pcktBuff[1],pcktBuff[2],pcktBuff[3],(int)(pcktBuff-pcktBuffPtr));
                    //getchar();
                    if(*lastPckt && lastPckt<pcktBuff)
                    {
			printf("\nLast Packet processing...\n");
                        for (byte=0;byte<(pcktBuff-lastPckt);byte++)
                            printf("%c",lastPckt[byte]);
                        printf("\nType: %02X Timestamp: %04X Epoch: %04X\n", htobe16(etherHdr1.etherType), etherHdr1.timeStamp, epochSeconds);					
			pcapPcktHdr1.tsSec=htobe32(epochSeconds+(etherHdr1.timeStamp/1e6));
			pcapPcktHdr1.tsuSec=htobe32((etherHdr1.timeStamp%(uint32_t)1e6));
			pcapPcktHdr1.capLen=htobe32(pcktBuff-lastPckt);
			pcapPcktHdr1.pcktLen=htobe32(pcktBuff-lastPckt);			
			if(fwrite(&pcapPcktHdr1, 1, sizeof(pcapPcktHdr1), dataFile)<0)
                            errxit("Error writing data to file.");				
			if(fwrite (lastPckt, 1, pcktBuff-lastPckt, dataFile)<0)
                            errxit("Error writing data to file.");
                        bytesWritten+=sizeof(pcapPcktHdr)+(pcktBuff-lastPckt);
		    }
                    memcpy(&etherHdr1,pcktBuff,sizeof(etherHdr1));	
                    lastPckt = pcktBuff+8;  //skip delimeter and timecode
                    pcktBuff++;
		}
                pcktBuff=pcktBuffPtr;
            }
	}
        printf("Closing File...\n");
        //getchar();
	if(fclose(dataFile)<0)
            errxit("Closing data File.");
    }
    if(close(spiHandle)<0)
 	errxit("Closing SPI device.");
	
    if(close(i2cHandle)<0)
	errxit("Closing I2C device.");
    return 0; 
} 


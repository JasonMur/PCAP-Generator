/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

/* 
 * File:   phy.h
 * Author: jason
 *
 * Created on June 12, 2016, 1:00 PM
 */

#ifndef PHY_H
#define PHY_H

//Global header

typedef struct pcapGlobalHdr {
    uint32_t magicNumber;   // magic number  normal uSec resolution 0xa1b2c3d4
    uint16_t versionMajor;  // major version number 0x2
    uint16_t versionMinor;  // minor version number 0x4
    uint32_t thisZone;      // GMT to local correction all timestamps in GMT 0x0
    uint32_t sigFigs;       // accuracy of timestamps not used 0x0
    uint32_t snapLen;       // max length of captured packets, in octets 0xFFFF
    uint32_t dlinkType;     // data link type 0x1 for Ethernet
} pcapGlobalHdr_t;

//Packet Header

typedef struct pcapPcktHdr {
    uint32_t tsSec;         // timestamp seconds 
    uint32_t tsuSec;        // timestamp microseconds 
    uint32_t capLen;        // number of octets of packet saved in file
    uint32_t pcktLen;       // actual length of packet
} pcapPcktHdr_t;

typedef struct etherHdr {
    uint32_t pcktLabel;   //Label at start of each packet = 'Pckt'
    uint32_t timeStamp;   //32 bit timestamp in uSecs
    uint8_t  dstAddr[6];  //Destination MAC
    uint8_t  srcAddr[6];  //Source MAC
    uint16_t etherType;   //Ethernet data type 
} etherHdr_t;


#endif /* PHY_H */


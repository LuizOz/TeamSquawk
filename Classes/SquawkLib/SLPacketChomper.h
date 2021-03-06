//
//  SLPacketChomper.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"

#define PACKET_TYPE_LOGIN_REPLY       0x0004bef4
#define PACKET_TYPE_LOGIN_END         0x0008bef0
#define PACKET_TYPE_ACKNOWELDGE       0x0000bef1

#define PACKET_TYPE_CHANNEL_LIST      0x0006bef0
#define PACKET_TYPE_PLAYER_LIST       0x0007bef0

#define PACKET_TYPE_NEW_PLAYER        0x0064bef0
#define PACKET_TYPE_PLAYER_LEFT       0x0065bef0
#define PACKET_TYPE_CHANNEL_CHANGE    0x0067bef0
#define PACKET_TYPE_PLAYER_UPDATE     0x0068bef0
#define PACKET_TYPE_PRIV_UPDATE       0x006abef0
#define PACKET_TYPE_SERVERPRIV_UPDATE 0x006bbef0
#define PACKET_TYPE_SERVERINFO_UPDATE 0x008cbef0
#define PACKET_TYPE_PLAYER_MUTED      0x0141bef0
#define PACKET_TYPE_PLAYER_CHANKICKED 0x0066bef0

#define PACKET_TYPE_PING_REPLY        0x0002bef4

#define PACKET_TYPE_TEXT_MESSAGE      0x0082bef0

#define PACKET_TYPE_VOICE_SPEEX_3_4   0x0500bef3
#define PACKET_TYPE_VOICE_SPEEX_5_2   0x0600bef3
#define PACKET_TYPE_VOICE_SPEEX_7_2   0x0700bef3
#define PACKET_TYPE_VOICE_SPEEX_9_3   0x0800bef3
#define PACKET_TYPE_VOICE_SPEEX_12_3  0x0900bef3
#define PACKET_TYPE_VOICE_SPEEX_16_3  0x0a00bef3
#define PACKET_TYPE_VOICE_SPEEX_19_5  0x0b00bef3
#define PACKET_TYPE_VOICE_SPEEX_25_9  0x0c00bef3

#define PACKET_TYPE_CVOICE_SPEEX_3_4  0x0501bef3
#define PACKET_TYPE_CVOICE_SPEEX_5_2  0x0601bef3
#define PACKET_TYPE_CVOICE_SPEEX_7_2  0x0701bef3
#define PACKET_TYPE_CVOICE_SPEEX_9_3  0x0801bef3
#define PACKET_TYPE_CVOICE_SPEEX_12_3 0x0901bef3
#define PACKET_TYPE_CVOICE_SPEEX_16_3 0x0a01bef3
#define PACKET_TYPE_CVOICE_SPEEX_19_5 0x0b01bef3
#define PACKET_TYPE_CVOICE_SPEEX_25_9 0x0c01bef3

#define TRANSMIT_TIMEOUT  10
#define RECEIVE_TIMEOUT 10

@interface SLPacketChomper : NSObject {
  AsyncUdpSocket *socket;
  NSDictionary *fragment;
}

+ (id)packetChomper;
+ (id)packetChomperWithSocket:(AsyncUdpSocket*)socket;
- (id)init;
- (id)initWithSocket:(AsyncUdpSocket*)aSocket;
- (void)dealloc;
- (void)setSocket:(AsyncUdpSocket*)aSocket;
- (void)setFragment:(NSDictionary*)dictionary;

#pragma mark Chomper

- (NSDictionary*)chompPacket:(NSData*)data;

#pragma mark Login

- (NSDictionary*)chompLoginReply:(NSData*)data;

#pragma mark Server Info

- (NSDictionary*)chompChannelList:(NSData*)data;
- (NSDictionary*)chompPlayerList:(NSData*)data;

- (NSDictionary*)chompServerInfoUpdate:(NSData*)data;

#pragma mark Status Updates

- (NSDictionary*)chompNewPlayer:(NSData*)data;
- (NSDictionary*)chompPlayerLeft:(NSData*)data;
- (NSDictionary*)chompChannelChange:(NSData*)data;
- (NSDictionary*)chompPlayerUpdate:(NSData*)data;
- (NSDictionary*)chompPlayerMutedUpdate:(NSData*)data;
- (NSDictionary*)chompChannelPrivUpdate:(NSData*)data;
- (NSDictionary*)chompServerPrivUpdate:(NSData*)data;
- (NSDictionary*)chompPlayerKicked:(NSData*)data;

#pragma mark Text/Chat Messages

- (NSDictionary*)chompTextMessage:(NSData*)data;
- (NSDictionary*)chompMoreTextMessage:(NSData*)data;

#pragma mark Voice Packet

- (NSDictionary*)chompVoiceMessage:(NSData*)data;

#pragma mark Channels

@end

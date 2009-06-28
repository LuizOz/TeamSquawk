//
//  SLPacketChomper.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"

#define PACKET_TYPE_LOGIN_REPLY   0x0004bef4
#define PACKET_TYPE_LOGIN_END     0x0008bef0
#define PACKET_TYPE_ACKNOWELDGE   0x0000bef1

#define PACKET_TYPE_CHANNEL_LIST  0x0006bef0
#define PACKET_TYPE_PLAYER_LIST   0x0007bef0

@interface SLPacketChomper : NSObject {
  AsyncUdpSocket *socket;
}

+ (id)packetChomper;
+ (id)packetChomperWithSocket:(AsyncUdpSocket*)socket;
- (id)init;
- (id)initWithSocket:(AsyncUdpSocket*)aSocket;
- (void)dealloc;
- (void)setSocket:(AsyncUdpSocket*)aSocket;

#pragma mark Chomper

- (NSDictionary*)chompPacket:(NSData*)data;

#pragma mark Login

- (NSDictionary*)chompLoginReply:(NSData*)data;

#pragma mark Server Info

- (NSDictionary*)chompChannelList:(NSData*)data;
- (NSDictionary*)chompPlayerList:(NSData*)data;

@end

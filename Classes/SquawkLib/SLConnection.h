//
//  SLConnection.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"

typedef enum {
  SLCodecSpeex_3_4 = 0x05,
  SLCodecSpeex_5_2 = 0x06,
  SLCodecSpeex_7_2 = 0x07,
  SLCodecSpeex_9_3 = 0x08,
  SLCodecSpeex_12_3 = 0x09,
  SLCodecSpeex_16_3 = 0x0a,
  SLCodecSpeex_19_5 = 0x0b,
  SLCodecSpeex_25_9 = 0x0c,
} SLAudioCodecType;

@interface SLConnection : NSObject {
  AsyncUdpSocket *socket;
  NSThread *connectionThread;
  
  NSTimer *pingTimer;
  NSDictionary *textFragments;

  unsigned int connectionID;
  unsigned int clientID;
  unsigned int sequenceNumber;
  
  unsigned short audioSequenceCounter;
  
  int clientMajorVersion, clientMinorVersion;
  NSString *clientName;
  NSString *clientOperatingSystem;
  
  id delegate;
}

@property (assign) id delegate;
@property (retain) NSString *clientName;
@property (retain) NSString *clientOperatingSystem;
@property (assign) int clientMajorVersion;
@property (assign) int clientMinorVersion;

- (id)initWithHost:(NSString*)host withError:(NSError**)error;
- (id)initWithHost:(NSString*)host withPort:(int)port withError:(NSError**)error;

#pragma mark Commands

- (void)beginAsynchronousLogin:(NSString*)username password:(NSString*)password nickName:(NSString*)nickName isRegistered:(BOOL)isRegistered;
- (void)disconnect;

#pragma mark Incoming Events

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port;
- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error;

#pragma mark Ping Timer

- (void)pingTimer:(NSTimer*)timer;

#pragma mark Text Message

- (void)sendTextMessage:(NSString*)message toPlayer:(unsigned int)playerID;

#pragma mark Voice Message

- (void)sendVoiceMessage:(NSData*)audioCodecData frames:(unsigned char)frames commanderChannel:(BOOL)command packetCount:(unsigned short)packetCount codec:(SLAudioCodecType)codec;

@end

@interface NSObject (SLConnectionDelegate)

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform
      majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage;

- (void)connectionFinishedLogin:(SLConnection*)connection;
- (void)connectionFailedToLogin:(SLConnection*)connection;

- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary;
- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary;

- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname;
- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags;
- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID;

- (void)connectionPingReply:(SLConnection*)connection;

- (void)connection:(SLConnection*)connection receivedTextMessage:(NSString*)message fromNickname:(NSString*)nickname playerID:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID senderPacketCounter:(unsigned short)count;

@end


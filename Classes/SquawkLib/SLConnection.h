//
//  SLConnection.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AsyncUdpSocket.h"

@interface SLConnection : NSObject {
  AsyncUdpSocket *socket;

  unsigned int sequenceNumber;
  
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

#pragma mark Incoming Events

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port;
- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error;

@end

@interface NSObject (SLConnectionDelegate)

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform
      majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage;

- (void)connectionFailedToLogin:(SLConnection*)connection;

- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary;
- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary;

- (void)connectionFinishedLogin:(SLConnection*)connection;

@end


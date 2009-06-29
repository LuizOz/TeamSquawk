//
//  SLConnection.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SLConnection.h"
#import "SLPacketBuilder.h"
#import "SLPacketChomper.h"

@implementation SLConnection

@synthesize clientName;
@synthesize clientOperatingSystem;
@synthesize clientMajorVersion;
@synthesize clientMinorVersion;

@synthesize delegate;

- (id)initWithHost:(NSString*)host withError:(NSError**)error
{
  return [self initWithHost:host withPort:8767 withError:error];
}

- (id)initWithHost:(NSString*)host withPort:(int)port withError:(NSError**)error
{
  if (self = [super init])
  {
    socket = [[AsyncUdpSocket alloc] initWithDelegate:self];    
    textFragments = nil;
    
    BOOL connected = [socket connectToHost:host onPort:port error:error];
    if (!connected)
    {
      NSLog(@"%@", *error);
      [socket release];
      [self release];
      return nil;
    }
  }
  return self;
}

#pragma mark Commands

- (void)beginAsynchronousLogin:(NSString*)username password:(NSString*)password nickName:(NSString*)nickName isRegistered:(BOOL)isRegistered
{
  sequenceNumber = 1;
  
  SLPacketBuilder *packetBuilder = [SLPacketBuilder packetBuilder];
  NSData *packet = [packetBuilder buildLoginPacketWithSequenceID:sequenceNumber
                                                      clientName:[self clientName]
                                             operatingSystemName:[self clientOperatingSystem]
                                              clientVersionMajor:[self clientMajorVersion]
                                              clientVersionMinor:[self clientMinorVersion]
                                                    isRegistered:isRegistered
                                                       loginName:username
                                                   loginPassword:password
                                                   loginNickName:nickName];
  [socket sendData:packet withTimeout:20 tag:0];
  
  // queue up a read for the return packet
  [socket receiveWithTimeout:20 tag:0];
}

#pragma mark Incoming Events

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{  
  SLPacketChomper *chomper = [SLPacketChomper packetChomperWithSocket:socket];
  
  if (textFragments && ([[textFragments objectForKey:@"SLFragmentCount"] unsignedIntValue] > 0))
  {
    // we've got leftovers from the last part of the text message. let the chomper glue them
    // together.
    [chomper setFragment:textFragments];
  }
  
  NSDictionary *packet = [chomper chompPacket:data];
  
  if (packet)
  {
    switch ([[packet objectForKey:@"SLPacketType"] unsignedIntValue])
    {
      case PACKET_TYPE_LOGIN_REPLY:
      {
        BOOL isBadLogin = [[packet objectForKey:@"SLBadLogin"] boolValue];
        
        if (isBadLogin)
        {
          if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionFailedToLogin:)])
          {
            [[self delegate] connectionFailedToLogin:self];
          }
        }
        else
        {
          connectionID = [[packet objectForKey:@"SLNewConnectionID"] unsignedIntValue];
          clientID = [[packet objectForKey:@"SLClientID"] unsignedIntValue];
          unsigned int lastCRC32 = [[packet objectForKey:@"SLCRC32"] unsignedIntValue];
          
          NSData *newPacket = [[SLPacketBuilder packetBuilder] buildLoginResponsePacketWithConnectionID:connectionID
                                                                                               clientID:clientID
                                                                                             sequenceID:sequenceNumber++
                                                                                              lastCRC32:lastCRC32];
          [sock sendData:newPacket withTimeout:20 tag:0];
          
          if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:didLoginTo:port:serverName:platform:majorVersion:minorVersion:subLevelVersion:subsubLevelVersion:welcomeMessage:)])
          {
            [[self delegate] connection:self
                             didLoginTo:host
                                   port:port
                             serverName:[packet objectForKey:@"SLServerName"]
                               platform:[packet objectForKey:@"SLPlatform"]
                           majorVersion:[[packet objectForKey:@"SLMajorVersion"] intValue]
                           minorVersion:[[packet objectForKey:@"SLMinorVersion"] intValue]
                        subLevelVersion:[[packet objectForKey:@"SLSubLevelVersion"] intValue]
                     subsubLevelVersion:[[packet objectForKey:@"SLSubSubLevelVersion"] intValue]
                         welcomeMessage:[packet objectForKey:@"SLWelcomeMessage"]];
          }
        }
        
        break;
      }
      case PACKET_TYPE_CHANNEL_LIST:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedChannelList:)])
        {
          [[self delegate] connection:self receivedChannelList:packet];
        }
        break;
      }
      case PACKET_TYPE_PLAYER_LIST:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerList:)])
        {
          [[self delegate] connection:self receivedPlayerList:packet];
        }
        break;
      }
      case PACKET_TYPE_LOGIN_END:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionFinishedLogin:)])
        {
          [[self delegate] connectionFinishedLogin:self];
        }
        
        // we should probably schedule some auto-pings here
        [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(pingTimer:) userInfo:nil repeats:YES];
        
        break;
      }
      case PACKET_TYPE_PING_REPLY:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionPingReply:)])
        {
          [[self delegate] connectionPingReply:self];
        }
        break;
      }
      case PACKET_TYPE_TEXT_MESSAGE:
      {
        if ([[packet objectForKey:@"SLFragmentCount"] unsignedIntValue] > 0)
        {
          textFragments = [packet retain];
          
          // don't tell the delegate about this packet till we've got all of it
          break;
        }
        
        // we got all of a fragment, so print it and ditch the last parts we had
        [textFragments release];
        textFragments = nil;
        
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedTextMessage:fromNickname:playerID:)])
        {
          [[self delegate] connection:self
                  receivedTextMessage:[packet objectForKey:@"SLMessage"] 
                         fromNickname:[packet objectForKey:@"SLNickname"]
                             playerID:-1];
        }
        
        break;
      }
      default:
        NSLog(@"got chomped packet I don't know about: %@", packet);
    }
    
    [sock receiveWithTimeout:20 tag:0];
    return YES;
  }
  return NO;
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error
{
  // for now, just queue up again
  [sock receiveWithTimeout:20 tag:0];
}

#pragma mark Ping Timer

- (void)pingTimer:(NSTimer*)timer
{
  // fire a ping every time this goes off
  NSData *data = [[SLPacketBuilder packetBuilder] buildPingPacketWithConnectionID:connectionID clientID:clientID sequenceID:1];
  [socket sendData:data withTimeout:20 tag:0];
}

#pragma mark Text Message

- (void)sendTextMessage:(NSString*)message toPlayer:(unsigned int)playerID
{
  NSData *packet = [[SLPacketBuilder packetBuilder] buildTextMessagePacketWithConnectionID:connectionID
                                                                                  clientID:clientID
                                                                                sequenceID:sequenceNumber++
                                                                                  playerID:playerID
                                                                                   message:message];
  [socket sendData:packet withTimeout:20 tag:0];
}

@end

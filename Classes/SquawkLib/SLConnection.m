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
    connectionThread = [[NSThread currentThread] retain];
    
    [socket setRunLoopModes:[NSArray arrayWithObjects:NSRunLoopCommonModes, nil]];
    
    textFragments = nil;
    audioSequenceCounter = 0;
    
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

- (void)dealloc
{
  [socket release];
  [connectionThread release];
  [textFragments release];
  [super dealloc];
}

#pragma mark Threading

- (void)sendData:(NSData*)data
{
  // intended to be run on the socket's thread
  [socket sendData:data withTimeout:20 tag:0];
  [socket maybeDequeueSend];
}

- (void)queueReceiveData
{
  // queue up a recieve
  [socket receiveWithTimeout:20 tag:0];
}

#pragma mark Commands

- (void)beginAsynchronousLogin:(NSString*)username password:(NSString*)password nickName:(NSString*)nickName isRegistered:(BOOL)isRegistered
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
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
  // send the packet
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  
  // queue up a read
  [self performSelector:@selector(queueReceiveData) onThread:connectionThread withObject:nil waitUntilDone:YES];
  [pool release];
}

- (void)disconnect
{
  if (pingTimer)
  {
    [pingTimer invalidate];
    [pingTimer release];
    pingTimer = nil;
  }
  
  NSData *packet = [[SLPacketBuilder packetBuilder] buildDisconnectPacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber++];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  
  if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionDisconnected:)])
  {
    [[self delegate] connectionDisconnected:self];
  }
}

#pragma mark Incoming Events

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
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
          // this only gets called form the socket's thread. so should be thread safe.
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
        // we should probably schedule some auto-pings here
        pingTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(pingTimer:) userInfo:nil repeats:YES] retain];
        
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionFinishedLogin:)])
        {
          [[self delegate] connectionFinishedLogin:self];
        }
        
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
      case PACKET_TYPE_VOICE_SPEEX_3_4:
      case PACKET_TYPE_VOICE_SPEEX_5_2:
      case PACKET_TYPE_VOICE_SPEEX_7_2:
      case PACKET_TYPE_VOICE_SPEEX_9_3:
      case PACKET_TYPE_VOICE_SPEEX_12_3:
      case PACKET_TYPE_VOICE_SPEEX_16_3:
      case PACKET_TYPE_VOICE_SPEEX_19_5:
      case PACKET_TYPE_VOICE_SPEEX_25_9:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedVoiceMessage:codec:playerID:senderPacketCounter:)])
        {
          NSData *data = [packet objectForKey:@"SLAudioCodecData"];
          SLAudioCodecType codec = (([[packet objectForKey:@"SLPacketType"] unsignedIntValue] >> 6) & 0xff);
          unsigned int playerID = [[packet objectForKey:@"SLSenderID"] unsignedIntValue];
          unsigned short count = [[packet objectForKey:@"SLSenderCounter"] unsignedShortValue];
          
          [[self delegate] connection:self receivedVoiceMessage:data codec:codec playerID:playerID senderPacketCounter:count];
        }
        break;
      }
      case PACKET_TYPE_NEW_PLAYER:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedNewPlayerNotification:channel:nickname:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int channelID = [[packet objectForKey:@"SLChannelID"] unsignedIntValue];
          NSString *nick = [packet objectForKey:@"SLNickname"];
          
          [[self delegate] connection:self receivedNewPlayerNotification:playerID channel:channelID nickname:nick];
        }
        break;
      }
      case PACKET_TYPE_PLAYER_LEFT:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerLeftNotification:)])
        {
          [[self delegate] connection:self receivedPlayerLeftNotification:[[packet objectForKey:@"SLPlayerID"] unsignedIntValue]];
        }
        break;
      }
      case PACKET_TYPE_CHANNEL_CHANGE:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedChannelChangeNotification:fromChannel:toChannel:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int oldChannelID = [[packet objectForKey:@"SLPreviousChannelID"] unsignedIntValue];
          unsigned int newChannelID = [[packet objectForKey:@"SLNewChannelID"] unsignedIntValue];
          
          [[self delegate] connection:self receivedChannelChangeNotification:playerID fromChannel:oldChannelID toChannel:newChannelID];
        }
        break;
      }
      case PACKET_TYPE_PLAYER_UPDATE:
      {
        if ([self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerUpdateNotification:flags:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned short playerFlags = [[packet objectForKey:@"SLPlayerFlags"] unsignedShortValue];
          
          [[self delegate] connection:self receivedPlayerUpdateNotification:playerID flags:playerFlags];
        }
        break;
      }
      default:
        NSLog(@"got chomped packet I don't know about: %@", packet);
    }
    
    [sock receiveWithTimeout:20 tag:0];
    [pool release];
    return YES;
  }
  [pool release];
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
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  // fire a ping every time this goes off
  NSData *data = [[SLPacketBuilder packetBuilder] buildPingPacketWithConnectionID:connectionID clientID:clientID sequenceID:1];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:data waitUntilDone:YES];
  [pool release];
}

#pragma mark Text Message

- (void)sendTextMessage:(NSString*)message toPlayer:(unsigned int)playerID
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildTextMessagePacketWithConnectionID:connectionID
                                                                                  clientID:clientID
                                                                                sequenceID:sequenceNumber++
                                                                                  playerID:playerID
                                                                                   message:message];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [pool release];
}

#pragma mark Voice Message

- (void)sendVoiceMessage:(NSData*)audioCodecData frames:(unsigned char)frames commanderChannel:(BOOL)command packetCount:(unsigned short)packetCount codec:(SLAudioCodecType)codec
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildVoiceMessageWithConnectionID:connectionID
                                                                             clientID:clientID
                                                                                codec:(codec & 0xff)
                                                                          packetCount:packetCount
                                                                            audioData:audioCodecData
                                                                          audioFrames:frames
                                                                       commandChannel:command];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [pool release];
}

#pragma mark Channel/Status

- (void)changeChannelTo:(unsigned int)newChannel withPassword:(NSString*)password
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildSwitchChannelMessageWithConnectionID:connectionID
                                                                                     clientID:clientID
                                                                                   sequenceID:sequenceNumber++
                                                                                 newChannelID:newChannel
                                                                                     password:password];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [pool release];
}

@end

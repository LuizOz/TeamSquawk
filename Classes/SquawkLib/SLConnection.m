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

@synthesize clientID;

@synthesize delegate;

+ (unsigned int)bitrateForCodec:(unsigned int)codec
{
  switch (codec)
  {
    case SLCodecSpeex_3_4:
      return 3400;
    case SLCodecSpeex_5_2:
      return 5200;
    case SLCodecSpeex_7_2:
      return 7200;
    case SLCodecSpeex_9_3:
      return 9300;
    case SLCodecSpeex_12_3:
      return 12300;
    case SLCodecSpeex_16_3:
      return 16300;
    case SLCodecSpeex_19_5:
      return 19500;
    case SLCodecSpeex_25_9:
      return 25900;
    default:
      return 0;
  }
}

- (id)initWithHost:(NSString*)host withError:(NSError**)error
{
  return [self initWithHost:host withPort:8767 withError:error];
}

- (id)initWithHost:(NSString*)host withPort:(int)port withError:(NSError**)error
{
  if (self = [super init])
  {
    connectionThread = [[NSThread alloc] initWithTarget:self selector:@selector(spawnThread) object:nil];
    [connectionThread start];
    
    [self performSelector:@selector(initSocketOnThread) onThread:connectionThread withObject:nil waitUntilDone:YES];
    
    textFragments = nil;
    audioSequenceCounter = 0;
    isDisconnecting = NO;
    hasFinishedDisconnecting = NO;
    pendingReceive = NO;
    
    connectionSequenceNumber = 0;
    standardSequenceNumber = 0;
    serverConnectionSequenceNumber = 0;
    serverStandardSequenceNumber = 0;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[socket methodSignatureForSelector:@selector(connectToHost:onPort:error:)]];
    [invocation setTarget:socket];
    [invocation setSelector:@selector(connectToHost:onPort:error:)];
    [invocation setArgument:&host atIndex:2];
    [invocation setArgument:&port atIndex:3];
    [invocation setArgument:&error atIndex:4];
    [invocation performSelector:@selector(invoke) onThread:connectionThread withObject:nil waitUntilDone:YES];
    
    BOOL connected;
    [invocation getReturnValue:&connected];
    
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
  [connectionThread cancel];
  [socket release];
  [connectionThread release];
  [textFragments release];
  [super dealloc];
}

#pragma mark Threading
    
- (void)spawnThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow] target:nil selector:nil userInfo:nil repeats:NO];
  
  while (![[NSThread currentThread] isCancelled])
  {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    [pool release];
    pool = [[NSAutoreleasePool alloc] init];
  }
  [pool release];
}

- (void)initSocketOnThread
{
  socket = [[AsyncUdpSocket alloc] initWithDelegate:self];
  connectionThread = [[NSThread currentThread] retain];
  
  [socket setRunLoopModes:[NSArray arrayWithObjects:NSRunLoopCommonModes, nil]];
}

- (void)sendData:(NSData*)data
{
  // intended to be run on the socket's thread
  [socket sendData:data withTimeout:20 tag:0];
}

- (void)queueReceiveData
{
  // queue up a recieve
  [socket receiveWithTimeout:20 tag:0];
}

- (void)waitForSend
{
  [socket maybeDequeueSend];
}

- (void)queueReceiveDataAndWait
{
  pendingReceive = YES;
  [socket receiveWithTimeout:20 tag:0];
  while (pendingReceive)
  {
    [[NSRunLoop currentRunLoop] runMode:NSRunLoopCommonModes beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
}

#pragma mark Commands

- (void)beginAsynchronousLogin:(NSString*)username password:(NSString*)password nickName:(NSString*)nickName isRegistered:(BOOL)isRegistered
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  connectionSequenceNumber = 1;
  
  SLPacketBuilder *packetBuilder = [SLPacketBuilder packetBuilder];
  NSData *packet = [packetBuilder buildLoginPacketWithSequenceID:connectionSequenceNumber
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
  
  isDisconnecting = YES;
  
  NSData *packet = [[SLPacketBuilder packetBuilder] buildDisconnectPacketWithConnectionID:connectionID clientID:clientID sequenceID:standardSequenceNumber++];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [self performSelector:@selector(waitForSend) onThread:connectionThread withObject:nil waitUntilDone:YES];
  
  // we get a player packet here, we need to queue a send then close waiting for receive. then poll till we're closed
  [self performSelector:@selector(queueReceiveData) onThread:connectionThread withObject:nil waitUntilDone:YES];
  
  while (!hasFinishedDisconnecting)
  {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
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
  
  pendingReceive = NO;
  
  if (textFragments && ([[textFragments objectForKey:@"SLFragmentCount"] unsignedIntValue] > 0))
  {
    // we've got leftovers from the last part of the text message. let the chomper glue them
    // together.
    [chomper setFragment:textFragments];
  }
  
  NSDictionary *packet = [chomper chompPacket:data];
  
  if (packet)
  {
    unsigned int packetType = [[packet objectForKey:@"SLPacketType"] unsignedIntValue];
    
    if ([packet objectForKey:@"SLSequenceNumber"])
    {
      unsigned int seq = [[packet objectForKey:@"SLSequenceNumber"] unsignedIntValue];
      
      if ((packetType & 0x0000ffff) == 0x0000bef4)
      {
        // connection sequence
        if (seq <= serverConnectionSequenceNumber)
        {
          return NO;
        }
        serverConnectionSequenceNumber = seq;
      }
      else if ((packetType & 0x0000ffff) == 0x0000bef0)
      {
        // standard sequence
        if (seq <= serverStandardSequenceNumber)
        {
          return NO;
        }
        serverStandardSequenceNumber = seq;
      }
    }
    
    switch (packetType)
    {
      case PACKET_TYPE_LOGIN_REPLY:
      {
        BOOL isBadLogin = [[packet objectForKey:@"SLBadLogin"] boolValue];
        standardSequenceNumber = 1;

        if (isBadLogin)
        {
          if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionFailedToLogin:)])
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
                                                                                             sequenceID:standardSequenceNumber++
                                                                                              lastCRC32:lastCRC32];
          // this only gets called form the socket's thread. so should be thread safe.
          [sock sendData:newPacket withTimeout:20 tag:0];
          [sock maybeDequeueSend];
          
          if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:didLoginTo:port:serverName:platform:majorVersion:minorVersion:subLevelVersion:subsubLevelVersion:welcomeMessage:)])
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
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedChannelList:)])
        {
          [[self delegate] connection:self receivedChannelList:packet];
        }
        break;
      }
      case PACKET_TYPE_PLAYER_LIST:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerList:)])
        {
          [[self delegate] connection:self receivedPlayerList:packet];
        }
        break;
      }
      case PACKET_TYPE_LOGIN_END:
      {
        // reset the sequence ids
        connectionSequenceNumber = 0;
        
        // we should probably schedule some auto-pings here
        pingTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(pingTimer:) userInfo:nil repeats:YES] retain];
        
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionFinishedLogin:)])
        {
          [[self delegate] connectionFinishedLogin:self];
        }
        
        break;
      }
      case PACKET_TYPE_PING_REPLY:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionPingReply:)])
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
        
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedTextMessage:fromNickname:playerID:)])
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
      case PACKET_TYPE_CVOICE_SPEEX_3_4:
      case PACKET_TYPE_CVOICE_SPEEX_5_2:
      case PACKET_TYPE_CVOICE_SPEEX_7_2:
      case PACKET_TYPE_CVOICE_SPEEX_9_3:
      case PACKET_TYPE_CVOICE_SPEEX_12_3:
      case PACKET_TYPE_CVOICE_SPEEX_16_3:
      case PACKET_TYPE_CVOICE_SPEEX_19_5:
      case PACKET_TYPE_CVOICE_SPEEX_25_9:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedVoiceMessage:codec:playerID:commandChannel:senderPacketCounter:)])
        {
          NSData *data = [packet objectForKey:@"SLAudioCodecData"];
          SLAudioCodecType codec = (([[packet objectForKey:@"SLPacketType"] unsignedIntValue] >> 24) & 0xff);
          unsigned int playerID = [[packet objectForKey:@"SLSenderID"] unsignedIntValue];
          unsigned short count = [[packet objectForKey:@"SLSenderCounter"] unsignedShortValue];
          BOOL commandChannel = [[packet objectForKey:@"SLCommandChannel"] boolValue];
          
          [[self delegate] connection:self receivedVoiceMessage:data codec:codec playerID:playerID commandChannel:commandChannel senderPacketCounter:count];
        }
        break;
      }
      case PACKET_TYPE_NEW_PLAYER:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedNewPlayerNotification:channel:nickname:extendedFlags:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int channelID = [[packet objectForKey:@"SLChannelID"] unsignedIntValue];
          unsigned int extendedFlags = [[packet objectForKey:@"SLPlayerExtendedFlags"] unsignedIntValue];
          NSString *nick = [packet objectForKey:@"SLNickname"];
          
          [[self delegate] connection:self receivedNewPlayerNotification:playerID channel:channelID nickname:nick extendedFlags:extendedFlags];
        }
        break;
      }
      case PACKET_TYPE_PLAYER_LEFT:
      {
        // this could be us!
        if (isDisconnecting)
        {
          hasFinishedDisconnecting = YES;
        }
        
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerLeftNotification:)])
        {
          [[self delegate] connection:self receivedPlayerLeftNotification:[[packet objectForKey:@"SLPlayerID"] unsignedIntValue]];
        }
        break;
      }
      case PACKET_TYPE_CHANNEL_CHANGE:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedChannelChangeNotification:fromChannel:toChannel:)])
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
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerUpdateNotification:flags:)])
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

- (void)onUdpSocketDidClose:(AsyncUdpSocket *)sock
{
  NSLog(@"i'm closed");
}

#pragma mark Ping Timer

- (void)pingTimer:(NSTimer*)timer
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  // fire a ping every time this goes off
  NSData *data = [[SLPacketBuilder packetBuilder] buildPingPacketWithConnectionID:connectionID clientID:clientID sequenceID:connectionSequenceNumber++];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:data waitUntilDone:YES];
  [self performSelector:@selector(waitForSend) onThread:connectionThread withObject:nil waitUntilDone:YES];
  [pool release];
}

#pragma mark Text Message

- (void)sendTextMessage:(NSString*)message toPlayer:(unsigned int)playerID
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildTextMessagePacketWithConnectionID:connectionID
                                                                                  clientID:clientID
                                                                                sequenceID:standardSequenceNumber++
                                                                                  playerID:playerID
                                                                                   message:message];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [pool release];
}

#pragma mark Voice Message

- (void)sendVoiceMessage:(NSData*)audioCodecData frames:(unsigned char)frames packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID codec:(SLAudioCodecType)codec
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildVoiceMessageWithConnectionID:connectionID
                                                                             clientID:clientID
                                                                                codec:(codec & 0xff)
                                                                          packetCount:packetCount
                                                                       transmissionID:transmissionID
                                                                            audioData:audioCodecData
                                                                          audioFrames:frames];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [pool release];
}

- (void)sendVoiceWhisper:(NSData*)audioCodecData frames:(unsigned char)frames packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID codec:(SLAudioCodecType)codec recipients:(NSArray*)recipients;
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildVoiceWhisperWithConnectionID:connectionID
                                                                             clientID:clientID 
                                                                                codec:(codec & 0xff) 
                                                                          packetCount:packetCount 
                                                                       transmissionID:transmissionID
                                                                            audioData:audioCodecData
                                                                          audioFrames:frames
                                                                           recipients:recipients];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:YES];
  [pool release];
}

#pragma mark Channel/Status

- (void)changeChannelTo:(unsigned int)newChannel withPassword:(NSString*)password
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildSwitchChannelMessageWithConnectionID:connectionID
                                                                                     clientID:clientID
                                                                                   sequenceID:standardSequenceNumber++
                                                                                 newChannelID:newChannel
                                                                                     password:password];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:NO];
  [pool release];
}

- (void)changeStatusTo:(unsigned short)flags
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildChangePlayerStatusMessageWithConnectionID:connectionID
                                                                                          clientID:clientID
                                                                                        sequenceID:standardSequenceNumber++
                                                                                    newStatusFlags:flags];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:NO];
  [pool release];
}

@end

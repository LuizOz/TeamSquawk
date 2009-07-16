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

//#define PERMS_DEBUG 1

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
    sendReceiveLock = [[NSRecursiveLock alloc] init];
    
    connectionThread = [[NSThread alloc] initWithTarget:self selector:@selector(spawnThread) object:nil];
    [connectionThread start];
    
    [self performSelector:@selector(initSocketOnThread) onThread:connectionThread withObject:nil waitUntilDone:YES];
    
    textFragments = nil;
    audioSequenceCounter = 0;
    isDisconnecting = NO;
    hasFinishedDisconnecting = NO;
    pendingReceive = NO;
    pingReplyPending = NO;
    
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
  // clear the connection timeout timer
  [connectionTimer invalidate];
  [connectionTimer release];
  connectionTimer = nil;
  
  // clear the ping timer
  [pingTimer invalidate];
  [pingTimer release];
  pingTimer = nil;
  
  [connectionThread cancel];
  [socket release];
  [connectionThread release];
  [textFragments release];
  [sendReceiveLock release];
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
  while (![sendReceiveLock tryLock])
  {
    // allow a deadlocked runloop to break itself
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
  // intended to be run on the socket's thread
  [socket sendData:data withTimeout:TRANSMIT_TIMEOUT tag:0];
  
  [sendReceiveLock unlock];
}

- (void)queueReceiveData
{
  while (![sendReceiveLock tryLock])
  {
    // allow a deadlocked runloop to break itself
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
  // queue up a recieve
  [socket receiveWithTimeout:RECEIVE_TIMEOUT tag:0];
  
  [sendReceiveLock unlock];
}

- (void)waitForSend
{
  [socket maybeDequeueSend];
}

- (void)queueReceiveDataAndWait
{
  pendingReceive = YES;
  [socket receiveWithTimeout:RECEIVE_TIMEOUT tag:0];
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
  
  connectionTimer = [[NSTimer scheduledTimerWithTimeInterval:TRANSMIT_TIMEOUT target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO] retain];
  
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
  
  if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionDisconnected:withError:)])
  {
    [[self delegate] connectionDisconnected:self withError:nil];
  }
}

#pragma mark Incoming Events

- (BOOL)onUdpSocket:(AsyncUdpSocket *)sock didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  SLPacketChomper *chomper = [SLPacketChomper packetChomperWithSocket:socket];
  
  [sendReceiveLock lock];
  
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
          if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionFailedToLogin:withError:)])
          {
            NSError *error = [NSError errorWithDomain:@"SLConnectionError" 
                                                 code:SLConnectionErrorBadLogin 
                                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       @"Server returned \"Bad Login\"", NSLocalizedDescriptionKey,
                                                       @"Please check your username and password and try again.", NSLocalizedRecoverySuggestionErrorKey,
                                                       nil]];
            [[self delegate] connectionFailedToLogin:self withError:error];
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
          [sock sendData:newPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
          [sock maybeDequeueSend];
          
          // setup a new timeout
          [connectionTimer invalidate];
          [connectionTimer release];
          connectionTimer = [[NSTimer scheduledTimerWithTimeInterval:TRANSMIT_TIMEOUT target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO] retain];
          
          [self parsePermissionData:[packet objectForKey:@"SLPermissionsData"]];
          
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
        
        // clear the connection timeout timer
        [connectionTimer invalidate];
        [connectionTimer release];
        connectionTimer = nil;
        
        // we should probably schedule some auto-pings here
        pingTimer = [[NSTimer scheduledTimerWithTimeInterval:5.0f target:self selector:@selector(pingTimer:) userInfo:nil repeats:YES] retain];
        
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionFinishedLogin:)])
        {
          [[self delegate] connectionFinishedLogin:self];
        }
        
        break;
      }
      case PACKET_TYPE_PING_REPLY:
      {
        pingReplyPending = NO;
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
      case PACKET_TYPE_PLAYER_MUTED:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerMutedNotification:wasMuted:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          BOOL muted = [[packet objectForKey:@"SLMutedStatus"] boolValue];
          
          [[self delegate] connection:self receivedPlayerMutedNotification:playerID wasMuted:muted];          
        }
        break;
      }
      default:
        NSLog(@"got chomped packet I don't know about: %@", packet);
    }
    
    [sock receiveWithTimeout:RECEIVE_TIMEOUT tag:0];
    [sendReceiveLock unlock];
    [pool release];
    return YES;
  }
  [sendReceiveLock unlock];
  [pool release];
  return NO;
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotReceiveDataWithTag:(long)tag dueToError:(NSError *)error
{
  // for now, just queue up again
  [sock receiveWithTimeout:RECEIVE_TIMEOUT tag:0];
}

- (void)onUdpSocket:(AsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error
{
  // we couldn't send a packet? this is pretty bad, especially for UDP where the only reportable errors are to do
  // with local sending.
  if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionFailedToLogin:withError:)])
  {
    [[self delegate] connectionDisconnected:self withError:error];
  }
}

- (void)parsePermissionData:(NSData*)data
{
  unsigned int position = 0;
  
  // skip 10 bytes of crap
  position += 10;
  
  [data getBytes:&serverAdminPermissions range:NSMakeRange(position, 10)];
  position += 10;
  
#ifdef PERMS_DEBUG
  NSLog(@"server admin: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x", 
        serverAdminPermissions[0], serverAdminPermissions[1], serverAdminPermissions[2], serverAdminPermissions[3], serverAdminPermissions[4],
        serverAdminPermissions[5], serverAdminPermissions[6], serverAdminPermissions[7], serverAdminPermissions[8], serverAdminPermissions[9]);
#endif
  
  // skip 4 bytes
  position += 4;
  
  [data getBytes:&channelAdminPermissions range:NSMakeRange(position, 8)];
  position += 8;
  
#ifdef PERMS_DEBUG
  NSLog(@"channel admin: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        channelAdminPermissions[0], channelAdminPermissions[1], channelAdminPermissions[2], channelAdminPermissions[3],
        channelAdminPermissions[4], channelAdminPermissions[5], channelAdminPermissions[6], channelAdminPermissions[7]);
#endif
  
  // skip 3 bytes
  position += 3;
  
  [data getBytes:&operatorPemissions range:NSMakeRange(position, 8)];
  position += 8;
  
#ifdef PERMS_DEBUG
  NSLog(@"operator: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        operatorPemissions[0], operatorPemissions[1], operatorPemissions[2], operatorPemissions[3],
        operatorPemissions[4], operatorPemissions[5], operatorPemissions[6], operatorPemissions[7]);
#endif
  
  // skip 3 bytes
  position += 3;
  
  [data getBytes:&voicePermissions range:NSMakeRange(position, 8)];
  position += 8;
  
#ifdef PERMS_DEBUG
  NSLog(@"voice: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        voiceBits[0], voiceBits[1], voiceBits[2], voiceBits[3],
        voiceBits[4], voiceBits[5], voiceBits[6], voiceBits[7]);
#endif
  
  // skip no bytes here
  
  [data getBytes:&registeredPermissions range:NSMakeRange(position, 10)];
  position += 10;
  
#ifdef PERMS_DEBUG
  NSLog(@"registered: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x", 
        registeredPermissions[0], registeredPermissions[1], registeredPermissions[2], registeredPermissions[3], registeredPermissions[4],
        registeredPermissions[5], registeredPermissions[6], registeredPermissions[7], registeredPermissions[8], registeredPermissions[9]);
#endif
  
  // skip 4 bytes
  position += 4;
  
  [data getBytes:&anonymousPermissions range:NSMakeRange(position, 8)];
  
#ifdef PERMS_DEBUG
  NSLog(@"anonymous: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        anonymousPermissions[0], anonymousPermissions[1], anonymousPermissions[2], anonymousPermissions[3],
        anonymousPermissions[4], anonymousPermissions[5], anonymousPermissions[6], anonymousPermissions[7]);
#endif
}

#pragma mark Ping Timer

- (void)pingTimer:(NSTimer*)timer
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (pingReplyPending)
  {
    // if we've got a reply pending then we've probably timed out.
    if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionDisconnected:withError:)])
    {
      NSError *error = [NSError errorWithDomain:@"SLConnectionError" 
                                           code:SLConnectionErrorPingTimeout 
                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                 @"Ping to server timed out.", NSLocalizedDescriptionKey,
                                                 @"The remote server failed to respond to ping requests, your connection has timed out.", NSLocalizedRecoverySuggestionErrorKey,
                                                 nil]];
      [[self delegate] connectionDisconnected:self withError:error];
    }
    
    [pingTimer invalidate];
    [pingTimer release];
    pingTimer = nil;
    
    return;
  }
  
  // fire a ping every time this goes off
  NSData *data = [[SLPacketBuilder packetBuilder] buildPingPacketWithConnectionID:connectionID clientID:clientID sequenceID:connectionSequenceNumber++];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:data waitUntilDone:YES];
  [self performSelector:@selector(waitForSend) onThread:connectionThread withObject:nil waitUntilDone:YES];
  
  pingReplyPending = YES;
  
  [pool release];
}

- (void)connectionTimer:(NSTimer*)timer
{
  // if we hit this then we've got a connection timeout. UDP can't tell us if a packet came in or not, we just have to setup our
  // own timer and guess when its taken too long.
  if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionFailedToLogin:withError:)])
  {
    NSError *error = [NSError errorWithDomain:@"SLConnectionError" 
                                         code:SLConnectionErrorTimedOut 
                                     userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                               @"Connection timed out", NSLocalizedDescriptionKey, 
                                               @"A timeout occured whilst trying to connect to the server, your server may be down or not be responding.", NSLocalizedRecoverySuggestionErrorKey,
                                               nil]];
    [[self delegate] connectionFailedToLogin:self withError:error];
  }
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

- (void)changeMute:(BOOL)isMuted onOtherPlayerID:(unsigned int)playerID
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildChangeOtherPlayerMuteStatusWithConnectionID:connectionID
                                                                                            clientID:clientID
                                                                                          sequenceID:standardSequenceNumber++
                                                                                            playerID:playerID
                                                                                               muted:isMuted];
  [self performSelector:@selector(sendData:) onThread:connectionThread withObject:packet waitUntilDone:NO];
  [pool release];
}

@end

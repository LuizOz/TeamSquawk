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
#define LOGIN_DEBUG 1
#ifdef LOGIN_DEBUG
# define LOGIN_DBG(x...) NSLog(x)
#else
# define LOGIN_DBG(x...)
#endif

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

- (id)initWithHost:(NSString*)host withPort:(short)port withError:(NSError**)error
{
  if (self = [super init])
  {
    socket = [[GCDUDPSocket alloc] initWithDelegate:self];
    BOOL connected = [socket connectToHost:host port:port error:error];
    
    fragments = nil;
    audioSequenceCounter = 0;
    isDisconnecting = NO;
    hasFinishedDisconnecting = NO;
    pendingReceive = NO;
    pingReplysPending = 0;
    
    connectionSequenceNumber = 0;
    standardSequenceNumber = 0;
    serverConnectionSequenceNumber = 0;
    serverStandardSequenceNumber = 0;
    
    // setup the ping source here but don't start it
    pingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(pingTimer, dispatch_time(DISPATCH_TIME_NOW, 0), 3ull * NSEC_PER_SEC, 1ull * NSEC_PER_SEC);
    dispatch_source_set_event_handler(pingTimer, ^{
      [self pingTimer:nil];
    });    

    if (!connected)
    {
      [*error autorelease];
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
  dispatch_release(pingTimer);
  
  [socket release];
  [fragments release];
  [super dealloc];
}

#pragma mark Commands

- (void)beginAsynchronousLogin:(NSString*)username password:(NSString*)password nickName:(NSString*)nickName isRegistered:(BOOL)isRegistered
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  connectionSequenceNumber = 1;
  
  LOGIN_DBG(@"LOGIN_DBG: begin login");
  
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
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
   
  connectionTimer = [[NSTimer scheduledTimerWithTimeInterval:TRANSMIT_TIMEOUT target:self selector:@selector(connectionTimer:) userInfo:nil repeats:NO] retain];
  
  [pool release];
}

- (void)disconnect
{
  dispatch_suspend(pingTimer);
  
  isDisconnecting = YES;
  
  LOGIN_DBG(@"LOGIN_DBG: begin disconnect");
  
  NSData *packet = [[SLPacketBuilder packetBuilder] buildDisconnectPacketWithConnectionID:connectionID clientID:clientID sequenceID:standardSequenceNumber++];
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
  
  LOGIN_DBG(@"LOGIN_DBG: waiting for disconnect");
  
  while (!hasFinishedDisconnecting)
  {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
  LOGIN_DBG(@"LOGIN_DBG: disconnect completed");
  
  if ([self delegate] && [[self delegate] respondsToSelector:@selector(connectionDisconnected:withError:)])
  {
    [[self delegate] connectionDisconnected:self withError:nil];
  }
}

#pragma mark Incoming Events

- (void)GCDUDPSocket:(GCDUDPSocket*)sock didReceiveData:(NSData*)data fromHost:(NSString*)host port:(unsigned short)port
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  SLPacketChomper *chomper = [SLPacketChomper packetChomperWithSocket:socket];
    
  pendingReceive = NO;
  
  [chomper setFragment:fragments];
  NSDictionary *packet = [chomper chompPacket:data];
  
  [fragments autorelease];
  fragments = [[chomper fragment] retain];
  
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
          return;
        }
        serverConnectionSequenceNumber = seq;
      }
      else if ((packetType & 0x0000ffff) == 0x0000bef0)
      {
        // standard sequence
        if (seq <= serverStandardSequenceNumber)
        {
          return;
        }
        serverStandardSequenceNumber = seq;
      }
    }
    
    switch (packetType)
    {
      case PACKET_TYPE_LOGIN_REPLY:
      {
        LOGIN_DBG(@"LOGIN_DBG: server login reply, part 1");
        
        BOOL isBadLogin = [[packet objectForKey:@"SLBadLogin"] boolValue];
        standardSequenceNumber = 1;

        if (isBadLogin)
        {
          if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionFailedToLogin:withError:)])
          {
            NSString *desc, *recoverySuggestion;
            switch ([[packet objectForKey:@"SLBadLoginCode"] unsignedCharValue])
            {
              case 0xff:
              {
                desc = @"The server refused your credentials.";
                recoverySuggestion = @"Please check your username and password and try again.";
                break;
              }
              case 0xfe:
              {
                desc = @"Too many users logged in.";
                recoverySuggestion = @"Too many users are logged in to this server, please try again later.";
                break;
              }
              case 0xfa:
              {
                desc = @"You are banned.";
                recoverySuggestion = @"You are banned from this server.";
                break;
              }
              case 0xf9:
              {
                desc = @"Already logged in.";
                recoverySuggestion = @"A user with your login details is already logged in to the server.";
                break;
              }
              default:
              {
                NSLog(@"%x", [[packet objectForKey:@"SLBadLoginCode"] unsignedCharValue]);
                desc = @"Server returned \"Bad Login\"";
                recoverySuggestion = @"Please check your username and password and try again.";
                break;
              }
            }
            
            [connectionTimer invalidate];
            [connectionTimer release];
            connectionTimer = nil;
            
            NSError *error = [NSError errorWithDomain:@"SLConnectionError" 
                                                 code:SLConnectionErrorBadLogin 
                                             userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       desc, NSLocalizedDescriptionKey,
                                                       recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
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
          [sock sendData:newPacket withTimeout:TRANSMIT_TIMEOUT];
          
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
        LOGIN_DBG(@"LOGIN_DBG: recieved channel list");
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedChannelList:)])
        {
          [[self delegate] connection:self receivedChannelList:packet];
        }
        break;
      }
      case PACKET_TYPE_PLAYER_LIST:
      {
        LOGIN_DBG(@"LOGIN_DBG: recieved player list");
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerList:)])
        {
          [[self delegate] connection:self receivedPlayerList:packet];
        }
        break;
      }
      case PACKET_TYPE_LOGIN_END:
      {
        LOGIN_DBG(@"LOGIN_DBG: login complete");
        
        // reset the sequence ids
        connectionSequenceNumber = 0;
        
        // clear the connection timeout timer
        [connectionTimer invalidate];
        [connectionTimer release];
        connectionTimer = nil;
        
        // start the ping timer
        dispatch_resume(pingTimer);
                
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionFinishedLogin:)])
        {
          [[self delegate] connectionFinishedLogin:self];
        }
        
        break;
      }
      case PACKET_TYPE_PING_REPLY:
      {
        LOGIN_DBG(@"LOGIN_DBG: ping counter reset");
        
        pingReplysPending = 0;
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionPingReply:)])
        {
          [[self delegate] connectionPingReply:self];
        }
        break;
      }
      case PACKET_TYPE_TEXT_MESSAGE:
      {
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
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedVoiceMessage:codec:playerID:isWhisper:senderPacketCounter:)])
        {
          NSData *data = [packet objectForKey:@"SLAudioCodecData"];
          SLAudioCodecType codec = (([[packet objectForKey:@"SLPacketType"] unsignedIntValue] >> 24) & 0xff);
          unsigned int playerID = [[packet objectForKey:@"SLSenderID"] unsignedIntValue];
          unsigned short count = [[packet objectForKey:@"SLSenderCounter"] unsignedShortValue];
          BOOL isWhisper = [[packet objectForKey:@"SLIsWhisper"] boolValue];
          
          [[self delegate] connection:self receivedVoiceMessage:data codec:codec playerID:playerID isWhisper:isWhisper senderPacketCounter:count];
        }
        break;
      }
      case PACKET_TYPE_NEW_PLAYER:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedNewPlayerNotification:channel:nickname:channelPrivFlags:extendedFlags:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int channelID = [[packet objectForKey:@"SLChannelID"] unsignedIntValue];
          unsigned int channelPrivFlags = [[packet objectForKey:@"SLChannelPrivFlags"] unsignedIntValue];
          unsigned int extendedFlags = [[packet objectForKey:@"SLPlayerExtendedFlags"] unsignedIntValue];
          NSString *nick = [packet objectForKey:@"SLNickname"];
          
          [[self delegate] connection:self receivedNewPlayerNotification:playerID channel:channelID nickname:nick channelPrivFlags:channelPrivFlags extendedFlags:extendedFlags];
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
        
        unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
        // check if we're not disconnecting but it was us that left. we've been kicked or the server went down
        if (!isDisconnecting && (playerID == clientID) && [self delegate] && [[self delegate] respondsToSelector:@selector(connectionDisconnected:withError:)])
        {
          dispatch_suspend(pingTimer);
          
          NSError *error = [NSError errorWithDomain:@"SLConnection" code:SLConnectionErrorSelfLeft userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                             @"Disconnected from server", NSLocalizedDescriptionKey,
                                                                                                             @"You were disconnected from the server.", NSLocalizedRecoverySuggestionErrorKey,
                                                                                                             nil]];
          [[self delegate] connectionDisconnected:self withError:error];
        }
        else
        {
          if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerLeftNotification:)])
          {
            [[self delegate] connection:self receivedPlayerLeftNotification:playerID];
          }
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
      case PACKET_TYPE_PRIV_UPDATE:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerPriviledgeChangeNotification:byPlayerID:changeType:privFlag:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int byPlayerID = [[packet objectForKey:@"SLFromPlayerID"] unsignedIntValue];
          unsigned int flag = 0;
          BOOL addNotRemove = [[packet objectForKey:@"SLAddNotRemove"] boolValue];
          
          switch ([[packet objectForKey:@"SLPrivFlag"] unsignedIntValue])
          {
            case 0x00:
              flag = SLConnectionChannelAdmin;
              break;
            case 0x01:
              flag = SLConnectionOperator;
              break;
            case 0x02:
              flag = SLConnectionVoice;
              break;
          }
          
          if (flag != 0)
          {
            [[self delegate] connection:self receivedPlayerPriviledgeChangeNotification:playerID byPlayerID:byPlayerID changeType:addNotRemove privFlag:flag];
          }
        }
        break;
      }
      case PACKET_TYPE_SERVERPRIV_UPDATE:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerServerPriviledgeChangeNotification:byPlayerID:changeType:privFlag:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int byPlayerID = [[packet objectForKey:@"SLFromPlayerID"] unsignedIntValue];
          unsigned int flag = 0;
          BOOL addNotRemove = [[packet objectForKey:@"SLAddNotRemove"] boolValue];
          
          switch ([[packet objectForKey:@"SLPrivFlag"] unsignedIntValue])
          {
            case 0x00:
              flag = SLConnectionServerAdmin;
              break;
          }
          
          if (flag != 0)
          {
            [[self delegate] connection:self receivedPlayerServerPriviledgeChangeNotification:playerID byPlayerID:byPlayerID changeType:addNotRemove privFlag:flag];
          }
        }
        break;
      }
      case PACKET_TYPE_SERVERINFO_UPDATE:
      {
        NSData *data = [packet objectForKey:@"SLPermissionsData"];
        [self parsePermissionData:data];
        break;
      }
      case PACKET_TYPE_PLAYER_CHANKICKED:
      {
        if (!isDisconnecting && [self delegate] && [[self delegate] respondsToSelector:@selector(connection:receivedPlayerKickedFromChannel:fromChannel:intoChannel:reason:)])
        {
          unsigned int playerID = [[packet objectForKey:@"SLPlayerID"] unsignedIntValue];
          unsigned int byPlayerID = [[packet objectForKey:@"SLFromChannelID"] unsignedIntValue];
          unsigned int channelID = [[packet objectForKey:@"SLToChannelID"] unsignedIntValue];
          NSString *reason = [packet objectForKey:@"SLReason"];
          
          [[self delegate] connection:self receivedPlayerKickedFromChannel:playerID fromChannel:byPlayerID intoChannel:channelID reason:reason];
        }
        break;
      }
      default:
        NSLog(@"got chomped packet I don't know about: %@", packet);
    }
  }
  [pool release];
  return;
}

#pragma mark Permissions

- (void)parsePermissionData:(NSData*)data
{
  unsigned int position = 0;
  
  // skip 10 bytes of crap
  position += 10;
  
  [data getBytes:serverAdminPermissions range:NSMakeRange(position, 10)];
  position += 10;
  
#ifdef PERMS_DEBUG
  NSLog(@"server admin: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x", 
        serverAdminPermissions[0], serverAdminPermissions[1], serverAdminPermissions[2], serverAdminPermissions[3], serverAdminPermissions[4],
        serverAdminPermissions[5], serverAdminPermissions[6], serverAdminPermissions[7], serverAdminPermissions[8], serverAdminPermissions[9]);
#endif
  
  // skip 4 bytes
  position += 4;
  
  [data getBytes:channelAdminPermissions range:NSMakeRange(position, 8)];
  position += 8;
  
#ifdef PERMS_DEBUG
  NSLog(@"channel admin: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        channelAdminPermissions[0], channelAdminPermissions[1], channelAdminPermissions[2], channelAdminPermissions[3],
        channelAdminPermissions[4], channelAdminPermissions[5], channelAdminPermissions[6], channelAdminPermissions[7]);
#endif
  
  // skip 3 bytes
  position += 3;
  
  [data getBytes:operatorPemissions range:NSMakeRange(position, 8)];
  position += 8;
  
#ifdef PERMS_DEBUG
  NSLog(@"operator: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        operatorPemissions[0], operatorPemissions[1], operatorPemissions[2], operatorPemissions[3],
        operatorPemissions[4], operatorPemissions[5], operatorPemissions[6], operatorPemissions[7]);
#endif
  
  // skip 3 bytes
  position += 3;
  
  [data getBytes:voicePermissions range:NSMakeRange(position, 8)];
  position += 8;
  
#ifdef PERMS_DEBUG
  NSLog(@"voice: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        voicePermissions[0], voicePermissions[1], voicePermissions[2], voicePermissions[3],
        voicePermissions[4], voicePermissions[5], voicePermissions[6], voicePermissions[7]);
#endif
  
  // skip no bytes here
  
  [data getBytes:registeredPermissions range:NSMakeRange(position, 10)];
  position += 10;
  
#ifdef PERMS_DEBUG
  NSLog(@"registered: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x", 
        registeredPermissions[0], registeredPermissions[1], registeredPermissions[2], registeredPermissions[3], registeredPermissions[4],
        registeredPermissions[5], registeredPermissions[6], registeredPermissions[7], registeredPermissions[8], registeredPermissions[9]);
#endif
  
  // skip 4 bytes
  position += 4;
  
  [data getBytes:anonymousPermissions range:NSMakeRange(position, 8)];
  
#ifdef PERMS_DEBUG
  NSLog(@"anonymous: 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x 0x%02x ", 
        anonymousPermissions[0], anonymousPermissions[1], anonymousPermissions[2], anonymousPermissions[3],
        anonymousPermissions[4], anonymousPermissions[5], anonymousPermissions[6], anonymousPermissions[7]);
#endif
}

- (BOOL)checkPermission:(unsigned char)permission permissionType:(SLConnectionPermissionType)type forExtendedFlags:(SLConnectionExtendedFlags)extendedFlags andChannelPrivFlags:(SLConnectionChannelPrivFlags)channelPrivFlags
{
  unsigned char permission10ByteMap[] = { PERMS_10BYTE_MISC_BYTE, PERMS_10BYTE_REVOKE_BYTE, PERMS_10BYTE_GRANT_BYTE, PERMS_10BYTE_CHANEDIT_BYTE, PERMS_10BYTE_CHAN_BYTE, PERMS_10BYTE_ADMIN_BYTE };
  unsigned char permission8ByteMap[] = { PERMS_8BYTE_MISC_BYTE, PERMS_8BYTE_REVOKE_BYTE, PERMS_8BYTE_GRANT_BYTE, PERMS_8BYTE_CHANEDIT_BYTE, PERMS_8BYTE_CHAN_BYTE, PERMS_8BYTE_ADMIN_BYTE };
  
  BOOL hasPermission = NO;
  
  // go through in order, Server Admin first
  if ((extendedFlags & SLConnectionServerAdmin) == SLConnectionServerAdmin)
  {
    hasPermission = ((serverAdminPermissions[permission10ByteMap[type]] & permission) == permission);
  }
  
  if (!hasPermission && ((extendedFlags & SLConnectionRegisteredPlayer) == SLConnectionRegisteredPlayer))
  {
    hasPermission = ((registeredPermissions[permission10ByteMap[type]] & permission) == permission);
  }
  
  if (!hasPermission && ((channelPrivFlags & SLConnectionChannelAdmin) == SLConnectionChannelAdmin))
  {
    hasPermission = ((channelAdminPermissions[permission8ByteMap[type]] & permission) == permission);
  }
  
  if (!hasPermission && ((channelPrivFlags & SLConnectionOperator) == SLConnectionOperator))
  {
    hasPermission = ((operatorPemissions[permission8ByteMap[type]] & permission) == permission);
  }
  
  if (!hasPermission && ((channelPrivFlags & SLConnectionVoice) == SLConnectionVoice))
  {
    hasPermission = ((voicePermissions[permission8ByteMap[type]] & permission) == permission);
  }
  
  // anonymous
  if (!hasPermission)
  {
    hasPermission = ((anonymousPermissions[permission8ByteMap[type]] & permission) == permission);
  }
  
  return hasPermission;
}

#pragma mark Ping Timer

- (void)pingTimer:(NSTimer*)timer
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (pingReplysPending > 5)
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

    dispatch_suspend(pingTimer);
    return;
  }
  
  // fire a ping every time this goes off
  NSData *data = [[SLPacketBuilder packetBuilder] buildPingPacketWithConnectionID:connectionID clientID:clientID sequenceID:connectionSequenceNumber++];
  [socket sendData:data withTimeout:TRANSMIT_TIMEOUT];
  
  pingReplysPending++;
  
  LOGIN_DBG(@"LOGIN_DBG: ping sent, %d pending", pingReplysPending);
  
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
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
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
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
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
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
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
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
  [pool release];
}

- (void)changeStatusTo:(unsigned short)flags
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildChangePlayerStatusMessageWithConnectionID:connectionID
                                                                                          clientID:clientID
                                                                                        sequenceID:standardSequenceNumber++
                                                                                    newStatusFlags:flags];
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
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
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
  [pool release];
}

#pragma mark Admin Functions

- (void)kickPlayer:(unsigned int)player withReason:(NSString*)reason
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildKickMessageWithConnectionID:connectionID 
                                                                            clientID:clientID
                                                                          sequenceID:standardSequenceNumber++
                                                                            playerID:player
                                                                              reason:reason];
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
  [pool release];
}

- (void)kickPlayerFromChannel:(unsigned int)player withReason:(NSString*)reason
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSData *packet = [[SLPacketBuilder packetBuilder] buildChannelKickMessageWithConnectionID:connectionID
                                                                                   clientID:clientID 
                                                                                 sequenceID:standardSequenceNumber++
                                                                                   playerID:player
                                                                                     reason:reason];
  [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT];
  [pool release];
}

@end

//
//  SLPacketChomper.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SLPacketChomper.h"
#import "SLPacketBuilder.h"

#import "NSData+Extensions.h"


#define SNARF_INIT(data)  unsigned int snarfPos = 0; \
                          NSData *snarfData = data

#define SNARF_SKIP(count) snarfPos += count;
#define SNARF_POS()       snarfPos

#define SNARF_BYTES(dest, count)  [snarfData getBytes:&dest range:NSMakeRange(snarfPos, count)]; \
                                  snarfPos += count

#define SNARF_BYTE(dest)  [snarfData getBytes:&dest range:NSMakeRange(snarfPos, 1)]; \
                          snarfPos += 1

#define SNARF_SHORT(dest) [snarfData getBytes:&dest range:NSMakeRange(snarfPos, 2)]; \
                          snarfPos += 2; \
                          dest = NSSwapLittleShortToHost(dest)

#define SNARF_INT(dest)   [snarfData getBytes:&dest range:NSMakeRange(snarfPos, 4)]; \
                          snarfPos += 4; \
                          dest = NSSwapLittleIntToHost(dest)

#define SNARF_DATA(dest, count)   dest = [data subdataWithRange:NSMakeRange(snarfPos, count)]; \
                                  snarfPos += count

#define SNARF_255BYTE_STRING(dest)  unsigned char dest##Len = 0; \
                                    unsigned char dest##Buffer[255]; \
                                    [snarfData getBytes:&dest##Len range:NSMakeRange(snarfPos, 1)]; \
                                    snarfPos += 1; \
                                    [snarfData getBytes:&dest##Buffer range:NSMakeRange(snarfPos, 255)]; \
                                    snarfPos += 255; \
                                    dest = [[[NSString alloc] initWithCString:(const char*)dest##Buffer length:dest##Len] autorelease]

#define SNARF_30BYTE_STRING(dest)   unsigned char dest##Len; \
                                    unsigned char dest##Buffer[29]; \
                                    [snarfData getBytes:&dest##Len range:NSMakeRange(snarfPos, 1)]; \
                                    snarfPos += 1; \
                                    memset(dest##Buffer, '\0', 29); \
                                    [snarfData getBytes:&dest##Buffer range:NSMakeRange(snarfPos, 29)]; \
                                    snarfPos += 29; \
                                    dest = [[[NSString alloc] initWithCString:(const char*)dest##Buffer length:dest##Len] autorelease]

#define SNARF_NULLTERM_STRING(dest) char *dest##DataPtr = (char*)[[snarfData subdataWithRange:NSMakeRange(snarfPos, [snarfData length] - snarfPos)] bytes]; \
                                    unsigned int dest##Len = (strlen(dest##DataPtr) < ([snarfData length] - snarfPos)) ? strlen(dest##DataPtr) : ([snarfData length] - snarfPos); \
                                    dest = [[[NSString alloc] initWithCString:dest##DataPtr length:dest##Len] autorelease]; \
                                    snarfPos += dest##Len + 1

#define SNARF_CRC()   unsigned int crc; \
                      [snarfData getBytes:&crc range:NSMakeRange(snarfPos, 4)]; \
                      crc = NSSwapLittleIntToHost(crc); \
                      NSMutableData *crcCheckData = [snarfData mutableCopy]; \
                      [crcCheckData resetBytesInRange:NSMakeRange(snarfPos, 4)]; \
                      if ([crcCheckData crc32] != crc) \
                      { \
                        NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc); \
                      } \
                      [crcCheckData release]; \
                      snarfPos += 4

@implementation SLPacketChomper

+ (id)packetChomper
{
  return [[[[self class] alloc] init] autorelease];
}

+ (id)packetChomperWithSocket:(AsyncUdpSocket*)socket
{
  return [[[[self class] alloc] initWithSocket:socket] autorelease];
}

- (id)init
{
  if (self = [super init])
  {
    // nada
    socket = nil;
    fragment = nil;
  }
  return self;
}

- (id)initWithSocket:(AsyncUdpSocket*)aSocket
{
  if (self = [self init])
  {
    [self setSocket:aSocket];
  }
  return self;
}

- (void)dealloc
{
  [fragment release];
  [socket release];
  [super dealloc];
}

- (void)setSocket:(AsyncUdpSocket*)aSocket
{
  [socket autorelease];
  socket = [aSocket retain];
}

- (void)setFragment:(NSDictionary*)dictionary
{
  [fragment autorelease];
  fragment = [dictionary retain];
}

#pragma mark Chomper

- (NSDictionary*)chompPacket:(NSData*)data
{
  SNARF_INIT(data);
  
  // We've been given a packet to do something with. First four bytes of the packet are the packet type.
  unsigned int packetType, connectionID, clientID, sequenceNumber;
  SNARF_INT(packetType);
  
  if (packetType == PACKET_TYPE_ACKNOWELDGE)
  {
    // catch ack early. we don't really care about them.
    return nil;
  }
  
  // these aren't true for all packets. the one that aren't we'll have to specficially not send acks in the
  // switch statement.
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  SNARF_INT(sequenceNumber);
  
  switch (packetType) 
  {
    case PACKET_TYPE_LOGIN_REPLY:
    {
      return [self chompLoginReply:data];
      break;
    }
    case PACKET_TYPE_CHANNEL_LIST:
    {
      NSDictionary *chompedPacket = [self chompChannelList:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_PLAYER_LIST:
    {
      NSDictionary *chompedPacket = [self chompPlayerList:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_LOGIN_END:
    {
      // there is some data in this packet but i'm not convinced I care enough about it. looked like a url to the server website or something
      // in wireshark
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:packetType], @"SLPacketType", [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber", nil];
    }
    case PACKET_TYPE_PING_REPLY:
    {
      // we don't need to ack ping packets.
      return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:packetType], @"SLPacketType", nil];
    }
    case PACKET_TYPE_TEXT_MESSAGE:
    {
      NSDictionary *chompedPacket = [self chompTextMessage:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
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
      NSDictionary *chompedPacket = [self chompVoiceMessage:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_NEW_PLAYER:
    {
      NSDictionary *chompedPacket = [self chompNewPlayer:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_PLAYER_LEFT:
    {
      NSDictionary *chompedPacket = [self chompPlayerLeft:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_CHANNEL_CHANGE:
    {
      NSDictionary *chompedPacket = [self chompChannelChange:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_PLAYER_UPDATE:
    {
      NSDictionary *chompedPacket = [self chompPlayerUpdate:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_PLAYER_MUTED:
    {
      NSDictionary *chompedPacket = [self chompPlayerMutedUpdate:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_PRIV_UPDATE:
    {
      NSDictionary *chompedPacket = [self chompChannelPrivUpdate:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_SERVERPRIV_UPDATE:
    {
      NSDictionary *chompedPacket = [self chompServerPrivUpdate:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_SERVERINFO_UPDATE:
    {
      NSDictionary *chompedPacket = [self chompServerInfoUpdate:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    case PACKET_TYPE_PLAYER_CHANKICKED:
    {
      NSDictionary *chompedPacket = [self chompPlayerKicked:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      return chompedPacket;
    }
    default:
    {
      NSLog(@"unknown packet type: 0x%08x", packetType);
      NSData *packet = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:packet withTimeout:TRANSMIT_TIMEOUT tag:0];
      [socket maybeDequeueSend];
      break;
    }
  }
  return nil;
}

#pragma mark Login

- (NSDictionary*)chompLoginReply:(NSData*)data
{
  SNARF_INIT(data);
  
  // We've already got the packet type. So start at the session key, though it appears to be zero on this kind of reply.
  SNARF_SKIP(4);
  
  unsigned int sessionKey;
  SNARF_INT(sessionKey);
  
  unsigned int clientID;
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber;
  SNARF_INT(sequenceNumber);
  
  SNARF_CRC();
  
  // server name is next, guessing its 30 bytes like most of the other stuff. one length, 29 data.
  NSString *serverName;
  SNARF_30BYTE_STRING(serverName);
  
  // platform string
  NSString *platformName;
  SNARF_30BYTE_STRING(platformName);
  
  // versions
  unsigned short majorVersion, minorVersion;
  unsigned short subLevelVersion, subsubLevelVersion;
  SNARF_SHORT(majorVersion);
  SNARF_SHORT(minorVersion);
  SNARF_SHORT(subLevelVersion);
  SNARF_SHORT(subsubLevelVersion);
  
  // bad login?
  unsigned char badLogin[4] = { 0x0, 0x0, 0x0, 0x0 };
  SNARF_BYTES(badLogin, 4);
  
  // These are the permissions bits
  NSData *permissions;
  SNARF_DATA(permissions, 80);
  
  // session key
  unsigned int newConnectionID = 0;
  SNARF_INT(newConnectionID);
  
  // there appears to be a rogue 4 bytes here, so 176 to 180
  SNARF_SKIP(4);
  
  // welcome message
  NSString *welcomeMessage;
  SNARF_255BYTE_STRING(welcomeMessage);
  
  BOOL isBadLogin = ((badLogin[1] == 0xff) && (badLogin[2] == 0xff) && (badLogin[3] == 0xff));
  
  // build this all into a dictionary
  NSDictionary *packetDescriptionDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithUnsignedInt:PACKET_TYPE_LOGIN_REPLY], @"SLPacketType",
                                               [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                               [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                               [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                               serverName, @"SLServerName",
                                               platformName, @"SLPlatform",
                                               [NSNumber numberWithUnsignedShort:majorVersion], @"SLMajorVersion",
                                               [NSNumber numberWithUnsignedShort:minorVersion], @"SLMinorVersion",
                                               [NSNumber numberWithUnsignedShort:subLevelVersion], @"SLSubLevelVersion",
                                               [NSNumber numberWithUnsignedShort:subsubLevelVersion], @"SLSubSubLevelVersion",
                                               [NSNumber numberWithBool:isBadLogin], @"SLBadLogin",
                                               [NSNumber numberWithUnsignedChar:badLogin[0]], @"SLBadLoginCode",
                                               [NSNumber numberWithUnsignedInt:newConnectionID], @"SLNewConnectionID",
                                               welcomeMessage, @"SLWelcomeMessage",
                                               permissions, @"SLPermissionsData",
                                               nil];

  return packetDescriptionDictionary;
}

#pragma mark Server Info

- (NSDictionary*)chompChannelList:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);

  // crc
  SNARF_CRC();
  
  // number of channels
  unsigned int currentChannel = 0, numberOfChannels = 0;
  SNARF_INT(numberOfChannels);
  
  NSMutableArray *channels = [NSMutableArray array];
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_CHANNEL_LIST], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:numberOfChannels], @"SLNumberOfChannels",
                                    channels, @"SLChannels",
                                    nil];
  if (numberOfChannels > 100) {
		return packetDictionary;
  }
  while (currentChannel < numberOfChannels)
  {
    unsigned int channelID = 0;
    SNARF_INT(channelID);
    
    unsigned short flags = 0;
    SNARF_SHORT(flags);
    
    unsigned short codec = 0;
    SNARF_SHORT(codec);
    
    unsigned int parentID = 0;
    SNARF_INT(parentID);
    
    unsigned short sortOrder = 0;
    SNARF_SHORT(sortOrder);
    
    unsigned short maxUsers;
    SNARF_SHORT(maxUsers);
    
    // we have to start reading null-terminated strings here :(
    NSString *channelName;
    SNARF_NULLTERM_STRING(channelName);
    
    NSString *channelTopic;
    SNARF_NULLTERM_STRING(channelTopic);

    NSString *channelDescription;
    SNARF_NULLTERM_STRING(channelDescription);
    
    NSDictionary *channelDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSNumber numberWithUnsignedInt:channelID], @"SLChannelID",
                                       [NSNumber numberWithUnsignedShort:flags], @"SLChannelFlags",
                                       [NSNumber numberWithUnsignedShort:codec], @"SLChannelCodec",
                                       [NSNumber numberWithUnsignedInt:parentID], @"SLChannelParentID",
                                       channelName, @"SLChannelName",
                                       channelTopic, @"SLChannelTopic",
                                       channelDescription, @"SLChannelDescription",
                                       [NSNumber numberWithUnsignedShort:maxUsers], @"SLChannelMaxUsers",
                                       [NSNumber numberWithUnsignedShort:sortOrder], @"SLChannelSortOrder",
                                       nil];
    [channels addObject:channelDictionary];    
    currentChannel++;
  }
  
  return packetDictionary;
}

- (NSDictionary*)chompPlayerList:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);

  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();
  
  unsigned int currentPlayer = 0, numberOfPlayers = 0;
  SNARF_INT(numberOfPlayers);
  
  NSMutableArray *players = [NSMutableArray array];
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_LIST], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:numberOfPlayers], @"SLNumberOfPlayers",
                                    players, @"SLPlayers",
                                    nil];
  
  for (currentPlayer = 0; currentPlayer < numberOfPlayers; currentPlayer++)
  {
    unsigned int playerID = 0;
    SNARF_INT(playerID);
    
    unsigned int channelID = 0;
    SNARF_INT(channelID);

    unsigned short channelPrivFlags;
    SNARF_SHORT(channelPrivFlags);
    
    unsigned short playerExtendedFlags;
    SNARF_SHORT(playerExtendedFlags);
    
    unsigned short flags = 0;
    SNARF_SHORT(flags);
    
    NSString *nick;
    SNARF_30BYTE_STRING(nick);
    
    NSDictionary *playerDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                      [NSNumber numberWithUnsignedInt:channelID], @"SLChannelID",
                                      [NSNumber numberWithUnsignedShort:flags], @"SLPlayerFlags",
                                      [NSNumber numberWithUnsignedShort:playerExtendedFlags], @"SLPlayerExtendedFlags",
                                      [NSNumber numberWithUnsignedShort:channelPrivFlags], @"SLChannelPrivFlags",
                                      nick, @"SLPlayerNick",
                                      nil];
    [players addObject:playerDictionary];
  }
  
  return packetDictionary;
}

- (NSDictionary*)chompServerInfoUpdate:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();
  
  NSData *serverPermissions;
  SNARF_DATA(serverPermissions, 80);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_SERVERINFO_UPDATE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    serverPermissions, @"SLPermissionsData",
                                    nil];
  
  return packetDictionary;
}

#pragma mark Status Updates

- (NSDictionary*)chompNewPlayer:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();
  
  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned int channelID;
  SNARF_INT(channelID);
  
  unsigned short channelPrivFlags;
  SNARF_SHORT(channelPrivFlags);
  
  unsigned short extendedFlags;
  SNARF_SHORT(extendedFlags);
  
  SNARF_SKIP(2);
  
  NSString *nick;
  SNARF_30BYTE_STRING(nick);
  
  // 4 bytes at the end that I don't know what they are either
  SNARF_SKIP(4);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_NEW_PLAYER], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedInt:channelID], @"SLChannelID",
                                    [NSNumber numberWithUnsignedInt:extendedFlags], @"SLPlayerExtendedFlags",
                                    [NSNumber numberWithUnsignedShort:channelPrivFlags], @"SLChannelPrivFlags",
                                    nick, @"SLNickname",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompPlayerLeft:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();

  unsigned int playerID;
  SNARF_INT(playerID);
  
  // there is a whole load of crap in the player left packet but I've no idea what
  // it means. Some if it will be timed out vs. disconnected I imagine
  
  // its actually
  // short x3 + 30 byte string. if I ever care.
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_LEFT], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompChannelChange:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();
  
  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned int previousChannelID;
  SNARF_INT(previousChannelID);
  
  unsigned int newChannelID;
  SNARF_INT(newChannelID);
  
  // 2 bytes of unknown + possible other crc?
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_CHANNEL_CHANGE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedInt:previousChannelID], @"SLPreviousChannelID",
                                    [NSNumber numberWithUnsignedInt:newChannelID], @"SLNewChannelID",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompPlayerUpdate:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();

  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned short playerFlags;
  SNARF_SHORT(playerFlags);
  
  // 4 bytes of unknown, possible other crc?
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_UPDATE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedShort:playerFlags], @"SLPlayerFlags",
                                    nil];
  
  return packetDictionary;  
}

- (NSDictionary*)chompPlayerMutedUpdate:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();
  
  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned char mutedStatus;
  SNARF_BYTE(mutedStatus);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_MUTED], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithBool:(mutedStatus == 0x01 ? YES : NO)], @"SLMutedStatus",
                                    nil];
  return packetDictionary;
}

- (NSDictionary*)chompChannelPrivUpdate:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();  
  
  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned char addOrRemove;
  SNARF_BYTE(addOrRemove);
  
  unsigned char privFlag;
  SNARF_BYTE(privFlag);
  
  unsigned int fromPlayerID;
  SNARF_INT(fromPlayerID);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PRIV_UPDATE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:fragmentCount], @"SLFragmentCount",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithBool:(addOrRemove == 0x0 ? YES : NO)], @"SLAddNotRemove",
                                    [NSNumber numberWithUnsignedChar:privFlag], @"SLPrivFlag",
                                    [NSNumber numberWithUnsignedInt:fromPlayerID], @"SLFromPlayerID",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompServerPrivUpdate:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();  
  
  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned char addOrRemove;
  SNARF_BYTE(addOrRemove);
  
  unsigned char privFlag;
  SNARF_BYTE(privFlag);
  
  unsigned int fromPlayerID;
  SNARF_INT(fromPlayerID);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_SERVERPRIV_UPDATE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:fragmentCount], @"SLFragmentCount",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithBool:(addOrRemove == 0x0 ? YES : NO)], @"SLAddNotRemove",
                                    [NSNumber numberWithUnsignedChar:privFlag], @"SLPrivFlag",
                                    [NSNumber numberWithUnsignedInt:fromPlayerID], @"SLFromPlayerID",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompPlayerKicked:(NSData*)data
{
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();  
  
  unsigned int playerID;
  SNARF_INT(playerID);
  
  unsigned int fromChannel;
  SNARF_INT(fromChannel);
  
  unsigned int toChannel;
  SNARF_INT(toChannel);
  
  unsigned short unknown;
  SNARF_SHORT(unknown);
  
  NSString *reason;
  SNARF_30BYTE_STRING(reason);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_CHANKICKED], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:fragmentCount], @"SLFragmentCount",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedInt:fromChannel], @"SLFromChannelID",
                                    [NSNumber numberWithUnsignedInt:toChannel], @"SLToChannelID",
                                    reason, @"SLReason",
                                    nil];
  
  return packetDictionary;
}

#pragma mark Text/Chat Messages

- (NSDictionary*)chompTextMessage:(NSData*)data
{
  // Firstly, if we've got a fragment and its count is more than
  // zero, we need to divert to the more message handler
  if (fragment && ([[fragment objectForKey:@"SLFragmentCount"] unsignedIntValue] > 0))
  {
    return [self chompMoreTextMessage:data];
  }
  
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();
  
  // there appears to be 5 bytes of crap here, probably 4 + 1 but the length
  // of the sending nickname is at the 6th
  SNARF_SKIP(5);
  
  NSString *nick;
  SNARF_30BYTE_STRING(nick);
  
  // according to libtbb, the message data starts at 0x3b (59) and continues till the first
  // null character. if it hits EOM then we should be expecting a second/third/etc packet

  NSString *message;
  SNARF_NULLTERM_STRING(message);
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_TEXT_MESSAGE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:fragmentCount], @"SLFragmentCount",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    nick, @"SLNickname",
                                    message, @"SLMessage",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompMoreTextMessage:(NSData*)data
{
  NSMutableDictionary *mutableFragment = [fragment mutableCopy];
  
  SNARF_INIT(data);
  SNARF_SKIP(4);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
  
  unsigned int sequenceNumber = 0;
  SNARF_INT(sequenceNumber);
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  SNARF_SHORT(resendCount);
  SNARF_SHORT(fragmentCount);
  
  SNARF_CRC();

  NSString *moreMessage;
  SNARF_NULLTERM_STRING(moreMessage);
  
  // we've got more message, mutate the fragment and bomb out
  NSString *messageFragment = [mutableFragment objectForKey:@"SLMessage"];
  NSString *betterMessageFragment = [messageFragment stringByAppendingString:moreMessage];
  
  [mutableFragment setObject:betterMessageFragment forKey:@"SLMessage"];
  [mutableFragment setObject:[NSNumber numberWithUnsignedShort:fragmentCount] forKey:@"SLFragmentCount"];
  
  return mutableFragment;
}

#pragma mark Voice Packet

- (NSDictionary*)chompVoiceMessage:(NSData*)data
{
  SNARF_INIT(data);
  
  unsigned int packetType;
  SNARF_INT(packetType);
  
  BOOL isWhisper = (((packetType >> 16) & 0xff) == 0x01);
  
  // get connection id and client id
  unsigned int connectionID, clientID;
  SNARF_INT(connectionID);
  SNARF_INT(clientID);
    
  unsigned short packetCounter;
  SNARF_SHORT(packetCounter);
  
  unsigned short serverData;
  SNARF_SHORT(serverData);
  
  unsigned int senderID;
  SNARF_INT(senderID);
  
  // one byte of guff here?
  SNARF_SKIP(1);
  
  unsigned short senderCounter;
  SNARF_SHORT(senderCounter);
  
  NSData *audioCodecData;
  SNARF_DATA(audioCodecData, [data length] - SNARF_POS());
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:packetType], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedShort:packetCounter], @"SLPacketCounter",
                                    [NSNumber numberWithUnsignedShort:serverData], @"SLServerData",
                                    [NSNumber numberWithUnsignedInt:senderID], @"SLSenderID",
                                    [NSNumber numberWithUnsignedShort:senderCounter], @"SLSenderCounter",
                                    [NSNumber numberWithBool:isWhisper], @"SLIsWhisper",
                                    audioCodecData, @"SLAudioCodecData",
                                    nil];
  
  return packetDictionary;
}

@end

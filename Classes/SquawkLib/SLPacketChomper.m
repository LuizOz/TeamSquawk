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
  // We've been given a packet to do something with. First four bytes of the packet are the packet type.
  unsigned int packetType, connectionID, clientID, sequenceNumber;
  [data getBytes:&packetType range:NSMakeRange(0, 4)];
  
  if (packetType == PACKET_TYPE_ACKNOWELDGE)
  {
    // catch ack early. we don't really care about them.
    return nil;
  }
  
  // these aren't true for all packets. the one that aren't we'll have to specficially not send acks in the
  // switch statement.
  [data getBytes:&connectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
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
  
  BOOL isBadLogin = ((badLogin[0] == 0xff) && (badLogin[1] == 0xff) && (badLogin[2] == 0xff) && (badLogin[3] == 0xff));
  
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
                                               [NSNumber numberWithUnsignedInt:newConnectionID], @"SLNewConnectionID",
                                               welcomeMessage, @"SLWelcomeMessage",
                                               permissions, @"SLPermissionsData",
                                               nil];

  return packetDescriptionDictionary;
}

#pragma mark Server Info

- (NSDictionary*)chompChannelList:(NSData*)data
{  
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  // number of channels
  unsigned int currentChannel = 0, numberOfChannels = 0;
  [data getBytes:&numberOfChannels range:NSMakeRange(24, 4)];
  
  // from here on we're gonna need a channel byte pointer
  unsigned int byteIndex = 28;
  
  NSMutableArray *channels = [NSMutableArray array];
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_CHANNEL_LIST], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:numberOfChannels], @"SLNumberOfChannels",
                                    channels, @"SLChannels",
                                    nil];
  
  while (currentChannel < numberOfChannels)
  {
    unsigned int channelID = 0;
    [data getBytes:&channelID range:NSMakeRange(byteIndex, 4)];
    byteIndex += 4;
    
    unsigned short flags = 0;
    [data getBytes:&flags range:NSMakeRange(byteIndex, 2)];
    byteIndex += 2;
    
    unsigned short codec = 0;
    [data getBytes:&codec range:NSMakeRange(byteIndex, 2)];
    byteIndex += 2;
    
    unsigned int parentID = 0;
    [data getBytes:&parentID range:NSMakeRange(byteIndex, 4)];
    byteIndex += 4;
    
    unsigned short sortOrder = 0;
    [data getBytes:&sortOrder range:NSMakeRange(byteIndex, 2)];
    byteIndex += 2;
    
    unsigned short maxUsers;
    [data getBytes:&maxUsers range:NSMakeRange(byteIndex, 2)];
    byteIndex += 2;    
    
    // we have to start reading null-terminated strings here :(
    char *dataPtr = (char*)[[data subdataWithRange:NSMakeRange(byteIndex, [data length] - byteIndex)] bytes];
    unsigned int dataLen = strlen(dataPtr);
    
    NSString *channelName = [[[NSString alloc] initWithCString:dataPtr length:dataLen] autorelease];
    byteIndex += dataLen + 1;
    
    dataPtr = (char*)[[data subdataWithRange:NSMakeRange(byteIndex, [data length] - byteIndex)] bytes];
    dataLen = strlen(dataPtr);
    
    NSString *channelTopic = [[[NSString alloc] initWithCString:dataPtr length:dataLen] autorelease];
    byteIndex += dataLen + 1;
    
    dataPtr = (char*)[[data subdataWithRange:NSMakeRange(byteIndex, [data length] - byteIndex)] bytes];
    dataLen = strlen(dataPtr);
    
    NSString *channelDescription = [[[NSString alloc] initWithCString:dataPtr length:dataLen] autorelease];
    byteIndex += dataLen + 1;
        
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
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  unsigned int currentPlayer = 0, numberOfPlayers = 0;
  [data getBytes:&numberOfPlayers range:NSMakeRange(24, 4)];
  
  // they're fixed spaces but we still need a byte counter
  unsigned int byteIndex = 28;
  
  NSMutableArray *players = [NSMutableArray array];
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_LIST], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:numberOfPlayers], @"SLNumberOfPlayers",
                                    players, @"SLPlayers",
                                    nil];
  
  for (currentPlayer = 0; currentPlayer < numberOfPlayers; currentPlayer++)
  {
    unsigned int playerID = 0;
    [data getBytes:&playerID range:NSMakeRange(byteIndex, 4)];
    byteIndex += 4;
    
    unsigned int channelID = 0;
    [data getBytes:&channelID range:NSMakeRange(byteIndex, 4)];
    byteIndex += 4;
    
    // skip two bytes
    byteIndex += 2;
    
    unsigned short playerExtendedFlags;
    [data getBytes:&playerExtendedFlags range:NSMakeRange(byteIndex, 2)];
    byteIndex += 2;
    
    unsigned short flags = 0;
    [data getBytes:&flags range:NSMakeRange(byteIndex, 2)];
    byteIndex += 2;
    
    unsigned char nickLen = 0;
    [data getBytes:&nickLen range:NSMakeRange(byteIndex, 1)];
    byteIndex++;
    
    unsigned char nickBuffer[29];
    [data getBytes:&nickBuffer range:NSMakeRange(byteIndex, 29)];
    byteIndex += 29;
    
    NSString *nick = [[[NSString alloc] initWithCString:(char*)nickBuffer length:nickLen] autorelease];
    
    NSDictionary *playerDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                      [NSNumber numberWithUnsignedInt:channelID], @"SLChannelID",
                                      [NSNumber numberWithUnsignedShort:flags], @"SLPlayerFlags",
                                      [NSNumber numberWithUnsignedShort:playerExtendedFlags], @"SLPlayerExtendedFlags",
                                      nick, @"SLPlayerNick",
                                      nil];
    [players addObject:playerDictionary];
  }
  
  return packetDictionary;
}

#pragma mark Status Updates

- (NSDictionary*)chompNewPlayer:(NSData*)data
{
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  unsigned int playerID;
  [data getBytes:&playerID range:NSMakeRange(24, 4)];
  
  unsigned int channelID;
  [data getBytes:&channelID range:NSMakeRange(28, 4)];
  
  // 2 bytes of crap, then the player extended flags and then two more I don't know about eyt
  unsigned short extendedFlags;
  [data getBytes:&extendedFlags range:NSMakeRange(34, 2)];
  
  unsigned char nickLen;
  char nickBuffer[29];
  [data getBytes:&nickLen range:NSMakeRange(38, 1)];
  [data getBytes:nickBuffer range:NSMakeRange(39, 29)];
  
  NSString *nick = [NSString stringWithCString:nickBuffer length:nickLen];
  
  // 4 bytes at the end that I don't know what they are either
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_NEW_PLAYER], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedInt:channelID], @"SLChannelID",
                                    [NSNumber numberWithUnsignedInt:extendedFlags], @"SLPlayerExtendedFlags",
                                    nick, @"SLNickname",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompPlayerLeft:(NSData*)data
{
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }

  unsigned int playerID;
  [data getBytes:&playerID range:NSMakeRange(24, 4)];
  
  // there is a whole load of crap in the player left packet but I've no idea what
  // it means. Some if it will be timed out vs. disconnected I imagine
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_LEFT], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompChannelChange:(NSData*)data
{
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  unsigned int playerID;
  [data getBytes:&playerID range:NSMakeRange(24, 4)];
  
  unsigned int previousChannelID;
  [data getBytes:&previousChannelID range:NSMakeRange(28, 4)];
  
  unsigned int newChannelID;
  [data getBytes:&newChannelID range:NSMakeRange(32, 4)];
  
  // 2 bytes of unknown + possible other crc?
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_CHANNEL_CHANGE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedInt:previousChannelID], @"SLPreviousChannelID",
                                    [NSNumber numberWithUnsignedInt:newChannelID], @"SLNewChannelID",
                                    nil];
  
  return packetDictionary;
}

- (NSDictionary*)chompPlayerUpdate:(NSData*)data
{
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }

  unsigned int playerID;
  [data getBytes:&playerID range:NSMakeRange(24, 4)];
  
  unsigned short playerFlags;
  [data getBytes:&playerFlags range:NSMakeRange(28, 2)];
  
  // 4 bytes of unknown, possible other crc?
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_UPDATE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithUnsignedShort:playerFlags], @"SLPlayerFlags",
                                    nil];
  
  return packetDictionary;  
}

- (NSDictionary*)chompPlayerMutedUpdate:(NSData*)data
{
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  unsigned int playerID;
  [data getBytes:&playerID range:NSMakeRange(24, 4)];
  
  unsigned char mutedStatus;
  [data getBytes:&mutedStatus range:NSMakeRange(28, 1)];
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_PLAYER_MUTED], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedInt:sequenceNumber], @"SLSequenceNumber",
                                    [NSNumber numberWithUnsignedInt:playerID], @"SLPlayerID",
                                    [NSNumber numberWithBool:(mutedStatus == 0x01 ? YES : NO)], @"SLMutedStatus",
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
  
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  // there appears to be 5 bytes of crap here, probably 4 + 1 but the length
  // of the sending nickname is at the 6th
  
  unsigned char nickLen;
  [data getBytes:&nickLen range:NSMakeRange(29, 1)];
  
  unsigned char nickBuffer[29];
  [data getBytes:&nickBuffer range:NSMakeRange(30, 29)];
  
  NSString *nick = [[[NSString alloc] initWithCString:(char*)nickBuffer length:nickLen] autorelease];
  
  // according to libtbb, the message data starts at 0x3b (59) and continues till the first
  // null character. if it hits EOM then we should be expecting a second/third/etc packet
  
  unsigned int byteIndex = 59;
  
  unsigned char *dataPtr = (unsigned char*)[data bytes];
  NSString *message = [NSString string];
  
  while (byteIndex < [data length])
  {
    if (dataPtr[byteIndex]  == '\0')
    {
      break;
    }
    message = [message stringByAppendingFormat:@"%c", dataPtr[byteIndex++]];
  }
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:PACKET_TYPE_TEXT_MESSAGE], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:crc], @"SLCRC32",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connnectionID], @"SLConnectionID",
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
  
  // get connection id and client id
  unsigned int connnectionID, clientID;
  [data getBytes:&connnectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber = 0;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  // resend and fragment count
  unsigned short resendCount = 0, fragmentCount = 0;
  [data getBytes:&resendCount range:NSMakeRange(16, 2)];
  [data getBytes:&fragmentCount range:NSMakeRange(18, 2)];
  
  // crc
  unsigned int crc = 0;
  [data getBytes:&crc range:NSMakeRange(20, 4)];
  
  // check the crc
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(20, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  unsigned int byteIndex = 24;
  
  unsigned char *dataPtr = (unsigned char*)[data bytes];
  NSString *moreMessage = [NSString string];
  
  while (byteIndex < [data length])
  {
    if (dataPtr[byteIndex] == '\0')
    {
      break;
    }
    moreMessage = [moreMessage stringByAppendingFormat:@"%c", dataPtr[byteIndex++]];
  }
  
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
  unsigned int packetType;
  [data getBytes:&packetType range:NSMakeRange(0, 4)];
  
  BOOL commanderChannel = (((packetType >> 16) & 0xff) == 0x01);
  
  unsigned int connectionID, clientID;
  [data getBytes:&connectionID range:NSMakeRange(4, 4)];
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned short packetCounter;
  [data getBytes:&packetCounter range:NSMakeRange(12, 2)];
  
  unsigned short serverData;
  [data getBytes:&serverData range:NSMakeRange(14, 2)];
  
  unsigned int senderID;
  [data getBytes:&senderID range:NSMakeRange(16, 4)];
  
  // one byte of guff here?
  
  unsigned int senderCounter;
  [data getBytes:&senderCounter range:NSMakeRange(21, 2)];
  
  NSData *audioCodecData = [data subdataWithRange:NSMakeRange(23, [data length]-23)];
  
  NSDictionary *packetDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSNumber numberWithUnsignedInt:packetType], @"SLPacketType",
                                    [NSNumber numberWithUnsignedInt:clientID], @"SLClientID",
                                    [NSNumber numberWithUnsignedInt:connectionID], @"SLConnectionID",
                                    [NSNumber numberWithUnsignedShort:packetCounter], @"SLPacketCounter",
                                    [NSNumber numberWithUnsignedShort:serverData], @"SLServerData",
                                    [NSNumber numberWithUnsignedInt:senderID], @"SLSenderID",
                                    [NSNumber numberWithUnsignedShort:senderCounter], @"SLSenderCounter",
                                    [NSNumber numberWithBool:commanderChannel], @"SLCommandChannel",
                                    audioCodecData, @"SLAudioCodecData",
                                    nil];
  
  return packetDictionary;
}

@end

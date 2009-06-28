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
  [socket release];
  [super dealloc];
}

- (void)setSocket:(AsyncUdpSocket*)aSocket
{
  [socket autorelease];
  socket = [aSocket retain];
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
      [socket sendData:ackPacket withTimeout:20 tag:0];
      return chompedPacket;
    }
    case PACKET_TYPE_PLAYER_LIST:
    {
      NSDictionary *chompedPacket = [self chompPlayerList:data];
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:20 tag:0];
      return chompedPacket;
    }
    case PACKET_TYPE_LOGIN_END:
    {
      // there is some data in this packet but i'm not convinced I care enough about it. looked like a url to the server website or something
      // in wireshark
      NSData *ackPacket = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:ackPacket withTimeout:20 tag:0];
      return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:PACKET_TYPE_LOGIN_END], @"SLPacketType", nil];
    }
    default:
    {
      NSLog(@"unknown packet type: 0x%08x", packetType);
      NSData *packet = [[SLPacketBuilder packetBuilder] buildAcknowledgePacketWithConnectionID:connectionID clientID:clientID sequenceID:sequenceNumber];
      [socket sendData:packet withTimeout:20 tag:0];
      break;
    }
  }
  return nil;
}

#pragma mark Login

- (NSDictionary*)chompLoginReply:(NSData*)data
{
  // We've already got the packet type. So start at the session key, though it appears to be zero on this kind of reply.
  unsigned int sessionKey;
  [data getBytes:&sessionKey range:NSMakeRange(4, 4)];
  
  unsigned int clientID;
  [data getBytes:&clientID range:NSMakeRange(8, 4)];
  
  unsigned int sequenceNumber;
  [data getBytes:&sequenceNumber range:NSMakeRange(12, 4)];
  
  unsigned int crc;
  [data getBytes:&crc range:NSMakeRange(16, 4)];
  
  // right, check if the crc is correct.
  NSMutableData *crcCheckData = [data mutableCopy];
  [crcCheckData resetBytesInRange:NSMakeRange(16, 4)];
  if ([crcCheckData crc32] != crc)
  {
    NSLog(@"crc check failed, 0x%08x != 0x%08x", [crcCheckData crc32], crc);
  }
  
  // server name is next, guessing its 30 bytes like most of the other stuff. one length, 29 data.
  unsigned char serverNameLen;
  [data getBytes:&serverNameLen range:NSMakeRange(20, 1)];
  
  unsigned char serverNameBuffer[29];
  memset(serverNameBuffer, '\0', 29);
  [data getBytes:&serverNameBuffer range:NSMakeRange(21, 29)];
  
  // convert it to a cocoa string
  NSString *serverName = [[[NSString alloc] initWithCString:(const char*)serverNameBuffer length:serverNameLen] autorelease];
  
  // platform string
  unsigned char platformNameLen;
  [data getBytes:&platformNameLen range:NSMakeRange(50, 1)];
  
  unsigned char platformNameBuffer[29];
  memset(platformNameBuffer, '\0', 29);
  [data getBytes:&platformNameBuffer range:NSMakeRange(51, 29)];
  
  // convert to cocoa
  NSString *platformName = [[[NSString alloc] initWithCString:(const char*)platformNameBuffer length:platformNameLen] autorelease];
  
  // versions
  unsigned short majorVersion, minorVersion;
  unsigned short subLevelVersion, subsubLevelVersion;
  [data getBytes:&majorVersion range:NSMakeRange(80, 2)];
  [data getBytes:&minorVersion range:NSMakeRange(82, 2)];
  [data getBytes:&subLevelVersion range:NSMakeRange(84, 2)];
  [data getBytes:&subsubLevelVersion range:NSMakeRange(86, 2)];
  
  // bad login?
  unsigned char badLogin[4] = { 0x0, 0x0, 0x0, 0x0 };
  [data getBytes:&badLogin range:NSMakeRange(88, 4)];
  
  // 80 bytes of crap, so advance the pointer from 92 upto 172
  
  // session key
  unsigned int newConnectionID = 0;
  [data getBytes:&newConnectionID range:NSMakeRange(172, 4)];
  
  // there appears to be a rogue 4 bytes here, so 176 to 180
  
  // welcome message
  unsigned char welcomeMessageLen = 0;
  [data getBytes:&welcomeMessageLen range:NSMakeRange(180, 1)];
  
  unsigned char welcomeMessageBuffer[255];
  [data getBytes:&welcomeMessageBuffer range:NSMakeRange(181, 255)];
  
  NSString *welcomeMessage = [[[NSString alloc] initWithCString:(const char*)welcomeMessageBuffer length:welcomeMessageLen] autorelease];
  
  BOOL isBadLogin = ((badLogin[0] == 0xff) && (badLogin[1] == 0xff) && (badLogin[2] == 0xff) && (badLogin[3] == 0x0ff));
  
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
  
  // multiple packet channel names come in more than one blob
  unsigned int packetCounter = 0;
  [data getBytes:&packetCounter range:NSMakeRange(12, 4)];
  
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
    
    // some unknown chomp here
    byteIndex += 4;
    
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
  
  // multiple packet channel names come in more than one blob
  unsigned int packetCounter = 0;
  [data getBytes:&packetCounter range:NSMakeRange(12, 4)];
  
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
    
    // two blank bytes
    byteIndex += 4;
    
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
                                      nick, @"SLPlayerNick",
                                      nil];
    [players addObject:playerDictionary];
  }
  
  return packetDictionary;
}

@end

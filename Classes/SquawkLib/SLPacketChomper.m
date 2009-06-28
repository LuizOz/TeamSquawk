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
  unsigned int packetType;
  [data getBytes:&packetType range:NSMakeRange(0, 4)];
  
  switch (packetType) 
  {
    case PACKET_TYPE_LOGIN_REPLY:
    {
      return [self chompLoginReply:data];
      break;
    }
    default:
      NSLog(@"unknown packet type: 0x%08x", packetType);
      break;
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

@end

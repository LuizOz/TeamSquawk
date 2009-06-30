//
//  SLPacketBuilder.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SLPacketBuilder.h"
#import "NSData+Extensions.h"

@implementation SLPacketBuilder

+ (id)packetBuilder
{
  return [[[[self class] alloc] init] autorelease];
}

- (id)init
{
  if (self = [super init])
  {
    // not much to do here yet.
  }
  return self;
}

- (void)dealloc
{
  [super dealloc];
}

#pragma mark Login

- (NSData*)buildLoginPacketWithSequenceID:(unsigned int)sequenceID
                               clientName:(NSString*)client 
                      operatingSystemName:(NSString*)osName
                       clientVersionMajor:(int)majorVersion
                       clientVersionMinor:(int)minorVersion
                             isRegistered:(BOOL)isRegistered
                                loginName:(NSString*)loginName
                            loginPassword:(NSString*)loginPassword
                            loginNickName:(NSString*)loginNickName;
{
  // See http://fiasko-nw.net/~thomas/2006/TeamTapper/protocol/f4/be/03/index.php.en
  NSMutableData *packetData = [NSMutableData data];
  
  // This is the "I'm a login packet" header
  unsigned char headerChunk[] = { 0xf4, 0xbe, 0x03, 0x00 };
  [packetData appendBytes:headerChunk length:4];
  
  // We don't have a connection id yet, login packets have it blank
  unsigned char connectionIDChunk[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
  [packetData appendBytes:connectionIDChunk length:8];
  
  // Sequence
  [packetData appendBytes:&sequenceID length:4];
  
  // We're gonna have to come back and do the CRC later, so pad out 4 bytes of blank
  unsigned char crc32Chunk[] = { 0x00, 0x00, 0x00, 0x00 };
  [packetData appendBytes:crc32Chunk length:4];
  
  // Client name has to be less than 29 bytes.
  unsigned char clientNameLen = ([client length] < 30 ? (char)([client length] & 0xff) : 29);
  unsigned char clientNameChunk[29];
  
  // Copy the chunk over
  memset(clientNameChunk, '\0', 29);
  memcpy(clientNameChunk, [client cStringUsingEncoding:NSASCIIStringEncoding], clientNameLen);
  [packetData appendBytes:&clientNameLen length:1];
  [packetData appendBytes:clientNameChunk length:29];
  
  // Same routine again for the OS name
  unsigned char osNameLen = ([osName length] < 30 ? [osName length] : 29);
  unsigned char osNameChunk[29];
  
  // Copy the chunk
  memset(osNameChunk, '\0', 29);
  memcpy(osNameChunk, [osName cStringUsingEncoding:NSASCIIStringEncoding], osNameLen);
  [packetData appendBytes:&osNameLen length:1];
  [packetData appendBytes:osNameChunk length:29];
  
  // Two bytes of majorVersion, two bytes of minorVersion, then two lots of one byte of sub/subsublevel which I don't implement
  unsigned short majorVersionChunk = (majorVersion & 0xffff);
  unsigned short minorVersionChunk = (minorVersion & 0xffff);
  [packetData appendBytes:&majorVersionChunk length:2];
  [packetData appendBytes:&minorVersionChunk length:2];
  
  unsigned char subLevelVersionChunk = 0x00;
  unsigned char subsubLevelVersionChunk = 0x00;
  [packetData appendBytes:&subLevelVersionChunk length:1];
  [packetData appendBytes:&subsubLevelVersionChunk length:1];
  
  // Unknown data? Two bytes, 0x00 0x01
  unsigned char unknownChunk[] = { 0x00, 0x01 };
  [packetData appendBytes:unknownChunk length:2];
  
  // Are we registered or anonymous
  unsigned short registeredChunk = (isRegistered ? 0x02 : 0x01);
  [packetData appendBytes:&registeredChunk length:2];
  
  // Login name
  unsigned char loginNameLen = ([loginName length] < 30 ? [loginName length] : 29);
  unsigned char loginNameChunk[29];
  
  memset(loginNameChunk, '\0', 29);
  memcpy(loginNameChunk, [loginName cStringUsingEncoding:NSASCIIStringEncoding], loginNameLen);
  [packetData appendBytes:&loginNameLen length:1];
  [packetData appendBytes:loginNameChunk length:29];
  
  // Login password
  unsigned char loginPasswordLen = ([loginPassword length] < 30 ? [loginPassword length] : 29);
  unsigned char loginPasswordChunk[29];
  
  memset(loginPasswordChunk, '\0', 29);
  memcpy(loginPasswordChunk, [loginPassword cStringUsingEncoding:NSASCIIStringEncoding], loginPasswordLen);
  [packetData appendBytes:&loginPasswordLen length:1];
  [packetData appendBytes:loginPasswordChunk length:29];
  
  // Login name
  unsigned char loginNickNameLen = ([loginNickName length] < 30 ? [loginNickName length] : 29);
  unsigned char loginNickNameChunk[29];
  
  memset(loginNickNameChunk, '\0', 29);
  memcpy(loginNickNameChunk, [loginNickName cStringUsingEncoding:NSASCIIStringEncoding], loginNickNameLen);
  [packetData appendBytes:&loginNickNameLen length:1];
  [packetData appendBytes:loginNickNameChunk length:29];
  
  // Now to CRC
  unsigned int crc32 = [packetData crc32];
  [packetData replaceBytesInRange:NSMakeRange(16, 4) withBytes:&crc32 length:4];
  
  return packetData;
}

- (NSData*)buildLoginResponsePacketWithConnectionID:(unsigned int)connectionID
                                           clientID:(unsigned int)clientID
                                         sequenceID:(unsigned int)sequenceID
                                          lastCRC32:(unsigned int)lastCRC32
{
  // This packet appears to contain loads more information than this but no one knows quite what it is
  NSMutableData *packetData = [NSMutableData data];

  // login response packet
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x05, 0x00 };
  [packetData appendBytes:headerChunk length:4];
  
  // connection/session id + clientID
  [packetData appendBytes:&connectionID length:4];
  [packetData appendBytes:&clientID length:4];
  
  // sequence id
  [packetData appendBytes:&sequenceID length:4];
  
  // resend and fragment count, according to wireshark are both 2 bytes each.
  unsigned short resendCount = 0, fragmentCount = 0;
  [packetData appendBytes:&resendCount length:2];
  [packetData appendBytes:&fragmentCount length:2];
  
  // crc spacer
  unsigned int crc = 0;
  [packetData appendBytes:&crc length:4];
  
  // not sure what this is
  unsigned short body1 = 0x0001;
  [packetData appendBytes:&body1 length:2];
  
  // these are actually channel name, sub channel name and password
  unsigned char channelNameLen = 0;
  unsigned char channelNameBuffer[29];
  
  memset(channelNameBuffer, '\0', 29);
  [packetData appendBytes:&channelNameLen length:1];
  [packetData appendBytes:channelNameBuffer length:29];
  
  // sub channel
  unsigned char subChannelNameLen = 0;
  unsigned char subChannelNameBuffer[29];
  
  memset(subChannelNameBuffer, '\0', 29);
  [packetData appendBytes:&subChannelNameLen length:1];
  [packetData appendBytes:subChannelNameBuffer length:29];  
  
  // channel password
  unsigned char channelPasswordLen = 0;
  unsigned char channelPasswordBuffer[25];
  
  memset(channelPasswordBuffer, '\0', 25);
  [packetData appendBytes:&channelPasswordLen length:1];
  [packetData appendBytes:channelPasswordBuffer length:25];  
  
  // now the crc from the previous login call
  [packetData appendBytes:&lastCRC32 length:4];
  
  // and 4 btyes of blank?
  unsigned int spacer2 = 0;
  [packetData appendBytes:&spacer2 length:4];
  
  // do the crc
  unsigned int packetCRC = [packetData crc32];
  [packetData replaceBytesInRange:NSMakeRange(20, 4) withBytes:&packetCRC length:4];
  
  return packetData;
}

- (NSData*)buildDisconnectPacketWithConnectionID:(unsigned int)connectionID
                                        clientID:(unsigned int)clientID
                                      sequenceID:(unsigned int)sequenceID
{
  NSMutableData *packetData = [NSMutableData data];
  
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x2c, 0x01 };
  [packetData appendBytes:headerChunk length:4];
  
  // connection id + client id
  [packetData appendBytes:&connectionID length:4];
  [packetData appendBytes:&clientID length:4];
  
  // sequence id
  [packetData appendBytes:&sequenceID length:4];
  
  unsigned short resendCount = 0, fragmentCount = 0;
  [packetData appendBytes:&resendCount length:2];
  [packetData appendBytes:&fragmentCount length:2];
  
  unsigned int crc = 0, crcPosition = [packetData length];
  [packetData appendBytes:&crc length:4];
  
  unsigned int crc32 = [packetData crc32];
  [packetData replaceBytesInRange:NSMakeRange(crcPosition, 4) withBytes:&crc32 length:4];
  
  return packetData;
}

#pragma mark Ack

- (NSData*)buildAcknowledgePacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID
{
  // we need to ack packets the server sends us.
  NSMutableData *packetData = [NSMutableData data];
  
  // this is the acknowledge header
  unsigned char headerChunk[] = { 0xf1,  0xbe, 0x00, 0x00 };
  [packetData appendBytes:headerChunk length:4];
  
  // connectiond id + client id
  [packetData appendBytes:&connectionID length:4];
  [packetData appendBytes:&clientID length:4];
  
  // sequence to ack
  [packetData appendBytes:&sequenceID length:4];
  
  // don't need a crc, how odd
  
  return packetData;
}

- (NSData*)buildPingPacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID
{
  NSMutableData *packetData = [NSMutableData data];
  
  // ping header
  unsigned char headerChunk[] = { 0xf4, 0xbe, 0x01, 0x00 };
  [packetData appendBytes:headerChunk length:4];
  
  // session key
  [packetData appendBytes:&connectionID length:4];
  
  // client id
  [packetData appendBytes:&clientID length:4];
  
  // sequence
  [packetData appendBytes:&sequenceID length:4];
  
  // crc placeholder
  unsigned int crc = 0;
  [packetData appendBytes:&crc length:4];
  
  unsigned int crc32 = [packetData crc32];
  [packetData replaceBytesInRange:NSMakeRange(16, 4) withBytes:&crc32 length:4];
  
  return packetData;
}

#pragma mark Text Messages

- (NSData*)buildTextMessagePacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID message:(NSString*)message
{
  NSMutableData *packetData = [NSMutableData data];
  
  // text message header
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0xae, 0x01 };
  [packetData appendBytes:headerChunk length:4];
  
  // session key
  [packetData appendBytes:&connectionID length:4];
  
  // client id
  [packetData appendBytes:&clientID length:4];
  
  // sequence
  [packetData appendBytes:&sequenceID length:4];
  
  // we're gonna need to do something with the fragment count if we want to send long message
  unsigned short resentCount = 0, fragmentCount = 0;
  [packetData appendBytes:&resentCount length:2];
  [packetData appendBytes:&fragmentCount length:2];
  
  // crc placeholder
  unsigned int crc = 0;
  [packetData appendBytes:&crc length:4];
  
  // 5 bytes of junk? then the player id.
  unsigned char junk[] = { 0x00, 0x00, 0x00, 0x00, 0x02 };
  [packetData appendBytes:junk length:5];
  
  // player id
  [packetData appendBytes:&playerID length:4];
  
  const char *textBuffer = [message cStringUsingEncoding:NSASCIIStringEncoding];
  [packetData appendBytes:textBuffer length:([message length]+1)];
  
  // do the crc
  unsigned int crc32 = [packetData crc32];
  [packetData replaceBytesInRange:NSMakeRange(20, 4) withBytes:&crc32 length:4];
  
  return packetData;
}

#pragma mark Voice Messages

- (NSData*)buildVoiceMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID codec:(unsigned char)codec packetCount:(unsigned short)packetCount audioData:(NSData*)data commandChannel:(BOOL)command
{
  NSMutableData *packetData = [NSMutableData data];
  
  // packet header
  unsigned char headerChunk[] = { 0xf2, 0xbe, (command ? 0x01 : 0x00), codec };
  [packetData appendBytes:&headerChunk length:4];
  
  // conenction id + client id
  [packetData appendBytes:&connectionID length:4];
  [packetData appendBytes:&clientID length:4];
  
  // packet count
  [packetData appendBytes:&packetCount length:2];
  
  // unknown data
  unsigned char unknown[] = { 0x01, 0x00, 0x05 };
  [packetData appendBytes:unknown length:3];
  
  // audio data
  [packetData appendData:data];
  
  return packetData;
}

@end

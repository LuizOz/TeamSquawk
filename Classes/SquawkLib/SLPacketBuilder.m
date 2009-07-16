//
//  SLPacketBuilder.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Foundation/NSByteOrder.h>

#import "SLPacketBuilder.h"
#import "NSData+Extensions.h"

#define VOMIT_INIT()  NSMutableData *packetData = [NSMutableData data]

#define VOMIT_BYTE(name)  [packetData appendBytes:&name length:1]
#define VOMIT_BYTES(name, len)   [packetData appendBytes:name length:len]

#define VOMIT_SHORT(name) unsigned short bs##name = NSSwapHostShortToLittle((name & 0xffff)); \
                          [packetData appendBytes:&bs##name length:2]

#define VOMIT_INT(name)   unsigned int bs##name = NSSwapHostIntToLittle(name & 0xffffffff); \
                          [packetData appendBytes:&bs##name length:4]

#define VOMIT_CRC_BLANKS()  unsigned char crc32Chunk[] = { 0x00, 0x00, 0x00, 0x00 }; \
                            NSRange crcRange = NSMakeRange([packetData length], 4); \
                            [packetData appendBytes:crc32Chunk length:4]

#define VOMIT_CRC() unsigned int crc32 = NSSwapHostIntToLittle([packetData crc32]); \
                    [packetData replaceBytesInRange:crcRange withBytes:&crc32 length:4];

#define VOMIT_STRING(str)   const char *str##Buffer = [str cStringUsingEncoding:NSASCIIStringEncoding]; \
                            [packetData appendBytes:(char*)str##Buffer length:([str length] + 1)]

#define VOMIT_30BYTE_STRING(str)  unsigned char str##Len = ([str length] < 30 ? (char)([str length] & 0xff) : 29); \
                                  unsigned char str##Chunk[29]; \
                                  memset(str##Chunk, '\0', 29); \
                                  memcpy(str##Chunk, [str cStringUsingEncoding:NSASCIIStringEncoding], str##Len); \
                                  [packetData appendBytes:&str##Len length:1]; \
                                  [packetData appendBytes:str##Chunk length:29]

#define VOMIT_BLANKS(id, count) unsigned char blanks##id[count]; \
                                memset(blanks##id, '\0', count); \
                                [packetData appendBytes:&blanks##id length:count];

#define VOMIT_DATA(data)  [packetData appendData:data]

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
  VOMIT_INIT();
  
  // This is the "I'm a login packet" header
  unsigned char headerChunk[] = { 0xf4, 0xbe, 0x03, 0x00 };
  VOMIT_BYTES(headerChunk, 4);
  
  // We don't have a connection id yet, login packets have it blank
  unsigned char connectionIDChunk[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
  VOMIT_BYTES(connectionIDChunk, 8);
  
  // Sequence
  VOMIT_INT(sequenceID);
  
  // We're gonna have to come back and do the CRC later, so pad out 4 bytes of blank
  VOMIT_CRC_BLANKS();
  
  // Client name has to be less than 29 bytes.
  VOMIT_30BYTE_STRING(client);
  
  // Same routine again for the OS name
  VOMIT_30BYTE_STRING(osName);
  
  // Two bytes of majorVersion, two bytes of minorVersion, then two lots of one byte of sub/subsublevel which I don't implement
  VOMIT_SHORT(majorVersion);
  VOMIT_SHORT(minorVersion);
  
  unsigned char subLevelVersionChunk = 0x00;
  unsigned char subsubLevelVersionChunk = 0x00;
  VOMIT_BYTE(subLevelVersionChunk);
  VOMIT_BYTE(subsubLevelVersionChunk);
  
  // Unknown data? Two bytes, 0x00 0x01
  unsigned char unknownChunk[] = { 0x00, 0x01 };
  VOMIT_BYTES(unknownChunk, 2);
  
  // Are we registered or anonymous
  unsigned char registeredChunk[] = { 0x01, (isRegistered ? 0x02 : 0x01) };
  VOMIT_BYTES(registeredChunk, 2);
  
  // Login name
  VOMIT_30BYTE_STRING(loginName);

  // Login password
  VOMIT_30BYTE_STRING(loginPassword);
  
  // Login name
  VOMIT_30BYTE_STRING(loginNickName);
  
  // Now to CRC
  VOMIT_CRC();
  
  return packetData;
}

- (NSData*)buildLoginResponsePacketWithConnectionID:(unsigned int)connectionID
                                           clientID:(unsigned int)clientID
                                         sequenceID:(unsigned int)sequenceID
                                          lastCRC32:(unsigned int)lastCRC32
{
  // This packet appears to contain loads more information than this but no one knows quite what it is
  VOMIT_INIT();

  // login response packet
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x05, 0x00 };
  VOMIT_BYTES(headerChunk, 4);
  
  // connection/session id + clientID
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  
  // sequence id
  VOMIT_INT(sequenceID);
  
  // resend and fragment count, according to wireshark are both 2 bytes each.
  unsigned short resendCount = 0, fragmentCount = 0;
  VOMIT_SHORT(resendCount);
  VOMIT_SHORT(fragmentCount);
  
  // crc spacer
  VOMIT_CRC_BLANKS();
  
  // not sure what this is
  unsigned short body1 = 0x0001;
  VOMIT_SHORT(body1);
  
  // these are actually channel name, sub channel name and password
  NSString *channelName = @"", *subChannelName = @"", *channelPassword = @"";
  VOMIT_30BYTE_STRING(channelName);
  
  // sub channel
  VOMIT_30BYTE_STRING(subChannelName);
  
  // channel password
  VOMIT_30BYTE_STRING(channelPassword);
  
  // now the crc from the previous login call
  VOMIT_INT(lastCRC32);
  
  // and 4 btyes of blank
  VOMIT_BLANKS(0, 4);
  
  // do the crc
  VOMIT_CRC();
  
  return packetData;
}

- (NSData*)buildDisconnectPacketWithConnectionID:(unsigned int)connectionID
                                        clientID:(unsigned int)clientID
                                      sequenceID:(unsigned int)sequenceID
{
  VOMIT_INIT();
  
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x2c, 0x01 };
  VOMIT_BYTES(headerChunk, 4);

  // connection id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  
  // sequence id
  VOMIT_INT(sequenceID);
  
  unsigned short resendCount = 0, fragmentCount = 0;
  VOMIT_SHORT(resendCount);
  VOMIT_SHORT(fragmentCount);
  
  VOMIT_CRC_BLANKS();
  VOMIT_CRC();
  
  return packetData;
}

#pragma mark Ack

- (NSData*)buildAcknowledgePacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID
{
  // we need to ack packets the server sends us.
  VOMIT_INIT();
  
  // this is the acknowledge header
  unsigned char headerChunk[] = { 0xf1,  0xbe, 0x00, 0x00 };
  VOMIT_BYTES(headerChunk, 4);
  
  // connectiond id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  
  // sequence to ack
  VOMIT_INT(sequenceID);
  
  // don't need a crc, how odd
  
  return packetData;
}

- (NSData*)buildPingPacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID
{
  VOMIT_INIT();
  
  // ping header
  unsigned char headerChunk[] = { 0xf4, 0xbe, 0x01, 0x00 };
  VOMIT_BYTES(headerChunk, 4);
  
  // session key
  VOMIT_INT(connectionID);
  
  // client id
  VOMIT_INT(clientID);
  
  // sequence
  VOMIT_INT(sequenceID);
  
  // crc placeholder
  VOMIT_CRC_BLANKS();
  VOMIT_CRC();
  
  return packetData;
}

#pragma mark Text Messages

- (NSData*)buildTextMessagePacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID message:(NSString*)message
{
  VOMIT_INIT();
  
  // text message header
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0xae, 0x01 };
  VOMIT_BYTES(headerChunk, 4);
  
  // session key
  VOMIT_INT(connectionID);
  
  // client id
  VOMIT_INT(clientID);
  
  // sequence
  VOMIT_INT(sequenceID);
  
  // we're gonna need to do something with the fragment count if we want to send long message
  unsigned short resentCount = 0, fragmentCount = 0;
  VOMIT_SHORT(resentCount);
  VOMIT_SHORT(fragmentCount);
  
  // crc placeholder
  VOMIT_CRC_BLANKS();
  
  // 5 bytes of junk? then the player id.
  unsigned char junk[] = { 0x00, 0x00, 0x00, 0x00, 0x02 };
  VOMIT_BYTES(junk, 5);
  
  // player id
  VOMIT_INT(playerID);
  VOMIT_STRING(message);
  
  // do the crc
  VOMIT_CRC();
  
  return packetData;
}

#pragma mark Voice Messages

- (NSData*)buildVoiceMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID codec:(unsigned char)codec packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID audioData:(NSData*)data audioFrames:(unsigned char)frames
{
  VOMIT_INIT();
  
  // packet header
  unsigned char headerChunk[] = { 0xf2, 0xbe, 0x00, codec };
  VOMIT_BYTES(headerChunk, 4);
  
  // conenction id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  
  // packet count
  VOMIT_SHORT(packetCount);
  
  // tranmission id
  VOMIT_SHORT(transmissionID);
  
  // number of frames
  VOMIT_BYTE(frames);
  
  // audio data
  VOMIT_DATA(data);
  
  return packetData;
}

- (NSData*)buildVoiceWhisperWithConnectionID:(unsigned int)connectionID
                                    clientID:(unsigned int)clientID
                                       codec:(unsigned char)codec
                                 packetCount:(unsigned short)packetCount
                              transmissionID:(unsigned short)transmissionID
                                   audioData:(NSData*)data 
                                 audioFrames:(unsigned char)frames
                                  recipients:(NSArray*)recipientIDs
{
  VOMIT_INIT();
  
  // packet header
  unsigned char headerChunk[] = { 0xf2, 0xbe, 0x01, codec };
  VOMIT_BYTES(headerChunk, 4);
  
  // conenction id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  
  // packet count
  VOMIT_SHORT(packetCount);
  
  // some kind of transmission count?
  VOMIT_SHORT(transmissionID);
  
  unsigned char numOfRecipients = [recipientIDs count];
  VOMIT_BYTE(numOfRecipients);
  
  for (NSNumber *recipient in recipientIDs)
  {
    // something odd?
    unsigned char odd = 0x01;
    VOMIT_BYTE(odd);
    
    unsigned int recipientID = [recipient unsignedIntValue];
    VOMIT_INT(recipientID);
  }
  
  // number of frames
  VOMIT_BYTE(frames);
  
  // audio data
  VOMIT_DATA(data);
  
  return packetData;
}

#pragma mark Channel/Status

- (NSData*)buildSwitchChannelMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID newChannelID:(unsigned int)channelID password:(NSString*)password
{
  VOMIT_INIT();
  
  // packet header
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x2f, 0x01 };
  VOMIT_BYTES(headerChunk, 4);
  
  // connection id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  VOMIT_INT(sequenceID);
  
  unsigned short resendCount = 0, fragmentCount = 0;
  VOMIT_SHORT(resendCount);
  VOMIT_SHORT(fragmentCount);
  
  VOMIT_CRC_BLANKS();
  
  // channel id
  VOMIT_INT(channelID);
  
  // password length
  VOMIT_30BYTE_STRING(password);
    
  VOMIT_CRC();
  
  return packetData;
}

- (NSData*)buildChangePlayerStatusMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID newStatusFlags:(unsigned short)statusFlags
{
  VOMIT_INIT();
  
  // packet header
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x30, 0x01 };
  VOMIT_BYTES(headerChunk, 4);
  
  // connection id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);

  VOMIT_INT(sequenceID);
  
  unsigned short resendCount = 0, fragmentCount = 0;
  VOMIT_SHORT(resendCount);
  VOMIT_SHORT(fragmentCount);
  
  VOMIT_CRC_BLANKS();
  
  VOMIT_SHORT(statusFlags);
  
  VOMIT_CRC();
  
  return packetData;  
}

- (NSData*)buildChangeOtherPlayerMuteStatusWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID muted:(BOOL)flag
{
  VOMIT_INIT();
  
  // packet header
  unsigned char headerChunk[] = { 0xf0, 0xbe, 0x40, 0x01 };
  VOMIT_BYTES(headerChunk, 4);
  
  // connection id + client id
  VOMIT_INT(connectionID);
  VOMIT_INT(clientID);
  VOMIT_INT(sequenceID);
  
  unsigned short resendCount = 0, fragmentCount = 0;
  VOMIT_SHORT(resendCount);
  VOMIT_SHORT(fragmentCount);

  VOMIT_CRC_BLANKS();
  
  VOMIT_INT(playerID);
  
  unsigned char muted = (flag ? 0x01 : 0x00);
  VOMIT_BYTE(muted);

  VOMIT_CRC();
  
  return packetData;
}

@end

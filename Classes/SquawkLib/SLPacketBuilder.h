/*
 * TeamSquawk: An open-source TeamSpeak client for Mac OS X
 *
 * Copyright (c) 2009 Matt Wright
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <Cocoa/Cocoa.h>

#define VOICE_CODEC_SPEEX_3_4         0x05
#define VOICE_CODEC_SPEEX_5_2         0x06
#define VOICE_CODEC_SPEEX_7_2         0x07
#define VOICE_CODEC_SPEEX_9_3         0x08
#define VOICE_CODEC_SPEEX_12_3        0x09
#define VOICE_CODEC_SPEEX_16_3        0x0a
#define VOICE_CODEC_SPEEX_19_5        0x0b
#define VOICE_CODEC_SPEEX_25_9        0x0c

@interface SLPacketBuilder : NSObject {

}

+ (id)packetBuilder;
- (id)init;

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

- (NSData*)buildLoginResponsePacketWithConnectionID:(unsigned int)connectionID
                                           clientID:(unsigned int)clientID
                                         sequenceID:(unsigned int)sequenceID
                                          lastCRC32:(unsigned int)lastCRC32;

- (NSData*)buildDisconnectPacketWithConnectionID:(unsigned int)connectionID
                                        clientID:(unsigned int)clientID
                                      sequenceID:(unsigned int)sequenceID;

#pragma mark Ack

- (NSData*)buildAcknowledgePacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID;
- (NSData*)buildPingPacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID;

#pragma mark Text Messages

- (NSData*)buildTextMessagePacketWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID message:(NSString*)message;

#pragma mark Voice Messages

- (NSData*)buildVoiceMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID codec:(unsigned char)codec packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID audioData:(NSData*)data audioFrames:(unsigned char)frames;
- (NSData*)buildVoiceWhisperWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID codec:(unsigned char)codec packetCount:(unsigned short)packetCount transmissionID:(unsigned short)transmissionID audioData:(NSData*)data audioFrames:(unsigned char)frames recipients:(NSArray*)recipientIDs;

#pragma mark Channel/Status

- (NSData*)buildSwitchChannelMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID newChannelID:(unsigned int)channelID password:(NSString*)password;
- (NSData*)buildChangePlayerStatusMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID newStatusFlags:(unsigned short)statusFlags;
- (NSData*)buildChangeOtherPlayerMuteStatusWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID muted:(BOOL)flag;
//- (NSData*)buildCreateChannelMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID 

#pragma mark Admin

- (NSData*)buildKickMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID reason:(NSString*)reason;
- (NSData*)buildChannelKickMessageWithConnectionID:(unsigned int)connectionID clientID:(unsigned int)clientID sequenceID:(unsigned int)sequenceID playerID:(unsigned int)playerID reason:(NSString*)reason;

@end


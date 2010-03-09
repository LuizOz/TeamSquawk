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

#import <dispatch/dispatch.h>

#import <Cocoa/Cocoa.h>
#import "SpeexDecoder.h"
#import "TSAUGraphPlayer.h"
#import "TSAudioConverter.h"

typedef enum {
  TSPlayerChannelCommander = 0x01,
  TSPlayerBlockWhispers = 0x04,
  TSPlayerIsAway = 0x08,
  TSPlayerHasMutedMicrophone = 0x10,
  TSPlayerHasMutedSpeakers = 0x20,
} TSPlayerFlags;

@interface TSPlayer : NSObject {
  TSAUGraphPlayer *graphPlayer;
  TSAudioConverter *converter;
  SpeexDecoder *speex;
  dispatch_queue_t queue;
  
  unsigned int graphPlayerChannel;
  
  NSString *playerName;
  unsigned int playerFlags;
  unsigned int extendedFlags;
  unsigned int channelPrivFlags;
  unsigned int playerID;
  unsigned int channelID;
  unsigned int lastVoicePacketCount;
  
  BOOL isTransmitting;
  BOOL isWhispering;
  BOOL isLocallyMuted;
}

@property (readonly) SpeexDecoder *decoder;
@property (readonly) TSAudioConverter *converter;
@property (retain) TSAUGraphPlayer *graphPlayer;
@property (readonly) dispatch_queue_t queue;
@property (assign) unsigned int lastVoicePacketCount;
@property (assign) unsigned int extendedFlags;
@property (assign) unsigned int channelPrivFlags;
@property (assign) BOOL isTransmitting;
@property (assign) BOOL isWhispering;
@property (assign) BOOL isLocallyMuted;
@property (readonly) unsigned int graphPlayerChannel;

- (id)initWithGraphPlayer:(TSAUGraphPlayer*)player;
- (id)copyWithZone:(NSZone *)zone;

- (void)backgroundDecodeData:(NSData*)audioCodecData;

- (NSString*)playerName;
- (void)setPlayerName:(NSString*)name;

- (unsigned int)playerFlags;
- (void)setPlayerFlags:(unsigned int)flags;

- (BOOL)isChannelCommander;
- (BOOL)shouldBlockWhispers;
- (BOOL)isAway;
- (BOOL)hasMutedMicrophone;
- (BOOL)hasMutedSpeakers;

- (BOOL)isRegistered;
- (BOOL)isServerAdmin;

- (BOOL)isChannelAdmin;
- (BOOL)isChannelOperator;
- (BOOL)isChannelVoice;

- (BOOL)isTalking;

- (unsigned int)playerID;
- (void)setPlayerID:(unsigned int)aPlayerID;

- (unsigned int)channelID;
- (void)setChannelID:(unsigned int)aChannelID;

@end

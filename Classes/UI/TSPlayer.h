//
//  TSPlayer.h
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

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

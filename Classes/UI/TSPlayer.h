//
//  TSPlayer.h
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SpeexDecoder.h"
#import "TSAudioConverter.h"
#import "TSCoreAudioPlayer.h"

typedef enum {
  TSPlayerChannelCommander = 0x01,
  TSPlayerBlockWhispers = 0x04,
  TSPlayerIsAway = 0x08,
  TSPlayerHasMutedMicrophone = 0x10,
  TSPlayerIsMuted = 0x20,
} TSPlayerFlags;

@interface TSPlayer : NSObject {
  TSCoreAudioPlayer *coreAudio;
  TSAudioConverter *converter;
  SpeexDecoder *speex;
  
  NSString *playerName;
  unsigned int playerFlags;
  unsigned int playerID;
  unsigned int channelID;
  unsigned int lastVoicePacketCount;
}

@property (readonly) SpeexDecoder *decoder;
@property (readonly) TSAudioConverter *converter;
@property (readonly) TSCoreAudioPlayer *coreAudioPlayer;
@property (assign) unsigned int lastVoicePacketCount;

- (NSString*)playerName;
- (void)setPlayerName:(NSString*)name;

- (unsigned int)playerFlags;
- (void)setPlayerFlags:(unsigned int)flags;

- (BOOL)isChannelCommander;
- (BOOL)shouldBlockWhispers;
- (BOOL)isAway;
- (BOOL)hasMutedMicrophone;
- (BOOL)isMuted;

- (unsigned int)playerID;
- (void)setPlayerID:(unsigned int)aPlayerID;

- (unsigned int)channelID;
- (void)setChannelID:(unsigned int)aChannelID;

@end

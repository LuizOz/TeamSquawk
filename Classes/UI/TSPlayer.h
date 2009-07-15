//
//  TSPlayer.h
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SpeexDecoder.h"
#import "TSAUGraphPlayer.h"
#import "TSAudioConverter.h"

typedef enum {
  TSPlayerChannelCommander = 0x01,
  TSPlayerBlockWhispers = 0x04,
  TSPlayerIsAway = 0x08,
  TSPlayerHasMutedMicrophone = 0x10,
  TSPlayerIsMuted = 0x20,
} TSPlayerFlags;

typedef enum {
  TSPlayerServerAdmin = 0x01,
  TSPlayerRegistered = 0x04,
} TSPlayerExtendedFlags;

@interface TSPlayer : NSObject {
  TSAUGraphPlayer *graphPlayer;
  TSAudioConverter *converter;
  SpeexDecoder *speex;
  NSOperationQueue *decodeQueue;
  
  unsigned int graphPlayerChannel;
  
  NSString *playerName;
  unsigned int playerFlags;
  unsigned int extendedFlags;
  unsigned int playerID;
  unsigned int channelID;
  unsigned int lastVoicePacketCount;
  
  BOOL isTransmitting;
  BOOL isWhispering;
}

@property (readonly) SpeexDecoder *decoder;
@property (readonly) TSAudioConverter *converter;
@property (retain) TSAUGraphPlayer *graphPlayer;
@property (readonly) NSOperationQueue *decodeQueue;
@property (assign) unsigned int lastVoicePacketCount;
@property (assign) unsigned int extendedFlags;
@property (assign) BOOL isTransmitting;
@property (assign) BOOL isWhispering;

- (id)initWithGraphPlayer:(TSAUGraphPlayer*)player;
- (id)copyWithZone:(NSZone *)zone;

- (NSString*)playerName;
- (void)setPlayerName:(NSString*)name;

- (unsigned int)playerFlags;
- (void)setPlayerFlags:(unsigned int)flags;

- (BOOL)isChannelCommander;
- (BOOL)shouldBlockWhispers;
- (BOOL)isAway;
- (BOOL)hasMutedMicrophone;
- (BOOL)isMuted;

- (BOOL)isRegistered;
- (BOOL)isServerAdmin;

- (BOOL)isTalking;

- (unsigned int)playerID;
- (void)setPlayerID:(unsigned int)aPlayerID;

- (unsigned int)channelID;
- (void)setChannelID:(unsigned int)aChannelID;

@end

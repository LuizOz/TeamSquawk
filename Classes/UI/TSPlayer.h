//
//  TSPlayer.h
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
  TSPlayerChannelCommander = 0x01,
  TSPlayerBlockWhispers = 0x04,
  TSPlayerIsAway = 0x08,
  TSPlayerHasMutedMicrophone = 0x10,
  TSPlayerIsMuted = 0x20,
} TSPlayerFlags;

@interface TSPlayer : NSObject {
  NSString *playerName;
  unsigned int playerFlags;
  unsigned int playerID;
  unsigned int channelID;
}

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

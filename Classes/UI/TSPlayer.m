//
//  TSPlayer.m
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TSPlayer.h"


@implementation TSPlayer

- (id)init
{
  if (self = [super init])
  {
    playerName = nil;
  }
  return self;
}

- (void)dealloc
{
  [playerName release];
  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%@: %p, name: %@, flags: 0x%x <cc: %d, bw: %d, ia: %d, mm: %d, im: %d>, chan: 0x%x, id: 0x%x>",
          [self className], self, [self playerName], [self playerFlags],
          [self isChannelCommander], [self shouldBlockWhispers], [self isAway], [self hasMutedMicrophone], [self isMuted],
          [self channelID],
          [self playerID]];
}

- (NSString*)playerName
{
  return playerName;
}

- (void)setPlayerName:(NSString*)name
{
  [playerName autorelease];
  playerName = [name retain];
}

- (unsigned int)playerFlags
{
  return playerFlags;
}

- (void)setPlayerFlags:(unsigned int)flags
{
  playerFlags = flags;
}

- (BOOL)isChannelCommander
{
  return ((playerFlags & TSPlayerChannelCommander) == TSPlayerChannelCommander);
}

- (BOOL)shouldBlockWhispers
{
  return ((playerFlags & TSPlayerBlockWhispers) == TSPlayerBlockWhispers);
}

- (BOOL)isAway
{
  return ((playerFlags & TSPlayerIsAway) == TSPlayerIsAway);
}

- (BOOL)hasMutedMicrophone
{
  return ((playerFlags & TSPlayerHasMutedMicrophone) == TSPlayerHasMutedMicrophone);
}

- (BOOL)isMuted
{
  return ((playerFlags & TSPlayerIsMuted) == TSPlayerIsMuted);
}

- (unsigned int)playerID
{
  return playerID;
}

- (void)setPlayerID:(unsigned int)aPlayerID
{
  playerID = aPlayerID;
}

- (unsigned int)channelID
{
  return channelID;
}

- (void)setChannelID:(unsigned int)aChannelID
{
  channelID = aChannelID;
}

@end

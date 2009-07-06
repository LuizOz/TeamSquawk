//
//  TSChannel.m
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TSChannel.h"


@implementation TSChannel

@synthesize channelName;
@synthesize channelDescription;
@synthesize channelTopic;

@synthesize channelID;
@synthesize parent;
@synthesize codec;
@synthesize flags;
@synthesize maxUsers;
@synthesize sortOrder;

- (id)init
{
  if (self = [super init])
  {
    channelName = nil;
    channelDescription = nil;
    channelTopic = nil;
    subChannels = [[NSMutableArray alloc] init];
    players = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [players release];
  [subChannels release];
  [channelName release];
  [channelDescription release];
  [channelTopic release];
  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%@: %p, name: %@, desc: %@, topic: %@; id: 0x%x, parent: 0x%x, codec: 0x%x, flags: 0x%x, %@>",
          [self className], self, [self channelName], [self channelDescription], [self channelTopic],
          [self channelID], [self parent], [self codec], [self flags], ([[self subChannels] count] > 0 ? [self subChannels] : nil)];
}

- (NSArray*)subChannels
{
  return subChannels;
}

- (void)addSubChannel:(TSChannel*)channel
{
  [subChannels addObject:channel];
}

- (void)removeSubChannel:(TSChannel*)channel
{
  [subChannels removeObject:channel];
}

- (void)removeAllSubChannels
{
  [subChannels removeAllObjects];
}

- (NSArray*)players
{
  return players;
}

- (void)addPlayer:(TSPlayer*)player
{
  [players addObject:player];
  [players sortUsingDescriptors:[NSArray arrayWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"playerName" ascending:YES] autorelease], nil]];;
}

- (void)removePlayer:(TSPlayer*)player
{
  [players removeObject:player];
}

- (void)removeAllPlayers
{
  [players removeAllObjects];
}

- (BOOL)isDefaultChannel
{
  return ((flags & TSChannelDefault) == TSChannelDefault);
}

- (BOOL)isModerated
{
  return ((flags & TSChannelIsModerated) == TSChannelIsModerated);
}

- (BOOL)hasSubChannels
{
  return ((flags & TSChannelHasSubChannels) == TSChannelHasSubChannels);
}

- (BOOL)hasPassword
{
  return ((flags & TSChannelHasPassword) == TSChannelHasPassword);
}

@end

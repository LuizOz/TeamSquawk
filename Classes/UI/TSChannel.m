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

//
//  TSChannel.h
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TSPlayer;

@interface TSChannel : NSObject {
  NSString *channelName;
  NSString *channelDescription;
  NSString *channelTopic;
  
  NSMutableArray *subChannels;
  NSMutableArray *players;
  
  unsigned int channelID;
  unsigned int parent;
  unsigned int codec;
  unsigned int flags;
}

- (id)init;
- (void)dealloc;

- (NSArray*)subChannels;
- (void)addSubChannel:(TSChannel*)channel;
- (void)removeSubChannel:(TSChannel*)channel;
- (void)removeAllSubChannels;

- (NSArray*)players;
- (void)addPlayer:(TSPlayer*)player;
- (void)removePlayer:(TSPlayer*)player;
- (void)removeAllPlayers;

@property (retain) NSString *channelName;
@property (retain) NSString *channelDescription;
@property (retain) NSString *channelTopic;

@property (assign) unsigned int channelID;
@property (assign) unsigned int parent;
@property (assign) unsigned int codec;
@property (assign) unsigned int flags;

@end

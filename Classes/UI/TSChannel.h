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

@class TSPlayer;

typedef enum {
  TSChannelDefault = 0x80,
  TSChannelHasSubChannels = 0x08,
  TSChannelHasPassword = 0x04,
  TSChannelIsModerated = 0x02,
} TSChannelFlags;

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
  unsigned int maxUsers;
  unsigned int sortOrder;
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

- (BOOL)isDefaultChannel;
- (BOOL)isModerated;
- (BOOL)hasSubChannels;
- (BOOL)hasPassword;

@property (retain) NSString *channelName;
@property (retain) NSString *channelDescription;
@property (retain) NSString *channelTopic;

@property (assign) unsigned int channelID;
@property (assign) unsigned int parent;
@property (assign) unsigned int codec;
@property (assign) unsigned int flags;
@property (assign) unsigned int maxUsers;
@property (assign) unsigned int sortOrder;

@end

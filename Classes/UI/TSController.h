//
//  TSController.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SLConnection.h"
#import "TSCoreAudioPlayer.h"
#import "TSAudioConverter.h"

#import "SpeexEncoder.h"
#import "SpeexDecoder.h"

@class RPImageAndTextCell, TSPlayer, TSChannel;

@interface TSController : NSObject {
  
  // user interface
  
  IBOutlet NSWindow *mainWindow;
  IBOutlet NSOutlineView *mainWindowOutlineView;
  
  // state
  
  BOOL isConnected;
  NSMutableDictionary *players;
  NSMutableDictionary *channels;
  NSMutableDictionary *flattenedChannels;
  NSArray *sortedChannels;
  
  // background stuff
  
  SLConnection *teamspeakConnection;
  
//  TSCoreAudioPlayer *player;
//  TSAudioConverter *converter;
  
  SpeexDecoder *speex;
  SpeexEncoder *speexEncoder;
}

- (void)awakeFromNib;

#pragma mark OutlineView DataSource

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

#pragma mark OutlineView Delegates

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(RPImageAndTextCell*)cell forTableColumn:(NSTableColumn*)tableColumn forChannel:(TSChannel*)channel;
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(RPImageAndTextCell*)cell forTableColumn:(NSTableColumn*)tableColumn forPlayer:(TSPlayer*)player;

#pragma mark Menu Items

- (IBAction)connectMenuAction:(id)sender;
- (IBAction)disconnectMenuAction:(id)sender;
- (IBAction)doubleClickOutlineView:(id)sender;

#pragma mark Menu Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem;

#pragma mark SLConnection Delegates

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage;
- (void)connectionFinishedLogin:(SLConnection*)connection;
- (void)connectionFailedToLogin:(SLConnection*)connection;
- (void)connectionDisconnected:(SLConnection*)connection;
- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary;
- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary;
- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname;
- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags;
- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID;

#pragma mark Audio

- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID senderPacketCounter:(unsigned short)count;
- (void)invokeInBackground:(NSInvocation*)invocation;

#pragma mark NSApplication Delegate

- (void)applicationWillTerminate:(NSNotification *)aNotification;

#pragma mark Old Shit


@end

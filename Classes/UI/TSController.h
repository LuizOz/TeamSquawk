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
#import "TSPlayerCell.h"

#import "SpeexEncoder.h"
#import "SpeexDecoder.h"

@class RPImageAndTextCell, TSPlayer, TSChannel;

typedef enum {
  TSControllerPlayerActive = 1,
  TSControllerPlayerMuteMic,
  TSControllerPlayerMute,

  TSControllerPlayerAway,
  TSControllerPlayerChannelCommander,
  TSControllerPlayerBlockWhispers,
} TSControllerPlayerStatus;

@interface TSController : NSObject {
  
  // user interface
  
  IBOutlet NSWindow *mainWindow;
  IBOutlet NSOutlineView *mainWindowOutlineView;
  IBOutlet NSToolbar *toolbar;
  
  // connection window
  IBOutlet NSWindow *connectionWindow;
  IBOutlet NSTextField *connectionWindowServerTextField;
  IBOutlet NSTextField *connectionWindowNicknameTextField;
  IBOutlet NSMatrix *connectionWindowTypeMatrix;
  IBOutlet NSTextField *connectionWindowUsernameField;
  IBOutlet NSTextField *connectionWindowPasswordField;
  
  // toobar view
  IBOutlet NSView *toolbarView;
  IBOutlet NSImageView *toolbarViewAwayImageView;
  IBOutlet NSTextField *toolbarViewNicknameField;
  IBOutlet NSPopUpButton *toolbarViewStatusPopupButton;
  IBOutlet NSImageView *toolbarViewStatusImageView;
  
  // outline view stuff
  NSTextFieldCell *sharedTextFieldCell;
  TSPlayerCell *sharedPlayerCell;
  
  // state
  
  BOOL isConnected;
  NSString *currentServerAddress;
  
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

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item;
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item;
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(RPImageAndTextCell*)cell forTableColumn:(NSTableColumn*)tableColumn forChannel:(TSChannel*)channel;
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(RPImageAndTextCell*)cell forTableColumn:(NSTableColumn*)tableColumn forPlayer:(TSPlayer*)player;

#pragma mark Toolbar Delegates

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)aToolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)aToolbar;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;

#pragma mark Menu Items

- (IBAction)connectMenuAction:(id)sender;
- (IBAction)disconnectMenuAction:(id)sender;
- (IBAction)doubleClickOutlineView:(id)sender;
- (IBAction)changeUserStatusAction:(id)sender;
- (IBAction)toggleAway:(id)sender;
- (IBAction)toggleChannelCommander:(id)sender;
- (IBAction)toggleBlockWhispers:(id)sender;

#pragma mark Connection Window Actions

- (IBAction)connectionWindowUpdateType:(id)sender;
- (IBAction)connectionWindowOKAction:(id)sender;
- (IBAction)connectionWindowCancelAction:(id)sender;

#pragma mark Player Status View

- (void)updatePlayerStatusView;

#pragma mark Connection Menu

- (void)setupDisconnectedToolbarStatusPopupButton;
- (void)setupConnectedToolbarStatusPopupButton;

#pragma mark Menu Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem;

#pragma mark SLConnection Calls

- (void)loginToServer:(NSString*)server port:(int)port nickname:(NSString*)nickname registered:(BOOL)registered username:(NSString*)username password:(NSString*)password;

#pragma mark SLConnection Delegates

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage;
- (void)connectionFinishedLogin:(SLConnection*)connection;
- (void)connectionFailedToLogin:(SLConnection*)connection;
- (void)connectionDisconnected:(SLConnection*)connection;
- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary;
- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary;
- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname extendedFlags:(unsigned int)extendedFlags;
- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags;
- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID;

#pragma mark Audio

- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID senderPacketCounter:(unsigned short)count;
- (void)idleAudioCheck:(NSTimer*)timer;

#pragma mark NSApplication Delegate

- (void)applicationWillTerminate:(NSNotification *)aNotification;

@end

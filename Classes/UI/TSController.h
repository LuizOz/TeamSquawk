//
//  TSController.h
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SLConnection.h"
#import "TSAUGraphPlayer.h"
#import "TSAudioConverter.h"
#import "TSPlayerCell.h"
#import "TSHotkeyManager.h"
#import "TSTransmission.h"

#import "SpeexEncoder.h"
#import "SpeexDecoder.h"

@class RPImageAndTextCell, TSPlayer, TSChannel;

#define ASSERT_UI_THREAD_SAFETY() NSAssert2([[NSThread mainThread] isEqual:[NSThread currentThread]], @"[%@ %@]: [NSThread mainThread] != [NSThread currentThread], unsafe behaviour for UI updates", [self className], NSStringFromSelector(_cmd))

typedef enum {
  TSControllerPlayerActive = 1,
  TSControllerPlayerMuteMic = 2,
  TSControllerPlayerMuteSpeakers = 3,

  TSControllerPlayerAway = 100,
  TSControllerPlayerChannelCommander = 200,
  TSControllerPlayerBlockWhispers = 300,
} TSControllerPlayerStatus;

@interface TSController : NSObject <NSOutlineViewDelegate, NSOutlineViewDataSource, NSToolbarDelegate> {
  
  // user interface
  
  IBOutlet NSWindow *mainWindow;
  IBOutlet NSOutlineView *mainWindowOutlineView;
  IBOutlet NSToolbar *toolbar;
  IBOutlet NSMenu *fileMenu;
  IBOutlet NSMenu *statusMenu;
  IBOutlet NSMenu *channelsMenu;
  
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
  BOOL isConnecting;
  BOOL isConnected;
  NSString *currentServerAddress;
  
  NSMutableDictionary *players;
  NSMutableDictionary *channels;
  NSMutableDictionary *flattenedChannels;
  NSArray *sortedChannels;
  
  TSChannel *currentChannel;
  
  // main graph player
  TSAUGraphPlayer *graphPlayer;
  
  // background stuff
  SLConnection *teamspeakConnection;
  
  // transmission stuff
  TSTransmission *transmission;
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

#pragma mark Context Menu Generators

- (NSMenu*)contextualMenuForPlayer:(TSPlayer*)player;

#pragma mark Contextual Menu Actions

- (void)toggleMutePlayer:(id)sender;
- (void)kickPlayer:(id)sender;
- (void)channelKickPlayer:(id)sender;

#pragma mark Toolbar Delegates

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)aToolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)aToolbar;
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;

#pragma mark Menu Items

- (IBAction)connectMenuAction:(id)sender;
- (IBAction)disconnectMenuAction:(id)sender;
- (IBAction)preferencesMenuAction:(id)sender;
- (IBAction)connectToHistoryAction:(id)sender;
- (IBAction)singleClickOutlineView:(id)sender;
- (IBAction)doubleClickOutlineView:(id)sender;
- (IBAction)changeUserStatusAction:(id)sender;
- (IBAction)toggleAway:(id)sender;
- (IBAction)toggleChannelCommander:(id)sender;
- (IBAction)toggleBlockWhispers:(id)sender;
- (IBAction)menuChangeChannelAction:(id)sender;

#pragma mark Connection Window Actions

- (IBAction)connectionWindowUpdateType:(id)sender;
- (IBAction)connectionWindowOKAction:(id)sender;
- (IBAction)connectionWindowCancelAction:(id)sender;

#pragma mark Player Status View

- (void)updatePlayerStatusView;

#pragma mark Connection Menu

- (void)recentServersChanged:(NSNotification*)notification;
- (IBAction)editServerListAction:(id)sender;
- (void)setupRecentServersMenu;
- (void)setupChannelsMenu;
- (void)setupDisconnectedToolbarStatusPopupButton;
- (void)setupConnectedToolbarStatusPopupButton;

#pragma mark Menu Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem;

#pragma mark SLConnection Calls

- (void)loginToServer:(NSString*)server port:(int)port nickname:(NSString*)nickname registered:(BOOL)registered username:(NSString*)username password:(NSString*)password;

#pragma mark SLConnection Delegates

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage;
- (void)connectionFinishedLogin:(SLConnection*)connection;
- (void)connectionFailedToLogin:(SLConnection*)connection withError:(NSError*)error;
- (void)connectionDisconnected:(SLConnection*)connection withError:(NSError*)error;
- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary;
- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary;
- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname channelPrivFlags:(unsigned int)cFlags extendedFlags:(unsigned int)eFlags;
- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID;
- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags;
- (void)connection:(SLConnection*)connection receivedPlayerMutedNotification:(unsigned int)playerID wasMuted:(BOOL)muted;
- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID;
- (void)connection:(SLConnection*)connection receivedPlayerPriviledgeChangeNotification:(unsigned int)playerID byPlayerID:(unsigned int)byPlayerID changeType:(SLConnectionPrivChange)changeType privFlag:(SLConnectionChannelPrivFlags)flag;
- (void)connection:(SLConnection*)connection receivedPlayerServerPriviledgeChangeNotification:(unsigned int)playerID byPlayerID:(unsigned int)byPlayerID changeType:(SLConnectionPrivChange)changeType privFlag:(SLConnectionChannelPrivFlags)flag;
- (void)connection:(SLConnection*)connection receivedPlayerKickedFromChannel:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID intoChannel:(unsigned int)channelID reason:(NSString*)reason;

#pragma mark Audio

- (void)outputDeviceHasChanged:(NSNotification*)notification;
- (void)outputDeviceGainChanged:(NSNotification*)notification;
- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID isWhisper:(BOOL)isWhisper senderPacketCounter:(unsigned short)count;
- (void)idleAudioCheck:(NSTimer*)timer;
- (void)speakVoiceEvent:(NSString*)eventText alternativeText:(NSString*)alternativeText;

#pragma mark Hotkeys

- (void)hotkeyPressed:(TSHotkey*)hotkey;
- (void)hotkeyReleased:(TSHotkey*)hotkey;
- (void)hotkeyMappingsChanged:(NSNotification*)notification;

#pragma mark Defaults

- (void)userDefaultsChanged:(NSNotification*)notification;

#pragma mark NSAlert Sheet Delegate

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;

#pragma mark NSApplication Delegate

- (void)applicationWillTerminate:(NSNotification *)aNotification;

@end

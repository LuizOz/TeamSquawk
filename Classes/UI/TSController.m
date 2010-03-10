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

#import <dispatch/dispatch.h>

#import <Sparkle/Sparkle.h>
#import "TSStandardVersionComparator.h"

#import <MTCoreAudio/MTCoreAudio.h>
#import <MWFramework/MWFramework.h>

#import "TSPreferencesController.h"
#import "TSController.h"
#import "TSAudioExtraction.h"
#import "TSPlayer.h"
#import "TSChannel.h"
#import "TSLogger.h"

#define SPEECH_RATE 150.0f

@implementation TSController

- (void)awakeFromNib
{  
  [MWBetterCrashes createBetterCrashes];
  UKCrashReporterCheckForCrash();
    
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithFloat:1.0], @"InputGain",
                            [NSNumber numberWithFloat:1.0], @"OutputGain",
                            [NSArray array], @"RecentServers",
                            [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithInt:TSHotkeyPushToTalk], @"HotkeyAction",
                                                       [NSNumber numberWithInt:-1], @"HotkeyKeycode",
                                                       [NSNumber numberWithInt:0], @"HotkeyModifiers",
                                                       nil], nil], @"Hotkeys",
                            [NSNumber numberWithBool:NO], @"SmallPlayers",
                            [NSNumber numberWithBool:NO], @"AutoChannelCommander",
                            [NSNumber numberWithBool:YES], @"SpeakChannelEvents",
                            [NSNumber numberWithBool:YES], @"UseTeamspeakPhrases",
                            [NSSpeechSynthesizer defaultVoice], @"SpeechVoice",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hotkeyMappingsChanged:) name:@"TSHotkeysDidChange" object:nil];
  [self hotkeyMappingsChanged:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recentServersChanged:) name:@"TSRecentServersDidChange" object:nil];
  [self setupRecentServersMenu];
  
  // setup the outline view
  [mainWindowOutlineView setDelegate:self];
  [mainWindowOutlineView setDataSource:self];
  //[mainWindowOutlineView setAction:@selector(singleClickOutlineView:)];
  [mainWindowOutlineView setDoubleAction:@selector(doubleClickOutlineView:)];
  [mainWindowOutlineView setTarget:self];
  
  float rowHeight = ([[NSUserDefaults standardUserDefaults] boolForKey:@"SmallPlayers"] ? [TSPlayerCell smallCellHeight] : [TSPlayerCell cellHeight]);
  [mainWindowOutlineView setRowHeight:rowHeight];
  
  // setup the toolbar
  toolbar = [[NSToolbar alloc] initWithIdentifier:@"MainWindowToolbar"];
  [toolbar setDelegate:self];
  [toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
  [toolbar setSizeMode:NSToolbarSizeModeSmall];
  [mainWindow setToolbar:toolbar];
  
  // setup the toolbar view
  [toolbarViewAwayImageView setImage:[NSImage imageNamed:@"Graphite"]];
  [toolbarViewNicknameField setStringValue:@"TeamSquawk"];
  [self setupDisconnectedToolbarStatusPopupButton];

  sharedTextFieldCell = [[NSTextFieldCell alloc] init];
  sharedPlayerCell = [[TSPlayerCell alloc] init];
  
  // reset our internal state
  isConnected = NO;
  isConnecting = NO;
  players = [[TSSafeMutableDictionary alloc] init];
  channels = [[TSSafeMutableDictionary alloc] init];
  flattenedChannels = [[TSSafeMutableDictionary alloc] init];
  sortedChannels = nil;
  transmission = nil;
  graphPlayer = nil;
  
  // point NSApp here
  [NSApp setDelegate:self];
  
  // get the output device going
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputDeviceHasChanged:) name:@"TSOutputDeviceChanged" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputDeviceGainChanged:) name:@"TSOutputGainChanged" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userDefaultsChanged:) name:NSUserDefaultsDidChangeNotification object:nil];
  
  // setup the initial graph player
  [self outputDeviceHasChanged:nil];
  [self outputDeviceGainChanged:nil];
  
  [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(idleAudioCheck:) userInfo:nil repeats:YES];
  
  if(getenv("NSZombieEnabled") || getenv("NSAutoreleaseFreedObjectCheckEnabled"))
  {
		NSLog(@"NSZombieEnabled/NSAutoreleaseFreedObjectCheckEnabled enabled!");
	}
}

#pragma mark OutlineView DataSource

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  if (item == nil)
  {
    return [sortedChannels objectAtIndex:index];
  }
  else if ([item isKindOfClass:[TSChannel class]])
  {
    return [[item players] objectAtIndex:index];
  }
  return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  if (item == nil)
  {
    return YES;
  }
  if ([item isKindOfClass:[TSChannel class]])
  {
    return ([[item players] count] > 0);
  }
  return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  if (item == nil)
  {
    return [sortedChannels count];
  }
  else if ([item isKindOfClass:[TSChannel class]])
  {
    return [[item players] count];
  }
  return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  // assert thread safety here, if someone's called reloadItem/reloadData badly we'll know about it.
  ASSERT_UI_THREAD_SAFETY();
  if ([item isKindOfClass:[TSChannel class]])
  {
    return [(TSChannel*)item channelName];
  }
  else if ([item isKindOfClass:[TSPlayer class]])
  {
    return (TSPlayer*)item;
  }
  return nil;
}

#pragma mark OutlineView Delegates

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  if ([item isKindOfClass:[TSChannel class]])
  {
    return 17.0;
  }
  return [outlineView rowHeight];
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  if ([item isKindOfClass:[TSPlayer class]])
  {
    return sharedPlayerCell;
  }
  return sharedTextFieldCell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  if ([outlineView isEqualTo:mainWindowOutlineView] && [item isKindOfClass:[TSChannel class]])
  {
    return YES;
  }
  return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
  ASSERT_UI_THREAD_SAFETY();
  
  // This is a hack but I can't seem to get the view to paint properly without it
  [outlineView sizeToFit];
  
  if ([item isKindOfClass:[TSChannel class]])
  {
    [self outlineView:outlineView willDisplayCell:cell forTableColumn:tableColumn forChannel:item];
  }
  else if ([item isKindOfClass:[TSPlayer class]])
  {
    [self outlineView:outlineView willDisplayCell:cell forTableColumn:tableColumn forPlayer:item];
  }
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(RPImageAndTextCell*)cell forTableColumn:(NSTableColumn*)tableColumn forChannel:(TSChannel*)channel
{
  [cell setImage:nil];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(RPImageAndTextCell*)cell forTableColumn:(NSTableColumn*)tableColumn forPlayer:(TSPlayer*)player
{
  [cell setMenu:[self contextualMenuForPlayer:player]];
}

#pragma mark Context Menu Generators

- (NSMenu*)contextualMenuForPlayer:(TSPlayer*)player
{
  NSMenu *menu = [[NSMenu allocWithZone:[NSMenu menuZone]] init];
  
  [menu addItemWithTitle:@"Kick Player" action:@selector(kickPlayer:) keyEquivalent:@""];
  [menu addItemWithTitle:@"Kick Player From Channel" action:@selector(channelKickPlayer:) keyEquivalent:@""];
  [menu addItemWithTitle:@"Ban Player" action:nil keyEquivalent:@""];
  
  if ([player isLocallyMuted])
  {
    [menu addItemWithTitle:@"Unmute Player" action:@selector(toggleMutePlayer:) keyEquivalent:@""];
  }
  else
  {
    [menu addItemWithTitle:@"Mute Player" action:@selector(toggleMutePlayer:) keyEquivalent:@""];
  }
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  [menu addItemWithTitle:@"Get Info" action:nil keyEquivalent:@""];
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  [menu addItemWithTitle:@"Channel Admin" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Auto-Operator" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Auto-Voice" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Operator" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Voice" action:nil keyEquivalent:@""];
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  [menu addItemWithTitle:@"Send Player Text Message" action:nil keyEquivalent:@""];
  
  return [menu autorelease];
}

#pragma mark Contextual Menu Actions

- (void)toggleMutePlayer:(id)sender
{  
  TSPlayer *player = [mainWindowOutlineView itemAtRow:[mainWindowOutlineView clickedRow]];
  [teamspeakConnection changeMute:![player isLocallyMuted] onOtherPlayerID:[player playerID]];
}

- (void)kickPlayer:(id)sender
{
  TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
  
  if ([teamspeakConnection checkPermission:PERMS_MISC_SERVERKICK_BYTE5 permissionType:SLConnectionPermissionMisc forExtendedFlags:[me extendedFlags] andChannelPrivFlags:[me channelPrivFlags]])
  {
    TSPlayer *player = [mainWindowOutlineView itemAtRow:[mainWindowOutlineView clickedRow]];
    [teamspeakConnection kickPlayer:[player playerID] withReason:@""];
  }  
}

- (void)channelKickPlayer:(id)sender
{
  TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
  
  if ([teamspeakConnection checkPermission:PERMS_MISC_CHANKICK_BYTE5 permissionType:SLConnectionPermissionMisc forExtendedFlags:[me extendedFlags] andChannelPrivFlags:[me channelPrivFlags]])
  {
    TSPlayer *player = [mainWindowOutlineView itemAtRow:[mainWindowOutlineView clickedRow]];
    [teamspeakConnection kickPlayerFromChannel:[player playerID] withReason:@""];
  }  
}

#pragma mark Toolbar Delegates

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)aToolbar
{
  return [NSArray arrayWithObjects:@"TSControllerToolbarView", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)aToolbar
{
  return [self toolbarAllowedItemIdentifiers:aToolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
  if ([itemIdentifier isEqualToString:@"TSControllerToolbarView"])
  {
    NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:@"TSControllerToolbarView"] autorelease];
    [item setView:toolbarView];
    [item setMinSize:[toolbarView frame].size];
    [item setMaxSize:NSMakeSize(FLT_MAX, [toolbarView frame].size.height)];
    return item;
  }
  return nil;
}

#pragma mark Menu Items

- (IBAction)connectMenuAction:(id)sender
{  
  [connectionWindowUsernameField setEnabled:([[connectionWindowTypeMatrix selectedCell] tag] == 0)];
  [connectionWindowServerTextField setStringValue:@""];
  [connectionWindowNicknameTextField setStringValue:@""];
  [connectionWindowUsernameField setStringValue:@""];
  [connectionWindowPasswordField setStringValue:@""];
  
  [connectionWindow center];
  [connectionWindow makeKeyAndOrderFront:sender];
}

- (IBAction)disconnectMenuAction:(id)sender
{
  if (isConnected)
  {
    [teamspeakConnection disconnect];
  }
}

- (IBAction)preferencesMenuAction:(id)sender
{
  [[TSPreferencesController sharedPrefsWindowController] showWindow:nil];
}

- (IBAction)connectToHistoryAction:(id)sender
{
  NSMenuItem *item = sender;
  NSDictionary *server = [item representedObject];
  
  [self loginToServer:[server objectForKey:@"ServerAddress"] 
                 port:[[server objectForKey:@"Port"] intValue]
             nickname:[server objectForKey:@"Nickname"]
           registered:[[server objectForKey:@"Registered"] boolValue]
             username:([[server objectForKey:@"Registered"] boolValue] ? [server objectForKey:@"Username"] : nil)
             password:[server objectForKey:@"Password"]];
}

- (IBAction)singleClickOutlineView:(id)sender
{
  
}

- (IBAction)doubleClickOutlineView:(id)sender
{
  id item = [(NSOutlineView*)sender itemAtRow:[(NSOutlineView*)sender selectedRow]];
  
  if ([item isKindOfClass:[TSChannel class]])
  {
    [teamspeakConnection changeChannelTo:[(TSChannel*)item channelID] withPassword:nil];
  }
  
}

- (IBAction)changeUserStatusAction:(id)sender
{
  NSMenuItem *item = sender;
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
  unsigned short currentFlags = ([player playerFlags] & 0xffff);
  
  switch ([item tag])
  {
    case TSControllerPlayerActive:
    {
      currentFlags &= ~(TSPlayerHasMutedSpeakers | TSPlayerHasMutedMicrophone);
      [teamspeakConnection changeStatusTo:currentFlags];
      break;
    }
    case TSControllerPlayerMuteMic:
    {
      currentFlags &= ~(TSPlayerHasMutedSpeakers | TSPlayerHasMutedMicrophone);
      currentFlags |= TSPlayerHasMutedMicrophone;
      [teamspeakConnection changeStatusTo:currentFlags];
      break;
    }
    case TSControllerPlayerMuteSpeakers:
    {
      currentFlags &= ~(TSPlayerHasMutedSpeakers | TSPlayerHasMutedMicrophone);
      currentFlags |= TSPlayerHasMutedSpeakers;
      [teamspeakConnection changeStatusTo:currentFlags];      
    }
    default:
      break;
  }
}

- (IBAction)toggleAway:(id)sender
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
  unsigned short currentFlags = [player playerFlags] & 0xffff, newFlags;
  
  newFlags = currentFlags;
  newFlags &= ~TSPlayerIsAway;
  newFlags |= ~(currentFlags & TSPlayerIsAway) & TSPlayerIsAway;
  
  [teamspeakConnection changeStatusTo:newFlags];
}

- (IBAction)toggleChannelCommander:(id)sender
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
  unsigned short currentFlags = [player playerFlags] & 0xffff, newFlags;
  
  newFlags = currentFlags;
  newFlags &= ~TSPlayerChannelCommander;
  newFlags |= ~(currentFlags & TSPlayerChannelCommander) & TSPlayerChannelCommander;
  
  [teamspeakConnection changeStatusTo:newFlags];
}

- (IBAction)toggleBlockWhispers:(id)sender
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
  unsigned short currentFlags = [player playerFlags] & 0xffff, newFlags;
  
  newFlags = currentFlags;
  newFlags &= ~TSPlayerBlockWhispers;
  newFlags |= ~(currentFlags & TSPlayerBlockWhispers) & TSPlayerBlockWhispers;
  
  [teamspeakConnection changeStatusTo:newFlags];
}

- (IBAction)menuChangeChannelAction:(id)sender
{
  [teamspeakConnection changeChannelTo:[sender tag] withPassword:nil];
}

- (IBAction)debugWindowMenuAction:(id)sender
{
  [TSLogger setEventBlock:^{
    NSString *t = [TSLogger log];
    dispatch_async(dispatch_get_main_queue(), ^{
      [debugTextView setString:t];
      [debugTextView setNeedsDisplay:YES];
    });
  }];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(debugWindowWillClose:) name:NSWindowWillCloseNotification object:debugWindow];
  [debugTextView setString:[TSLogger log]];
  [debugWindow makeKeyAndOrderFront:sender];
}

- (IBAction)debugWindowCopyAction:(id)sender
{
  [[NSPasteboard generalPasteboard] clearContents];
  [[NSPasteboard generalPasteboard] setString:[debugTextView string] forType:NSPasteboardTypeString];
}

- (void)debugWindowWillClose:(NSNotification*)notification
{
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:debugWindow];
  [TSLogger setEventBlock:nil];
}

#pragma mark Connection Window Actions

- (IBAction)connectionWindowUpdateType:(id)sender
{
  [connectionWindowUsernameField setEnabled:([[connectionWindowTypeMatrix selectedCell] tag] == 0)];
}

- (IBAction)connectionWindowOKAction:(id)sender
{
  [connectionWindow orderOut:sender];
  
  [self loginToServer:[connectionWindowServerTextField stringValue] 
                 port:8767 
             nickname:[connectionWindowNicknameTextField stringValue] 
           registered:([[connectionWindowTypeMatrix selectedCell] tag] == 0)
             username:(([[connectionWindowTypeMatrix selectedCell] tag] == 0) ? [connectionWindowUsernameField stringValue] : nil)
             password:[connectionWindowPasswordField stringValue]];
}

- (IBAction)connectionWindowCancelAction:(id)sender
{
  [connectionWindow orderOut:sender];
}

#pragma mark Player Status View

- (void)updatePlayerStatusView
{
  ASSERT_UI_THREAD_SAFETY();
  if (isConnected)
  {
    TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
    
    [toolbarViewNicknameField setStringValue:[player playerName]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerActive] setState:(([player playerFlags] & (TSPlayerHasMutedMicrophone | TSPlayerHasMutedSpeakers)) == 0)];
    [[statusMenu itemWithTag:TSControllerPlayerActive] setState:(([player playerFlags] & (TSPlayerHasMutedMicrophone | TSPlayerHasMutedSpeakers)) == 0)];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerMuteMic] setState:[player hasMutedMicrophone]];
    [[statusMenu itemWithTag:TSControllerPlayerMuteMic] setState:[player hasMutedMicrophone]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerMuteSpeakers] setState:[player hasMutedSpeakers]];
    [[statusMenu itemWithTag:TSControllerPlayerMuteSpeakers] setState:[player hasMutedSpeakers]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerAway] setState:[player isAway]];
    [[statusMenu itemWithTag:TSControllerPlayerAway] setState:[player isAway]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerChannelCommander] setState:[player isChannelCommander]];
    [[statusMenu itemWithTag:TSControllerPlayerChannelCommander] setState:[player isChannelCommander]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerBlockWhispers] setState:[player shouldBlockWhispers]];
    [[statusMenu itemWithTag:TSControllerPlayerBlockWhispers] setState:[player shouldBlockWhispers]];

    if ([player hasMutedSpeakers])
    {
      [toolbarViewAwayImageView setImage:[NSImage imageNamed:@"Mute"]];
    }
    else if ([player isAway])
    {
      [toolbarViewAwayImageView setImage:[NSImage imageNamed:@"Away"]];
    }
    else if ([player hasMutedMicrophone])
    {
      [toolbarViewAwayImageView setImage:[NSImage imageNamed:@"Orange"]];
    }
    else
    {
      [toolbarViewAwayImageView setImage:[NSImage imageNamed:@"Green"]];
    }
    
    if (transmission && [transmission isTransmitting])
    {
      [toolbarViewStatusImageView setImage:[NSImage imageNamed:@"TransmitOrange"]];
    }
    else if ([player isChannelCommander])
    {
      [toolbarViewStatusImageView setImage:[NSImage imageNamed:@"TransmitBlue"]];
    }
    else
    {
      [toolbarViewStatusImageView setImage:[NSImage imageNamed:@"TransmitGreen"]];
    }
  }
  else
  {
    [toolbarViewNicknameField setStringValue:@"TeamSquawk"];
    [toolbarViewAwayImageView setImage:[NSImage imageNamed:@"Graphite"]];
    [toolbarViewStatusImageView setImage:[NSImage imageNamed:@"TransmitGray"]];
  }
}

#pragma mark Connection Menu

- (void)recentServersChanged:(NSNotification*)notification
{
  ASSERT_UI_THREAD_SAFETY();
  if (!isConnected)
  {
    [self setupDisconnectedToolbarStatusPopupButton];
    [self setupRecentServersMenu];
  }
}

- (IBAction)editServerListAction:(id)sender
{
  ASSERT_UI_THREAD_SAFETY();
  [[TSPreferencesController sharedPrefsWindowController] showWindow:sender];
  [[TSPreferencesController sharedPrefsWindowController] displayViewForIdentifier:@"Servers" animate:YES];
}

- (void)setupRecentServersMenu
{
  ASSERT_UI_THREAD_SAFETY();
  int recentServersIndex = -1;
  
  for (NSMenuItem *item in [fileMenu itemArray])
  {
    if ([item tag] == -1)
    {
      recentServersIndex = [fileMenu indexOfItem:item] + 1;
      break;
    }
  }
  
  while ([[fileMenu itemAtIndex:recentServersIndex] tag] != -1)
  {
    [fileMenu removeItemAtIndex:recentServersIndex];
  }
  
  NSArray *recentServers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"];
  if ([recentServers count] > 0)
  {
    unsigned int connectionNumber = 1;
    
    for (NSDictionary *server in recentServers)
    {
      NSString *serverTitle = [NSString stringWithFormat:@"%@ @ %@", [server objectForKey:@"Nickname"], [server objectForKey:@"ServerAddress"]];
      NSString *keyEquivalent = @"";
      
      if (connectionNumber < 10)
      {
        keyEquivalent = [NSString stringWithFormat:@"%d", connectionNumber++];
      }
      
      NSMenuItem *recentServer = [[[NSMenuItem alloc] initWithTitle:serverTitle action:@selector(connectToHistoryAction:) keyEquivalent:keyEquivalent] autorelease];
      [recentServer setTarget:self];
      [recentServer setImage:([[server objectForKey:@"Registered"] boolValue] ? [NSImage imageNamed:@"Blue"] : [NSImage imageNamed:@"Green"])];
      [recentServer setRepresentedObject:server];
      [fileMenu insertItem:recentServer atIndex:recentServersIndex++];
    }
  }
  else
  {
    NSMenuItem *recentServer = [[[NSMenuItem alloc] initWithTitle:@"No Recent Servers" action:@selector(unusedSelfDisablingAction:) keyEquivalent:@""] autorelease];
    [recentServer setTarget:self];
    [fileMenu insertItem:recentServer atIndex:recentServersIndex++];
  }
}

- (void)setupChannelsMenu
{
  ASSERT_UI_THREAD_SAFETY();
  for (NSMenuItem *item in [[[channelsMenu itemArray] copy] autorelease])
  {
    [channelsMenu removeItem:item];
  }  
  
  if (isConnected)
  {
    TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
        
    for (TSChannel *channel in sortedChannels)
    {
      NSMenuItem *item = [channelsMenu addItemWithTitle:[channel channelName] action:@selector(menuChangeChannelAction:) keyEquivalent:@""];
      [item setTarget:self];
      [item setTag:[channel channelID]];
      if ([[channel players] containsObject:me])
      {
        [item setState:YES];
      }
    }
  }
  else
  {
    [channelsMenu addItemWithTitle:@"Not Connected" action:nil keyEquivalent:@""];
  }
}

- (void)setupDisconnectedToolbarStatusPopupButton
{
  ASSERT_UI_THREAD_SAFETY();
  NSMenu *menu = [[NSMenu alloc] init];
  [menu addItemWithTitle:@"Offline" action:nil keyEquivalent:@""];
  [[menu addItemWithTitle:@"Connect..." action:@selector(connectMenuAction:) keyEquivalent:@""] setTarget:self];;
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  NSArray *recentServers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"];
  
  if ([recentServers count] > 0)
  {
    for (NSDictionary *server in recentServers)
    {
      NSString *serverTitle = [NSString stringWithFormat:@"%@ @ %@", [server objectForKey:@"Nickname"], [server objectForKey:@"ServerAddress"]];
      NSMenuItem *recentServer = [menu addItemWithTitle:serverTitle action:@selector(connectToHistoryAction:) keyEquivalent:@""];
      [recentServer setTarget:self];
      [recentServer setImage:([[server objectForKey:@"Registered"] boolValue] ? [NSImage imageNamed:@"Blue"] : [NSImage imageNamed:@"Green"])];
      [recentServer setRepresentedObject:server];
    }
  }
  else
  {
    [[menu addItemWithTitle:@"No Recent Servers" action:@selector(unusedSelfDisablingAction:) keyEquivalent:@""] setTarget:self];;
  }
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  [[menu addItemWithTitle:@"Edit Server List..." action:@selector(editServerListAction:) keyEquivalent:@""] setTarget:self];
  
  [toolbarViewStatusPopupButton setMenu:menu];
  [menu release];
  
  [toolbarViewStatusPopupButton setTitle:@"Offline"];
}

- (void)setupConnectedToolbarStatusPopupButton
{
  ASSERT_UI_THREAD_SAFETY();
  NSMenu *menu = [[NSMenu alloc] init];
  
  [menu addItemWithTitle:@"Connected" action:nil keyEquivalent:@""];
  [[menu addItemWithTitle:@"Disconnect..." action:@selector(disconnectMenuAction:) keyEquivalent:@""] setTarget:self];
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  NSMenuItem *activeMenuItem = [menu addItemWithTitle:@"Active" action:@selector(changeUserStatusAction:) keyEquivalent:@""];
  [activeMenuItem setTarget:self];
  [activeMenuItem setTag:TSControllerPlayerActive];
  [activeMenuItem setImage:[NSImage imageNamed:@"Green"]];
  [activeMenuItem setState:YES];
  
  NSMenuItem *muteMicrophoneItem = [menu addItemWithTitle:@"Mute Microphone" action:@selector(changeUserStatusAction:) keyEquivalent:@""];
  [muteMicrophoneItem setTarget:self];
  [muteMicrophoneItem setTag:TSControllerPlayerMuteMic];
  [muteMicrophoneItem setImage:[NSImage imageNamed:@"Orange"]];
  
  NSMenuItem *muteBothItem = [menu addItemWithTitle:@"Mute Mic + Speakers" action:@selector(changeUserStatusAction:) keyEquivalent:@""];
  [muteBothItem setTarget:self];
  [muteBothItem setTag:TSControllerPlayerMuteSpeakers];
  [muteBothItem setImage:[NSImage imageNamed:@"Mute"]];
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  NSMenuItem *awayItem = [menu addItemWithTitle:@"Away" action:@selector(toggleAway:) keyEquivalent:@""];
  [awayItem setTarget:self];
  [awayItem setTag:TSControllerPlayerAway];
  [awayItem setImage:[NSImage imageNamed:@"Away"]];
  
  [menu addItem:[NSMenuItem separatorItem]];
  
  NSMenuItem *channelCommanderItem = [menu addItemWithTitle:@"Channel Commander" action:@selector(toggleChannelCommander:) keyEquivalent:@""];
  [channelCommanderItem setTarget:self];
  [channelCommanderItem setTag:TSControllerPlayerChannelCommander];
  [channelCommanderItem setImage:[NSImage imageNamed:@"ChannelCommander"]];
  
  NSMenuItem *blockWhispersItem = [menu addItemWithTitle:@"Block Whispers" action:@selector(toggleBlockWhispers:) keyEquivalent:@""];
  [blockWhispersItem setTarget:self];
  [blockWhispersItem setTag:TSControllerPlayerBlockWhispers];
  [blockWhispersItem setImage:[NSImage imageNamed:@"BlockWhispers"]];
  
  [toolbarViewStatusPopupButton setMenu:menu];
  [menu release];
}
   
#pragma mark Menu Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
  if ([anItem action] == @selector(connectMenuAction:))
  {
    return (!isConnected && !isConnecting);
  }
  else if ([anItem action] == @selector(disconnectMenuAction:))
  {
    return (isConnected && !isConnecting);
  }
  else if ([anItem action] == @selector(unusedSelfDisablingAction:))
  {
    // never let this one enable
    return NO;
  }
  else if ([anItem action] == @selector(connectToHistoryAction:))
  {
    return (!isConnected && !isConnecting);
  }
  else if ([anItem action] == @selector(changeUserStatusAction:))
  {
    return (isConnected && (([currentChannel codec] >= SLCodecSpeex_3_4) && ([currentChannel codec] <= SLCodecSpeex_25_9)));
  }
  else if (([anItem action] == @selector(toggleAway:)) ||
           ([anItem action] == @selector(toggleBlockWhispers:)))
  {
    return isConnected;
  }
  else if ([anItem action] == @selector(toggleChannelCommander:))
  {
    if (isConnected)
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      BOOL hasChanCmdrPriv = [teamspeakConnection checkPermission:PERMS_MISC_CHANCOMMANDER_BYTE5 
                                                   permissionType:SLConnectionPermissionMisc
                                                 forExtendedFlags:[me extendedFlags]
                                              andChannelPrivFlags:[me channelPrivFlags]];
      return hasChanCmdrPriv;
    }
    return NO;
  }
  else if ([anItem action] == @selector(kickPlayer:))
  {
    if (isConnected)
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      BOOL canServerKick = [teamspeakConnection checkPermission:PERMS_MISC_SERVERKICK_BYTE5
                                                 permissionType:SLConnectionPermissionMisc 
                                               forExtendedFlags:[me extendedFlags]
                                            andChannelPrivFlags:[me channelPrivFlags]];
      return canServerKick;
    }
  }
  else if ([anItem action] == @selector(channelKickPlayer:))
  {
    if (isConnected)
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      BOOL canChannelKick = [teamspeakConnection checkPermission:PERMS_MISC_CHANKICK_BYTE5
                                                  permissionType:SLConnectionPermissionMisc 
                                                forExtendedFlags:[me extendedFlags]
                                             andChannelPrivFlags:[me channelPrivFlags]];
      return canChannelKick;
    }
  }
  
  return YES;
}

#pragma mark SLConnection Calls

- (void)loginToServer:(NSString*)server port:(int)port nickname:(NSString*)nickname registered:(BOOL)registered username:(NSString*)username password:(NSString*)password
{
  NSError *error = nil;
  
  // create our recent servers entry
  NSDictionary *recentServer = [NSDictionary dictionaryWithObjectsAndKeys:
                                server, @"ServerAddress",
                                nickname, @"Nickname",
                                [NSNumber numberWithInt:port], @"Port",
                                [NSNumber numberWithBool:registered], @"Registered",
                                password, @"Password",
                                // should always come last, then nil username will stop the array
                                username, @"Username",
                                nil];
  NSArray *recentServers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"];
  BOOL alreadyInRecentServers = NO;
  
  for (NSDictionary *server in recentServers)
  {
    if ([[server objectForKey:@"ServerAddress"] isEqual:[recentServer objectForKey:@"ServerAddress"]] &&
        [[server objectForKey:@"Nickname"] isEqual:[recentServer objectForKey:@"Nickname"]] &&
        [[server objectForKey:@"Port"] isEqual:[recentServer objectForKey:@"Port"]] &&
        [[server objectForKey:@"Registered"] isEqual:[recentServer objectForKey:@"Registered"]] &&
        [[server objectForKey:@"Password"] isEqual:[recentServer objectForKey:@"Password"]])
    {
      if (([[recentServer objectForKey:@"Registered"] boolValue] && 
           [[server objectForKey:@"Username"] isEqual:[recentServer objectForKey:@"Username"]]) || 
          ![[recentServer objectForKey:@"Registered"] boolValue])
      {
        alreadyInRecentServers = YES;
        break;
      }
    }
  }
  
  if (!alreadyInRecentServers)
  {
    recentServers = [recentServers arrayByAddingObject:recentServer];
    [[NSUserDefaults standardUserDefaults] setObject:recentServers forKey:@"RecentServers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
  }
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"TSRecentServersDidChange" object:nil];
  
  currentServerAddress = [server retain];
  [toolbarViewStatusPopupButton setTitle:@"Connecting..."];
  isConnecting = YES;
    
  // create a connection
  teamspeakConnection = [[SLConnection alloc] initWithHost:currentServerAddress withPort:port withError:&error];
  
  if (!teamspeakConnection)
  {
    isConnected = NO;
    isConnecting = NO;
    
    [self setupDisconnectedToolbarStatusPopupButton];
    [self updatePlayerStatusView];
    [self setupChannelsMenu];
    
    if (error)
    {
      if ([[error domain] isEqual:@"kCFStreamErrorDomainNetDB"])
      {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[[error localizedDescription] capitalizedString], NSLocalizedDescriptionKey, 
                              @"Could not resolve the address of the server you specified, please check the address and try again. Alternatively, the server may not exist.", NSLocalizedRecoverySuggestionErrorKey, nil];
        error = [NSError errorWithDomain:[error domain] code:[error code] userInfo:dict];
      }
      
      [[NSAlert alertWithError:error] beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    }
    
    return;
  }
  
  [teamspeakConnection setDelegate:self];
    
  // setup some basic things about this client
  [teamspeakConnection setClientName:@"TeamSquawk"];
  [teamspeakConnection setClientOperatingSystem:@"Mac OS X"];
  [teamspeakConnection setClientMajorVersion:1];
  [teamspeakConnection setClientMinorVersion:0];
    
  [teamspeakConnection beginAsynchronousLogin:username password:password nickName:nickname isRegistered:registered];
}

#pragma mark SLConnection Delegates

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform
      majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage
{
  
}

- (void)connectionFinishedLogin:(SLConnection*)connection
{
  isConnected = YES;
  isConnecting = NO;
    
  // get the TSPlayer for who we are
  TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
    
  // find what channel we ended up in
  for (TSChannel *channel in [flattenedChannels allValues])
  {
    for (TSPlayer *player in [channel players])
    {
      if ([player isEqual:me])
      {
        currentChannel = [channel retain];
        break;
      }
    }
  }
  
  // double check
  if (!currentChannel)
  {
//    [[NSException exceptionWithName:@"ChannelFail" reason:@"Teamspeak connection established but failed to find user in any channel." userInfo:nil] raise];
//    return;
  }
  
  // setup transmission
  transmission = [[TSTransmission alloc] initWithConnection:teamspeakConnection codec:[currentChannel codec] voiceActivated:NO];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setupConnectedToolbarStatusPopupButton];
    [self updatePlayerStatusView];
    [self setupChannelsMenu];
    
    [toolbarViewStatusPopupButton setTitle:currentServerAddress];
    
    [mainWindowOutlineView reloadData];
    [mainWindowOutlineView expandItem:nil expandChildren:YES];
  });
  
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AutoChannelCommander"])
  {
    [self toggleChannelCommander:nil];
  }
  
  [self speakVoiceEvent:@"Link Engaged." alternativeText:@"Connected."];
}

- (void)connectionFailedToLogin:(SLConnection*)connection withError:(NSError*)error
{
  isConnected = NO;
  isConnecting = NO;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setupDisconnectedToolbarStatusPopupButton];
    [self updatePlayerStatusView];
    [self setupChannelsMenu];
    [mainWindowOutlineView reloadData];
  });
  
  if (error)
  {
    [[NSAlert alertWithError:error] beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
  }
}

- (void)connectionDisconnected:(SLConnection*)connection withError:(NSError*)error
{  
  isConnected = NO;
  isConnecting = NO;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self setupDisconnectedToolbarStatusPopupButton];
    [self updatePlayerStatusView];
    [self setupChannelsMenu];

    [sortedChannels release];
    sortedChannels = nil;
    
    [transmission setIsTransmitting:NO];
    [transmission close];
    [transmission release];
    transmission = nil;
    
    [flattenedChannels removeAllObjects];
    [channels removeAllObjects];
    [players removeAllObjects];
    
    [mainWindowOutlineView reloadData];
  });
  
  if (error)
  {
    [[NSAlert alertWithError:error] beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
  }
  
  [self speakVoiceEvent:@"Link Disengaged." alternativeText:@"Disconnected."];
}

- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary
{
  NSArray *channelsDictionary = [channelDictionary objectForKey:@"SLChannels"];
  
  for (NSDictionary *channelDictionary in channelsDictionary)
  {
    TSChannel *channel = [[TSChannel alloc] init];
    
    [channel setChannelName:[channelDictionary objectForKey:@"SLChannelName"]];
    [channel setChannelDescription:[channelDictionary objectForKey:@"SLChannelDescription"]];
    [channel setChannelTopic:[channelDictionary objectForKey:@"SLChannelTopic"]];
    [channel setChannelID:[[channelDictionary objectForKey:@"SLChannelID"] unsignedIntValue]];
    [channel setParent:[[channelDictionary objectForKey:@"SLChannelParentID"] unsignedIntValue]];
    [channel setCodec:[[channelDictionary objectForKey:@"SLChannelCodec"] unsignedIntValue]];
    [channel setFlags:[[channelDictionary objectForKey:@"SLChannelFlags"] unsignedIntValue]];
    [channel setMaxUsers:[[channelDictionary objectForKey:@"SLChannelMaxUsers"] unsignedIntValue]];
    [channel setSortOrder:[[channelDictionary objectForKey:@"SLChannelSortOrder"] unsignedIntValue]];

    dispatch_sync(dispatch_get_main_queue(), ^{
      [flattenedChannels setObject:channel forKey:[NSNumber numberWithUnsignedInt:[channel channelID]]];
      
      // root channels have a parent of 0xffffffff, if we've got a real parent and we haven't
      // encountered yet then we should crater
      if ([channel parent] == 0xffffffff)
      {
        [channels setObject:channel forKey:[NSNumber numberWithUnsignedInt:[channel channelID]]];
      }
      else
      {
        NSNumber *parentChannel = [NSNumber numberWithUnsignedInt:[channel parent]];
        
        if (![flattenedChannels objectForKey:parentChannel])
        {
          [[NSException exceptionWithName:@"ParentChannelNotFound" reason:@"Subchannel defined before parent channel." userInfo:nil] raise];
          return;
        }
        [(TSChannel*)[flattenedChannels objectForKey:parentChannel] addSubChannel:channel];
      }
      
      [channel release];
    });
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    // channels can come in async after players have. so hoover up any orphans we may have lying arounf
    for (TSPlayer *player in [players allValues])
    {
      TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
      if (![[channel players] containsObject:player])
      {
        [channel addPlayer:player];
      }
    }
    
    [sortedChannels autorelease];
    NSArray *sortDescriptors = [NSArray arrayWithObjects:
                                [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease],
                                [[[NSSortDescriptor alloc] initWithKey:@"channelName" ascending:YES] autorelease],
                                nil];
    sortedChannels = [[[channels allValues] sortedArrayUsingDescriptors:sortDescriptors] retain];
    
    [self setupChannelsMenu];
    [mainWindowOutlineView reloadData];
    [mainWindowOutlineView expandItem:nil expandChildren:YES];
  });
}

- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary
{
  NSArray *playersDictionary = [playerDictionary objectForKey:@"SLPlayers"];
  
  for (NSDictionary *playerDictionary in playersDictionary)
  {
    TSPlayer *player = [[[TSPlayer alloc] initWithGraphPlayer:graphPlayer] autorelease];
    
    [player setPlayerName:[playerDictionary objectForKey:@"SLPlayerNick"]];
    [player setPlayerFlags:[[playerDictionary objectForKey:@"SLPlayerFlags"] unsignedIntValue]];
    [player setExtendedFlags:[[playerDictionary objectForKey:@"SLPlayerExtendedFlags"] unsignedIntValue]];
    [player setChannelPrivFlags:[[playerDictionary objectForKey:@"SLChannelPrivFlags"] unsignedIntValue]];
    [player setPlayerID:[[playerDictionary objectForKey:@"SLPlayerID"] unsignedIntValue]];
    [player setChannelID:[[playerDictionary objectForKey:@"SLChannelID"] unsignedIntValue]];
    [player setLastVoicePacketCount:0];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
      [players setObject:player forKey:[NSNumber numberWithUnsignedInt:[player playerID]]];
      
      TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
      [channel addPlayer:player];
    });
  }
}

- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname channelPrivFlags:(unsigned int)cFlags extendedFlags:(unsigned int)eFlags
{
  TSPlayer *player = [[[TSPlayer alloc] initWithGraphPlayer:graphPlayer] autorelease];
  
  [player setPlayerID:playerID];
  [player setPlayerName:nickname];
  [player setChannelID:channelID];
  [player setPlayerFlags:0];
  [player setExtendedFlags:eFlags];
  [player setChannelPrivFlags:cFlags];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [players setObject:player forKey:[NSNumber numberWithUnsignedInt:[player playerID]]];
    
    TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
    [channel addPlayer:player];
    
    [mainWindowOutlineView reloadItem:channel reloadChildren:YES];
    [mainWindowOutlineView expandItem:channel];
  });
  
  [self speakVoiceEvent:@"New Player." alternativeText:[NSString stringWithFormat:@"%@ connected.", [player playerName]]];
}

- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
   
  [self speakVoiceEvent:@"Player Left." alternativeText:[NSString stringWithFormat:@"%@ disconnected.", [player playerName]]];

  dispatch_async(dispatch_get_main_queue(), ^{
    [channel removePlayer:player];
    [players removeObjectForKey:[NSNumber numberWithUnsignedInt:playerID]];
    [mainWindowOutlineView reloadItem:channel reloadChildren:YES];
  });
}

- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  [player setPlayerFlags:flags];
 
  dispatch_async(dispatch_get_main_queue(), ^{
    // if this is us, update some menu stuff
    if (playerID == [teamspeakConnection clientID])
    {
      [self updatePlayerStatusView];
    }
    
    [mainWindowOutlineView reloadItem:player];
  });
}

- (void)connection:(SLConnection*)connection receivedPlayerMutedNotification:(unsigned int)playerID wasMuted:(BOOL)muted
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  [player setIsLocallyMuted:muted];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [mainWindowOutlineView reloadItem:player];
  });
}

- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *oldChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:fromChannelID]];
  TSChannel *newChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:toChannelID]];
  
  [player setChannelID:[newChannel channelID]];

  dispatch_sync(dispatch_get_main_queue(), ^{
    [oldChannel removePlayer:player];
    [newChannel addPlayer:player];
    [mainWindowOutlineView reloadData];
  });
    
  if ([player playerID] == [teamspeakConnection clientID])
  {
    [currentChannel autorelease];
    currentChannel = [newChannel retain];

    if (([newChannel codec] >= SLCodecSpeex_3_4) && ([newChannel codec] <= SLCodecSpeex_25_9))
    {
      // if we were in a crap codec channel, put our status back to active
      if (([oldChannel codec] < SLCodecSpeex_3_4) || ([oldChannel codec] > SLCodecSpeex_25_9))
      {
        unsigned int newFlags = ([player playerFlags] & ~(TSPlayerHasMutedSpeakers | TSPlayerHasMutedMicrophone));
        [teamspeakConnection changeStatusTo:newFlags];
      }
      [transmission setCodec:[currentChannel codec]];
    }
    else
    {
      unsigned int newFlags = (([player playerFlags] & ~(TSPlayerHasMutedSpeakers | TSPlayerHasMutedMicrophone)) | TSPlayerHasMutedSpeakers);
      [teamspeakConnection changeStatusTo:newFlags];
      
      NSAlert *alert = [NSAlert alertWithMessageText:@"Incompatible codec." defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"This channel uses a non-Speex codec, you can't listen or talk on this channel."];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
      });
    }
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [mainWindowOutlineView expandItem:newChannel];
    [self setupChannelsMenu];
  });
}

- (void)connection:(SLConnection*)connection receivedPlayerPriviledgeChangeNotification:(unsigned int)playerID byPlayerID:(unsigned int)byPlayerID changeType:(SLConnectionPrivChange)changeType privFlag:(SLConnectionChannelPrivFlags)flag
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  
  if (changeType == SLConnectionPrivAdded)
  {
    [player setChannelPrivFlags:([player channelPrivFlags] | flag)];
  }
  else
  {
    [player setChannelPrivFlags:([player channelPrivFlags] & ~flag)];
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [mainWindowOutlineView reloadItem:player reloadChildren:YES];
  });
}

- (void)connection:(SLConnection*)connection receivedPlayerServerPriviledgeChangeNotification:(unsigned int)playerID byPlayerID:(unsigned int)byPlayerID changeType:(SLConnectionPrivChange)changeType privFlag:(SLConnectionChannelPrivFlags)flag
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  
  if (changeType == SLConnectionPrivAdded)
  {
    [player setExtendedFlags:([player extendedFlags] | flag)];
  }
  else
  {
    [player setExtendedFlags:([player extendedFlags] & ~flag)];
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [mainWindowOutlineView reloadItem:player reloadChildren:YES];
  });
}

- (void)connection:(SLConnection*)connection receivedPlayerKickedFromChannel:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID intoChannel:(unsigned int)channelID reason:(NSString*)reason
{
  // find the player
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *fromChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:fromChannelID]];
  
  // move the player
  [self connection:connection receivedChannelChangeNotification:playerID fromChannel:fromChannelID toChannel:channelID];
  
  // if player is us
  if (playerID == [teamspeakConnection clientID])
  {
    [self speakVoiceEvent:@"You were kicked from channel." alternativeText:[NSString stringWithFormat:@"You were kicked from %@.", [fromChannel channelName]]];
  }
  else
  {
    [self speakVoiceEvent:@"Player Kicked" alternativeText:[NSString stringWithFormat:@"%@ was kicked from %@", [player playerName], [fromChannel channelName]]];
  }
}

#pragma mark Audio

- (void)outputDeviceHasChanged:(NSNotification*)notification
{
  // setup a new graph player and tell any TSPlayer objects we have a new one
  NSString *outputDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"OutputDeviceUID"];
  MTCoreAudioDevice *outputDevice = (outputDeviceUID ? [MTCoreAudioDevice deviceWithUID:outputDeviceUID] : [MTCoreAudioDevice defaultOutputDevice]);
  
  // STOP, this can be nil if the device has fooked off.
  if (!outputDevice)
  {
    // we could display a message here
    dispatch_async(dispatch_get_main_queue(), ^{
      NSAlert *alert = [NSAlert alertWithMessageText:@"Audio Device not found."
                                       defaultButton:@"OK"
                                     alternateButton:nil
                                         otherButton:nil
                           informativeTextWithFormat:@"Your default audio device could not be found, the default system device has been selected instead."];
      
      [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    });
    
    outputDevice = [MTCoreAudioDevice defaultOutputDevice];
  }
  
  MTCoreAudioStreamDescription *outputDeviceFormat = [outputDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection];
  
  [graphPlayer close];
  [graphPlayer autorelease];
  graphPlayer = [[TSAUGraphPlayer alloc] initWithAudioDevice:outputDevice inputStreamDescription:outputDeviceFormat];
  [graphPlayer setDelegate:self];
  
  for (TSPlayer *player in [players allValues])
  {
    [player setGraphPlayer:graphPlayer];
  }
}

- (void)outputDeviceGainChanged:(NSNotification*)notification
{
  float volume = [[NSUserDefaults standardUserDefaults] floatForKey:@"OutputGain"];
  [graphPlayer setOutputVolume:volume];  
}

- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID isWhisper:(BOOL)isWhisper senderPacketCounter:(unsigned short)count
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  
  // out-of-band, I know, least messy way though
  [player setIsWhispering:isWhisper];
  
  dispatch_async([player queue], ^{
    BOOL wasTransmitting = [player isTransmitting];
    [player backgroundDecodeData:audioCodecData];
    if (wasTransmitting != [player isTransmitting])
    {
      // its different, please redraw
      dispatch_async(dispatch_get_main_queue(), ^{
        [mainWindowOutlineView reloadItem:player];
      });
    }    
  });
}

- (void)idleAudioCheck:(NSTimer*)timer
{

}

- (void)graphPlayer:(TSAUGraphPlayer*)player bufferUnderunForInputStream:(unsigned int)index
{
  for (TSPlayer *player in [players allValues])
  {
    if ([player graphPlayerChannel] == index)
    {
      dispatch_async(dispatch_get_main_queue(), ^{
        [mainWindowOutlineView reloadItem:player];
      });
    }
  }
}

- (void)speakVoiceEvent:(NSString*)eventText alternativeText:(NSString*)alternativeText
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  if ([defaults boolForKey:@"SpeakChannelEvents"])
  {    
    NSString *voice = [defaults objectForKey:@"SpeechVoice"];
    NSSpeechSynthesizer *synth = [[[NSSpeechSynthesizer alloc] initWithVoice:voice] autorelease];
    
    [synth setRate:SPEECH_RATE];
    [synth setVolume:1.0];
    
    NSString *text = ([defaults boolForKey:@"UseTeamspeakPhrases"] ? eventText : alternativeText);
    [synth startSpeakingString:text];
  }
}

#pragma mark Hotkeys

- (void)hotkeyPressed:(TSHotkey*)hotkey
{
  NSDictionary *hotkeyDictionary = [hotkey context];
  
  switch ([[hotkeyDictionary objectForKey:@"HotkeyAction"] intValue])
  {
    case TSHotkeyPushToTalk:
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      [transmission setWhisperRecipients:nil];
      [transmission setIsWhispering:NO];
      [transmission setIsTransmitting:YES];
      [me setIsWhispering:NO];
      [me setIsTransmitting:YES];
      
      [self updatePlayerStatusView];
      [mainWindowOutlineView reloadItem:me];
      break;
    }
    case TSHotkeyCommandChannel:
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      if ([me isChannelCommander])
      {
        NSArray *channelCommanders = [[[players allValues] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(isChannelCommander == YES) AND (playerID != %d)", [teamspeakConnection clientID]]] valueForKeyPath:@"playerID"];
        
        [transmission setWhisperRecipients:channelCommanders];
        [transmission setIsWhispering:YES];
        [transmission setIsTransmitting:YES];
        [me setIsWhispering:YES];
        [me setIsTransmitting:YES];
        
        [self updatePlayerStatusView];
        [mainWindowOutlineView reloadItem:me];
      }
      break;
    }
    default:
      break;
  }
}

- (void)hotkeyReleased:(TSHotkey*)hotkey
{
  NSDictionary *hotkeyDictionary = [hotkey context];
  
  switch ([[hotkeyDictionary objectForKey:@"HotkeyAction"] intValue])
  {
    case TSHotkeyPushToTalk:
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      [transmission setIsTransmitting:NO];
      [me setIsTransmitting:NO];
      
      [self updatePlayerStatusView];
      [mainWindowOutlineView reloadItem:me];
      break;
    }
    case TSHotkeyCommandChannel:
    {
      TSPlayer *me = [players objectForKey:[NSNumber numberWithUnsignedInt:[teamspeakConnection clientID]]];
      [transmission setIsTransmitting:NO];
      [transmission setIsWhispering:NO];
      [transmission setWhisperRecipients:nil];
      [me setIsTransmitting:NO];
      
      [self updatePlayerStatusView];
      [mainWindowOutlineView reloadItem:me];
      break;
    }
    default:
      break;
  }
}

- (void)hotkeyMappingsChanged:(NSNotification*)notification
{
  [[TSHotkeyManager globalManager] removeAllHotkeys];
  
  NSArray *savedHotkeys = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"];
  
  for (NSDictionary *hotkeyDict in savedHotkeys)
  {
    int keycode = [[hotkeyDict objectForKey:@"HotkeyKeycode"] intValue];
    int action = [[hotkeyDict objectForKey:@"HotkeyAction"] intValue];
    
    if (keycode == 0 || keycode == -1 || action == -1)
    {
      continue;
    }
    
    TSHotkey *hotkey = [[[TSHotkey alloc] init] autorelease];
    [hotkey setHotkeyID:[[TSHotkeyManager globalManager] nextHotkeyID]];
    [hotkey setTarget:self];
    [hotkey setModifiers:[[hotkeyDict objectForKey:@"HotkeyModifiers"] unsignedIntValue]];
    [hotkey setKeyCode:keycode];
    [hotkey setContext:hotkeyDict];
    
    [[TSHotkeyManager globalManager] addHotkey:hotkey];
  }
}

#pragma mark Defaults

- (void)userDefaultsChanged:(NSNotification*)notification
{
  // check for some stuff here that we'd need to deal with when a user ticks buttons
  
  // requested small buttons, or not, reload the UI
  float rowHeight = ([[NSUserDefaults standardUserDefaults] boolForKey:@"SmallPlayers"] ? [TSPlayerCell smallCellHeight] : [TSPlayerCell cellHeight]);
  [mainWindowOutlineView setRowHeight:rowHeight];
  [mainWindowOutlineView reloadData];
}

#pragma mark NSAlert Sheet Delegate

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
  [[alert window] orderOut:self];
}

#pragma mark NSApplication Delegate

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
  if (isConnected)
  {
    [teamspeakConnection disconnect];
  }
}

//- (void)audioDecoderThread2
//{
//  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//  //TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Music/iTunes/iTunes Music/Level 70 Elite Tauren Chieftain/[non-album tracks]/02 Rogues Do It From Behind.mp3"];
//  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Desktop/Disturbed/Ten Thousand Fists/Disturbed/Ten Thousand Fists/01 - Ten Thousand Fists.mp3"];
//  
//  [speexEncoder setBitrate:25900];
//  MTCoreAudioStreamDescription *encoderDescription = [speexEncoder encoderStreamDescription];
//  [extraction setOutputStreamDescription:encoderDescription];
//  
//  unsigned int frameSize = [speexEncoder frameSize];
//  unsigned short packetCount = 0;
//  NSDate *releaseTime = [[NSDate distantPast] retain];
//  
//  while ([extraction position] < [extraction numOfFrames])
//  {
//    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
//    [speexEncoder resetEncoder];
//    int i;
//    
//    for (i=0; i<5; i++)
//    {
//      AudioBufferList *audio = [extraction extractNumberOfFrames:frameSize];
//      [speexEncoder encodeAudioBufferList:audio];
//      MTAudioBufferListDispose(audio);
//    }
//    
//    NSData *packetData = [speexEncoder encodedData];
//    
//    while ([[releaseTime laterDate:[NSDate date]] isEqual:releaseTime])
//    {
//      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
//    }
//    
//    [connection sendVoiceMessage:packetData frames:5 commanderChannel:NO packetCount:packetCount++ codec:SLCodecSpeex_25_9];
//    [releaseTime release];
//    releaseTime = [[NSDate dateWithTimeIntervalSinceNow:(double)((frameSize*5)/[encoderDescription sampleRate])] retain];
//    
//    [innerPool release];
//  }
//  
//  [pool release];
//}

@end

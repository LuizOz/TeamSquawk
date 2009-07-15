//
//  TSController.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <MTCoreAudio/MTCoreAudio.h>
#import <ExceptionHandling/ExceptionHandling.h>

#import "TSPreferencesController.h"
#import "TSController.h"
#import "TSAudioExtraction.h"
#import "TSPlayer.h"
#import "TSChannel.h"

void UncaughtExceptionHandler(NSException *exception)
{
  if ([exception callStackReturnAddresses]) 
  {
    NSTask *ls = [[NSTask alloc] init];
    NSString *pid = [[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]] stringValue];
    NSMutableArray *args = [NSMutableArray arrayWithCapacity:20];
    
    [args addObject:@"-p"];
    [args addObject:pid];
    [args addObjectsFromArray:[[exception callStackReturnAddresses] valueForKeyPath:@"stringValue"]];
    // Note: function addresses are separated by double spaces, not a single space.
    
    [ls setLaunchPath:@"/usr/bin/atos"];
    [ls setArguments:args];
    [ls launch];
    [ls release];
    
  } 
  else 
  {
    NSLog(@"No stack trace available.");
  }
}

@implementation TSController

- (void)awakeFromNib
{  
  NSSetUncaughtExceptionHandler(&UncaughtExceptionHandler);
  
  NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithFloat:1.0], @"InputGain",
                            [NSNumber numberWithFloat:1.0], @"OutputGain",
                            [NSArray array], @"RecentServers",
                            [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [NSNumber numberWithInt:TSHotkeyPushToTalk], @"HotkeyAction",
                                                       [NSNumber numberWithInt:-1], @"HotkeyKeycode",
                                                       [NSNumber numberWithInt:0], @"HotkeyModifiers",
                                                       nil], nil], @"Hotkeys",
                            nil];
  [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hotkeyMappingsChanged:) name:@"TSHotkeysDidChange" object:nil];
  [self hotkeyMappingsChanged:nil];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(recentServersChanged:) name:@"TSRecentServersDidChange" object:nil];
  [self setupRecentServersMenu];
  
  // setup the outline view
  [mainWindowOutlineView setDelegate:self];
  [mainWindowOutlineView setDataSource:self];
  [mainWindowOutlineView setDoubleAction:@selector(doubleClickOutlineView:)];
  [mainWindowOutlineView setTarget:self];
  //[mainWindowOutlineView setIndentationPerLevel:0.0];
  
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
  players = [[NSMutableDictionary alloc] init];
  channels = [[NSMutableDictionary alloc] init];
  flattenedChannels = [[NSMutableDictionary alloc] init];
  sortedChannels = nil;
  transmission = nil;
  graphPlayer = nil;
  
  // point NSApp here
  [NSApp setDelegate:self];
  
  // get the output device going
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputDeviceHasChanged:) name:@"TSOutputDeviceChanged" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputDeviceGainChanged:) name:@"TSOutputGainChanged" object:nil];
  
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
  if (item == nil)
  {
    return @"Foo";
  }
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
      currentFlags &= ~(TSPlayerIsMuted | TSPlayerHasMutedMicrophone);
      [teamspeakConnection changeStatusTo:currentFlags];
      break;
    }
    case TSControllerPlayerMuteMic:
    {
      currentFlags &= ~(TSPlayerIsMuted | TSPlayerHasMutedMicrophone);
      currentFlags |= TSPlayerHasMutedMicrophone;
      [teamspeakConnection changeStatusTo:currentFlags];
      break;
    }
    case TSControllerPlayerMute:
    {
      currentFlags &= ~(TSPlayerIsMuted | TSPlayerHasMutedMicrophone);
      currentFlags |= TSPlayerIsMuted;
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
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerActive] setState:(([player playerFlags] & (TSPlayerHasMutedMicrophone | TSPlayerIsMuted)) == 0)];
    [[statusMenu itemWithTag:TSControllerPlayerActive] setState:(([player playerFlags] & (TSPlayerHasMutedMicrophone | TSPlayerIsMuted)) == 0)];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerMuteMic] setState:[player hasMutedMicrophone]];
    [[statusMenu itemWithTag:TSControllerPlayerMuteMic] setState:[player hasMutedMicrophone]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerMute] setState:[player isMuted]];
    [[statusMenu itemWithTag:TSControllerPlayerMute] setState:[player isMuted]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerAway] setState:[player isAway]];
    [[statusMenu itemWithTag:TSControllerPlayerAway] setState:[player isAway]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerChannelCommander] setState:[player isChannelCommander]];
    [[statusMenu itemWithTag:TSControllerPlayerChannelCommander] setState:[player isChannelCommander]];
    
    [[[toolbarViewStatusPopupButton menu] itemWithTag:TSControllerPlayerBlockWhispers] setState:[player shouldBlockWhispers]];
    [[statusMenu itemWithTag:TSControllerPlayerBlockWhispers] setState:[player shouldBlockWhispers]];

    if ([player isMuted])
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
  [muteBothItem setTag:TSControllerPlayerMute];
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
  else if (([anItem action] == @selector(changeUserStatusAction:)) ||
           ([anItem action] == @selector(toggleAway:)) ||
           ([anItem action] == @selector(toggleChannelCommander:)) ||
           ([anItem action] == @selector(toggleBlockWhispers:)))
  {
    return isConnected;
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
    
  // do some UI sugar
  [self performSelectorOnMainThread:@selector(setupConnectedToolbarStatusPopupButton) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(updatePlayerStatusView) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(setupChannelsMenu) withObject:nil waitUntilDone:YES];
  [toolbarViewStatusPopupButton setTitle:currentServerAddress];
  
  // find what channel we ended up in
  for (TSChannel *channel in [flattenedChannels allValues])
  {
    for (TSPlayer *player in [channel players])
    {
      if ([player playerID] == [teamspeakConnection clientID])
      {
        currentChannel = [channel retain];
        break;
      }
    }
  }
  
  // double check
  if (!currentChannel)
  {
    [[NSException exceptionWithName:@"ChannelFail" reason:@"Teamspeak connection established but failed to find user in any channel." userInfo:nil] raise];
    return;
  }
  
  // setup transmission
  transmission = [[TSTransmission alloc] initWithConnection:teamspeakConnection codec:[currentChannel codec] voiceActivated:NO];
  
  [mainWindowOutlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];

  id item = nil;
  BOOL expandChildren = YES;
  
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[mainWindowOutlineView methodSignatureForSelector:@selector(expandItem:expandChildren:)]];
  [invocation setSelector:@selector(expandItem:expandChildren:)];
  [invocation setArgument:&item atIndex:2];
  [invocation setArgument:&expandChildren atIndex:3];
  
  [invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:mainWindowOutlineView waitUntilDone:YES];
}

- (void)connectionFailedToLogin:(SLConnection*)connection withError:(NSError*)error
{
  isConnected = NO;
  isConnecting = NO;
  [self performSelectorOnMainThread:@selector(setupDisconnectedToolbarStatusPopupButton) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(updatePlayerStatusView) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(setupChannelsMenu) withObject:nil waitUntilDone:YES];
  [mainWindowOutlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
  
  if (error)
  {
    [[NSAlert alertWithError:error] beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
  }
}

- (void)connectionDisconnected:(SLConnection*)connection withError:(NSError*)error
{
  isConnected = NO;
  isConnecting = NO;
  [self performSelectorOnMainThread:@selector(setupDisconnectedToolbarStatusPopupButton) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(updatePlayerStatusView) withObject:nil waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(setupChannelsMenu) withObject:nil waitUntilDone:YES];
  
  [sortedChannels release];
  sortedChannels = nil;
  
  [transmission setIsTransmitting:NO];
  [transmission close];
  [transmission release];
  transmission = nil;
  
  [flattenedChannels removeAllObjects];
  [channels removeAllObjects];
  [players removeAllObjects];
    
  [mainWindowOutlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];

  if (error)
  {
    [[NSAlert alertWithError:error] beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
  }
}

- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary
{
  NSArray *channelsDictionary = [channelDictionary objectForKey:@"SLChannels"];
  [flattenedChannels removeAllObjects];
  
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
      }
      [(TSChannel*)[flattenedChannels objectForKey:parentChannel] addSubChannel:channel];
    }
  }
  
  [sortedChannels autorelease];
  NSArray *sortDescriptors = [NSArray arrayWithObjects:
                              [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease],
                              [[[NSSortDescriptor alloc] initWithKey:@"channelName" ascending:YES] autorelease],
                              nil];
  sortedChannels = [[[channels allValues] sortedArrayUsingDescriptors:sortDescriptors] retain];
  
  [self performSelectorOnMainThread:@selector(setupChannelsMenu) withObject:nil waitUntilDone:YES];
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
    [player setPlayerID:[[playerDictionary objectForKey:@"SLPlayerID"] unsignedIntValue]];
    [player setChannelID:[[playerDictionary objectForKey:@"SLChannelID"] unsignedIntValue]];
    [player setLastVoicePacketCount:0];
    
    [players setObject:player forKey:[NSNumber numberWithUnsignedInt:[player playerID]]];
    
    TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
    [channel addPlayer:player];
  }
}

- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname extendedFlags:(unsigned int)extendedFlags
{
  TSPlayer *player = [[[TSPlayer alloc] init] autorelease];
  
  [player setPlayerID:playerID];
  [player setPlayerName:nickname];
  [player setChannelID:channelID];
  [player setPlayerFlags:0];
  [player setExtendedFlags:extendedFlags];
  
  [players setObject:player forKey:[NSNumber numberWithUnsignedInt:[player playerID]]];
  
  TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
  [channel addPlayer:player];

  BOOL reloadChildren = YES;
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[mainWindowOutlineView methodSignatureForSelector:@selector(reloadItem:reloadChildren:)]];
  [invocation setSelector:@selector(reloadItem:reloadChildren:)];
  [invocation setArgument:&channel atIndex:2];
  [invocation setArgument:&reloadChildren atIndex:3];
  [invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:mainWindowOutlineView waitUntilDone:YES];
  [mainWindowOutlineView performSelectorOnMainThread:@selector(expandItem:) withObject:channel waitUntilDone:YES];
}

- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
  
  [channel removePlayer:player];
  [players removeObjectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  
  BOOL reloadChildren = YES;
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[mainWindowOutlineView methodSignatureForSelector:@selector(reloadItem:reloadChildren:)]];
  [invocation setSelector:@selector(reloadItem:reloadChildren:)];
  [invocation setArgument:&channel atIndex:2];
  [invocation setArgument:&reloadChildren atIndex:3];
  [invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:mainWindowOutlineView waitUntilDone:YES];
}

- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  [player setPlayerFlags:flags];
  
  // if this is us, update some menu stuff
  if (playerID == [teamspeakConnection clientID])
  {
    [self performSelectorOnMainThread:@selector(updatePlayerStatusView) withObject:nil waitUntilDone:YES];
  }
  
  [mainWindowOutlineView performSelectorOnMainThread:@selector(reloadItem:) withObject:player waitUntilDone:YES];
}

- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *oldChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:fromChannelID]];
  TSChannel *newChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:toChannelID]];
  
  [oldChannel removePlayer:player];
  [newChannel addPlayer:player];
  
  if ([player playerID] == [teamspeakConnection clientID])
  {
    [currentChannel autorelease];
    currentChannel = [newChannel retain];
    [transmission setCodec:[currentChannel codec]];
  }
  
  BOOL reloadChildren = YES;
  NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[mainWindowOutlineView methodSignatureForSelector:@selector(reloadItem:reloadChildren:)]];
  [invocation setSelector:@selector(reloadItem:reloadChildren:)];
  [invocation setArgument:&oldChannel atIndex:2];
  [invocation setArgument:&reloadChildren atIndex:3];
  [invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:mainWindowOutlineView waitUntilDone:YES];
  [invocation setArgument:&newChannel atIndex:2];
  [invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:mainWindowOutlineView waitUntilDone:YES];
  
  [mainWindowOutlineView performSelectorOnMainThread:@selector(expandItem:) withObject:newChannel waitUntilDone:YES];
  [self performSelectorOnMainThread:@selector(setupChannelsMenu) withObject:nil waitUntilDone:YES];
}

#pragma mark Audio

- (void)outputDeviceHasChanged:(NSNotification*)notification
{
  // setup a new graph player and tell any TSPlayer objects we have a new one
  NSString *outputDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"OutputDeviceUID"];
  MTCoreAudioDevice *outputDevice = (outputDeviceUID ? [MTCoreAudioDevice deviceWithUID:outputDeviceUID] : [MTCoreAudioDevice defaultOutputDevice]);
  MTCoreAudioStreamDescription *outputDeviceFormat = [outputDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection];
  
  [graphPlayer close];
  [graphPlayer autorelease];
  graphPlayer = [[TSAUGraphPlayer alloc] initWithAudioDevice:outputDevice inputStreamDescription:outputDeviceFormat];
  
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

- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID commandChannel:(BOOL)command senderPacketCounter:(unsigned short)count
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  
  // out-of-band, I know, least messy way though
  [player setIsWhispering:NO];
  
  NSInvocationOperation *invocation = [[NSInvocationOperation alloc] initWithTarget:player selector:@selector(backgroundDecodeData:) object:[audioCodecData retain]];
  [[player decodeQueue] addOperation:invocation];
  [invocation release];

  [mainWindowOutlineView performSelectorOnMainThread:@selector(reloadItem:) withObject:player waitUntilDone:YES];
}

- (void)idleAudioCheck:(NSTimer*)timer
{
  [mainWindowOutlineView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
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

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

@interface TSController : NSObject {
  
  // user interface
  
  IBOutlet NSWindow *mainWindow;
  IBOutlet NSOutlineView *mainWindowOutlineView;
  
  // state
  
  BOOL isConnected;
  
  // background stuff
  
  SLConnection *teamspeakConnection;
  
  TSCoreAudioPlayer *player;
  TSAudioConverter *converter;
  
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


#pragma mark Menu Items

- (IBAction)connectMenuAction:(id)sender;
- (IBAction)disconnectMenuAction:(id)sender;

#pragma mark Menu Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem;

#pragma mark Old Shit

- (void)awakeFromNib2;
- (void)connectionFinishedLogin:(SLConnection*)connection;
- (void)audioPlayerThread;
- (void)audioDecoderThread;
- (void)audioDecoderThread2;
- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID senderPacketCounter:(unsigned short)count;


@end

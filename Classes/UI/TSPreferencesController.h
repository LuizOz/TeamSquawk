//
//  TSPreferencesController.h
//  TeamSquawk
//
//  Created by Matt Wright on 09/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DBPrefsWindowController.h"
#import <MTCoreAudio/MTCoreAudio.h>
#import "SRCommon.h"
#import "SRRecorderControl.h"
#import "TSAudioConverter.h"
#import "SpeexEncoder.h"
#import "SpeexDecoder.h"

typedef enum {
  TSHotkeyNone = -1,
  TSHotkeyPushToTalk = 1,
  TSHotkeyCommandChannel = 2,
} TSHotkeyActions;

@interface TSPreferencesController : DBPrefsWindowController {
  IBOutlet NSView *generalPreferencesView;
  IBOutlet NSView *soundPreferencesView;
  IBOutlet NSView *hotkeysPreferencesView;
  
  // sound
  IBOutlet NSPopUpButton *inputSoundDeviceButton;
  IBOutlet NSPopUpButton *outputSoundDeviceButton;
  IBOutlet NSLevelIndicator *inputLevelIndicator;
  IBOutlet NSSlider *inputSlider;
  IBOutlet NSSlider *outputSlider;
  IBOutlet NSPopUpButton *loopbackCodecButton;
  IBOutlet NSButton *loopbackSoundTestButton;
  
  // input device
  MTCoreAudioDevice *inputPreviewDevice;
  MTCoreAudioDevice *outputPreviewDevice;
  MTByteBuffer *preEncodingBuffer;
  MTAudioBuffer *postDecodingBuffer;
  TSAudioConverter *inputConverter;
  TSAudioConverter *outputConverter;
  SpeexEncoder *encoder;
  SpeexDecoder *decoder;
  float inputGain;
  float outputGain;
  
  // hotkeys
  IBOutlet NSTableView *hotkeyTableView;
  IBOutlet NSWindow *hotkeyEditorWindow;
  IBOutlet NSPopUpButton *hotkeyEditorActionPopup;
  IBOutlet SRRecorderControl *hotkeyEditorRecorder;
}

- (void)setupToolbar;
- (void)setupSoundPreferences;
- (void)setupHotkeyPreferences;

#pragma mark Sound Toolbar

- (OSStatus)ioCycleForDevice:(MTCoreAudioDevice *)theDevice timeStamp:(const AudioTimeStamp *)inNow inputData:(const AudioBufferList *)inInputData inputTime:(const AudioTimeStamp *)inInputTime outputData:(AudioBufferList *)outOutputData outputTime:(const AudioTimeStamp *)inOutputTime clientData:(void *)inClientData;
- (IBAction)inputDeviceButtonChange:(id)sender;
- (IBAction)inputSliderChange:(id)sender;
- (IBAction)outputSliderChange:(id)sender;
- (IBAction)outputDeviceButtonChange:(id)sender;
- (IBAction)loopbackSoundTestButtonChange:(id)sender;
- (IBAction)loopbackCodecButtonChange:(id)sender;
- (void)windowWillClose:(NSNotification*)notification;

#pragma mark Hotkey Toolbar

- (IBAction)addHotkeyAction:(id)sender;
- (IBAction)deleteHotkeyAction:(id)sender;
- (IBAction)doubleClickHotkeyTableView:(id)sender;
- (IBAction)hotkeyEditorButtonAction:(id)sender;
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;;
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

@end

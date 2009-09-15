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
  IBOutlet NSView *serversPreferencesView;
  IBOutlet NSView *soundPreferencesView;
  IBOutlet NSView *hotkeysPreferencesView;
  
  // general
  IBOutlet NSPopUpButton *generalVoicesPopupButton;
  
  // servers
  IBOutlet NSTableView *serversTableView;
  IBOutlet NSButton *serversDeleteServerButton;
  IBOutlet NSWindow *connectionEditorWindow;
  IBOutlet NSTextField *connectionEditorServerTextField;
  IBOutlet NSTextField *connectionEditorNicknameTextField;
  IBOutlet NSMatrix *connectionEditorTypeMatrix;
  IBOutlet NSTextField *connectionEditorUsernameTextField;
  IBOutlet NSTextField *connectionEditorPasswordTextField;
  
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
  IBOutlet NSButton *hotkeyDeleteHotkeyButton;
}

- (void)setupToolbar;
- (void)setupGeneralPreferences;
- (void)setupServersPreferences;
- (void)setupSoundPreferences;
- (void)setupHotkeyPreferences;

#pragma mark General Toolbar

- (IBAction)voicesPopupButtonAction:(id)sender;

#pragma mark Servers Toolbar

- (IBAction)addServerAction:(id)sender;
- (IBAction)deleteServerAction:(id)sender;
- (IBAction)doubleClickServersTableView:(id)sender;
- (IBAction)connectionEditorWindowUpdateType:(id)sender;
- (IBAction)connectionEditorWindowOKAction:(id)sender;
- (IBAction)connectionEditorWindowCancelAction:(id)sender;
- (void)connectionEditorSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;;
- (NSInteger)serversNumberOfRowsInTableView:(NSTableView *)aTableView;
- (id)serversTableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (void)serversTableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (BOOL)serversTableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)serversTableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)serversTableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;
- (void)serversTableViewSelectionDidChange:(NSNotification *)aNotification;

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
- (NSInteger)hotkeysNumberOfRowsInTableView:(NSTableView*)aTableview;
- (id)hotkeysTableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (void)hotkeysTableViewSelectionDidChange:(NSNotification *)aNotification;

#pragma mark Shared Delegate Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard;
- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op;
- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation;

@end

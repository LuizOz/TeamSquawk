//
//  TSPreferencesController.m
//  TeamSquawk
//
//  Created by Matt Wright on 09/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSPreferencesController.h"

@implementation TSPreferencesController

- (void)setupToolbar
{
  [self addView:soundPreferencesView label:@"Sound" image:[NSImage imageNamed:@"Mic"]];
  [self setupSoundPreferences];
  
  [self addView:hotkeysPreferencesView label:@"HotKeys" image:[NSImage imageNamed:@"Keyboard"]];
  [self setupHotkeyPreferences];
}

- (void)setupSoundPreferences
{
  // make sure we know about the preference window closing
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:[self window]];
  
  [inputLevelIndicator setFloatValue:0.0];
  
  [inputSoundDeviceButton removeAllItems];
  [outputSoundDeviceButton removeAllItems];
  
  for (MTCoreAudioDevice *device in [MTCoreAudioDevice allDevices])
  {
    if ([[device streamsForDirection:kMTCoreAudioDevicePlaybackDirection] count] > 0)
    {
      [[[outputSoundDeviceButton menu] addItemWithTitle:[device deviceName] action:nil keyEquivalent:@""] setRepresentedObject:device];
    }
    
    if ([[device streamsForDirection:kMTCoreAudioDeviceRecordDirection] count] > 0)
    {
      [[[inputSoundDeviceButton menu] addItemWithTitle:[device deviceName] action:nil keyEquivalent:@""] setRepresentedObject:device];
    }
  }
  
  // load up the preferred device if we've got one
  NSString *prefsDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"InputDeviceUID"];
  MTCoreAudioDevice *preferredInputDevice = (prefsDeviceUID ? [MTCoreAudioDevice deviceWithUID:prefsDeviceUID] : [MTCoreAudioDevice defaultInputDevice]);
  if (!preferredInputDevice)
  {
    preferredInputDevice = [MTCoreAudioDevice defaultInputDevice];
  }
  
  prefsDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"OutputDeviceUID"];
  MTCoreAudioDevice *preferredOutputDevice = (prefsDeviceUID ? [MTCoreAudioDevice deviceWithUID:prefsDeviceUID] : [MTCoreAudioDevice defaultOutputDevice]);
  if (!preferredOutputDevice)
  {
    preferredOutputDevice = [MTCoreAudioDevice defaultOutputDevice];
  }
  
  [inputSoundDeviceButton selectItemAtIndex:[inputSoundDeviceButton indexOfItemWithRepresentedObject:preferredInputDevice]];
  [outputSoundDeviceButton selectItemAtIndex:[outputSoundDeviceButton indexOfItemWithRepresentedObject:preferredOutputDevice]];
  
  // setup the selected device for input preview
  inputPreviewDevice = [(MTCoreAudioDevice*)[[inputSoundDeviceButton selectedItem] representedObject] retain];
  
  // point the device here so we can take a look at its data
  [inputPreviewDevice setIOTarget:self withSelector:@selector(ioCycleForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:) withClientData:nil];
  
  // set the slider with the current volume
  [inputSlider setFloatValue:[inputPreviewDevice volumeForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection]];
  
  // start running
  [inputPreviewDevice deviceStart];
  [inputPreviewDevice setDevicePaused:NO];
}

- (void)setupHotkeyPreferences
{
  [hotkeyTableView setDataSource:self];
  [hotkeyTableView setDelegate:self];
  [hotkeyTableView setTarget:self];
  [hotkeyTableView setDoubleAction:@selector(doubleClickHotkeyTableView:)];
  
  [hotkeyTableView reloadData];
}

#pragma mark Sound Toolbar

- (OSStatus)ioCycleForDevice:(MTCoreAudioDevice *)theDevice
                    timeStamp:(const AudioTimeStamp *)inNow
                    inputData:(const AudioBufferList *)inInputData
                    inputTime:(const AudioTimeStamp *)inInputTime
                   outputData:(AudioBufferList *)outOutputData
                   outputTime:(const AudioTimeStamp *)inOutputTime
                   clientData:(void *)inClientData
{
  // input is in input data
  unsigned long i = 0, frames = inInputData->mBuffers[0].mDataByteSize / sizeof(float);
  float level = 0;
  float *data = inInputData->mBuffers[0].mData;
  
  for (i=0; i<frames; i++)
  {
    level += fabs(data[i]);
  }
  [inputLevelIndicator setFloatValue:10.0 * (level / (float)frames)];
  
  return noErr;
}

- (IBAction)inputDeviceButtonChange:(id)sender
{
  [inputPreviewDevice deviceStop];
  [inputPreviewDevice removeIOProc];
  [inputPreviewDevice release];
  
  inputPreviewDevice = [(MTCoreAudioDevice*)[[inputSoundDeviceButton selectedItem] representedObject] retain];
  [inputPreviewDevice setIOTarget:self withSelector:@selector(ioCycleForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:) withClientData:nil];
  [inputPreviewDevice deviceStart];
  [inputPreviewDevice setDevicePaused:NO];
  
  [[NSUserDefaults standardUserDefaults] setObject:[inputPreviewDevice deviceUID] forKey:@"InputDeviceUID"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"TSInputDeviceChanged" object:nil];
}

- (IBAction)inputSliderChange:(id)sender
{
  [inputPreviewDevice setVolume:[inputSlider floatValue] forChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection];
}

- (IBAction)outputDeviceButtonChange:(id)sender
{
  MTCoreAudioDevice *outputDevice = [[outputSoundDeviceButton selectedItem] representedObject];
  
  [[NSUserDefaults standardUserDefaults] setObject:[outputDevice deviceUID] forKey:@"OutputDeviceUID"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"TSOutputDeviceChanged" object:nil];
}

- (void)windowWillClose:(NSNotification*)notification
{
  [inputPreviewDevice deviceStop];
  [inputPreviewDevice removeIOProc];
  [inputPreviewDevice release];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[self window]];
}

#pragma mark Hotkey Toolbar

- (IBAction)addHotkeyAction:(id)sender
{
  
}

- (IBAction)deleteHotkeyAction:(id)sender
{
  
}

- (IBAction)doubleClickHotkeyTableView:(id)sender
{
  [hotkeyEditorRecorder setRequiredFlags:0];
  [hotkeyEditorRecorder setAllowedFlags:NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask];
  [hotkeyEditorRecorder setCanCaptureGlobalHotKeys:YES];
  [hotkeyEditorRecorder setAllowsKeyOnly:YES escapeKeysRecord:NO];
  
  [NSApp beginSheet:hotkeyEditorWindow
     modalForWindow:[self window]
      modalDelegate:self 
     didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
        contextInfo:nil];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
  [sheet orderOut:self];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  NSArray *hotkeys = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"];
  NSDictionary *hotkeyDict = [hotkeys objectAtIndex:rowIndex];
  
  if ([[aTableColumn identifier] isEqual:@"Key"])
  {
    int keycode = [[hotkeyDict objectForKey:@"HotkeyKeycode"] intValue];
    int modifiers = [[hotkeyDict objectForKey:@"HotkeyModifiers"] intValue];
    
    if (keycode == 0)
    {
      return @"<not assigned>";
    }
    else
    {
      return SRStringForCarbonModifierFlagsAndKeyCode(modifiers, keycode);
    }
  }
  else if ([[aTableColumn identifier] isEqual:@"Description"])
  {
    int action = [[hotkeyDict objectForKey:@"HotkeyAction"] intValue];
    
    switch (action)
    {
      case TSHotkeyPushToTalk:
        return @"Push to Talk";
      default:
        return @"Unknown";
    }
  }
  return nil;
}

@end

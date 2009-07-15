//
//  TSPreferencesController.m
//  TeamSquawk
//
//  Created by Matt Wright on 09/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSPreferencesController.h"
#import "SLConnection.h"

NSString *TSPreferencesServersDragType = @"TSPreferencesServersDragType";

@implementation TSPreferencesController

- (void)setupToolbar
{
  [self addView:serversPreferencesView label:@"Servers" image:[NSImage imageNamed:@"Servers"]];
  [self setupServersPreferences];
  
  [self addView:soundPreferencesView label:@"Sound" image:[NSImage imageNamed:@"Mic"]];
  [self setupSoundPreferences];
  
  [self addView:hotkeysPreferencesView label:@"HotKeys" image:[NSImage imageNamed:@"Keyboard"]];
  [self setupHotkeyPreferences];
}

- (void)setupServersPreferences
{
  [serversTableView setDataSource:self];
  [serversTableView setDelegate:self];
  [serversTableView setTarget:self];
  [serversTableView setDoubleAction:@selector(doubleClickServersTableView:)];
  
  [serversTableView registerForDraggedTypes:[NSArray arrayWithObjects:TSPreferencesServersDragType, nil]];
  
  [serversTableView reloadData];
}

- (void)setupSoundPreferences
{
  // make sure we know about the preference window closing
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:[self window]];
  
  [inputLevelIndicator setFloatValue:0.0];
  
  [loopbackSoundTestButton setState:NO];
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
  inputGain = [[[NSUserDefaults standardUserDefaults] objectForKey:@"InputGain"] floatValue];
  outputGain = [[[NSUserDefaults standardUserDefaults] objectForKey:@"OutputGain"] floatValue];
  [inputSlider setFloatValue:inputGain];
  [outputSlider setFloatValue:outputGain];
  
  // setup each codec menu item
  [loopbackCodecButton removeAllItems];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 3.4kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_3_4];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 5.2kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_5_2];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 7.2kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_7_2];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 9.3kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_9_3];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 12.4kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_12_3];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 16.3kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_16_3];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 19.5kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_19_5];
  [[[loopbackCodecButton menu] addItemWithTitle:@"Speex 25.9kbit" action:nil keyEquivalent:@""] setTag:SLCodecSpeex_25_9];
  [loopbackCodecButton selectItemWithTag:SLCodecSpeex_25_9];
  
  // setup the speex encoder and decoder
  encoder = [[SpeexEncoder alloc] initWithMode:SpeexEncodeWideBandMode];
  decoder = [[SpeexDecoder alloc] initWithMode:SpeexDecodeWideBandMode];
  [encoder setBitrate:[SLConnection bitrateForCodec:[loopbackCodecButton selectedTag]]];
  [encoder setInputSampleRate:(unsigned int)([[inputPreviewDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] sampleRate])];
  
  // setup the IO converters  
  inputConverter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[inputPreviewDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] andOutputStreamDescription:[encoder encoderStreamDescription]];
  outputConverter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[decoder decoderStreamDescription] andOutputStreamDescription:[(MTCoreAudioDevice*)[[outputSoundDeviceButton selectedItem] representedObject] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection]];
  
  // get the buffers made
  preEncodingBuffer = [[MTByteBuffer alloc] initWithCapacity:(([encoder frameSize] * sizeof(short) * [encoder inputSampleRate]) / [encoder sampleRate]) * 5];
  // a bit big but the data shouldn't be more than the this
  postDecodingBuffer = [[MTAudioBuffer alloc] initWithCapacityFrames:44100 channels:1];
  
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

#pragma mark Servers Toolbar

- (IBAction)addServerAction:(id)sender
{
  [connectionEditorServerTextField setStringValue:@""];
  [connectionEditorNicknameTextField setStringValue:@""];
  [connectionEditorTypeMatrix selectCellWithTag:1];
  [connectionEditorUsernameTextField setStringValue:@""];
  [connectionEditorPasswordTextField setStringValue:@""];
  
  [self connectionEditorWindowUpdateType:self];
  
  [NSApp beginSheet:connectionEditorWindow
     modalForWindow:[self window]
      modalDelegate:self
     didEndSelector:@selector(connectionEditorSheetDidEnd:returnCode:contextInfo:)
        contextInfo:nil];
}

- (IBAction)deleteServerAction:(id)sender
{
  NSMutableArray *recentServers = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"] mutableCopy];
  int row = [serversTableView selectedRow];      

  [recentServers removeObjectAtIndex:row];
  [[NSUserDefaults standardUserDefaults] setObject:recentServers forKey:@"RecentServers"];
  [[NSUserDefaults standardUserDefaults] synchronize];

  [[NSNotificationCenter defaultCenter] postNotificationName:@"TSRecentServersDidChange" object:nil];
  [serversTableView reloadData];

  [recentServers release];
}

- (IBAction)doubleClickServersTableView:(id)sender
{
  if ([serversTableView selectedRow] > -1)
  {
    NSArray *recentServers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"];
    NSDictionary *server = [recentServers objectAtIndex:[serversTableView selectedRow]];
    
    [connectionEditorServerTextField setStringValue:[server objectForKey:@"ServerAddress"]];
    [connectionEditorNicknameTextField setStringValue:[server objectForKey:@"Nickname"]];
    [connectionEditorTypeMatrix selectCellWithTag:([[server objectForKey:@"Registered"] boolValue] ? 0 : 1)];
    [connectionEditorUsernameTextField setStringValue:([server objectForKey:@"Username"] ? [server objectForKey:@"Username"] : @"")];
    [connectionEditorPasswordTextField setStringValue:[server objectForKey:@"Password"]];
    
    [self connectionEditorWindowUpdateType:self];
    
    [NSApp beginSheet:connectionEditorWindow
       modalForWindow:[self window]
        modalDelegate:self
       didEndSelector:@selector(connectionEditorSheetDidEnd:returnCode:contextInfo:)
          contextInfo:server];
  }
}

- (IBAction)connectionEditorWindowUpdateType:(id)sender
{
  [connectionEditorUsernameTextField setEnabled:([[connectionEditorTypeMatrix selectedCell] tag] == 0)];
}

- (IBAction)connectionEditorWindowOKAction:(id)sender
{
  [NSApp endSheet:connectionEditorWindow returnCode:NSOKButton];
}

- (IBAction)connectionEditorWindowCancelAction:(id)sender
{
  [NSApp endSheet:connectionEditorWindow returnCode:NSCancelButton];
}

- (void)connectionEditorSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
  [sheet orderOut:self];
  
  if (returnCode == NSOKButton)
  {
    NSDictionary *server = [NSDictionary dictionaryWithObjectsAndKeys:
                            [connectionEditorServerTextField stringValue], @"ServerAddress",
                            [connectionEditorNicknameTextField stringValue], @"Nickname",
                            [NSNumber numberWithInt:8767], @"Port",
                            [NSNumber numberWithBool:([[connectionEditorTypeMatrix selectedCell] tag] == 0)], @"Registered",
                            [connectionEditorPasswordTextField stringValue], @"Password",
                            // should always come last, then nil username will stop the array
                            (([[connectionEditorTypeMatrix selectedCell] tag] == 0) ? [connectionEditorUsernameTextField stringValue] : nil), @"Username",
                            nil];

    NSMutableArray *recentServers = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"] mutableCopy];
    
    // if we've got a contextinfo then we were editing. not creating.
    if (contextInfo)
    {
      int row = [serversTableView selectedRow];      
      [recentServers replaceObjectAtIndex:row withObject:server];
      [[NSUserDefaults standardUserDefaults] setObject:recentServers forKey:@"RecentServers"];
    }
    else
    {
      [recentServers addObject:server];
      [[NSUserDefaults standardUserDefaults] setObject:recentServers forKey:@"RecentServers"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"TSRecentServersDidChange" object:nil];
    [serversTableView reloadData];
    
    [recentServers release];
  }
}

- (NSInteger)serversNumberOfRowsInTableView:(NSTableView *)aTableView
{
  return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"] count];
}

- (id)serversTableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  NSArray *recentServers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"];
  NSDictionary *server = [recentServers objectAtIndex:rowIndex];
  
  return [NSString stringWithFormat:@"%@ @ %@", [server objectForKey:@"Nickname"], [server objectForKey:@"ServerAddress"]];
}

- (void)serversTableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  NSArray *recentServers = [[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"];
  NSDictionary *server = [recentServers objectAtIndex:rowIndex];

  [(NSCell*)aCell setImage:([[server objectForKey:@"Registered"] boolValue] ? [NSImage imageNamed:@"Blue"] : [NSImage imageNamed:@"Green"])];
}

- (BOOL)serversTableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
  [pboard declareTypes:[NSArray arrayWithObjects:TSPreferencesServersDragType, nil] owner:self];
  [pboard setData:data forType:TSPreferencesServersDragType];
  return YES;
}

- (NSDragOperation)serversTableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
  if ([[[info draggingPasteboard] types] containsObject:TSPreferencesServersDragType] && (op == NSTableViewDropAbove))
  {
    return YES;
  }
  return NO;
}

- (BOOL)serversTableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  if ([[[info draggingPasteboard] types] containsObject:TSPreferencesServersDragType])
  {
    NSIndexSet *indexes = [NSKeyedUnarchiver unarchiveObjectWithData:[[info draggingPasteboard] dataForType:TSPreferencesServersDragType]];
    if ([indexes count] > 1)
    {
      return NO;
    }
    
    int rowIndex = [indexes firstIndex];
    NSMutableArray *recentServers = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"] mutableCopy];
    
    // if we're about to remove a row thats below this one, we need to change the index
    if (row > rowIndex)
    {
      row--;
    }
    
    NSDictionary *interestingRow = [[recentServers objectAtIndex:rowIndex] retain];
    [recentServers removeObject:interestingRow];
    [recentServers insertObject:interestingRow atIndex:row];
    
    [[NSUserDefaults standardUserDefaults] setObject:recentServers forKey:@"RecentServers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [interestingRow release];
    [recentServers release];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TSRecentServersDidChange" object:nil];
    [serversTableView reloadData];
    
    return YES;
  }
  
  return NO;
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
  if ([theDevice isEqual:inputPreviewDevice])
  {
    // input is in input data
    unsigned long i = 0, frames = inInputData->mBuffers[0].mDataByteSize / sizeof(float);
    float level = 0;
    float *data = inInputData->mBuffers[0].mData;
    
    for (i=0; i<frames; i++)
    {
      // apply the input gain
      data[i] *= inputGain;
      level += fabs(data[i]);
    }
    [inputLevelIndicator setFloatValue:10.0 * (level / (float)frames)];
    
    if (outputPreviewDevice)
    {
      NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
      
      AudioBufferList *resampledInputAudio = [inputConverter audioBufferListByConvertingList:(AudioBufferList*)inInputData framesConverted:(unsigned int*)&frames];
      unsigned int bufferedBytes = [preEncodingBuffer writeFromBytes:resampledInputAudio->mBuffers[0].mData count:resampledInputAudio->mBuffers[0].mDataByteSize waitForRoom:NO];
      if (bufferedBytes < resampledInputAudio->mBuffers[0].mDataByteSize)
      {
        // encode it up and put it in the bufffffer
        unsigned int encodedPackets = 0, frameBytes = (([encoder frameSize] * sizeof(short) * [encoder inputSampleRate]) / [encoder sampleRate]);
        AudioBufferList *compressionBuffer = MTAudioBufferListNew(1, frameBytes / 4, NO);
        [encoder resetEncoder];
        
        while ([preEncodingBuffer count] >= frameBytes)
        {
          [preEncodingBuffer readToBytes:compressionBuffer->mBuffers[0].mData count:frameBytes waitForData:NO];
          [encoder encodeAudioBufferList:compressionBuffer];
          encodedPackets++;
        }
        
        NSData *encodedData = [encoder encodedData];
        unsigned int decodedFrames = 0;
        NSData *decodedData = [decoder audioDataForEncodedData:encodedData framesDecoded:&decodedFrames];
        
        AudioBufferList *compressedAudioList = MTAudioBufferListNew(1, [decodedData length] / sizeof(float), NO);
        compressedAudioList->mBuffers[0].mDataByteSize = [decodedData length];
        [decodedData getBytes:compressedAudioList->mBuffers[0].mData length:[decodedData length]];
        
        AudioBufferList *uncompressedAudioList = [outputConverter audioBufferListByConvertingList:compressedAudioList framesConverted:&decodedFrames];
        [postDecodingBuffer writeFromAudioBufferList:uncompressedAudioList maxFrames:decodedFrames rateScalar:1.0f waitForRoom:NO];
        MTAudioBufferListDispose(uncompressedAudioList);
        MTAudioBufferListDispose(compressedAudioList);
        
        [preEncodingBuffer writeFromBytes:(resampledInputAudio->mBuffers[0].mData + bufferedBytes) count:(resampledInputAudio->mBuffers[0].mDataByteSize - bufferedBytes) waitForRoom:NO];
        MTAudioBufferListDispose(compressionBuffer);
      }
      [pool release];
    }
  }
  
  if ([theDevice isEqual:outputPreviewDevice])
  {
    unsigned long i, frames = [postDecodingBuffer readToAudioBufferList:outOutputData maxFrames:[postDecodingBuffer count] waitForData:NO];
    
    for (i = 0; i<frames; i++)
    {
      ((float*)(outOutputData->mBuffers[0].mData))[i] *= outputGain;
    }
  }
  
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
  inputGain = [inputSlider floatValue];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:inputGain] forKey:@"InputGain"];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (IBAction)outputSliderChange:(id)sender
{
  outputGain = [outputSlider floatValue];
  [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithFloat:outputGain] forKey:@"OutputGain"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"TSOutputGainChanged" object:nil];
}

- (IBAction)outputDeviceButtonChange:(id)sender
{
  MTCoreAudioDevice *outputDevice = [[outputSoundDeviceButton selectedItem] representedObject];
  
  [[NSUserDefaults standardUserDefaults] setObject:[outputDevice deviceUID] forKey:@"OutputDeviceUID"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [[NSNotificationCenter defaultCenter] postNotificationName:@"TSOutputDeviceChanged" object:nil];
}

- (IBAction)loopbackSoundTestButtonChange:(id)sender
{
  if ([loopbackSoundTestButton state] == NSOnState)
  {
    outputPreviewDevice = [(MTCoreAudioDevice*)[[outputSoundDeviceButton selectedItem] representedObject] retain];
    [outputPreviewDevice setIOTarget:self withSelector:@selector(ioCycleForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:) withClientData:nil];
    [outputPreviewDevice deviceStart];
    [outputPreviewDevice setDevicePaused:NO];
  }
  else if ([loopbackSoundTestButton state] == NSOffState)
  {
    [outputPreviewDevice deviceStop];
    [outputPreviewDevice removeIOTarget];
    [outputPreviewDevice release];
    outputPreviewDevice = nil;
  }
}

- (IBAction)loopbackCodecButtonChange:(id)sender
{
  [encoder setBitrate:[SLConnection bitrateForCodec:[loopbackCodecButton selectedTag]]];
}

- (void)windowWillClose:(NSNotification*)notification
{
  [inputPreviewDevice deviceStop];
  [inputPreviewDevice removeIOTarget];
  [inputPreviewDevice release];
  
  if (outputPreviewDevice)
  {
    [outputPreviewDevice deviceStop];
    [outputPreviewDevice removeIOTarget];
    [outputPreviewDevice release];
    outputPreviewDevice = nil;
  }
  
  [inputConverter release];
  [outputConverter release];
  [preEncodingBuffer release];
  [postDecodingBuffer release];
  
  [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:[self window]];
}

#pragma mark Hotkey Toolbar

- (IBAction)addHotkeyAction:(id)sender
{
  NSDictionary *newHotkey = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInt:TSHotkeyNone], @"HotkeyAction",
                             [NSNumber numberWithInt:-1], @"HotkeyKeycode",
                             [NSNumber numberWithInt:0], @"HotkeyModifiers",
                             nil];
  NSArray *hotkeys = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"];
  hotkeys = [hotkeys arrayByAddingObject:newHotkey];
  
  [[NSUserDefaults standardUserDefaults] setObject:hotkeys forKey:@"Hotkeys"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  
  [hotkeyTableView reloadData];
}

- (IBAction)deleteHotkeyAction:(id)sender
{
  
}

- (IBAction)doubleClickHotkeyTableView:(id)sender
{
  int row = [hotkeyTableView selectedRow];
  
  if (row > -1)
  {
    [hotkeyEditorRecorder setRequiredFlags:0];
    [hotkeyEditorRecorder setAllowedFlags:NSCommandKeyMask|NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask];
    [hotkeyEditorRecorder setCanCaptureGlobalHotKeys:YES];
    [hotkeyEditorRecorder setAllowsKeyOnly:YES escapeKeysRecord:NO];
    
    // setup the hotkey editor window dropdown choices
    [hotkeyEditorActionPopup removeAllItems];
    [[[hotkeyEditorActionPopup menu] addItemWithTitle:@"No Action" action:nil keyEquivalent:@""] setTag:TSHotkeyNone];
    [[[hotkeyEditorActionPopup menu] addItemWithTitle:@"Push to Talk" action:nil keyEquivalent:@""] setTag:TSHotkeyPushToTalk];
    [[[hotkeyEditorActionPopup menu] addItemWithTitle:@"Talk on Commander Channel" action:nil keyEquivalent:@""] setTag:TSHotkeyCommandChannel];
    
    NSDictionary *hotkeyDict = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"] objectAtIndex:row];
    unsigned int modifiers = [[hotkeyDict objectForKey:@"HotkeyModifiers"] unsignedIntValue];
    int tag = [[hotkeyDict objectForKey:@"HotkeyAction"] unsignedIntValue];
    int keycode = [[hotkeyDict objectForKey:@"HotkeyKeycode"] intValue];
    
    KeyCombo combo = { [hotkeyEditorRecorder carbonToCocoaFlags:modifiers], keycode };
    
    [hotkeyEditorActionPopup selectItemWithTag:tag];
    [hotkeyEditorRecorder setKeyCombo:combo];
    
    [NSApp beginSheet:hotkeyEditorWindow
       modalForWindow:[self window]
        modalDelegate:self 
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
          contextInfo:(void*)row];
  }
}

- (IBAction)hotkeyEditorButtonAction:(id)sender
{
  [NSApp endSheet:hotkeyEditorWindow returnCode:[sender tag]];
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
  [sheet orderOut:self];
  
  if (returnCode == NSOKButton)
  {
    int row = (int)contextInfo;
    NSMutableArray *hotkeys = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"] mutableCopy];
    
    int keycode = [hotkeyEditorRecorder keyCombo].code;
    unsigned int modifiers = [hotkeyEditorRecorder cocoaToCarbonFlags:[hotkeyEditorRecorder keyCombo].flags];
    
    // right, setup a new dictionary for this entry
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithInt:[hotkeyEditorActionPopup selectedTag]], @"HotkeyAction",
                          [NSNumber numberWithInt:keycode], @"HotkeyKeycode",
                          [NSNumber numberWithUnsignedInt:modifiers], @"HotkeyModifiers",
                          nil];
    [hotkeys replaceObjectAtIndex:row withObject:dict];
    [[NSUserDefaults standardUserDefaults] setObject:hotkeys forKey:@"Hotkeys"];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TSHotkeysDidChange" object:nil];
  }
}

- (NSInteger)hotkeysNumberOfRowsInTableView:(NSTableView*)aTableview
{
  return [[[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"] count];

}

- (id)hotkeysTableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  NSArray *hotkeys = [[NSUserDefaults standardUserDefaults] arrayForKey:@"Hotkeys"];
  NSDictionary *hotkeyDict = [hotkeys objectAtIndex:rowIndex];
  
  if ([[aTableColumn identifier] isEqual:@"Key"])
  {
    int keycode = [[hotkeyDict objectForKey:@"HotkeyKeycode"] intValue];
    int modifiers = [[hotkeyDict objectForKey:@"HotkeyModifiers"] intValue];
    
    if (keycode == 0 || keycode == -1)
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
      case TSHotkeyNone:
        return @"No Action Assigned";
      case TSHotkeyPushToTalk:
        return @"Push to Talk";
      case TSHotkeyCommandChannel:
        return @"Talk on Commander Channel";
      default:
        return @"Unknown";
    }
  }
  return nil;
}

#pragma mark Shared Delegate Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if ([aTableView isEqualTo:hotkeyTableView])
  {
    return [self hotkeysNumberOfRowsInTableView:aTableView];
  }
  else if ([aTableView isEqualTo:serversTableView])
  {
    return [self serversNumberOfRowsInTableView:aTableView];
  }
  return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  if ([aTableView isEqualTo:hotkeyTableView])
  {
    return [self hotkeysTableView:aTableView objectValueForTableColumn:aTableColumn row:rowIndex];
  }
  else if ([aTableView isEqualTo:serversTableView])
  {
    return [self serversTableView:aTableView objectValueForTableColumn:aTableColumn row:rowIndex];
  }
  return nil;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  if ([aTableView isEqualTo:serversTableView])
  {
    [self serversTableView:aTableView willDisplayCell:aCell forTableColumn:aTableColumn row:rowIndex];
  }
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
  if ([tv isEqualTo:serversTableView])
  {
    return [self serversTableView:tv writeRowsWithIndexes:rowIndexes toPasteboard:pboard];
  }
  return NO;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
  if ([tv isEqual:serversTableView])
  {
    return [self serversTableView:tv validateDrop:info proposedRow:row proposedDropOperation:op];
  }
  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  if ([aTableView isEqual:serversTableView])
  {
    return [self serversTableView:aTableView acceptDrop:info row:row dropOperation:operation];
  }
  return NO;
}

@end

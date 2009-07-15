//
//  TSAUGraphPlayer.m
//  TestArkAudio
//
//  Created by Matt Wright on 14/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TSAUGraphPlayer.h"

#define MAX_ELEMENTS 128

#define initCheckErr(x, str) if (x != noErr) \
{ \
  NSLog(str); \
  NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]; \
  [[NSException exceptionWithName:@"TSAUGraphPlayerError" reason:[error localizedDescription] userInfo:nil] raise]; \
  isInitialised = NO; \
  return; \
}

OSStatus InputRenderCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData)
{
  TSAUGraphPlayer *player = inRefCon;
  
  return [player _inputRenderCallbackWithActionFlags:ioActionFlags
                                         inTimeStamp:inTimeStamp 
                                           busNumber:inBusNumber
                                      numberOfFrames:inNumberFrames
                                                data:ioData];
}

@implementation TSAUGraphPlayer

#pragma mark Init

- (id)initWithAudioDevice:(MTCoreAudioDevice*)device inputStreamDescription:(MTCoreAudioStreamDescription*)streamDesc
{
  if (self = [super init])
  {
    // set this to YES this now, the _initWithAudioDevice will set it to NO if it fails
    inputStreamDescription = [streamDesc retain];
    isInitialised = YES;
    
    // create a new thread to run on and setup the augraph on there
    renderThread = [[NSThread alloc] initWithTarget:self selector:@selector(_createRenderThread) object:nil];
    [renderThread start];
    
    // now run the init on the off-thread
    [self performSelector:@selector(_initWithAudioDevice:) onThread:renderThread withObject:device waitUntilDone:YES];
    
    if (!isInitialised)
    {
      [renderThread cancel];
      [self release];
      return nil;
    }
    
    inputBuffers = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [inputBuffers release];
  NSLog(@"dealloc");
  [super dealloc];
}

- (void)close
{
  // run dealloc on the render thread
  [self performSelector:@selector(_dealloc) onThread:renderThread withObject:nil waitUntilDone:YES];
  
  // kill the render thread
  [renderThread cancel];
  
  while (isInitialised)
  {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
  }
  
  for (MTAudioBuffer *buffer in [inputBuffers allValues])
  {
    [buffer flush];
  }
  [inputBuffers removeAllObjects];
}

#pragma mark Threading

- (void)_createRenderThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  // put a timer on the thread so that the runloop starts
  [NSTimer scheduledTimerWithTimeInterval:[[NSDate distantFuture] timeIntervalSinceNow] target:self selector:@selector(thatDoesntExist) userInfo:nil repeats:NO];
  
  while (![[NSThread currentThread] isCancelled])
  {
    // run the runloop for a while
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
    
    // recycle the autorelease pool
    [pool release];
    pool = [[NSAutoreleasePool alloc] init];
  }
  
  isInitialised = NO;
  
  [pool release];
}

- (void)_initWithAudioDevice:(MTCoreAudioDevice*)device
{
  AudioStreamBasicDescription inputASBD = [inputStreamDescription audioStreamBasicDescription], outputASBD;
  
  OSStatus err = NewAUGraph(&outputGraph);
  initCheckErr(err, @"NewAUGraph");
  
  err = AUGraphOpen(outputGraph);
  initCheckErr(err, @"AUGraphOpen");
  
  {
    // output unit
    ComponentDescription outputComponentDescription;
    outputComponentDescription.componentType = kAudioUnitType_Output;
    outputComponentDescription.componentSubType = kAudioUnitSubType_HALOutput;
    outputComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputComponentDescription.componentFlags = 0;
    outputComponentDescription.componentFlagsMask = 0;
    
    err = AUGraphAddNode(outputGraph, &outputComponentDescription, &outputDeviceNode);
    initCheckErr(err, @"AUGraphAddNode");
    
    err = AUGraphNodeInfo(outputGraph, outputDeviceNode, NULL, &outputDeviceUnit);
    initCheckErr(err, @"AUGraphNodeInfo");
    
    AudioDeviceID deviceID = [device deviceID];
    unsigned int sizeDeviceID = sizeof(AudioDeviceID);
    
    err = AudioUnitSetProperty(outputDeviceUnit, 
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &deviceID,
                               sizeDeviceID);
    initCheckErr(err, @"AudioUnitSetProperty");
    
    UInt32 outputASBDSize = sizeof(outputASBD);    
    err = AudioUnitGetProperty(outputDeviceUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputASBD, &outputASBDSize);
    initCheckErr(err, @"AudioUnitGetProperty (output device, input format)");
  }
  
  {
    // converter unit
    ComponentDescription converterComponentDescription;
    converterComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    converterComponentDescription.componentType = kAudioUnitType_FormatConverter;
    converterComponentDescription.componentSubType = kAudioUnitSubType_AUConverter;
    converterComponentDescription.componentFlags = 0;
    converterComponentDescription.componentFlagsMask = 0;
    
    err = AUGraphAddNode(outputGraph, &converterComponentDescription, &converterNode);
    initCheckErr(err, @"AUGraphAddNode (init converter node)");
    
    err = AUGraphNodeInfo(outputGraph, converterNode, NULL, &converterUnit);
    initCheckErr(err, @"AUGraphNodeInfo (get converter unit)");
    
    err = AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &inputASBD, sizeof(inputASBD));
    initCheckErr(err, @"AudioUnitSetProperty (converter unit, input format)");
    
    err = AudioUnitSetProperty(converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputASBD, sizeof(outputASBD));
    initCheckErr(err, @"AudioUnitSetProperty (converter unit, output format)");
  }
  
  {
    // mixer unit
    
    ComponentDescription mixerComponentDescription;
    mixerComponentDescription.componentType = kAudioUnitType_Mixer;
    mixerComponentDescription.componentSubType = kAudioUnitSubType_StereoMixer;
    mixerComponentDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixerComponentDescription.componentFlags = 0;
    mixerComponentDescription.componentFlagsMask = 0;
    
    err = AUGraphAddNode(outputGraph, &mixerComponentDescription, &mixerNode);
    initCheckErr(err, @"AUGraphAddNode");
    
    err = AUGraphNodeInfo(outputGraph, mixerNode, NULL, &mixerUnit);
    initCheckErr(err, @"AUGraphNodeInfo");
    
    // setup how many channels our mixer has
    unsigned int i, elements = MAX_ELEMENTS;
    err = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &elements, sizeof(elements));
    initCheckErr(err, @"AudioUnitSetProperty");
    
    for (i=0; i<elements; i++)
    {
      AURenderCallbackStruct inputCallbackStruct;
      inputCallbackStruct.inputProc = InputRenderCallback;
      inputCallbackStruct.inputProcRefCon = self;
      
      err = AudioUnitSetProperty(mixerUnit,
                                 kAudioUnitProperty_SetRenderCallback,
                                 kAudioUnitScope_Input,
                                 i,
                                 &inputCallbackStruct,
                                 sizeof(inputCallbackStruct));
      initCheckErr(err, @"AudioUnitSetProperty (inputCallback)");
      
      // set the volume
      float gain = 1.0;
      err = AudioUnitSetParameter(mixerUnit, kStereoMixerParam_Volume, kAudioUnitScope_Input, i, gain, 0);
      initCheckErr(err, @"AudioUnitSetParameter (volume)");
    }
  }
  
  err = AUGraphConnectNodeInput(outputGraph, mixerNode, 0, converterNode, 0);
  initCheckErr(err, @"AUGraphConnectNodeInput (mixer -> converter)");
  
  err = AUGraphConnectNodeInput(outputGraph, converterNode, 0, outputDeviceNode, 0);
  initCheckErr(err, @"AUGraphConnectNodeInput (converter -> output)");
  
  err = AUGraphInitialize(outputGraph);
  initCheckErr(err, @"AUGraphInitialize");
  
  err = AudioOutputUnitStart(outputDeviceUnit);
  initCheckErr(err, @"AudioOutputUnitStart");
  
  err = AUGraphStart(outputGraph);
  initCheckErr(err, @"AUGraphStart");
}

- (void)_dealloc
{
  AudioUnitUninitialize(outputDeviceUnit);
  AUGraphClose(outputGraph);
  DisposeAUGraph(outputGraph);
}

#pragma mark Channels

- (int)indexForNewInputStream
{
  for (int i=0; i<MAX_ELEMENTS; i++)
  {
    if ([inputBuffers objectForKey:[NSNumber numberWithInt:i]] == nil)
    {
      // give each channel 1/4 sec of buffer space
      unsigned int frames = (unsigned int)([inputStreamDescription sampleRate] * 0.25);
      
      MTAudioBuffer *buffer = [[MTAudioBuffer alloc] initWithCapacityFrames:frames channels:2];
      [inputBuffers setObject:[buffer autorelease] forKey:[NSNumber numberWithInt:i]];
      
      return i;
    }
  }
  return -1;
}

- (void)removeInputStream:(int)index
{
  if ([inputBuffers objectForKey:[NSNumber numberWithInt:index]] != nil)
  {
    [inputBuffers removeObjectForKey:[NSNumber numberWithInt:index]];
  }
}

- (unsigned long)numberOfFramesInInputStream:(unsigned int)index
{
  if ([inputBuffers objectForKey:[NSNumber numberWithInt:index]] != nil)
  {
    MTAudioBuffer *buffer = [inputBuffers objectForKey:[NSNumber numberWithInt:index]];
    return [buffer count];
  }
  return 0;
}

- (MTCoreAudioStreamDescription*)audioStreamDescription
{
  return inputStreamDescription;
}

#pragma mark Render Callback

- (OSStatus)_inputRenderCallbackWithActionFlags:(AudioUnitRenderActionFlags*)ioActionFlags
                                    inTimeStamp:(const AudioTimeStamp*)inTimeStamp
                                      busNumber:(UInt32)inBusNumber
                                 numberOfFrames:(UInt32)inNumberFrames
                                           data:(AudioBufferList*)ioData
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  MTAudioBufferListClear(ioData, 0, inNumberFrames);
  if ([inputBuffers objectForKey:[NSNumber numberWithInt:inBusNumber]] != nil)
  {
    MTAudioBuffer *buffer = [inputBuffers objectForKey:[NSNumber numberWithInt:inBusNumber]];
    [buffer readToAudioBufferList:ioData maxFrames:inNumberFrames waitForData:NO];
  }
  
  [pool release];
  return noErr;
}

#pragma mark Audio Queue

- (unsigned int)writeAudioBufferList:(AudioBufferList*)abl toInputStream:(unsigned int)index withForRoom:(BOOL)waitForRoom
{
  if (isInitialised && ([inputBuffers objectForKey:[NSNumber numberWithInt:index]] != nil))
  {
    MTAudioBuffer *buffer = [inputBuffers objectForKey:[NSNumber numberWithInt:index]];
    return [buffer writeFromAudioBufferList:abl maxFrames:MTAudioBufferListFrameCount(abl) rateScalar:1.0 waitForRoom:waitForRoom];
  }
  return 0;
}
    
@end

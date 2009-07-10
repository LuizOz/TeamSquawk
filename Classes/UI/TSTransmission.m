//
//  TSTransmission.m
//  TeamSquawk
//
//  Created by Matt Wright on 10/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSTransmission.h"


@implementation TSTransmission

- (id)initWithConnection:(SLConnection*)connection bitrate:(unsigned int)bitrate voiceActivated:(BOOL)voiceActivated
{
  if (self = [super init])
  {
    transmissionLock = [[NSLock alloc] init];
    
    encoder = [[SpeexEncoder alloc] initWithMode:SpeexEncodeWideBandMode];
    [encoder setBitrate:bitrate];
    
    NSString *inputDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"InputDeviceUID"];
    inputDevice = [(inputDeviceUID ? [MTCoreAudioDevice deviceWithUID:inputDeviceUID] : [MTCoreAudioDevice defaultInputDevice]) retain];
    if (!inputDevice)
    {
      inputDevice = [[MTCoreAudioDevice defaultInputDevice] retain];
    }
    [inputDevice setIOTarget:self withSelector:@selector(ioCycleForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:) withClientData:nil];
    [inputDevice setDevicePaused:NO];
    
    converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[inputDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] andOutputStreamDescription:[encoder encoderStreamDescription]];
    if (!converter)
    {
      [self release];
      return nil;
    }
    
    // start the thread
    transmissionThread = [[NSThread alloc] initWithTarget:self selector:@selector(_transmissionThread) object:nil];
    [transmissionThread start];
  }
  return self;
}

- (void)dealloc
{
  [self performSelector:@selector(_stopTransmitting) onThread:transmissionThread withObject:nil waitUntilDone:YES];
  [transmissionThread cancel];
  
  [converter release];
  [inputDevice release];
  [encoder release];
  [transmissionLock release];
  [super dealloc];
}

- (void)_transmissionThread
{
  while (![[NSThread currentThread] isCancelled])
  {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [pool release];
  }
}

- (void)_startTransmitting
{
  [inputDevice deviceStart];
}

- (void)_stopTransmitting
{
  [inputDevice deviceStop];
}

- (BOOL)isTransmitting
{
  return isTransmitting;
}

- (void)setIsTransmitting:(BOOL)flag
{
  [transmissionLock lock];
  isTransmitting = flag;
  [transmissionLock unlock];
}

- (OSStatus) ioCycleForDevice:(MTCoreAudioDevice *)theDevice
                    timeStamp:(const AudioTimeStamp *)inNow
                    inputData:(const AudioBufferList *)inInputData
                    inputTime:(const AudioTimeStamp *)inInputTime
                   outputData:(AudioBufferList *)outOutputData
                   outputTime:(const AudioTimeStamp *)inOutputTime
                   clientData:(void *)inClientData
{
  NSLog(@"foo");
}

@end

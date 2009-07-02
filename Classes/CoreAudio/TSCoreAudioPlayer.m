//
//  TSCoreAudioPlayer.m
//  TeamSquawk
//
//  Created by Matt Wright on 02/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSCoreAudioPlayer.h"


@implementation TSCoreAudioPlayer

- (id)initWithOutputDevice:(MTCoreAudioDevice*)device
{
  if (self = [super init])
  {
    audioDevice = [device retain];
    isRunning = NO;
    
    // 10s of audio at 44.1kHz mono.
    audioBuffer = [[MTAudioBuffer alloc] initWithCapacityFrames:441000 channels:1];
  }
  return self;
}

- (void)dealloc
{
  [audioDevice release];
  [audioBuffer release];
  [super dealloc];
}

- (BOOL)isRunning
{
  return isRunning;
}

- (void)setIsRunning:(BOOL)flag
{
  if (flag)
  {
    // start the device
    [audioDevice setIOTarget:self withSelector:@selector(ioCycleForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:) withClientData:nil];
    [audioDevice deviceStart];
    [audioDevice setDevicePaused:NO];
  }
  else
  {
    [audioDevice deviceStop];
    [audioDevice removeIOTarget];
  }
  isRunning = flag;
}
    
- (OSStatus)ioCycleForDevice:(MTCoreAudioDevice *)theDevice 
                   timeStamp:(const AudioTimeStamp *)inNow
                   inputData:(const AudioBufferList *)inInputData
                   inputTime:(const AudioTimeStamp *)inInputTime
                  outputData:(AudioBufferList *)outOutputData 
                  outputTime:(const AudioTimeStamp *)inOutputTime
                  clientData:(void *)inClientData
{
  // this will go off everytime core audio wants some more data, we'll try and read it from our audio buffer
  [audioBuffer readToAudioBufferList:outOutputData maxFrames:MTAudioBufferListFrameCount(outOutputData) waitForData:NO];
  
  return 0;
}

- (void)queueAudioBufferList:(const AudioBufferList*)theABL count:(unsigned int)count
{
  // this one should be quite easy, queue up audio in our buffer list. waitForRoom so we block the
  // producer if he's decoding too quickly.
  [audioBuffer writeFromAudioBufferList:theABL maxFrames:count rateScalar:1.0f waitForRoom:YES];
}

- (void)queueBytesFromData:(NSData*)data numOfFrames:(unsigned int)count
{
  // this is to let me queue data from somewhere else into an ABL to pass into the buffer
  AudioBufferList *tempABL = MTAudioBufferListNew(1, count, NO);
  
  // copy the data into the audio buffer
  tempABL->mBuffers[0].mDataByteSize = [data length];
  [data getBytes:tempABL->mBuffers[0].mData length:[data length]];
  
  [self queueAudioBufferList:tempABL count:count];
  
  MTAudioBufferListDispose(tempABL);
}

@end

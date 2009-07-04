//
//  TSAudioConverter.m
//  TeamSquawk
//
//  Created by Matt Wright on 02/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSAudioConverter.h"


@implementation TSAudioConverter

- (id)initConverterWithInputStreamDescription:(MTCoreAudioStreamDescription*)anInputDesc andOutputStreamDescription:(MTCoreAudioStreamDescription*)anOutputDesc
{
  if (self = [super init])
  {
    // firstly, try creating our ref before we retain the descriptions.
    AudioStreamBasicDescription inputBasicDesc = [anInputDesc audioStreamBasicDescription];
    AudioStreamBasicDescription outputBasicDesc = [anOutputDesc audioStreamBasicDescription];
    
    OSStatus err = AudioConverterNew(&inputBasicDesc, &outputBasicDesc, &audioConverterRef);
    if (err != noErr)
    {
      NSLog(@"AudioConverterNew failed with %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
      [self release];
      return nil;
    }
    
    inputStreamDescription = [anInputDesc retain];
    outputStreamDescription = [anOutputDesc retain];
    
    NSLog(@"%@, %@", inputStreamDescription, outputStreamDescription);
  }
  return self;
}

- (void)dealloc
{
  [inputStreamDescription release];
  [outputStreamDescription release];
  AudioConverterDispose(audioConverterRef);
  [super dealloc];
}

OSStatus AudioConverterInput(AudioConverterRef inAudioConverter, UInt32*ioNumberDataPackets, AudioBufferList*ioData, AudioStreamPacketDescription** outDataPacketDescription, void*inUserData)
{
  TSAudioConverterProc *userData = inUserData;
  
  if (userData->audioBufferList)
  {
    unsigned long packets = userData->audioBufferList->mBuffers[0].mDataByteSize / [userData->streamDesc bytesPerPacket];
    *ioNumberDataPackets = packets;
    
    ioData->mBuffers[0].mData = userData->audioBufferList->mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = userData->audioBufferList->mBuffers[0].mDataByteSize;
    ioData->mBuffers[0].mNumberChannels = userData->audioBufferList->mBuffers[0].mNumberChannels;
    
    // stop us coming here again
    userData->audioBufferList = 0;
  }
  else
  {
    *ioNumberDataPackets = 0;
  }
  
  
  return noErr;
}

- (AudioBufferList*)audioBufferListByConvertingList:(AudioBufferList*)inputList framesConverted:(unsigned int*)frames
{
  // this can only cope with single channel or interleaved data
  unsigned int outputBufferSize = inputList->mBuffers[0].mDataByteSize, propertyDataSize = sizeof(outputBufferSize);
  AudioConverterGetProperty(audioConverterRef, kAudioConverterPropertyCalculateOutputBufferSize, (UInt32*)&propertyDataSize, &outputBufferSize);
  
  unsigned long outputFrameCount = outputBufferSize / [outputStreamDescription bytesPerFrame];
  AudioBufferList *outputList = MTAudioBufferListNew([outputStreamDescription channelsPerFrame], outputFrameCount, YES);
  
  TSAudioConverterProc userData;
  userData.audioBufferList = inputList;
  userData.streamDesc = inputStreamDescription;

  OSStatus err = AudioConverterFillComplexBuffer(audioConverterRef, AudioConverterInput, &userData, &outputFrameCount, outputList, NULL);
  if (err != noErr)
  {
    NSLog(@"AudioConverterFillBuffer failed with %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
    MTAudioBufferListDispose(outputList);
    return nil;
  }
  
  *frames = (unsigned int)(outputFrameCount & 0xffff);
  return outputList;
}



@end

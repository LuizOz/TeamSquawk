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
      NSLog(@"input format: %@, output format: %@", anInputDesc, anOutputDesc);
      NSLog(@"AudioConverterNew failed with %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
      [self release];
      return nil;
    }
    
//    unsigned int value = kAudioConverterQuality_Max;
//    err = AudioConverterSetProperty(audioConverterRef, kAudioConverterSampleRateConverterQuality, sizeof(unsigned int), &value);
//    if (err != noErr)
//    {
//      NSLog(@"AudioConverterSetProperty failed with %d. %@", err, [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]);
//      [self release];
//      return nil;
//    }
        
    inputStreamDescription = [anInputDesc retain];
    outputStreamDescription = [anOutputDesc retain];
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
    userData->bytesRemaining -= ioData->mBuffers[0].mDataByteSize;
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
  userData.bytesRemaining = inputList->mBuffers[0].mDataByteSize;

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

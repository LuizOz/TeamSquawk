//
//  TSTransmission.m
//  TeamSquawk
//
//  Created by Matt Wright on 10/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "TSTransmission.h"


@implementation TSTransmission

@synthesize whisperRecipients;
@synthesize isWhispering;

- (id)initWithConnection:(SLConnection*)aConnection codec:(unsigned short)aCodec voiceActivated:(BOOL)voiceActivated
{
  if (self = [super init])
  {
    transmissionLock = [[NSLock alloc] init];
    connection = [aConnection retain];
    codec = aCodec;
    whisperRecipients = nil;
    packetCount = 0;
    transmissionCount = 0;
    
    encoder = [[SpeexEncoder alloc] initWithMode:SpeexEncodeWideBandMode];
    [encoder setBitrate:[SLConnection bitrateForCodec:codec]];
    
    NSString *inputDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"InputDeviceUID"];
    inputDevice = [(inputDeviceUID ? [MTCoreAudioDevice deviceWithUID:inputDeviceUID] : [MTCoreAudioDevice defaultInputDevice]) retain];
    if (!inputDevice)
    {
      inputDevice = [[MTCoreAudioDevice defaultInputDevice] retain];
    }

    // allocate enough buffer stream for five speex frames
    inputDeviceStreamDescription = [[inputDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDeviceRecordDirection] retain];
    [encoder setInputSampleRate:[inputDeviceStreamDescription sampleRate]];
    fragmentBuffer = [[MTByteBuffer alloc] initWithCapacity:((([encoder frameSize] * sizeof(short) * [encoder inputSampleRate]) / [encoder sampleRate]) * 5)];
    
    [inputDevice setIOTarget:self withSelector:@selector(ioCycleForDevice:timeStamp:inputData:inputTime:outputData:outputTime:clientData:) withClientData:nil];
    [inputDevice setDevicePaused:YES];
    [inputDevice deviceStart];
    
    converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:inputDeviceStreamDescription andOutputStreamDescription:[encoder encoderStreamDescription]];
    if (!converter)
    {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc
{
  [fragmentBuffer release];
  [connection release];
  [converter release];
  [inputDevice release];
  [encoder release];
  [transmissionLock release];
  [super dealloc];
}

- (BOOL)isTransmitting
{
  return isTransmitting;
}

- (void)close
{
  [inputDevice deviceStop];
  [inputDevice removeIOTarget];
}

- (void)setIsTransmitting:(BOOL)flag
{
  [transmissionLock lock];
  if (flag && (flag != isTransmitting))
  {
    [inputDevice setDevicePaused:!flag];
    transmissionCount++;
  }
  else if (!flag && (flag != isTransmitting))
  {
    [inputDevice setDevicePaused:!flag];
    [fragmentBuffer flush];
  }
  isTransmitting = flag;
  [transmissionLock unlock];
}

- (unsigned short)codec
{
  return codec;
}

- (void)setCodec:(unsigned short)newCodec
{
  codec = newCodec;
  [encoder setBitrate:[SLConnection bitrateForCodec:codec]];
  [encoder resetEncoder];
}

- (OSStatus) ioCycleForDevice:(MTCoreAudioDevice *)theDevice
                    timeStamp:(const AudioTimeStamp *)inNow
                    inputData:(const AudioBufferList *)inInputData
                    inputTime:(const AudioTimeStamp *)inInputTime
                   outputData:(AudioBufferList *)outOutputData
                   outputTime:(const AudioTimeStamp *)inOutputTime
                   clientData:(void *)inClientData
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  unsigned int outFrames = 0, i, inFramesCount = (inInputData->mBuffers[0].mDataByteSize / [inputDeviceStreamDescription bytesPerFrame]);
  float inputGain = [[[NSUserDefaults standardUserDefaults] objectForKey:@"InputGain"] floatValue];
  
  // do the input gain now
  for (i=0; i<inFramesCount; i++)
  {
    ((float*)inInputData->mBuffers[0].mData)[i] *= inputGain;
  }
  
  AudioBufferList *downsampledBufferList = [converter audioBufferListByConvertingList:(AudioBufferList*)inInputData framesConverted:&outFrames];
  unsigned int copiedBytes = [fragmentBuffer writeFromBytes:downsampledBufferList->mBuffers[0].mData count:downsampledBufferList->mBuffers[0].mDataByteSize waitForRoom:NO];
  
  if (copiedBytes < downsampledBufferList->mBuffers[0].mDataByteSize)
  {  
    // we've filled the fragment buffer. we need to compress it, send it and stash the remaining fragment.
    unsigned int encodedPackets = 0, frameInBytes = (([encoder frameSize] * sizeof(short) * [encoder inputSampleRate]) / [encoder sampleRate]);
    AudioBufferList *compressionBuffer = MTAudioBufferListNew(1, frameInBytes / 4, NO);
    [encoder resetEncoder];
    
    while ([fragmentBuffer count] >= frameInBytes)
    {
      [fragmentBuffer readToBytes:compressionBuffer->mBuffers[0].mData count:frameInBytes waitForData:NO];
      [encoder encodeAudioBufferList:compressionBuffer];
      encodedPackets++;
    }
    
    NSData *encodedData = [encoder encodedData];
    if (isWhispering)
    {
      if (whisperRecipients && ([whisperRecipients count] > 0))
      {
        [connection sendVoiceWhisper:encodedData frames:encodedPackets packetCount:packetCount++ transmissionID:transmissionCount codec:codec recipients:whisperRecipients];
      }
    }
    else
    {
      [connection sendVoiceMessage:encodedData frames:encodedPackets packetCount:packetCount++ transmissionID:transmissionCount codec:codec];
    }
    
    // now before we're too late, clear the compression buffer and copy the spare frames into it, then into the fragment buffer
    [fragmentBuffer writeFromBytes:(downsampledBufferList->mBuffers[0].mData + copiedBytes) count:(downsampledBufferList->mBuffers[0].mDataByteSize - copiedBytes) waitForRoom:NO];    
    MTAudioBufferListDispose(compressionBuffer);
  }
    
  MTAudioBufferListDispose(downsampledBufferList);
  
  [pool release];
  return noErr;
}

@end

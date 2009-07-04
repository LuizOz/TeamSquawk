//
//  TSController.m
//  TeamSquawk
//
//  Created by Matt Wright on 28/06/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <MTCoreAudio/MTCoreAudio.h>

#import "TSController.h"
#import "TSAudioExtraction.h"

#import "SpeexEncoder.h"
#import "SpeexDecoder.h"


@implementation TSController

- (void)awakeFromNib
{
  NSError *error = nil;
  
  [NSApp setDelegate:self];
  
  speex = [[SpeexDecoder alloc] initWithMode:SpeexWideBandMode];
  connection = [[SLConnection alloc] initWithHost:@"ts.deadcodeelimination.com" withError:&error];
  [connection setDelegate:self];
  
  if (!connection)
  {
    NSLog(@"%@", error);
  }
  
  [connection setClientName:@"TeamSquawk"];
  [connection setClientOperatingSystem:@"Mac OS X"];
  [connection setClientMajorVersion:1];
  [connection setClientMinorVersion:0];
    
  // get the output form that we need
  MTCoreAudioStreamDescription *outputDesc = [[MTCoreAudioDevice defaultOutputDevice] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection];
  MTCoreAudioStreamDescription *inputDesc = [[MTCoreAudioStreamDescription alloc] initWithAudioStreamBasicDescription:[outputDesc audioStreamBasicDescription]];
  [inputDesc setSampleRate:[speex bitRate]];
  [inputDesc setFormatFlags:kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked|kAudioFormatFlagsNativeEndian];
  [inputDesc setChannelsPerFrame:1];
  [inputDesc setBitsPerChannel:sizeof(short) * 8];
  [inputDesc setBytesPerFrame:sizeof(short) * [inputDesc channelsPerFrame]];
  [inputDesc setBytesPerPacket:[inputDesc bytesPerFrame]];

  converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:inputDesc andOutputStreamDescription:outputDesc];
  if (!converter)
  {
    return;
  }
  
  player = [[TSCoreAudioPlayer alloc] initWithOutputDevice:[MTCoreAudioDevice defaultOutputDevice]];
  [self performSelectorInBackground:@selector(audioPlayerThread) withObject:nil];
  //[self performSelectorInBackground:@selector(audioDecoderThread) withObject:nil];
  
  [connection beginAsynchronousLogin:nil password:@"lionftw" nickName:@"Shamlion" isRegistered:NO];
}

- (void)audioPlayerThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [player setIsRunning:YES];
  [pool release];
}

- (void)audioDecoderThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSError *error = nil;
  
  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Desktop/Disturbed/Believe/Disturbed/Believe/01 - Prayer.m4a"];
  NSLog(@"starting, %@", extraction);
  NSData *audio = [extraction extractWithDuration:120 error:&error];
  NSLog(@"finished, %@, %d", error, [audio length]);
  
  MTCoreAudioStreamDescription *inputDesc = [[[[MTCoreAudioDevice defaultOutputDevice] streamsForDirection:kMTCoreAudioDevicePlaybackDirection] objectAtIndex:0] streamDescriptionForSide:kMTCoreAudioDevicePlaybackDirection];
  [inputDesc setChannelsPerFrame:1];
  MTCoreAudioStreamDescription *outputDesc = [[MTCoreAudioStreamDescription alloc] initWithAudioStreamBasicDescription:[inputDesc audioStreamBasicDescription]];
  [outputDesc setSampleRate:22500];
  
  TSAudioConverter *converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:inputDesc andOutputStreamDescription:outputDesc];
  
  unsigned int counter = 0;
  while (counter < [audio length])
  {
    NSData *subData = [audio subdataWithRange:NSMakeRange(counter, 44100*sizeof(float))];
    
    // this is to let me queue data from somewhere else into an ABL to pass into the buffer
    AudioBufferList *tempABL = MTAudioBufferListNew(1, 44100*4, NO);
    
    // copy the data into the audio buffer
    tempABL->mBuffers[0].mNumberChannels = 1;
    tempABL->mBuffers[0].mDataByteSize = [subData length];
    [subData getBytes:tempABL->mBuffers[0].mData length:[subData length]];
    
    AudioBufferList *outputList = [converter audioBufferListByConvertingList:tempABL];
    [player queueAudioBufferList:outputList count:48000];
    
    MTAudioBufferListDispose(tempABL);
    MTAudioBufferListDispose(outputList);
    
    counter += 44110*4;
  }
  
  [pool release];
}

- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID senderPacketCounter:(unsigned short)count
{  
  unsigned int frames;
  NSData *audioData = [speex audioDataForEncodedData:audioCodecData framesDecoded:&frames];
  
  // convert our audio data to an ABL
  AudioBufferList *abl = MTAudioBufferListNew(1, frames * [speex frameSize], NO);
  
  // copy in the audio
  abl->mBuffers[0].mNumberChannels = 1;
  abl->mBuffers[0].mDataByteSize = [audioData length];
  [audioData getBytes:abl->mBuffers[0].mData length:[audioData length]];
  
  // convert
  unsigned int outputFrameCount = 0;
  AudioBufferList *convertedABL = [converter audioBufferListByConvertingList:abl framesConverted:&outputFrameCount];
  [player queueAudioBufferList:convertedABL count:outputFrameCount];
  
  MTAudioBufferListDispose(abl);
  MTAudioBufferListDispose(convertedABL);
}

@end

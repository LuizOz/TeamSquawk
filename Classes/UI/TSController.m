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

@implementation TSController

- (void)awakeFromNib
{
  NSError *error = nil;
  
  [NSApp setDelegate:self];
  
  speex = [[SpeexDecoder alloc] initWithMode:SpeexDecodeWideBandMode];
  speexEncoder = [[SpeexEncoder alloc] initWithMode:SpeexEncodeWideBandMode];
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
  [inputDesc setSampleRate:[speex sampleRate]];
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

- (void)connectionFinishedLogin:(SLConnection*)connection
{
  [self performSelectorInBackground:@selector(audioDecoderThread2) withObject:nil];
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
  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Music/iTunes/iTunes Music/Level 70 Elite Tauren Chieftain/[non-album tracks]/02 Rogues Do It From Behind.mp3"];
    
  MTCoreAudioStreamDescription *streamDescription = [[MTCoreAudioDevice defaultOutputDevice] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection];
  [extraction setOutputStreamDescription:streamDescription];
  
  while ([extraction position] < [extraction numOfFrames])
  {
    // decode a second at a time
    unsigned long samples = [streamDescription sampleRate];
    AudioBufferList *audio = [extraction extractNumberOfFrames:samples];
    [player queueAudioBufferList:audio count:samples];
    MTAudioBufferListDispose(audio);    
  }
  
  [pool release];
}

- (void)audioDecoderThread2
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Music/iTunes/iTunes Music/Level 70 Elite Tauren Chieftain/[non-album tracks]/02 Rogues Do It From Behind.mp3"];

  [speexEncoder setBitrate:24800];
  MTCoreAudioStreamDescription *encoderDescription = [speexEncoder encoderStreamDescription];
  [extraction setOutputStreamDescription:encoderDescription];
  
  unsigned int frameSize = [speexEncoder frameSize];
  unsigned short packetCount = 250;
  while ([extraction position] < [extraction numOfFrames])
  {
    NSMutableData *packetData = [NSMutableData data];
    int i;
    
    for (i=0; i<4; i++)
    {
      AudioBufferList *audio = [extraction extractNumberOfFrames:frameSize];
      NSData *encodedAudioData = [speexEncoder encodedDataForAudioBufferList:audio];
      MTAudioBufferListDispose(audio);
      [packetData appendData:encodedAudioData];
    }
    
    [connection sendVoiceMessage:packetData commanderChannel:NO packetCount:packetCount++ codec:SLCodecSpeex_25_9];
    NSLog(@"sent %@", packetData);
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
  
  NSLog(@"%d", [speex bitrate]);
  
  MTAudioBufferListDispose(abl);
  MTAudioBufferListDispose(convertedABL);
}

@end

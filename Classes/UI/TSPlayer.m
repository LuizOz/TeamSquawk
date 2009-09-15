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

#import "TSPlayer.h"
#import "SLConnection.h"

@implementation TSPlayer

@synthesize decoder = speex;
@synthesize converter;
@synthesize graphPlayer;
@synthesize queue;
@synthesize lastVoicePacketCount;
@synthesize extendedFlags;
@synthesize channelPrivFlags;
@synthesize isTransmitting;
@synthesize isWhispering;
@synthesize isLocallyMuted;
@synthesize graphPlayerChannel;

- (id)initWithGraphPlayer:(TSAUGraphPlayer*)player
{
  if (self = [super init])
  {
    speex = [[SpeexDecoder alloc] initWithMode:SpeexDecodeWideBandMode];
    [self setGraphPlayer:player];
    
    converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[speex decoderStreamDescription] andOutputStreamDescription:[graphPlayer audioStreamDescription]];
    queue = dispatch_queue_create("uk.co.sysctl.teamsquawk.playerqueue", 0);
        
    playerName = nil;
  }
  return self;
}

- (id)_init
{
  if (self = [super init])
  {
    speex = nil;
    graphPlayer = nil;
    converter = nil;
    playerName = nil;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  TSPlayer *copyPlayer = [[[self class] allocWithZone:zone] _init];
  
  copyPlayer->speex = [speex retain];
  copyPlayer->graphPlayer = [graphPlayer retain];
  copyPlayer->converter = [converter retain];
  copyPlayer->graphPlayerChannel = graphPlayerChannel;
  
  dispatch_retain(queue);
  copyPlayer->queue = queue;
  
  [copyPlayer setPlayerName:[self playerName]];
  [copyPlayer setPlayerID:[self playerID]];
  [copyPlayer setPlayerFlags:[self playerFlags]];
  [copyPlayer setChannelID:[self channelID]];
  [copyPlayer setLastVoicePacketCount:[self lastVoicePacketCount]];
  [copyPlayer setExtendedFlags:[self extendedFlags]];
  [copyPlayer setChannelPrivFlags:[self channelPrivFlags]];
  [copyPlayer setIsTransmitting:[self isTransmitting]];
  [copyPlayer setIsWhispering:[self isWhispering]];
  [copyPlayer setIsLocallyMuted:[self isLocallyMuted]];
  
  return copyPlayer;
}

- (void)dealloc
{
  [self setPlayerName:nil];
  
  dispatch_release(queue);
  
  [graphPlayer release];
  [converter release];
  [speex release];
  
  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%@: %p, name: %@, flags: 0x%x <cc: %d, bw: %d, ia: %d, mm: %d, im: %d>, chan: 0x%x, id: 0x%x>",
          [self className], self, [self playerName], [self playerFlags],
          [self isChannelCommander], [self shouldBlockWhispers], [self isAway], [self hasMutedMicrophone], [self hasMutedSpeakers],
          [self channelID],
          [self playerID]];
}

- (void)setGraphPlayer:(TSAUGraphPlayer*)player
{
  // let go of the old player
  [graphPlayer removeInputStream:graphPlayerChannel];
  [graphPlayer autorelease];
  
  // get the new one
  graphPlayer = [player retain];
  graphPlayerChannel = [graphPlayer indexForNewInputStream];
  
  if (graphPlayerChannel == -1)
  {
    [graphPlayer release];
    graphPlayer = nil;
    
    NSLog(@"-[%@ %@] failed to obtain a GraphPlayer channel.", [self className], NSStringFromSelector(_cmd));
  }
    
  // get a new audio converter
  TSAudioConverter *newConverter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[speex decoderStreamDescription] andOutputStreamDescription:[graphPlayer audioStreamDescription]];
  
  [converter autorelease];
  converter = newConverter; // already retained
}

- (void)backgroundDecodeData:(NSData*)audioCodecData
{
  // to try and control our memory usage
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  unsigned int decodedFrames = 0;
  NSData *data = [[self decoder] audioDataForEncodedData:audioCodecData framesDecoded:&decodedFrames];
  AudioBufferList *decodedBufferList = MTAudioBufferListNew(1, decodedFrames * [[self decoder] frameSize], NO);
  
  decodedBufferList->mBuffers[0].mNumberChannels = 1;
  decodedBufferList->mBuffers[0].mDataByteSize = [data length];
  [data getBytes:decodedBufferList->mBuffers[0].mData length:[data length]];
  
  unsigned int convertedFrameCount = 0;
  AudioBufferList *resampledBufferList = [[self converter] audioBufferListByConvertingList:decodedBufferList framesConverted:&convertedFrameCount];
  
  if ([graphPlayer numberOfFramesInInputStream:graphPlayerChannel] == 0)
  {
    // we've no audio, i'd like to lead the audio by 0.25s just to give us some jitter room
    unsigned int sampleRate = (unsigned int)[[[MTCoreAudioDevice defaultOutputDevice] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] sampleRate];
    AudioBufferList *blankFrames = MTAudioBufferListNew(1, sampleRate / 4, NO);
    [[self graphPlayer] writeAudioBufferList:blankFrames toInputStream:graphPlayerChannel withForRoom:YES];
    MTAudioBufferListDispose(blankFrames);
  }
  
  [[self graphPlayer] writeAudioBufferList:resampledBufferList toInputStream:graphPlayerChannel withForRoom:YES];
  
  MTAudioBufferListDispose(resampledBufferList);
  MTAudioBufferListDispose(decodedBufferList);

  [pool release];
}

- (NSString*)playerName
{
  return playerName;
}

- (void)setPlayerName:(NSString*)name
{
  [playerName autorelease];
  playerName = [name retain];
}

- (unsigned int)playerFlags
{
  return playerFlags;
}

- (void)setPlayerFlags:(unsigned int)flags
{
  playerFlags = flags;
}

- (BOOL)isChannelCommander
{
  return ((playerFlags & TSPlayerChannelCommander) == TSPlayerChannelCommander);
}

- (BOOL)shouldBlockWhispers
{
  return ((playerFlags & TSPlayerBlockWhispers) == TSPlayerBlockWhispers);
}

- (BOOL)isAway
{
  return ((playerFlags & TSPlayerIsAway) == TSPlayerIsAway);
}

- (BOOL)hasMutedMicrophone
{
  return ((playerFlags & TSPlayerHasMutedMicrophone) == TSPlayerHasMutedMicrophone);
}

- (BOOL)hasMutedSpeakers
{
  return ((playerFlags & TSPlayerHasMutedSpeakers) == TSPlayerHasMutedSpeakers);
}

- (BOOL)isTalking
{
  return (([graphPlayer numberOfFramesInInputStream:graphPlayerChannel] > 0) || [self isTransmitting]);
}

- (BOOL)isRegistered
{
  return ((extendedFlags & SLConnectionRegisteredPlayer) == SLConnectionRegisteredPlayer);
}

- (BOOL)isServerAdmin
{
  return ((extendedFlags & SLConnectionServerAdmin) == SLConnectionServerAdmin);
}

- (BOOL)isChannelAdmin
{
  return ((channelPrivFlags & SLConnectionChannelAdmin) == SLConnectionChannelAdmin);
}

- (BOOL)isChannelOperator
{
  return ((channelPrivFlags & SLConnectionOperator) == SLConnectionOperator);
}

- (BOOL)isChannelVoice
{
  return ((channelPrivFlags & SLConnectionVoice) == SLConnectionVoice);
}

- (unsigned int)playerID
{
  return playerID;
}

- (void)setPlayerID:(unsigned int)aPlayerID
{
  playerID = aPlayerID;
}

- (unsigned int)channelID
{
  return channelID;
}

- (void)setChannelID:(unsigned int)aChannelID
{
  channelID = aChannelID;
}

@end

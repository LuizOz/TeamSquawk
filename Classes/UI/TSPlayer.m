//
//  TSPlayer.m
//  TeamSquawk
//
//  Created by Matt Wright on 05/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TSPlayer.h"


@implementation TSPlayer

@synthesize decoder = speex;
@synthesize converter;
@synthesize coreAudioPlayer = coreAudio;
@synthesize decodeQueue;
@synthesize lastVoicePacketCount;
@synthesize extendedFlags;
@synthesize isTransmitting;
@synthesize isWhispering;

- (id)init
{
  if (self = [super init])
  {
    speex = [[SpeexDecoder alloc] initWithMode:SpeexDecodeWideBandMode];
    
    NSString *outputDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"OutputDeviceUID"];
    MTCoreAudioDevice *outputDevice = (outputDeviceUID ? [MTCoreAudioDevice deviceWithUID:outputDeviceUID] : [MTCoreAudioDevice defaultOutputDevice]);
    
    coreAudio = [[TSCoreAudioPlayer alloc] initWithOutputDevice:outputDevice];
    converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[speex decoderStreamDescription] andOutputStreamDescription:[outputDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection]];
    decodeQueue = [[NSOperationQueue alloc] init];
    [decodeQueue setMaxConcurrentOperationCount:1];
    
    [self performSelectorInBackground:@selector(_setIsRunningThread) withObject:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_outputDeviceChanged:) name:@"TSOutputDeviceChanged" object:nil];
    
    playerName = nil;
  }
  return self;
}

- (id)_init
{
  if (self = [super init])
  {
    speex = nil;
    coreAudio = nil;
    converter = nil;
    decodeQueue = nil;
    playerName = nil;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  TSPlayer *copyPlayer = [[[self class] allocWithZone:zone] _init];
  
  copyPlayer->speex = [speex retain];
  copyPlayer->coreAudio = [coreAudio retain];
  copyPlayer->converter = [converter retain];
  copyPlayer->decodeQueue = [decodeQueue retain];
  
  [copyPlayer setPlayerName:[self playerName]];
  [copyPlayer setPlayerID:[self playerID]];
  [copyPlayer setPlayerFlags:[self playerFlags]];
  [copyPlayer setChannelID:[self channelID]];
  [copyPlayer setLastVoicePacketCount:[self lastVoicePacketCount]];
  [copyPlayer setExtendedFlags:[self extendedFlags]];
  [copyPlayer setIsTransmitting:[self isTransmitting]];
  [copyPlayer setIsWhispering:[self isWhispering]];
  
  return copyPlayer;
}

- (void)dealloc
{
  [coreAudio release];
  [converter release];
  [speex release];
  [playerName release];
  [super dealloc];
}

- (NSString*)description
{
  return [NSString stringWithFormat:@"<%@: %p, name: %@, flags: 0x%x <cc: %d, bw: %d, ia: %d, mm: %d, im: %d>, chan: 0x%x, id: 0x%x>",
          [self className], self, [self playerName], [self playerFlags],
          [self isChannelCommander], [self shouldBlockWhispers], [self isAway], [self hasMutedMicrophone], [self isMuted],
          [self channelID],
          [self playerID]];
}

- (void)_setIsRunningThread
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [coreAudio setIsRunning:YES];
  [[NSRunLoop currentRunLoop] run];
  [pool release];
}

- (void)_outputDeviceChanged:(NSNotification*)notification
{
  [coreAudio setIsRunning:NO];
  [coreAudio autorelease];
  [converter autorelease];
  
  NSString *outputDeviceUID = [[NSUserDefaults standardUserDefaults] stringForKey:@"OutputDeviceUID"];
  MTCoreAudioDevice *outputDevice = (outputDeviceUID ? [MTCoreAudioDevice deviceWithUID:outputDeviceUID] : [MTCoreAudioDevice defaultOutputDevice]);
  
  TSCoreAudioPlayer *newCoreAudio = [[TSCoreAudioPlayer alloc] initWithOutputDevice:outputDevice];
  TSAudioConverter *newConverter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:[speex decoderStreamDescription] andOutputStreamDescription:[outputDevice streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection]];
  
  coreAudio = newCoreAudio;
  converter = newConverter;
  
  [self performSelectorInBackground:@selector(_setIsRunningThread) withObject:nil];
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
  
  if ([coreAudio activeFramesInBuffer] == 0)
  {
    // we've no audio, i'd like to lead the audio by 0.25s just to give us some jitter room
    unsigned int sampleRate = (unsigned int)[[[MTCoreAudioDevice defaultOutputDevice] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection] sampleRate];
    AudioBufferList *blankFrames = MTAudioBufferListNew(1, sampleRate / 4, NO);
    [[self coreAudioPlayer] queueAudioBufferList:blankFrames count:(sampleRate / 4)];
    MTAudioBufferListDispose(blankFrames);
  }
  
  [[self coreAudioPlayer] queueAudioBufferList:resampledBufferList count:convertedFrameCount];
  
  MTAudioBufferListDispose(resampledBufferList);
  MTAudioBufferListDispose(decodedBufferList);
  [audioCodecData release];
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

- (BOOL)isMuted
{
  return ((playerFlags & TSPlayerIsMuted) == TSPlayerIsMuted);
}

- (BOOL)isTalking
{
  return (([coreAudio activeFramesInBuffer] > 0) || [self isTransmitting]);
}

- (BOOL)isRegistered
{
  return ((extendedFlags & TSPlayerRegistered) == TSPlayerRegistered);
}

- (BOOL)isServerAdmin
{
  return ((extendedFlags & TSPlayerServerAdmin) == TSPlayerServerAdmin);
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

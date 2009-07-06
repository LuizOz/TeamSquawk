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
#import "TSPlayer.h"
#import "TSChannel.h"

@implementation TSController

- (void)awakeFromNib
{
  // setup the outline view
  [mainWindowOutlineView setDelegate:self];
  [mainWindowOutlineView setDataSource:self];
  
  // reset our internal state
  isConnected = NO;
  players = [[NSMutableDictionary alloc] init];
  channels = [[NSMutableDictionary alloc] init];
  flattenedChannels = [[NSMutableDictionary alloc] init];
  sortedChannels = nil;
}

#pragma mark OutlineView DataSource

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
  if (item == nil)
  {
    return [sortedChannels objectAtIndex:index];
  }
  else if ([item isKindOfClass:[TSChannel class]])
  {
    return [[item players] objectAtIndex:index];
  }
  return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
  if (item == nil)
  {
    return YES;
  }
  if ([item isKindOfClass:[TSChannel class]])
  {
    return ([[item players] count] > 0);
  }
  return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
  if (item == nil)
  {
    return [sortedChannels count];
  }
  else if ([item isKindOfClass:[TSChannel class]])
  {
    return [[item players] count];
  }
  
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  if (item == nil)
  {
    return @"Foo";
  }
  if ([item isKindOfClass:[TSChannel class]])
  {
    return [(TSChannel*)item channelName];
  }
  else if ([item isKindOfClass:[TSPlayer class]])
  {
    return [(TSPlayer*)item playerName];
  }
}

#pragma mark OutlineView Delegates

#pragma mark Menu Items

- (IBAction)connectMenuAction:(id)sender
{
  // this is going to be somewhat place holdery
  NSError *error = nil;
  
  // create a connection
  teamspeakConnection = [[SLConnection alloc] initWithHost:@"ts.deadcodeelimination.com" withError:&error];
  [teamspeakConnection setDelegate:self];
  
  // setup some basic things about this client
  [teamspeakConnection setClientName:@"TeamSquawk"];
  [teamspeakConnection setClientOperatingSystem:@"Mac OS X"];
  [teamspeakConnection setClientMajorVersion:1];
  [teamspeakConnection setClientMinorVersion:0];
  
  [teamspeakConnection beginAsynchronousLogin:nil password:@"lionftw" nickName:@"TeamSquawk" isRegistered:NO];
}

- (IBAction)disconnectMenuAction:(id)sender
{
  
}

#pragma mark Menu Validation

- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)anItem
{
  if ([anItem action] == @selector(connectMenuAction:))
  {
    return !isConnected;
  }
  else if ([anItem action] == @selector(disconnectMenuAction:))
  {
    return isConnected;
  }
  
  return YES;
}

#pragma mark SLConnection Delegates

- (void)connection:(SLConnection*)connection didLoginTo:(NSString*)host port:(int)port serverName:(NSString*)serverName platform:(NSString*)platform
      majorVersion:(int)majorVersion minorVersion:(int)minorVersion subLevelVersion:(int)subLevelVersion subsubLevelVersion:(int)subsubLevelVersion welcomeMessage:(NSString*)welcomeMessage
{
  
}

- (void)connectionFinishedLogin:(SLConnection*)connection
{
  [mainWindowOutlineView reloadData];
  [mainWindowOutlineView expandItem:nil expandChildren:YES];
}

- (void)connectionFailedToLogin:(SLConnection*)connection
{
  
}

- (void)connection:(SLConnection*)connection receivedChannelList:(NSDictionary*)channelDictionary
{
  NSArray *channelsDictionary = [channelDictionary objectForKey:@"SLChannels"];
  [flattenedChannels removeAllObjects];
  
  for (NSDictionary *channelDictionary in channelsDictionary)
  {
    TSChannel *channel = [[TSChannel alloc] init];
    
    [channel setChannelName:[channelDictionary objectForKey:@"SLChannelName"]];
    [channel setChannelDescription:[channelDictionary objectForKey:@"SLChannelDescription"]];
    [channel setChannelTopic:[channelDictionary objectForKey:@"SLChannelTopic"]];
    [channel setChannelID:[[channelDictionary objectForKey:@"SLChannelID"] unsignedIntValue]];
    [channel setParent:[[channelDictionary objectForKey:@"SLChannelParentID"] unsignedIntValue]];
    [channel setCodec:[[channelDictionary objectForKey:@"SLChannelCodec"] unsignedIntValue]];
    [channel setFlags:[[channelDictionary objectForKey:@"SLChannelFlags"] unsignedIntValue]];
    [channel setMaxUsers:[[channelDictionary objectForKey:@"SLChannelMaxUsers"] unsignedIntValue]];
    [channel setSortOrder:[[channelDictionary objectForKey:@"SLChannelSortOrder"] unsignedIntValue]];
   
    [flattenedChannels setObject:channel forKey:[NSNumber numberWithUnsignedInt:[channel channelID]]];
    
    // root channels have a parent of 0xffffffff, if we've got a real parent and we haven't
    // encountered yet then we should crater
    if ([channel parent] == 0xffffffff)
    {
      [channels setObject:channel forKey:[NSNumber numberWithUnsignedInt:[channel channelID]]];
    }
    else
    {
      NSNumber *parentChannel = [NSNumber numberWithUnsignedInt:[channel parent]];
      
      if (![flattenedChannels objectForKey:parentChannel])
      {
        [[NSException exceptionWithName:@"ParentChannelNotFound" reason:@"Subchannel defined before parent channel." userInfo:nil] raise];
      }
      [(TSChannel*)[flattenedChannels objectForKey:parentChannel] addSubChannel:channel];
    }
  }
  
  [sortedChannels autorelease];
  NSArray *sortDescriptors = [NSArray arrayWithObjects:
                              [[[NSSortDescriptor alloc] initWithKey:@"sortOrder" ascending:YES] autorelease],
                              [[[NSSortDescriptor alloc] initWithKey:@"channelName" ascending:YES] autorelease],
                              nil];
  sortedChannels = [[[channels allValues] sortedArrayUsingDescriptors:sortDescriptors] retain];
}

- (void)connection:(SLConnection*)connection receivedPlayerList:(NSDictionary*)playerDictionary
{
  NSArray *playersDictionary = [playerDictionary objectForKey:@"SLPlayers"];
  
  for (NSDictionary *playerDictionary in playersDictionary)
  {
    TSPlayer *player = [[[TSPlayer alloc] init] autorelease];
    
    [player setPlayerName:[playerDictionary objectForKey:@"SLPlayerNick"]];
    [player setPlayerFlags:[[playerDictionary objectForKey:@"SLPlayerFlags"] unsignedIntValue]];
    [player setPlayerID:[[playerDictionary objectForKey:@"SLPlayerID"] unsignedIntValue]];
    [player setChannelID:[[playerDictionary objectForKey:@"SLChannelID"] unsignedIntValue]];
    
    [players setObject:player forKey:[NSNumber numberWithUnsignedInt:[player playerID]]];
    
    TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
    [channel addPlayer:player];
  }
}

- (void)connection:(SLConnection*)connection receivedNewPlayerNotification:(unsigned int)playerID channel:(unsigned int)channelID nickname:(NSString*)nickname
{
  TSPlayer *player = [[[TSPlayer alloc] init] autorelease];
  
  [player setPlayerID:playerID];
  [player setPlayerName:nickname];
  [player setChannelID:channelID];
  [player setPlayerFlags:0];
  
  [players setObject:player forKey:[NSNumber numberWithUnsignedInt:[player playerID]]];
  
  TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
  [channel addPlayer:player];
  
  [mainWindowOutlineView reloadItem:channel];
  [mainWindowOutlineView expandItem:channel];
}

- (void)connection:(SLConnection*)connection receivedPlayerLeftNotification:(unsigned int)playerID
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *channel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:[player channelID]]];
  
  [channel removePlayer:player];
  [players removeObjectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  
  [mainWindowOutlineView reloadItem:channel];
}

- (void)connection:(SLConnection*)connection receivedPlayerUpdateNotification:(unsigned int)playerID flags:(unsigned short)flags
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  [player setPlayerFlags:flags];
  
  [mainWindowOutlineView reloadItem:player];
}

- (void)connection:(SLConnection*)connection receivedChannelChangeNotification:(unsigned int)playerID fromChannel:(unsigned int)fromChannelID toChannel:(unsigned int)toChannelID
{
  TSPlayer *player = [players objectForKey:[NSNumber numberWithUnsignedInt:playerID]];
  TSChannel *oldChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:fromChannelID]];
  TSChannel *newChannel = [flattenedChannels objectForKey:[NSNumber numberWithUnsignedInt:toChannelID]];
  
  [oldChannel removePlayer:player];
  [newChannel addPlayer:player];
  
  [mainWindowOutlineView reloadItem:oldChannel];
  [mainWindowOutlineView reloadItem:newChannel];
  [mainWindowOutlineView expandItem:newChannel];
}

#pragma mark Old Shit

//- (void)awakeFromNib2
//{
//  NSError *error = nil;
//  
//  [NSApp setDelegate:self];
//  
//  speex = [[SpeexDecoder alloc] initWithMode:SpeexDecodeWideBandMode];
//  speexEncoder = [[SpeexEncoder alloc] initWithMode:SpeexEncodeWideBandMode];
//  connection = [[SLConnection alloc] initWithHost:@"ts.deadcodeelimination.com" withError:&error];
//  [connection setDelegate:self];
//  
//  if (!connection)
//  {
//    NSLog(@"%@", error);
//  }
//  
//  [connection setClientName:@"TeamSquawk"];
//  [connection setClientOperatingSystem:@"Mac OS X"];
//  [connection setClientMajorVersion:1];
//  [connection setClientMinorVersion:0];
//    
//  // get the output form that we need
//  MTCoreAudioStreamDescription *outputDesc = [[MTCoreAudioDevice defaultOutputDevice] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection];
//  MTCoreAudioStreamDescription *inputDesc = [[MTCoreAudioStreamDescription alloc] initWithAudioStreamBasicDescription:[outputDesc audioStreamBasicDescription]];
//  [inputDesc setSampleRate:[speex sampleRate]];
//  [inputDesc setFormatFlags:kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked|kAudioFormatFlagsNativeEndian];
//  [inputDesc setChannelsPerFrame:1];
//  [inputDesc setBitsPerChannel:sizeof(short) * 8];
//  [inputDesc setBytesPerFrame:sizeof(short) * [inputDesc channelsPerFrame]];
//  [inputDesc setBytesPerPacket:[inputDesc bytesPerFrame]];
//
//  converter = [[TSAudioConverter alloc] initConverterWithInputStreamDescription:inputDesc andOutputStreamDescription:outputDesc];
//  if (!converter)
//  {
//    return;
//  }
//  
//  player = [[TSCoreAudioPlayer alloc] initWithOutputDevice:[MTCoreAudioDevice defaultOutputDevice]];
//  [self performSelectorInBackground:@selector(audioPlayerThread) withObject:nil];
//  //[self performSelectorInBackground:@selector(audioDecoderThread) withObject:nil];
//  
//  [connection beginAsynchronousLogin:nil password:@"lionftw" nickName:@"Shamlion" isRegistered:NO];
//}

//- (void)connectionFinishedLogin:(SLConnection*)connection
//{
//  //[self performSelectorInBackground:@selector(audioDecoderThread2) withObject:nil];
//  //[NSThread detachNewThreadSelector:@selector(audioDecoderThread2) toTarget:self withObject:nil];
//}

//- (void)audioPlayerThread
//{
//  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//  [player setIsRunning:YES];
//  [pool release];
//}

//- (void)audioDecoderThread
//{
//  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];  
//  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Music/iTunes/iTunes Music/Level 70 Elite Tauren Chieftain/[non-album tracks]/02 Rogues Do It From Behind.mp3"];
//    
//  MTCoreAudioStreamDescription *streamDescription = [[MTCoreAudioDevice defaultOutputDevice] streamDescriptionForChannel:0 forDirection:kMTCoreAudioDevicePlaybackDirection];
//  [extraction setOutputStreamDescription:streamDescription];
//  
//  while ([extraction position] < [extraction numOfFrames])
//  {
//    // decode a second at a time
//    unsigned long samples = [streamDescription sampleRate];
//    AudioBufferList *audio = [extraction extractNumberOfFrames:samples];
//    [player queueAudioBufferList:audio count:samples];
//    MTAudioBufferListDispose(audio);    
//  }
//  
//  [pool release];
//}

//- (void)audioDecoderThread2
//{
//  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//  //TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Music/iTunes/iTunes Music/Level 70 Elite Tauren Chieftain/[non-album tracks]/02 Rogues Do It From Behind.mp3"];
//  TSAudioExtraction *extraction = [[TSAudioExtraction alloc] initWithFilename:@"/Users/matt/Desktop/Disturbed/Ten Thousand Fists/Disturbed/Ten Thousand Fists/01 - Ten Thousand Fists.mp3"];
//  
//  [speexEncoder setBitrate:25900];
//  MTCoreAudioStreamDescription *encoderDescription = [speexEncoder encoderStreamDescription];
//  [extraction setOutputStreamDescription:encoderDescription];
//  
//  unsigned int frameSize = [speexEncoder frameSize];
//  unsigned short packetCount = 0;
//  NSDate *releaseTime = [[NSDate distantPast] retain];
//  
//  while ([extraction position] < [extraction numOfFrames])
//  {
//    NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
//    [speexEncoder resetEncoder];
//    int i;
//    
//    for (i=0; i<5; i++)
//    {
//      AudioBufferList *audio = [extraction extractNumberOfFrames:frameSize];
//      [speexEncoder encodeAudioBufferList:audio];
//      MTAudioBufferListDispose(audio);
//    }
//    
//    NSData *packetData = [speexEncoder encodedData];
//    
//    while ([[releaseTime laterDate:[NSDate date]] isEqual:releaseTime])
//    {
//      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
//    }
//    
//    [connection sendVoiceMessage:packetData frames:5 commanderChannel:NO packetCount:packetCount++ codec:SLCodecSpeex_25_9];
//    [releaseTime release];
//    releaseTime = [[NSDate dateWithTimeIntervalSinceNow:(double)((frameSize*5)/[encoderDescription sampleRate])] retain];
//    
//    [innerPool release];
//  }
//  
//  [pool release];
//}

//- (void)connection:(SLConnection*)connection receivedVoiceMessage:(NSData*)audioCodecData codec:(SLAudioCodecType)codec playerID:(unsigned int)playerID senderPacketCounter:(unsigned short)count
//{  
//  unsigned int frames;
//  NSData *audioData = [speex audioDataForEncodedData:audioCodecData framesDecoded:&frames];
//  
//  // convert our audio data to an ABL
//  AudioBufferList *abl = MTAudioBufferListNew(1, frames * [speex frameSize], NO);
//  
//  // copy in the audio
//  abl->mBuffers[0].mNumberChannels = 1;
//  abl->mBuffers[0].mDataByteSize = [audioData length];
//  [audioData getBytes:abl->mBuffers[0].mData length:[audioData length]];
//  
//  // convert
//  unsigned int outputFrameCount = 0;
//  AudioBufferList *convertedABL = [converter audioBufferListByConvertingList:abl framesConverted:&outputFrameCount];
//  [player queueAudioBufferList:convertedABL count:outputFrameCount];
//  
//  NSLog(@"%d", [speex bitrate]);
//  
//  MTAudioBufferListDispose(abl);
//  MTAudioBufferListDispose(convertedABL);
//}

@end

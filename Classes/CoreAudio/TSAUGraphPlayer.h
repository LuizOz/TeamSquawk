//
//  TSAUGraphPlayer.h
//  TestArkAudio
//
//  Created by Matt Wright on 14/07/2009.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

@interface TSAUGraphPlayer : NSObject {
  NSThread *renderThread;
  NSMutableDictionary *inputBuffers;
  
  MTCoreAudioDevice *outputDevice;
  MTCoreAudioStreamDescription *inputStreamDescription;
  
  AUGraph outputGraph;

  AUNode outputDeviceNode;
  AudioUnit outputDeviceUnit;
  
  AUNode converterNode;
  AudioUnit converterUnit;
  
  AUNode mixerNode;
  AudioUnit mixerUnit;
  
  BOOL isInitialised;
  unsigned int availableChannels;
}

#pragma mark Init

- (id)initWithAudioDevice:(MTCoreAudioDevice*)device inputStreamDescription:(MTCoreAudioStreamDescription*)streamDesc;
- (void)dealloc;
- (void)close;

#pragma mark Threading

- (void)_createRenderThread;
- (void)_initWithAudioDevice:(MTCoreAudioDevice*)device;
- (void)_dealloc;

#pragma mark Render Callback

- (OSStatus)_inputRenderCallbackWithActionFlags:(AudioUnitRenderActionFlags*)ioActionFlags inTimeStamp:(const AudioTimeStamp*)inTimeStamp busNumber:(UInt32)inBusNumber numberOfFrames:(UInt32)inNumberFrames data:(AudioBufferList*)ioData;

#pragma mark Channels

- (int)indexForNewInputStream;
- (void)removeInputStream:(int)index;

- (unsigned long)numberOfFramesInInputStream:(unsigned int)index;
- (MTCoreAudioStreamDescription*)audioStreamDescription;

#pragma mark Controls

- (float)outputVolume;
- (void)setOutputVolume:(float)volume;

#pragma mark Audio Queue

- (unsigned int)writeAudioBufferList:(AudioBufferList*)abl toInputStream:(unsigned int)index withForRoom:(BOOL)waitForRoom;

@end

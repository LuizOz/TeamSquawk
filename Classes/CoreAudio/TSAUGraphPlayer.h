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

#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

#import <dispatch/dispatch.h>

@interface TSAUGraphPlayer : NSObject {
  NSThread *renderThread;
  NSMutableDictionary *inputBuffers;
  dispatch_queue_t queue;
  
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
  
  id delegate;
}

#pragma mark Init

- (id)initWithAudioDevice:(MTCoreAudioDevice*)device inputStreamDescription:(MTCoreAudioStreamDescription*)streamDesc;
- (void)dealloc;
- (void)close;
- (id)delegate;
- (void)setDelegate:(id)aDelegate;

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

@interface NSObject (TSAUGraphPlayerDelegate)

- (void)graphPlayer:(TSAUGraphPlayer*)player bufferUnderunForInputStream:(unsigned int)index;

@end
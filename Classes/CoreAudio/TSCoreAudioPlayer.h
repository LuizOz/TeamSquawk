//
//  TSCoreAudioPlayer.h
//  TeamSquawk
//
//  Created by Matt Wright on 02/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>

@interface TSCoreAudioPlayer : NSObject {
  MTAudioBuffer *audioBuffer;
  MTCoreAudioDevice *audioDevice;
  
  BOOL isRunning;
}

- (id)initWithOutputDevice:(MTCoreAudioDevice*)device;
- (void)dealloc;

- (BOOL)isRunning;
- (void)setIsRunning:(BOOL)flag;

- (OSStatus)ioCycleForDevice:(MTCoreAudioDevice *)theDevice 
                   timeStamp:(const AudioTimeStamp *)inNow
                   inputData:(const AudioBufferList *)inInputData
                   inputTime:(const AudioTimeStamp *)inInputTime
                  outputData:(AudioBufferList *)outOutputData 
                  outputTime:(const AudioTimeStamp *)inOutputTime
                  clientData:(void *)inClientData;

- (void)queueAudioBufferList:(const AudioBufferList*)theABL count:(unsigned int)count;
- (void)queueBytesFromData:(NSData*)data numOfFrames:(unsigned int)count;

@end

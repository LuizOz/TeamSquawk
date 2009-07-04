//
//  TSAudioExtraction.h
//  TeamSquawk
//
//  Created by Matt Wright on 02/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuickTime/QuickTime.h>
#import <MTCoreAudio/MTCoreAudio.h>

@interface TSAudioExtraction : NSObject {
  MTCoreAudioStreamDescription *outputStreamDescription;
  NSData *audioFile;
  
  AudioFileID audioFileID;
  ExtAudioFileRef extAudioRef;
  SInt64 numFramesFile;
}

- (id)init;
- (id)initWithFilename:(NSString*)filename;
- (id)initWithFilename:(NSString*)filename withInternalCache:(BOOL)cache;

- (void)close;
- (void)dealloc;

- (OSStatus)openWithFilename:(NSString*)filename;
- (OSStatus)openWithFilename:(NSString*)filename withInternalCache:(BOOL)cache;

- (MTCoreAudioStreamDescription*)fileStreamDescription;

- (MTCoreAudioStreamDescription*)outputStreamDescription;
- (void)setOutputStreamDescription:(MTCoreAudioStreamDescription*)outputStreamDesc;

- (AudioBufferList*)extractNumberOfFrames:(unsigned long)frames;

- (unsigned long)position;
- (unsigned long)numOfFrames;

@end

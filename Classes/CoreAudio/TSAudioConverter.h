//
//  TSAudioConverter.h
//  TeamSquawk
//
//  Created by Matt Wright on 02/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MTCoreAudio/MTCoreAudio.h>

#import <AudioToolbox/AudioToolbox.h>

typedef struct {
  AudioBufferList *audioBufferList;
  MTCoreAudioStreamDescription *streamDesc;
  unsigned int bytesRemaining;
} TSAudioConverterProc;

@interface TSAudioConverter : NSObject {
  MTCoreAudioStreamDescription *inputStreamDescription;
  MTCoreAudioStreamDescription *outputStreamDescription;
  
  AudioConverterRef audioConverterRef;
}

- (id)initConverterWithInputStreamDescription:(MTCoreAudioStreamDescription*)anInputDesc andOutputStreamDescription:(MTCoreAudioStreamDescription*)anOutputDesc;
- (void)dealloc;
- (AudioBufferList*)audioBufferListByConvertingList:(AudioBufferList*)inputList framesConverted:(unsigned int*)frames;

@end

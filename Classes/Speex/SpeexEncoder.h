//
//  SpeexEncoder.h
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <speex/speex.h>
#import <MTCoreAudio/MTCoreAudio.h>

typedef enum {
  SpeexEncodeNarrowBandMode,
  SpeexEncodeWideBandMode,
  SpeexEncodeUltraWideBandMode,
} SpeexEncodeMode;

@interface SpeexEncoder : NSObject {
  void *speexState;
  SpeexBits speexBits;
  SpeexEncodeMode mode;
  
  unsigned int frameSize;
}

- (id)init;
- (id)initWithMode:(SpeexEncodeMode)mode;
- (void)dealloc;

- (unsigned int)frameSize;
- (float)sampleRate;
- (unsigned int)bitRate;
- (void)setBitrate:(unsigned int)bitrate;

- (MTCoreAudioStreamDescription*)encoderStreamDescription;

- (void)resetEncoder;
- (void)encodeAudioBufferList:(AudioBufferList*)audioBufferList;
- (NSData*)encodedData;

@end

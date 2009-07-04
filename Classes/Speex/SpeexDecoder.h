//
//  SpeexDecoder.h
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <speex/speex.h>

typedef enum {
  SpeexDecodeNarrowBandMode,
  SpeexDecodeWideBandMode,
  SpeexDecodeUltraWideBandMode,
} SpeexDecodeMode;

@interface SpeexDecoder : NSObject {
  void *speexState;
  SpeexBits speexBits;
  
  unsigned int frameSize;
  SpeexDecodeMode mode;
}

- (id)init;
- (id)initWithMode:(SpeexDecodeMode)mode;
- (void)dealloc;

- (unsigned int)frameSize;
- (float)sampleRate;
- (unsigned int)bitrate;

- (NSData*)audioDataForEncodedData:(NSData*)data framesDecoded:(unsigned int*)frames;

@end

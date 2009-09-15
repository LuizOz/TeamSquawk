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
#import <speex/speex.h>
#import <speex/speex_preprocess.h>
#import <speex/speex_resampler.h>
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
  SpeexPreprocessState *preprocessState;
  SpeexResamplerState *resamplerState;
  
  unsigned int frameSize;
  unsigned int inputSampleRate;
  
  void *internalEncodeBuffer;
}

- (id)init;
- (id)initWithMode:(SpeexEncodeMode)mode;
- (void)dealloc;

- (unsigned int)frameSize;
- (float)sampleRate;
- (unsigned int)bitRate;
- (void)setBitrate:(unsigned int)bitrate;
- (unsigned int)inputSampleRate;
- (void)setInputSampleRate:(unsigned int)sampleRate;

- (MTCoreAudioStreamDescription*)encoderStreamDescription;

- (void)resetEncoder;
- (void)encodeAudioBufferList:(AudioBufferList*)audioBufferList;
- (NSData*)encodedData;

@end

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

#import "SpeexDecoder.h"
#import <speex/speex_header.h>

@implementation SpeexDecoder

- (id)init
{
  return [self initWithMode:SpeexDecodeNarrowBandMode];
}

- (id)initWithMode:(SpeexDecodeMode)aMode
{
  if (self = [super init])
  {
    if (aMode == SpeexDecodeNarrowBandMode)
    {
      speexState = speex_decoder_init(&speex_nb_mode);
    }
    else if (aMode == SpeexDecodeWideBandMode)
    {
      speexState = speex_decoder_init(&speex_wb_mode);
    }
    else if (aMode == SpeexDecodeUltraWideBandMode)
    {
      speexState = speex_decoder_init(&speex_uwb_mode);
    }
    else
    {
      [self release];
      return nil;
    }
    
    mode = aMode;
    speex_bits_init(&speexBits);
    speex_decoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
  }
  return self;  
}

- (void)dealloc
{
  speex_decoder_destroy(speexState);
  speex_bits_destroy(&speexBits);
  [super dealloc];
}

- (unsigned int)frameSize
{
  return frameSize;
}

- (unsigned int)bitrate
{
  unsigned int bitrate;
  speex_decoder_ctl(speexState, SPEEX_GET_BITRATE, &bitrate);
  return bitrate;
}

- (float)sampleRate
{
  int sampleRate;
  speex_decoder_ctl(speexState, SPEEX_GET_SAMPLING_RATE, &sampleRate);
  
  return (float)sampleRate;
}

- (MTCoreAudioStreamDescription*)decoderStreamDescription
{
  MTCoreAudioStreamDescription *desc = [MTCoreAudioStreamDescription nativeStreamDescription];
  // set format
  [desc setFormatID:kAudioFormatLinearPCM];
  // set flags
  [desc setFormatFlags:kAudioFormatFlagIsSignedInteger|kAudioFormatFlagIsPacked|kAudioFormatFlagsNativeEndian];
  // 16 bit audio
  [desc setBitsPerChannel:8*sizeof(short)];
  // mono
  [desc setChannelsPerFrame:1];
  // bitrate
  [desc setSampleRate:[self sampleRate]];
  [desc setBytesPerFrame:sizeof(short)*[desc channelsPerFrame]];
  [desc setBytesPerPacket:[desc bytesPerFrame]];
  
  return desc;
}

- (void)resetDecoder
{
  speex_bits_reset(&speexBits);
}

- (NSData*)audioDataForEncodedData:(NSData*)data framesDecoded:(unsigned int*)frames
{
  NSMutableData *mutableData = [NSMutableData data];
  speex_bits_read_from(&speexBits, (char*)[data bytes], [data length]);
  
  *frames = 0;
  
  while (speex_bits_remaining(&speexBits) > 0)
  {
    short *decodeBuffer = (short*)malloc(frameSize*sizeof(short));

    int ret = speex_decode_int(speexState, &speexBits, decodeBuffer);
    if (ret == -1)
    {
      free(decodeBuffer);
      break;
    }
    
    [mutableData appendBytes:decodeBuffer length:(frameSize*sizeof(short))];
    (*frames)++;
    free(decodeBuffer);
  }
  return mutableData;
}

@end

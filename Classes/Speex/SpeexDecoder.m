//
//  SpeexDecoder.m
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SpeexDecoder.h"
#import <speex/speex_header.h>

@implementation SpeexDecoder

- (id)init
{
  return [self initWithMode:SpeexNarrowBandMode];
}

- (id)initWithMode:(SpeexDecodeMode)aMode
{
  if (self = [super init])
  {
    if (aMode == SpeexNarrowBandMode)
    {
      speexState = speex_decoder_init(&speex_nb_mode);
    }
    else if (aMode == SpeexWideBandMode)
    {
      speexState = speex_decoder_init(&speex_wb_mode);
    }
    else if (aMode == SpeexUltraWideBandMode)
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

- (float)bitRate
{
  switch (mode)
  {
    case SpeexNarrowBandMode:
      return 8000.0;
    case SpeexWideBandMode:
      return 16000.0;
    case SpeexUltraWideBandMode:
      return 32000.0;
    default:
      return NAN;
  }
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

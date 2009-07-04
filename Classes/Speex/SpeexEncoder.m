//
//  SpeexEncoder.m
//  TeamSquawk
//
//  Created by Matt Wright on 01/07/2009.
//  Copyright 2009 Matt Wright Consulting. All rights reserved.
//

#import "SpeexEncoder.h"


@implementation SpeexEncoder

- (id)init
{
  return [self initWithMode:SpeexEncodeNarrowBandMode];
}

- (id)initWithMode:(SpeexEncodeMode)aMode
{
  if (self = [super init])
  {
    mode = aMode;
    if (aMode == SpeexEncodeNarrowBandMode)
    {
      speexState = speex_encoder_init(&speex_nb_mode);
    }
    else if (aMode == SpeexEncodeWideBandMode)
    {
      speexState = speex_encoder_init(&speex_wb_mode);
    }
    else if (aMode == SpeexEncodeUltraWideBandMode)
    {
      speexState = speex_encoder_init(&speex_uwb_mode);
    }
    else
    {
      [self release];
      return nil;
    }
    
    speex_bits_init(&speexBits);
    speex_encoder_ctl(speexState, SPEEX_GET_FRAME_SIZE, &frameSize);
  }
  return self;
}

- (void)dealloc
{
  speex_encoder_destroy(speexState);
  speex_bits_destroy(&speexBits);
  [super dealloc];
}

- (unsigned int)frameSize
{
  return frameSize;
}

- (float)sampleRate
{
  switch (mode)
  {
    case SpeexEncodeNarrowBandMode:
      return 8000.0;
    case SpeexEncodeWideBandMode:
      return 16000.0;
    case SpeexEncodeUltraWideBandMode:
      return 32000.0;
    default:
      return NAN;
  }
}

- (unsigned int)bitRate
{
  unsigned int bitrate;
  speex_encoder_ctl(speexState, SPEEX_GET_BITRATE, &bitrate);
  return bitrate;
}

- (void)setBitrate:(unsigned int)bitrate
{
  speex_encoder_ctl(speexState, SPEEX_SET_BITRATE, &bitrate);
}

- (MTCoreAudioStreamDescription*)encoderStreamDescription
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
  
  NSLog(@"%@", desc);
  
  return desc;
}

- (NSData*)encodedDataForAudioBufferList:(AudioBufferList*)audioBufferList
{
  speex_bits_reset(&speexBits);
  speex_encode_int(speexState, audioBufferList->mBuffers[0].mData, &speexBits);
  
  // find out how many bits we're gonna have to write
  int nbytes = speex_bits_nbytes(&speexBits);
  char *buffer = (char*)malloc(nbytes);
  
  nbytes = speex_bits_write(&speexBits, buffer, nbytes);
  
  // copy the encoded data into an NSData
  return [NSData dataWithBytesNoCopy:buffer length:nbytes freeWhenDone:YES];
}

@end
